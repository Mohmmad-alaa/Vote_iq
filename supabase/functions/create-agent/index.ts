import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const emailSuffix = "@voteiq.example.com";

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function normalizeUsername(username: string) {
  return username.trim();
}

function buildAgentEmail(username: string) {
  const normalized = normalizeUsername(username);
  const asciiSafe = normalized.toLowerCase();

  if (/^[a-z0-9._-]+$/.test(asciiSafe)) {
    return `${asciiSafe}${emailSuffix}`;
  }

  const bytes = new TextEncoder().encode(normalized);
  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  const encoded = btoa(binary).replaceAll("+", "-").replaceAll("/", "_")
    .replace(/=+$/g, "");
  return `u_${encoded}${emailSuffix}`;
}

async function findAuthUserByEmail(
  adminClient: ReturnType<typeof createClient>,
  email: string,
) {
  let page = 1;

  while (true) {
    const { data, error } = await adminClient.auth.admin.listUsers({
      page,
      perPage: 1000,
    });
    if (error) throw error;

    const user = data.users.find((item) => item.email === email);
    if (user) return user;
    if (data.users.length < 1000) return null;
    page += 1;
  }
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

    const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const payload = await req.json();
    const accessToken = String(payload.access_token ?? "").trim();
    if (!accessToken) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

    const { data: authData, error: authError } = await adminClient.auth.getUser(
      accessToken,
    );
    if (authError || !authData.user) {
      return jsonResponse({ error: "Unauthorized" }, 401);
    }

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
      return jsonResponse({ error: "Forbidden" }, 403);
    }

    const fullName = String(payload.full_name ?? "").trim();
    const username = normalizeUsername(String(payload.username ?? ""));
    const password = String(payload.password ?? "");
    const isAdmin = Boolean(payload.is_admin ?? false);
    const canCreateAgents = Boolean(payload.can_create_agents ?? false);

    if (!fullName || !username || !password) {
      return jsonResponse({ error: "Missing required fields" }, 400);
    }

    if (!isCallerAdmin) {
      if (isAdmin) {
        return jsonResponse({ error: "لا تملك الصلاحية لإنشاء مسؤول نظام" }, 403);
      }
      if (canCreateAgents) {
        return jsonResponse({ error: "لا تملك الصلاحية لتمكين إنشاء وكلاء لغيرك" }, 403);
      }
    }

    const { data: existingAgent, error: existingAgentError } = await adminClient
      .from("agents")
      .select("id")
      .eq("username", username)
      .maybeSingle();

    if (existingAgentError) {
      return jsonResponse({ error: existingAgentError.message }, 400);
    }

    if (existingAgent != null) {
      return jsonResponse({ error: "اسم المستخدم موجود مسبقًا" }, 409);
    }

    const email = buildAgentEmail(username);
    let authUserId: string | null = null;

    const { data: createdUserData, error: createUserError } = await adminClient
      .auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: {
          username,
          full_name: fullName,
          role: isAdmin ? "admin" : "agent",
        },
      });

    if (createUserError) {
      const message = createUserError.message ?? "";
      if (
        message.includes("already been registered") ||
        message.includes("already registered") ||
        message.includes("duplicate")
      ) {
        const existingUser = await findAuthUserByEmail(adminClient, email);
        if (existingUser == null) {
          return jsonResponse({ error: message }, 409);
        }
        authUserId = existingUser.id;
      } else {
        return jsonResponse({ error: message }, 400);
      }
    } else {
      authUserId = createdUserData.user?.id ?? null;
    }

    if (!authUserId) {
      return jsonResponse({ error: "Failed to create auth user" }, 500);
    }

    const { data: agentRow, error: agentInsertError } = await adminClient
      .from("agents")
      .upsert({
        id: authUserId,
        full_name: fullName,
        username,
        role: isAdmin ? "admin" : "agent",
        is_active: true,
        can_create_agents: canCreateAgents,
        created_by: authData.user.id,
      }, { onConflict: "id" })
      .select()
      .single();

    if (agentInsertError) {
      return jsonResponse({ error: agentInsertError.message }, 400);
    }

    return jsonResponse(agentRow);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    return jsonResponse({ error: message }, 500);
  }
});
