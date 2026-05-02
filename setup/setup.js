/**
 * setup.js — Instalación automática del Sistema Escolar TECNM en Supabase
 *
 * Uso:
 *   1. Copia .env.example → .env y rellena tus credenciales
 *   2. npm install
 *   3. node setup.js
 */

require('dotenv').config();
const { Client } = require('pg');
const fs   = require('fs');
const path = require('path');

const DB_URL             = process.env.DB_URL;
const SUPABASE_URL        = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY;
const TEST_PASSWORD       = process.env.TEST_PASSWORD || 'Escolar2025!';

// ── Validar variables de entorno ─────────────────────────────────────────────
function validarEnv() {
  const faltantes = ['DB_URL','SUPABASE_URL','SUPABASE_SERVICE_KEY'].filter(k => !process.env[k]);
  if (faltantes.length) {
    console.error('\n❌  Faltan variables de entorno:', faltantes.join(', '));
    console.error('   Copia .env.example → .env y rellena los valores.\n');
    process.exit(1);
  }
}

// ── Colores de consola ────────────────────────────────────────────────────────
const ok  = txt => `\x1b[32m✓\x1b[0m  ${txt}`;
const err = txt => `\x1b[31m✗\x1b[0m  ${txt}`;
const hdr = txt => `\n\x1b[1m\x1b[34m${txt}\x1b[0m`;

// ── Paso 1: Ejecutar archivos SQL ─────────────────────────────────────────────
async function ejecutarSQL(client, archivo) {
  const sqlPath = path.join(__dirname, '..', 'supabase', archivo);
  const sql = fs.readFileSync(sqlPath, 'utf8');
  await client.query(sql);
  console.log(ok(archivo));
}

async function instalarEsquema() {
  console.log(hdr('Paso 1/3 — Instalando esquema en Supabase PostgreSQL'));

  const client = new Client({
    connectionString: DB_URL,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();
  console.log(ok('Conexión a la base de datos establecida'));

  const archivos = [
    '01_schema.sql',
    '02_funciones.sql',
    '03_procedimientos.sql',
    '04_triggers.sql',
    '05_vistas.sql',
    '06_seed.sql',
  ];

  for (const archivo of archivos) {
    try {
      await ejecutarSQL(client, archivo);
    } catch (e) {
      console.error(err(`${archivo}: ${e.message}`));
      await client.end();
      throw e;
    }
  }

  await client.end();
}

// ── Paso 2: Crear usuarios en Supabase Auth ───────────────────────────────────
const USUARIOS_PRUEBA = [
  { email: 'mperez@mazatlan.tecnm.mx',      nombre: 'Mario Pérez',        rol: 'admin' },
  { email: 'ecampos@mazatlan.tecnm.mx',     nombre: 'Ernesto Campos',     rol: 'coordinador' },
  { email: 'cruiz@mazatlan.tecnm.mx',       nombre: 'Carmen Ruiz',        rol: 'serv_escolares' },
  { email: 'pmora@mazatlan.tecnm.mx',       nombre: 'Patricia Mora',      rol: 'vinculacion' },
  { email: 'clopez@mazatlan.tecnm.mx',      nombre: 'Claudia López',      rol: 'docente' },
  { email: 'cramirez@mazatlan.tecnm.mx',    nombre: 'Carlos Ramírez',     rol: 'docente' },
  { email: '21310001@mazatlan.tecnm.mx',    nombre: 'Ana García',         rol: 'alumno' },
  { email: '21310002@mazatlan.tecnm.mx',    nombre: 'Carlos López',       rol: 'alumno' },
  { email: '21310003@mazatlan.tecnm.mx',    nombre: 'Diana Ramírez',      rol: 'alumno' },
  { email: '21310004@mazatlan.tecnm.mx',    nombre: 'Eduardo Torres',     rol: 'alumno' },
  { email: '21310005@mazatlan.tecnm.mx',    nombre: 'Fernanda Mendoza',   rol: 'alumno' },
];

async function crearUsuarioAuth(email, password) {
  const res = await fetch(`${SUPABASE_URL}/auth/v1/admin/users`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_SERVICE_KEY}`,
      'apikey': SUPABASE_SERVICE_KEY,
    },
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
    }),
  });

  const data = await res.json();
  if (!res.ok) {
    // Si ya existe, no es error real
    if (data?.msg?.includes('already') || data?.code === 'email_exists') {
      return { exists: true };
    }
    throw new Error(data?.msg || data?.message || JSON.stringify(data));
  }
  return data;
}

async function crearUsuariosAuth() {
  console.log(hdr('Paso 2/3 — Creando usuarios en Supabase Auth'));

  const uids = {};
  for (const u of USUARIOS_PRUEBA) {
    try {
      const data = await crearUsuarioAuth(u.email, TEST_PASSWORD);
      if (data.exists) {
        console.log(`   (ya existe) ${u.email}`);
      } else {
        uids[u.email] = data.id;
        console.log(ok(`${u.email}  (${u.rol})`));
      }
    } catch (e) {
      console.error(err(`${u.email}: ${e.message}`));
    }
  }
  return uids;
}

// ── Paso 3: Vincular supabase_uid en tabla usuarios ───────────────────────────
async function vincularUIDs() {
  console.log(hdr('Paso 3/3 — Vinculando Auth UIDs con tabla usuarios'));

  const client = new Client({
    connectionString: DB_URL,
    ssl: { rejectUnauthorized: false },
  });

  await client.connect();

  await client.query(`
    UPDATE usuarios u
    SET supabase_uid = a.id::UUID
    FROM auth.users a
    WHERE a.email = u.email
      AND u.supabase_uid IS NULL;
  `);

  const { rows } = await client.query(`SELECT COUNT(*) AS vinculados FROM usuarios WHERE supabase_uid IS NOT NULL`);
  console.log(ok(`${rows[0].vinculados} usuarios vinculados con Auth`));

  // Configurar permisos para PostgREST
  await client.query(`
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION inscribir_alumno(INT,INT) TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION baja_inscripcion(INT,VARCHAR) TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION capturar_calificacion_final(INT,NUMERIC,INT) TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION firmar_acta(INT,INT) TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION registrar_pago(INT,NUMERIC,TEXT,VARCHAR,INT) TO anon, authenticated;
    GRANT EXECUTE ON FUNCTION solicitar_constancia(INT,INT,BOOLEAN) TO anon, authenticated;
    GRANT INSERT, UPDATE ON notificaciones TO authenticated;
    GRANT INSERT ON inscripciones TO authenticated;
  `);
  console.log(ok('Permisos de PostgREST configurados'));

  await client.end();
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  console.log('\n╔══════════════════════════════════════════════════════╗');
  console.log('║   Sistema Escolar TECNM — Instalación automática    ║');
  console.log('╚══════════════════════════════════════════════════════╝');

  validarEnv();

  try {
    await instalarEsquema();
    await crearUsuariosAuth();
    await vincularUIDs();

    console.log('\n\x1b[32m\x1b[1m✓  Instalación completada.\x1b[0m');
    console.log('\nAhora abre Sistema Escolar.html y entra con:');
    console.log(`   Alumno  →  21310001@mazatlan.tecnm.mx  /  ${TEST_PASSWORD}`);
    console.log(`   Docente →  clopez@mazatlan.tecnm.mx    /  ${TEST_PASSWORD}`);
    console.log(`   Admin   →  mperez@mazatlan.tecnm.mx    /  ${TEST_PASSWORD}\n`);
  } catch (e) {
    console.error('\n❌  La instalación falló:', e.message);
    process.exit(1);
  }
}

main();
