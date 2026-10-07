/**
 * Standardized JSON response helpers for Edge Functions.
 */

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

export function jsonResponse(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

export function errorResponse(
  message: string,
  status = 400,
  code?: string,
): Response {
  return jsonResponse({ error: message, code: code ?? "BAD_REQUEST" }, status);
}

export function corsPreflightResponse(): Response {
  return new Response("ok", { headers: CORS_HEADERS });
}
