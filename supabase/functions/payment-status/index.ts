/**
 * Edge Function: /payment-status
 * Syncs transaction status from Midtrans to Supabase on demand.
 * 
 * Request: POST { order_id: string }
 * Security: Requires authenticated user (tenant or owner).
 */
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { getPaymentGateway } from "../_shared/midtrans-provider.ts";
import { jsonResponse, errorResponse, corsPreflightResponse } from "../_shared/response-helper.ts";

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();

  try {
    const user = await getAuthenticatedUser(req);
    if (!user) return errorResponse("Unauthorized", 401, "UNAUTHORIZED");

    const body = await req.json();
    const { order_id } = body;

    if (!order_id) {
      return errorResponse("order_id is required.");
    }

    const admin = createAdminClient();

    // 1. Find transaction and check access
    const { data: tx, error: txError } = await admin
      .from("payment_transactions")
      .select("id, payment_id, tenant_id, status, payments(property_id)")
      .eq("order_id", order_id)
      .single();

    if (txError || !tx) {
      return errorResponse("Transaction not found", 404, "NOT_FOUND");
    }

    // Verify access: user must be the tenant or the property owner
    let hasAccess = false;

    // Check if user is tenant
    const { data: tenant } = await admin
      .from("tenants")
      .select("profile_id")
      .eq("id", tx.tenant_id)
      .single();
    
    if (tenant?.profile_id === user.id) {
      hasAccess = true;
    } else {
      // Check if user is owner
      // deno-lint-ignore no-explicit-any
      const propertyId = (tx.payments as any)?.property_id;
      if (propertyId) {
        const { data: prop } = await admin
          .from("properties")
          .select("owner_id")
          .eq("id", propertyId)
          .single();
        if (prop?.owner_id === user.id) {
          hasAccess = true;
        }
      }
    }

    if (!hasAccess) {
      return errorResponse("Forbidden", 403, "FORBIDDEN");
    }

    // 2. Fetch status from Midtrans
    const gateway = getPaymentGateway();
    let statusResult;
    try {
      statusResult = await gateway.getTransactionStatus(order_id);
    } catch (e) {
      console.error("Gateway error:", e);
      return errorResponse("Failed to fetch status from gateway", 502, "GATEWAY_ERROR");
    }

    // 3. Map status and trigger update if changed (similar to webhook logic)
    const mapGatewayStatus = (s: string): string => {
      switch (s) {
        case "settlement":
        case "capture":
          return "success";
        case "pending":
          return "pending";
        case "deny":
        case "failure":
          return "failed";
        case "expire":
          return "expired";
        case "cancel":
          return "cancelled";
        default:
          return s; // Keep original if unknown
      }
    };

    const newStatus = mapGatewayStatus(statusResult.transactionStatus);

    if (newStatus !== tx.status && tx.status !== "success") {
       // Only update if changed and current is not success.
       // Ideally we'd just dispatch this to the same logic as webhook, but since 
       // webhook is asynchronous and we might need an immediate update for the UI:
       
       const txUpdate: Record<string, unknown> = {
         status: newStatus,
         updated_at: new Date().toISOString(),
       };
       if (newStatus === "success") {
         txUpdate.paid_at = new Date().toISOString();
         txUpdate.gateway_reference = statusResult.transactionId;
       }

       await admin
         .from("payment_transactions")
         .update(txUpdate)
         .eq("id", tx.id);
       
       // Note: We don't do the full invoice settlement here to avoid race conditions with webhook.
       // The webhook is the source of truth for settlement. We just update the tx status.
       // However, if we absolutely must, we could duplicate the webhook settlement logic here.
       // Let's rely on webhook for actual settlement.
    }

    return jsonResponse({
      order_id: order_id,
      transaction_status: statusResult.transactionStatus,
      mapped_status: newStatus,
      changed: newStatus !== tx.status
    });

  } catch (err) {
    console.error("payment-status error:", err);
    return errorResponse(
      err instanceof Error ? err.message : "Internal server error",
      500,
      "INTERNAL_ERROR"
    );
  }
});
