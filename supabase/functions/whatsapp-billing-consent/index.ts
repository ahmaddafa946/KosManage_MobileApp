import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createAdminClient, getAuthenticatedUser } from "../_shared/supabase-admin.ts";
import { corsPreflightResponse, errorResponse, jsonResponse } from "../_shared/response-helper.ts";

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return corsPreflightResponse();
  if (req.method !== "POST") return errorResponse("Method not allowed.", 405, "METHOD_NOT_ALLOWED");

  const user = await getAuthenticatedUser(req);
  if (!user) return errorResponse("Unauthorized.", 401, "UNAUTHORIZED");

  try {
    const body = await req.json();
    if (typeof body.opt_in !== "boolean") {
      return errorResponse("opt_in must be a boolean.", 400, "INVALID_INPUT");
    }
    const admin = createAdminClient();
    const timestamp = new Date().toISOString();
    const update = body.opt_in
      ? { whatsapp_billing_opt_in: true, whatsapp_billing_opt_in_at: timestamp, whatsapp_billing_opt_out_at: null, updated_at: timestamp }
      : { whatsapp_billing_opt_in: false, whatsapp_billing_opt_out_at: timestamp, updated_at: timestamp };

    const { data: tenant, error } = await admin.from("tenants")
      .update(update)
      .eq("profile_id", user.id)
      .select("id,whatsapp_billing_opt_in,whatsapp_billing_opt_in_at,whatsapp_billing_opt_out_at")
      .maybeSingle();
    if (error) throw error;
    if (!tenant) return errorResponse("Profil penyewa tidak ditemukan.", 404, "TENANT_NOT_FOUND");

    if (!body.opt_in) {
      const { error: stopError } = await admin.from("whatsapp_billing_outbox")
        .update({ status: "stopped", next_reminder_at: null, updated_at: timestamp, last_error: "Tenant opted out." })
        .eq("tenant_id", tenant.id).in("status", ["pending_approval", "sent", "failed"]);
      if (stopError) throw stopError;
    }
    return jsonResponse({ consent: tenant.whatsapp_billing_opt_in, updated_at: timestamp });
  } catch (err) {
    console.error("whatsapp-billing-consent error:", err);
    return errorResponse(err instanceof Error ? err.message : "Internal server error.", 500, "INTERNAL_ERROR");
  }
});
