const { createClient } = require('@supabase/supabase-js');

const ALLOWED_ROLES = ['admin', 'serv_escolares', 'coordinador'];

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const SUPABASE_URL = process.env.SUPABASE_URL;
  const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
  const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY;

  if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY || !SUPABASE_ANON_KEY) {
    return res.status(500).json({ error: 'Server env not configured (SUPABASE_URL / SUPABASE_SERVICE_KEY / SUPABASE_ANON_KEY)' });
  }

  const authHeader = req.headers.authorization || '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!token) return res.status(401).json({ error: 'Missing bearer token' });

  let body = req.body;
  if (typeof body === 'string') {
    try { body = JSON.parse(body); } catch (_) { body = {}; }
  }
  const email = (body && body.email || '').toString().trim();
  const password = (body && body.password || '').toString();
  if (!email || !password) return res.status(400).json({ error: 'email and password are required' });

  const sbClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: userData, error: userErr } = await sbClient.auth.getUser(token);
  if (userErr || !userData || !userData.user) {
    return res.status(401).json({ error: 'Invalid or expired token' });
  }
  const supabaseUid = userData.user.id;

  const { data: caller, error: callerErr } = await sbClient
    .from('usuarios')
    .select('id_usuario, roles:roles!inner(nombre)')
    .eq('supabase_uid', supabaseUid)
    .single();
  if (callerErr || !caller) {
    return res.status(403).json({ error: 'Caller not found in usuarios' });
  }
  const callerRole = caller.roles && caller.roles.nombre;
  if (!ALLOWED_ROLES.includes(callerRole)) {
    return res.status(403).json({ error: 'Caller role not authorized: ' + (callerRole || 'unknown') });
  }

  const sbAdmin = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data: created, error: createErr } = await sbAdmin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
  });
  if (createErr) {
    return res.status(400).json({ error: createErr.message || 'Could not create user' });
  }

  return res.status(200).json({ uid: created.user && created.user.id });
};
