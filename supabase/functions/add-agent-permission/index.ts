import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const supabaseServiceRoleKey = Deno.env.get("SERVICE_ROLE_KEY") ??
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      return jsonResponse({ error: "Missing Supabase environment variables" }, 500);
    }

    const payload = await req.json();
    const accessToken = String(payload.access_token ?? "").trim();
    const agentId = String(payload.agent_id ?? "").trim();
    const familyId = payload.family_id == null ? null : Number(payload.family_id);
    const subClanId = payload.sub_clan_id == null
      ? null
      : Number(payload.sub_clan_id);

    if (!accessToken || !agentId) {
      return jsonResponse({ error: "Missing required fields" }, 400);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey);
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const { data: authData, error: authError } = await userClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { data: callerAgent, error: callerError } = await adminClient
      .from("agents")
      .select("id, role, is_active")
      .eq("id", authData.user.id)
      .maybeSingle();

    if (callerError) {
      return jsonResponse({ error: callerError.message }, 403);
    }

    if (
      callerAgent == null || callerAgent["role"] !== "admin" ||
      callerAgent["is_active"] != true
    ) {
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    if (familyId == null && subClanId != null) {
      return jsonResponse({ error: "family_id is required with sub_clan_id" }, 400);
    }

    const { data: targetAgent, error: targetError } = await adminClient
      .from("agents")
      .select("id")
      .eq("id", agentId)
      .maybeSingle();

    if (targetError || targetAgent == null) {
      return jsonResponse({ error: "Target agent not found" }, 404);
    }

    let duplicateCheck;
    if (familyId == null && subClanId == null) {
      duplicateCheck = await adminClient
        .from("agent_permissions")
        .select("id")
        .eq("agent_id", agentId)
        .is("family_id", null)
        .is("sub_clan_id", null)
        .limit(1)
        .maybeSingle();
    } else if (familyId != null && subClanId == null) {
      duplicateCheck = await adminClient
        .from("agent_permissions")
        .select("id")
        .eq("agent_id", agentId)
        .eq("family_id", familyId)
        .is("sub_clan_id", null)
        .limit(1)
        .maybeSingle();
    } else {
      duplicateCheck = await adminClient
        .from("agent_permissions")
        .select("id")
        .eq("agent_id", agentId)
        .eq("family_id", familyId)
        .eq("sub_clan_id", subClanId)
        .limit(1)
        .maybeSingle();
    }

    const { data: existingPermission, error: duplicateError } = duplicateCheck;

    if (duplicateError) {
      return jsonResponse({ error: duplicateError.message }, 400);
    }

    if (existingPermission != null) {
      return jsonResponse({ error: "الصلاحية موجودة مسبقًا" }, 409);
    }

    const { data: inserted, error: insertError } = await adminClient
      .from("agent_permissions")
      .insert({
        agent_id: agentId,
        family_id: familyId,
        sub_clan_id: subClanId,
      })
      .select("id, agent_id, family_id, sub_clan_id")
      .single();

    if (insertError) {
      return jsonResponse({ error: insertError.message }, 400);
    }

    return jsonResponse(inserted);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 500);
  }
});
