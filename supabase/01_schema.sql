-- ====================================================
-- SISTEMA ESCOLAR INTEGRAL - TECNM Campus Mazatlán
-- PostgreSQL / Supabase  -  01_schema.sql
-- Ejecutar en: Supabase Dashboard → SQL Editor
-- ====================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ── CUSTOM TYPES ─────────────────────────────────────
DO $$ BEGIN CREATE TYPE t_estatus_alumno      AS ENUM ('activo','baja_temporal','baja_definitiva','egresado','titulado','irregular'); EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estatus_inscripcion AS ENUM ('inscrito','baja','acreditada','no_acreditada','en_curso');                    EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_periodo      AS ENUM ('programado','inscripcion','en_curso','cerrado');                              EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_grupo        AS ENUM ('abierto','cerrado','lleno','cancelado');                                     EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_tipo_materia        AS ENUM ('basica','especialidad','optativa','complementaria');                         EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_tipo_salon          AS ENUM ('aula','laboratorio','taller','auditorio');                                   EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_acta         AS ENUM ('borrador','firmada','rectificada');                                          EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estatus_kardex      AS ENUM ('aprobada','reprobada','equivalencia','revalidacion');                        EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_asistencia          AS ENUM ('P','F','J','R');                                                             EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_adeudo       AS ENUM ('pendiente','pagado','vencido','cancelado');                                  EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_metodo_pago         AS ENUM ('efectivo','deposito','transferencia','tarjeta','en_linea');                  EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_tipo_baja           AS ENUM ('temporal','definitiva');                                                     EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_tipo_notif          AS ENUM ('info','warn','success','danger');                                            EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_accion_audit        AS ENUM ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','OTRO');                          EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_grado_academico     AS ENUM ('licenciatura','maestria','doctorado','especialidad');                        EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_tipo_contrato       AS ENUM ('base','contrato','honorarios','interino');                                   EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_empresa      AS ENUM ('vigente','por_renovar','vencido','suspendido');                              EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_servicio     AS ENUM ('pendiente','activo','liberado','cancelado');                                 EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_residencia   AS ENUM ('registrada','en_curso','terminada','cancelada');                             EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estatus_laboral     AS ENUM ('empleado','posgrado','buscando','emprendedor','no_localizado');              EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_constancia   AS ENUM ('pendiente','en_proceso','lista','entregada','rechazada');                   EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_titulacion   AS ENUM ('en_proceso','autorizado','titulado','cancelado');                           EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_equivalencia AS ENUM ('pendiente','aprobada','rechazada');                                         EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_baja         AS ENUM ('pendiente','aprobada','rechazada','reactivada');                            EXCEPTION WHEN duplicate_object THEN null; END $$;
DO $$ BEGIN CREATE TYPE t_estado_doc          AS ENUM ('pendiente','verificado','rechazado');                                       EXCEPTION WHEN duplicate_object THEN null; END $$;

-- ── 1. RBAC ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS roles (
  id_rol         SERIAL PRIMARY KEY,
  nombre         VARCHAR(50)  NOT NULL UNIQUE,
  descripcion    VARCHAR(255),
  activo         BOOLEAN      DEFAULT TRUE,
  fecha_creacion TIMESTAMPTZ  DEFAULT NOW()
);

-- usuarios vincula con auth.users de Supabase por supabase_uid
CREATE TABLE IF NOT EXISTS usuarios (
  id_usuario        SERIAL PRIMARY KEY,
  supabase_uid      UUID        UNIQUE,
  email             VARCHAR(120) NOT NULL UNIQUE,
  id_rol            INT         NOT NULL REFERENCES roles(id_rol),
  nombres           VARCHAR(100) NOT NULL,
  apellido_pat      VARCHAR(80)  NOT NULL,
  apellido_mat      VARCHAR(80),
  telefono          VARCHAR(20),
  foto_url          VARCHAR(255),
  activo            BOOLEAN     DEFAULT TRUE,
  ultimo_acceso     TIMESTAMPTZ,
  intentos_fallidos SMALLINT    DEFAULT 0,
  bloqueado         BOOLEAN     DEFAULT FALSE,
  fecha_creacion    TIMESTAMPTZ DEFAULT NOW(),
  fecha_modif       TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_usuarios_email ON usuarios(email);
CREATE INDEX IF NOT EXISTS idx_usuarios_rol   ON usuarios(id_rol, activo);

CREATE TABLE IF NOT EXISTS permisos (
  id_permiso  SERIAL PRIMARY KEY,
  modulo      VARCHAR(50) NOT NULL,
  accion      VARCHAR(20) NOT NULL,
  descripcion VARCHAR(255),
  UNIQUE(modulo, accion)
);

CREATE TABLE IF NOT EXISTS roles_permisos (
  id_rol     INT NOT NULL REFERENCES roles(id_rol)     ON DELETE CASCADE,
  id_permiso INT NOT NULL REFERENCES permisos(id_permiso) ON DELETE CASCADE,
  PRIMARY KEY(id_rol, id_permiso)
);

-- ── 2. CATÁLOGOS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS carreras (
  id_carrera     SERIAL PRIMARY KEY,
  clave          VARCHAR(10)  NOT NULL UNIQUE,
  nombre         VARCHAR(120) NOT NULL,
  duracion_sem   SMALLINT     NOT NULL DEFAULT 9,
  creditos_total SMALLINT     NOT NULL,
  activa         BOOLEAN      DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS planes_estudio (
  id_plan       SERIAL PRIMARY KEY,
  id_carrera    INT         NOT NULL REFERENCES carreras(id_carrera),
  clave_plan    VARCHAR(20) NOT NULL,
  nombre        VARCHAR(120) NOT NULL,
  anio_vigencia INT         NOT NULL,
  activo        BOOLEAN     DEFAULT TRUE,
  UNIQUE(id_carrera, clave_plan)
);

CREATE TABLE IF NOT EXISTS especialidades (
  id_especialidad SERIAL PRIMARY KEY,
  id_carrera      INT         NOT NULL REFERENCES carreras(id_carrera),
  clave           VARCHAR(10) NOT NULL,
  nombre          VARCHAR(120) NOT NULL,
  activa          BOOLEAN     DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS materias (
  id_materia     SERIAL PRIMARY KEY,
  id_plan        INT          NOT NULL REFERENCES planes_estudio(id_plan),
  clave          VARCHAR(15)  NOT NULL,
  nombre         VARCHAR(150) NOT NULL,
  creditos       SMALLINT     NOT NULL,
  horas_teoria   SMALLINT     DEFAULT 0,
  horas_practica SMALLINT     DEFAULT 0,
  semestre_sug   SMALLINT,
  tipo           t_tipo_materia DEFAULT 'basica',
  activa         BOOLEAN      DEFAULT TRUE,
  UNIQUE(id_plan, clave)
);
CREATE INDEX IF NOT EXISTS idx_materias_plan_sem ON materias(id_plan, semestre_sug);

CREATE TABLE IF NOT EXISTS prerrequisitos (
  id_materia INT NOT NULL REFERENCES materias(id_materia) ON DELETE CASCADE,
  id_prerreq INT NOT NULL REFERENCES materias(id_materia) ON DELETE CASCADE,
  PRIMARY KEY(id_materia, id_prerreq),
  CONSTRAINT chk_no_self CHECK (id_materia <> id_prerreq)
);

CREATE TABLE IF NOT EXISTS salones (
  id_salon  SERIAL PRIMARY KEY,
  clave     VARCHAR(20)  NOT NULL UNIQUE,
  nombre    VARCHAR(80)  NOT NULL,
  tipo      t_tipo_salon DEFAULT 'aula',
  capacidad SMALLINT     NOT NULL,
  edificio  VARCHAR(50),
  activo    BOOLEAN      DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS periodos (
  id_periodo   SERIAL PRIMARY KEY,
  clave        VARCHAR(10) NOT NULL UNIQUE,
  fecha_inicio DATE        NOT NULL,
  fecha_fin    DATE        NOT NULL,
  insc_inicio  DATE        NOT NULL,
  insc_fin     DATE        NOT NULL,
  estado       t_estado_periodo DEFAULT 'programado',
  activo       BOOLEAN     DEFAULT TRUE
);

-- ── 3. ALUMNOS ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS alumnos (
  id_alumno       SERIAL PRIMARY KEY,
  id_usuario      INT     NOT NULL UNIQUE REFERENCES usuarios(id_usuario),
  matricula       VARCHAR(15) NOT NULL UNIQUE,
  id_carrera      INT     NOT NULL REFERENCES carreras(id_carrera),
  id_plan         INT     NOT NULL REFERENCES planes_estudio(id_plan),
  id_especialidad INT     REFERENCES especialidades(id_especialidad),
  fecha_ingreso   DATE    NOT NULL,
  semestre_actual SMALLINT DEFAULT 1,
  estatus         t_estatus_alumno DEFAULT 'activo',
  promedio_gral   NUMERIC(4,2) DEFAULT 0.00,
  creditos_acum   SMALLINT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_alumnos_carrera  ON alumnos(id_carrera, estatus);
CREATE INDEX IF NOT EXISTS idx_alumnos_matricula ON alumnos(matricula);

CREATE TABLE IF NOT EXISTS alumnos_datos (
  id_alumno        INT PRIMARY KEY REFERENCES alumnos(id_alumno) ON DELETE CASCADE,
  curp             CHAR(18),
  rfc              VARCHAR(13),
  fecha_nac        DATE,
  lugar_nac        VARCHAR(120),
  nacionalidad     VARCHAR(50) DEFAULT 'Mexicana',
  estado_civil     VARCHAR(20),
  genero           CHAR(1),
  email_personal   VARCHAR(120),
  telefono_cel     VARCHAR(20),
  calle_num        VARCHAR(150),
  colonia          VARCHAR(100),
  municipio        VARCHAR(100),
  estado           VARCHAR(50),
  cp               VARCHAR(10),
  telefono_dom     VARCHAR(20),
  emerg_nombre     VARCHAR(150),
  emerg_parentesco VARCHAR(50),
  emerg_telefono   VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS documentos_alumno (
  id_documento   SERIAL PRIMARY KEY,
  id_alumno      INT          NOT NULL REFERENCES alumnos(id_alumno) ON DELETE CASCADE,
  tipo           VARCHAR(50)  NOT NULL,
  nombre_archivo VARCHAR(255),
  url_archivo    VARCHAR(500),
  hash_sha256    CHAR(64),
  estado         t_estado_doc DEFAULT 'pendiente',
  fecha_subida   TIMESTAMPTZ  DEFAULT NOW(),
  fecha_verif    TIMESTAMPTZ,
  id_verificador INT          REFERENCES usuarios(id_usuario)
);

-- ── 4. DOCENTES ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS docentes (
  id_docente      SERIAL PRIMARY KEY,
  id_usuario      INT         NOT NULL UNIQUE REFERENCES usuarios(id_usuario),
  num_empleado    VARCHAR(15) NOT NULL UNIQUE,
  grado_academico t_grado_academico DEFAULT 'licenciatura',
  cedula_prof     VARCHAR(20),
  tipo_contrato   t_tipo_contrato   DEFAULT 'contrato',
  fecha_ingreso   DATE,
  departamento    VARCHAR(100),
  activo          BOOLEAN DEFAULT TRUE
);

-- ── 5. CARGA ACADÉMICA ────────────────────────────────
CREATE TABLE IF NOT EXISTS grupos (
  id_grupo       SERIAL PRIMARY KEY,
  clave_grupo    VARCHAR(20) NOT NULL,
  id_materia     INT         NOT NULL REFERENCES materias(id_materia),
  id_docente     INT         NOT NULL REFERENCES docentes(id_docente),
  id_periodo     INT         NOT NULL REFERENCES periodos(id_periodo),
  id_salon       INT         REFERENCES salones(id_salon),
  cupo_max       SMALLINT    NOT NULL DEFAULT 35,
  cupo_actual    SMALLINT    NOT NULL DEFAULT 0,
  estado         t_estado_grupo DEFAULT 'abierto',
  fecha_creacion TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(clave_grupo, id_periodo),
  CONSTRAINT chk_cupos CHECK (cupo_actual >= 0 AND cupo_actual <= cupo_max)
);
CREATE INDEX IF NOT EXISTS idx_grupos_periodo ON grupos(id_periodo, estado);
CREATE INDEX IF NOT EXISTS idx_grupos_materia ON grupos(id_materia, id_periodo);

CREATE TABLE IF NOT EXISTS horarios_grupo (
  id_horario  SERIAL PRIMARY KEY,
  id_grupo    INT      NOT NULL REFERENCES grupos(id_grupo) ON DELETE CASCADE,
  dia_semana  SMALLINT NOT NULL,  -- 1=Lun … 7=Dom
  hora_inicio TIME     NOT NULL,
  hora_fin    TIME     NOT NULL,
  id_salon    INT      NOT NULL REFERENCES salones(id_salon),
  CONSTRAINT chk_horario CHECK (hora_fin > hora_inicio)
);
CREATE INDEX IF NOT EXISTS idx_hor_dia   ON horarios_grupo(dia_semana, hora_inicio, hora_fin);
CREATE INDEX IF NOT EXISTS idx_hor_salon ON horarios_grupo(id_salon, dia_semana);

CREATE TABLE IF NOT EXISTS inscripciones (
  id_inscripcion  SERIAL PRIMARY KEY,
  id_alumno       INT     NOT NULL REFERENCES alumnos(id_alumno),
  id_grupo        INT     NOT NULL REFERENCES grupos(id_grupo),
  fecha_insc      TIMESTAMPTZ DEFAULT NOW(),
  estado          t_estatus_inscripcion DEFAULT 'inscrito',
  cal_p1          NUMERIC(4,2),
  cal_p2          NUMERIC(4,2),
  cal_final       NUMERIC(4,2),
  porc_asistencia NUMERIC(5,2),
  fecha_baja      TIMESTAMPTZ,
  motivo_baja     VARCHAR(255),
  UNIQUE(id_alumno, id_grupo),
  CONSTRAINT chk_cal_p1    CHECK (cal_p1    IS NULL OR cal_p1    BETWEEN 0 AND 10),
  CONSTRAINT chk_cal_p2    CHECK (cal_p2    IS NULL OR cal_p2    BETWEEN 0 AND 10),
  CONSTRAINT chk_cal_final CHECK (cal_final IS NULL OR cal_final BETWEEN 0 AND 10)
);
CREATE INDEX IF NOT EXISTS idx_insc_alumno ON inscripciones(id_alumno, estado);
CREATE INDEX IF NOT EXISTS idx_insc_grupo  ON inscripciones(id_grupo,  estado);

CREATE TABLE IF NOT EXISTS asistencias (
  id_asistencia  SERIAL PRIMARY KEY,
  id_inscripcion INT     NOT NULL REFERENCES inscripciones(id_inscripcion) ON DELETE CASCADE,
  fecha_sesion   DATE    NOT NULL,
  estado         t_asistencia NOT NULL,
  registrado_por INT     REFERENCES usuarios(id_usuario),
  fecha_registro TIMESTAMPTZ DEFAULT NOW(),
  observaciones  VARCHAR(255),
  UNIQUE(id_inscripcion, fecha_sesion)
);
CREATE INDEX IF NOT EXISTS idx_asist_fecha ON asistencias(fecha_sesion);

-- ── 6. ACTAS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS actas (
  id_acta      SERIAL PRIMARY KEY,
  id_grupo     INT         NOT NULL UNIQUE REFERENCES grupos(id_grupo),
  fecha_cierre TIMESTAMPTZ,
  hash_firma   CHAR(64),
  codigo_verif VARCHAR(20) UNIQUE,
  firmada_por  INT         REFERENCES docentes(id_docente),
  estado       t_estado_acta DEFAULT 'borrador'
);

-- ── 7. KÁRDEX ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kardex (
  id_kardex      SERIAL PRIMARY KEY,
  id_alumno      INT          NOT NULL REFERENCES alumnos(id_alumno),
  id_materia     INT          NOT NULL REFERENCES materias(id_materia),
  id_periodo     INT          NOT NULL REFERENCES periodos(id_periodo),
  calificacion   NUMERIC(4,2) NOT NULL,
  oportunidad    SMALLINT     DEFAULT 1,
  estatus        t_estatus_kardex NOT NULL,
  creditos       SMALLINT     NOT NULL,
  fecha_registro TIMESTAMPTZ  DEFAULT NOW(),
  UNIQUE(id_alumno, id_materia, oportunidad)
);
CREATE INDEX IF NOT EXISTS idx_kardex_alumno ON kardex(id_alumno, id_periodo);

-- ── 8. PAGOS ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS conceptos_pago (
  id_concepto SERIAL PRIMARY KEY,
  clave       VARCHAR(20)  UNIQUE,
  descripcion VARCHAR(150) NOT NULL,
  monto       NUMERIC(10,2) NOT NULL,
  recurrente  BOOLEAN DEFAULT FALSE,
  activo      BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS adeudos (
  id_adeudo    SERIAL PRIMARY KEY,
  id_alumno    INT           NOT NULL REFERENCES alumnos(id_alumno),
  id_concepto  INT           NOT NULL REFERENCES conceptos_pago(id_concepto),
  id_periodo   INT           REFERENCES periodos(id_periodo),
  monto        NUMERIC(10,2) NOT NULL,
  fecha_gen    DATE          NOT NULL,
  fecha_venc   DATE          NOT NULL,
  ref_bancaria VARCHAR(30)   UNIQUE,
  estado       t_estado_adeudo DEFAULT 'pendiente'
);
CREATE INDEX IF NOT EXISTS idx_adeudos_alumno ON adeudos(id_alumno, estado);
CREATE INDEX IF NOT EXISTS idx_adeudos_venc   ON adeudos(fecha_venc, estado);

CREATE TABLE IF NOT EXISTS pagos (
  id_pago         SERIAL PRIMARY KEY,
  id_adeudo       INT           NOT NULL REFERENCES adeudos(id_adeudo),
  monto_pagado    NUMERIC(10,2) NOT NULL,
  fecha_pago      TIMESTAMPTZ   DEFAULT NOW(),
  metodo          t_metodo_pago NOT NULL,
  num_transaccion VARCHAR(80),
  banco           VARCHAR(50),
  registrado_por  INT           REFERENCES usuarios(id_usuario),
  comprobante_url VARCHAR(500)
);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON pagos(fecha_pago);

-- ── 9. CONSTANCIAS ────────────────────────────────────
CREATE TABLE IF NOT EXISTS tipos_constancia (
  id_tipo        SERIAL PRIMARY KEY,
  nombre         VARCHAR(100) NOT NULL,
  descripcion    VARCHAR(255),
  costo          NUMERIC(8,2) DEFAULT 0,
  tiempo_entrega VARCHAR(50),
  requiere_pago  BOOLEAN DEFAULT FALSE,
  activo         BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS solicitudes_constancia (
  id_solicitud   SERIAL PRIMARY KEY,
  id_alumno      INT        NOT NULL REFERENCES alumnos(id_alumno),
  id_tipo        INT        NOT NULL REFERENCES tipos_constancia(id_tipo),
  fecha_sol      TIMESTAMPTZ DEFAULT NOW(),
  fecha_proc     TIMESTAMPTZ,
  estado         t_estado_constancia DEFAULT 'pendiente',
  motivo_rechazo VARCHAR(255),
  url_pdf        VARCHAR(500),
  procesada_por  INT        REFERENCES usuarios(id_usuario),
  urgente        BOOLEAN    DEFAULT FALSE
);
CREATE INDEX IF NOT EXISTS idx_const_estado ON solicitudes_constancia(estado);
CREATE INDEX IF NOT EXISTS idx_const_alumno ON solicitudes_constancia(id_alumno);

-- ── 10. BAJAS ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS bajas (
  id_baja        SERIAL PRIMARY KEY,
  id_alumno      INT        NOT NULL REFERENCES alumnos(id_alumno),
  tipo           t_tipo_baja NOT NULL,
  motivo         VARCHAR(500) NOT NULL,
  fecha_sol      DATE        NOT NULL,
  fecha_efectiva DATE,
  estado         t_estado_baja DEFAULT 'pendiente',
  docs_completos BOOLEAN    DEFAULT FALSE,
  procesada_por  INT        REFERENCES usuarios(id_usuario),
  observaciones  TEXT
);
CREATE INDEX IF NOT EXISTS idx_bajas_alumno ON bajas(id_alumno);
CREATE INDEX IF NOT EXISTS idx_bajas_estado ON bajas(estado);

-- ── 11. TITULACIÓN ────────────────────────────────────
CREATE TABLE IF NOT EXISTS modalidades_titulacion (
  id_modalidad SERIAL PRIMARY KEY,
  nombre       VARCHAR(100) NOT NULL UNIQUE,
  descripcion  TEXT,
  activa       BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS procesos_titulacion (
  id_proceso      SERIAL PRIMARY KEY,
  id_alumno       INT        NOT NULL UNIQUE REFERENCES alumnos(id_alumno),
  folio           VARCHAR(30) UNIQUE,
  id_modalidad    INT        REFERENCES modalidades_titulacion(id_modalidad),
  id_asesor       INT        REFERENCES docentes(id_docente),
  fecha_solicitud DATE       NOT NULL,
  fecha_acto      DATE,
  paso_actual     SMALLINT   DEFAULT 1,
  estado          t_estado_titulacion DEFAULT 'en_proceso',
  observaciones   TEXT
);

-- ── 12. TUTORÍAS ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS tutorias_asignacion (
  id_asignacion SERIAL PRIMARY KEY,
  id_alumno     INT  NOT NULL REFERENCES alumnos(id_alumno),
  id_tutor      INT  NOT NULL REFERENCES docentes(id_docente),
  id_periodo    INT  NOT NULL REFERENCES periodos(id_periodo),
  fecha_asign   DATE NOT NULL,
  activa        BOOLEAN DEFAULT TRUE,
  UNIQUE(id_alumno, id_periodo)
);

CREATE TABLE IF NOT EXISTS tutorias_sesiones (
  id_sesion     SERIAL PRIMARY KEY,
  id_asignacion INT  NOT NULL REFERENCES tutorias_asignacion(id_asignacion) ON DELETE CASCADE,
  fecha         DATE NOT NULL,
  notas         TEXT,
  nivel_riesgo  VARCHAR(10) DEFAULT 'bajo',
  acciones      TEXT
);

-- ── 13. INSTRUMENTACIÓN ───────────────────────────────
CREATE TABLE IF NOT EXISTS instrumentaciones (
  id_instr    SERIAL PRIMARY KEY,
  id_grupo    INT     NOT NULL UNIQUE REFERENCES grupos(id_grupo) ON DELETE CASCADE,
  competencia TEXT,
  metodologia TEXT,
  publicada   BOOLEAN DEFAULT FALSE,
  fecha_pub   TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS unidades_instr (
  id_unidad      SERIAL PRIMARY KEY,
  id_instr       INT         NOT NULL REFERENCES instrumentaciones(id_instr) ON DELETE CASCADE,
  numero         SMALLINT    NOT NULL,
  titulo         VARCHAR(150) NOT NULL,
  temas          TEXT,
  horas          SMALLINT,
  criterios_eval TEXT,
  UNIQUE(id_instr, numero)
);

-- ── 14. EVALUACIÓN DOCENTE ────────────────────────────
CREATE TABLE IF NOT EXISTS eval_preguntas (
  id_pregunta SERIAL PRIMARY KEY,
  texto       VARCHAR(255) NOT NULL,
  orden       SMALLINT,
  activa      BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS eval_docente (
  id_eval        SERIAL PRIMARY KEY,
  id_inscripcion INT NOT NULL UNIQUE REFERENCES inscripciones(id_inscripcion),
  fecha          TIMESTAMPTZ DEFAULT NOW(),
  comentarios    TEXT
);

CREATE TABLE IF NOT EXISTS eval_respuestas (
  id_eval     INT      NOT NULL REFERENCES eval_docente(id_eval) ON DELETE CASCADE,
  id_pregunta INT      NOT NULL REFERENCES eval_preguntas(id_pregunta),
  calificacion SMALLINT NOT NULL,
  PRIMARY KEY(id_eval, id_pregunta),
  CONSTRAINT chk_cal_eval CHECK (calificacion BETWEEN 1 AND 5)
);

-- ── 15. EQUIVALENCIAS ────────────────────────────────
CREATE TABLE IF NOT EXISTS equivalencias (
  id_equiv           SERIAL PRIMARY KEY,
  id_alumno          INT          NOT NULL REFERENCES alumnos(id_alumno),
  institucion_origen VARCHAR(200) NOT NULL,
  materia_origen     VARCHAR(200) NOT NULL,
  id_materia_destino INT          NOT NULL REFERENCES materias(id_materia),
  creditos           SMALLINT,
  calificacion       NUMERIC(4,2),
  doc_url            VARCHAR(500),
  estado             t_estado_equivalencia DEFAULT 'pendiente',
  procesada_por      INT          REFERENCES usuarios(id_usuario),
  fecha_sol          TIMESTAMPTZ  DEFAULT NOW(),
  fecha_resol        TIMESTAMPTZ,
  observaciones      TEXT
);

CREATE TABLE IF NOT EXISTS creditos_extra (
  id_credito   SERIAL PRIMARY KEY,
  id_alumno    INT         NOT NULL REFERENCES alumnos(id_alumno),
  actividad    VARCHAR(200) NOT NULL,
  creditos     SMALLINT    NOT NULL,
  fecha        DATE        NOT NULL,
  asignado_por INT         REFERENCES usuarios(id_usuario),
  observaciones TEXT
);

-- ── 16. VINCULACIÓN ───────────────────────────────────
CREATE TABLE IF NOT EXISTS empresas (
  id_empresa      SERIAL PRIMARY KEY,
  nombre          VARCHAR(200) NOT NULL,
  rfc             VARCHAR(13),
  sector          VARCHAR(100),
  contacto_nombre VARCHAR(150),
  contacto_email  VARCHAR(120),
  contacto_tel    VARCHAR(20),
  direccion       VARCHAR(255),
  convenio_inicio DATE,
  convenio_fin    DATE,
  estado          t_estado_empresa DEFAULT 'vigente',
  activa          BOOLEAN DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS servicio_social (
  id_servicio    SERIAL PRIMARY KEY,
  id_alumno      INT     NOT NULL REFERENCES alumnos(id_alumno),
  id_empresa     INT     REFERENCES empresas(id_empresa),
  fecha_inicio   DATE,
  fecha_fin      DATE,
  horas_total    SMALLINT DEFAULT 480,
  horas_acumul   SMALLINT DEFAULT 0,
  estado         t_estado_servicio DEFAULT 'pendiente',
  url_constancia VARCHAR(500)
);

CREATE TABLE IF NOT EXISTS residencias (
  id_residencia SERIAL PRIMARY KEY,
  id_alumno     INT          NOT NULL REFERENCES alumnos(id_alumno),
  id_empresa    INT          NOT NULL REFERENCES empresas(id_empresa),
  id_asesor     INT          REFERENCES docentes(id_docente),
  proyecto      VARCHAR(255) NOT NULL,
  fecha_inicio  DATE,
  fecha_fin     DATE,
  horas_total   SMALLINT DEFAULT 480,
  horas_acumul  SMALLINT DEFAULT 0,
  estado        t_estado_residencia DEFAULT 'registrada',
  calificacion  NUMERIC(4,2)
);

-- ── 17. EGRESADOS ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS egresados (
  id_egresado     SERIAL PRIMARY KEY,
  id_alumno       INT     NOT NULL UNIQUE REFERENCES alumnos(id_alumno),
  generacion      VARCHAR(20),
  fecha_egreso    DATE,
  estatus_laboral t_estatus_laboral,
  empresa_actual  VARCHAR(200),
  puesto          VARCHAR(150),
  area            VARCHAR(100),
  salario_rango   VARCHAR(50),
  fecha_actualiz  DATE
);

-- ── 18. NOTIFICACIONES ────────────────────────────────
CREATE TABLE IF NOT EXISTS notificaciones (
  id_notif     SERIAL PRIMARY KEY,
  id_usuario   INT        NOT NULL REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
  tipo         t_tipo_notif DEFAULT 'info',
  titulo       VARCHAR(150) NOT NULL,
  mensaje      TEXT         NOT NULL,
  url_accion   VARCHAR(255),
  leida        BOOLEAN    DEFAULT FALSE,
  fecha        TIMESTAMPTZ DEFAULT NOW(),
  fecha_lectura TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_notif_user ON notificaciones(id_usuario, leida, fecha);

-- ── 19. AUDITORÍA ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS auditoria (
  id_log         BIGSERIAL PRIMARY KEY,
  id_usuario     INT        REFERENCES usuarios(id_usuario),
  tabla_afectada VARCHAR(60) NOT NULL,
  id_registro    VARCHAR(60) NOT NULL,
  accion         t_accion_audit NOT NULL,
  datos_antes    JSONB,
  datos_despues  JSONB,
  ip_origen      VARCHAR(45),
  user_agent     VARCHAR(255),
  fecha          TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_audit_tabla ON auditoria(tabla_afectada, fecha);
CREATE INDEX IF NOT EXISTS idx_audit_user  ON auditoria(id_usuario, fecha);
