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

    if (!accessToken || !agentId) {
      return jsonResponse({ error: "Missing required fields: access_token, agent_id" }, 400);
    }

    const userClient = createClient(supabaseUrl, supabaseAnonKey);
    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    // 1. Authenticate caller
    const { data: authData, error: authError } = await userClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    // 2. Check if caller is admin or supervisor
    const { data: callerAgent, error: callerError } = await adminClient
      .from("agents")
      .select("id, role, is_active, can_create_agents")
      .eq("id", authData.user.id)
      .maybeSingle();

    if (callerError) {
      return jsonResponse({ error: callerError.message }, 403);
    }

    const isCallerAdmin = callerAgent?.role === "admin";
    const canCallerCreateAgents = callerAgent?.can_create_agents === true;

    if (
      callerAgent == null || callerAgent["is_active"] != true ||
      (!isCallerAdmin && !canCallerCreateAgents)
    ) {
      return jsonResponse({ error: "Forbidden: Only active admins or supervisors can delete agents" }, 403);
    }

    // 3. Prevent self-deletion if desired (optional but good practice)
    if (authData.user.id === agentId) {
      return jsonResponse({ error: "لا يٌسمح للوكيل بحذف حسابه الشخصي" }, 403);
    }

    // 4. Ensure target agent exists and is not the primary admin
    const { data: targetAgent, error: targetError } = await adminClient
      .from("agents")
      .select("username, role")
      .eq("id", agentId)
      .maybeSingle();

    if (targetError || !targetAgent) {
      return jsonResponse({ error: "الوكيل غير موجود" }, 404);
    }

    if (targetAgent.username === "admin") {
      return jsonResponse({ error: "لا يمكن حذف مسؤول النظام الأساسي" }, 403);
    }

    if (!isCallerAdmin && targetAgent.role === "admin") {
      return jsonResponse({ error: "لا تملك الصلاحية لحذف مسؤول نظام" }, 403);
    }

    // 5. Clear references to allow deletion
    // If the agent has updated any voters, set updated_by to null
    await adminClient
      .from("voters")
      .update({ updated_by: null })
      .eq("updated_by", agentId);

    // 6. Manually delete from agents table to prevent auth.users foreign key errors
    await adminClient
      .from("agents")
      .delete()
      .eq("id", agentId);

    // 7. Delete agent from auth.users
    const { error: deleteUserError } = await adminClient.auth.admin.deleteUser(
      agentId,
    );

    if (deleteUserError) {
      return jsonResponse({ error: deleteUserError.message }, 400);
    }

    return jsonResponse({ success: true, message: `Successfully deleted agent ${agentId}` });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 500);
  }
});
