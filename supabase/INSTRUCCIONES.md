# Instrucciones de instalación — Sistema Escolar TECNM

## Requisitos previos
- Cuenta gratuita en [supabase.com](https://supabase.com)
- Node.js 18 o superior instalado ([nodejs.org](https://nodejs.org))
- Navegador moderno (Chrome, Edge, Firefox)

---

## 1. Crear proyecto en Supabase

1. Entra a [app.supabase.com](https://app.supabase.com) → **New project**
2. Nombre: `sistema-escolar` (o el que prefieras)
3. Contraseña de base de datos: **guárdala**, la necesitarás en el paso 3
4. Región: la más cercana a México (`us-east-1` o `us-west-1`)
5. Plan: **Free** → Create project (espera ~2 min)

---

## 2. Habilitar extensión pgcrypto

1. En el panel ve a **Database → Extensions**
2. Busca `pgcrypto` y actívala
3. Es requerida por `firmar_acta` para generar el hash SHA-256

---

## 3. Instalar todo automáticamente (un solo comando)

El script `setup/setup.js` hace todo por ti: crea tablas, funciones, triggers, vistas, datos de prueba y usuarios de Auth.

### 3.1 Obtener credenciales

Necesitas 3 valores del panel de Supabase:

| Valor | Dónde encontrarlo |
|-------|-------------------|
| **DB_URL** | Settings → Database → Connection string → URI |
| **SUPABASE_URL** | Settings → API → Project URL |
| **SUPABASE_SERVICE_KEY** | Settings → API → `service_role` secret key |

### 3.2 Crear el archivo .env

Abre la carpeta `setup/`, copia `.env.example` → `.env` y rellena los 3 valores:

```
DB_URL=postgres://postgres:[TU_PASSWORD]@db.[REF].supabase.co:5432/postgres
SUPABASE_URL=https://[REF].supabase.co
SUPABASE_SERVICE_KEY=eyJ...
```

### 3.3 Ejecutar el script

Abre una terminal en la carpeta `setup/` y corre:

```bash
npm install
node setup.js
```

El script hace automáticamente:
- Ejecuta los 6 archivos SQL en orden (schema, funciones, procedimientos, triggers, vistas, seed)
- Crea los 11 usuarios de prueba en Supabase Auth
- Vincula los UIDs de Auth con la tabla `usuarios`
- Configura los permisos de PostgREST

---

## 4. Configurar el HTML

Abre `Sistema Escolar.html` con cualquier editor y busca estas dos líneas:

```js
const SUPABASE_URL      = 'TU_SUPABASE_URL_AQUI';
const SUPABASE_ANON_KEY = 'TU_SUPABASE_ANON_KEY_AQUI';
```

Reemplaza con:
- **SUPABASE_URL** — el mismo que usaste en `.env`
- **SUPABASE_ANON_KEY** — Settings → API → `anon` public key (diferente a la service key)

---

## 5. Abrir el sistema

Abre `Sistema Escolar.html` en el navegador (doble clic o arrastra a Chrome).

### Usuarios de prueba:

| Rol | Email | Contraseña |
|-----|-------|-----------|
| Alumno | `21310001@mazatlan.tecnm.mx` | `Escolar2025!` |
| Docente | `clopez@mazatlan.tecnm.mx` | `Escolar2025!` |
| Admin | `mperez@mazatlan.tecnm.mx` | `Escolar2025!` |

---

## Notas

- El HTML es **completamente autocontenido** — no requiere servidor ni npm
- La `anon key` es segura para el frontend — solo da acceso a lo que permiten las políticas RLS
- La `service_role key` **nunca** debe ir en el HTML, solo en el script de instalación
