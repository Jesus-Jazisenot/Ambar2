-- ====================================================
-- SISTEMA ESCOLAR - TRIGGERS  -  04_triggers.sql
-- ====================================================

-- Helper: lee id de usuario de la sesión (la app lo setea con
-- supabase.rpc o SET LOCAL app.current_user_id = x)
CREATE OR REPLACE FUNCTION get_session_user_id()
RETURNS INT LANGUAGE plpgsql AS $$
BEGIN
  RETURN NULLIF(current_setting('app.current_user_id', TRUE), '')::INT;
EXCEPTION WHEN OTHERS THEN RETURN NULL;
END; $$;

-- ── AUDITORÍA: cambios en calificaciones ─────────────
CREATE OR REPLACE FUNCTION tg_aud_kardex_upd_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.calificacion IS DISTINCT FROM NEW.calificacion
  OR OLD.estatus      IS DISTINCT FROM NEW.estatus THEN
    INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, datos_antes, datos_despues)
    VALUES (get_session_user_id(), 'kardex', OLD.id_kardex::TEXT, 'UPDATE',
            jsonb_build_object('calificacion', OLD.calificacion, 'estatus', OLD.estatus),
            jsonb_build_object('calificacion', NEW.calificacion, 'estatus', NEW.estatus));
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_aud_kardex_upd ON kardex;
CREATE TRIGGER tg_aud_kardex_upd
AFTER UPDATE ON kardex
FOR EACH ROW EXECUTE FUNCTION tg_aud_kardex_upd_fn();

-- ── AUDITORÍA: bajas ─────────────────────────────────
CREATE OR REPLACE FUNCTION tg_aud_bajas_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO auditoria (id_usuario, tabla_afectada, id_registro, accion, datos_despues)
  VALUES (get_session_user_id(), 'bajas', NEW.id_baja::TEXT, 'INSERT',
          jsonb_build_object('alumno', NEW.id_alumno, 'tipo', NEW.tipo, 'motivo', NEW.motivo));
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_aud_bajas ON bajas;
CREATE TRIGGER tg_aud_bajas
AFTER INSERT ON bajas
FOR EACH ROW EXECUTE FUNCTION tg_aud_bajas_fn();

-- ── ANTI-CRUCE DE HORARIOS ───────────────────────────
CREATE OR REPLACE FUNCTION tg_horario_no_choque_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_choque INT; v_id_periodo INT;
BEGIN
  SELECT id_periodo INTO v_id_periodo FROM grupos WHERE id_grupo = NEW.id_grupo;

  -- Conflicto de salón
  SELECT COUNT(*) INTO v_choque
  FROM horarios_grupo h JOIN grupos g ON g.id_grupo = h.id_grupo
  WHERE h.id_salon   = NEW.id_salon
    AND g.id_periodo = v_id_periodo
    AND h.dia_semana = NEW.dia_semana
    AND h.hora_inicio < NEW.hora_fin AND h.hora_fin > NEW.hora_inicio
    AND h.id_horario IS DISTINCT FROM NEW.id_horario;
  IF v_choque > 0 THEN
    RAISE EXCEPTION 'Conflicto de horario: el salón % ya está ocupado en ese bloque.', NEW.id_salon;
  END IF;

  -- Conflicto de docente
  SELECT COUNT(*) INTO v_choque
  FROM horarios_grupo h
  JOIN grupos g  ON g.id_grupo  = h.id_grupo
  JOIN grupos g2 ON g2.id_grupo = NEW.id_grupo
  WHERE g.id_docente = g2.id_docente
    AND g.id_periodo = v_id_periodo
    AND h.dia_semana = NEW.dia_semana
    AND h.hora_inicio < NEW.hora_fin AND h.hora_fin > NEW.hora_inicio
    AND h.id_horario IS DISTINCT FROM NEW.id_horario;
  IF v_choque > 0 THEN
    RAISE EXCEPTION 'Conflicto de horario: el docente ya tiene clase en ese bloque.';
  END IF;

  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_horario_no_choque ON horarios_grupo;
CREATE TRIGGER tg_horario_no_choque
BEFORE INSERT OR UPDATE ON horarios_grupo
FOR EACH ROW EXECUTE FUNCTION tg_horario_no_choque_fn();

-- ── ASISTENCIA → recalcular % + alertas ──────────────
CREATE OR REPLACE FUNCTION tg_asist_cambio_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_pct NUMERIC(5,2); v_faltas_c INT;
  v_id_user INT; v_materia VARCHAR(150);
BEGIN
  v_pct := fn_porc_asistencia(NEW.id_inscripcion);
  UPDATE inscripciones SET porc_asistencia = v_pct WHERE id_inscripcion = NEW.id_inscripcion;

  -- Alerta si hay 3 faltas consecutivas (solo en INSERT)
  IF TG_OP = 'INSERT' AND NEW.estado = 'F' THEN
    SELECT COUNT(*) INTO v_faltas_c
    FROM (SELECT estado FROM asistencias
          WHERE id_inscripcion = NEW.id_inscripcion
          ORDER BY fecha_sesion DESC LIMIT 3) ult
    WHERE estado = 'F';

    IF v_faltas_c >= 3 THEN
      SELECT u.id_usuario, m.nombre INTO v_id_user, v_materia
      FROM inscripciones i
      JOIN alumnos  a ON a.id_alumno  = i.id_alumno
      JOIN usuarios u ON u.id_usuario = a.id_usuario
      JOIN grupos   g ON g.id_grupo   = i.id_grupo
      JOIN materias m ON m.id_materia = g.id_materia
      WHERE i.id_inscripcion = NEW.id_inscripcion;

      INSERT INTO notificaciones (id_usuario, tipo, titulo, mensaje)
      VALUES (v_id_user, 'warn', 'Alerta de asistencia',
              'Llevas 3 faltas consecutivas en ' || v_materia || '. Acércate a tu tutor.');
    END IF;
  END IF;

  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_asist_ai ON asistencias;
CREATE TRIGGER tg_asist_ai
AFTER INSERT ON asistencias
FOR EACH ROW EXECUTE FUNCTION tg_asist_cambio_fn();

DROP TRIGGER IF EXISTS tg_asist_au ON asistencias;
CREATE TRIGGER tg_asist_au
AFTER UPDATE ON asistencias
FOR EACH ROW EXECUTE FUNCTION tg_asist_cambio_fn();

-- ── KÁRDEX → recalcular promedio + notificar reprobado ─
CREATE OR REPLACE FUNCTION tg_kardex_ai_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_user INT;
BEGIN
  UPDATE alumnos
     SET promedio_gral = fn_promedio_alumno(NEW.id_alumno),
         creditos_acum = fn_creditos_acumulados(NEW.id_alumno)
   WHERE id_alumno = NEW.id_alumno;

  IF NEW.estatus = 'reprobada' THEN
    SELECT a.id_usuario INTO v_user FROM alumnos a WHERE a.id_alumno = NEW.id_alumno;
    INSERT INTO notificaciones (id_usuario, tipo, titulo, mensaje)
    VALUES (v_user, 'danger', 'Materia reprobada',
            'Has reprobado con calificación ' || NEW.calificacion || '. Consulta a tu tutor.');
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_kardex_ai ON kardex;
CREATE TRIGGER tg_kardex_ai
AFTER INSERT ON kardex
FOR EACH ROW EXECUTE FUNCTION tg_kardex_ai_fn();

-- ── INSCRIPCIÓN → generar adeudo de colegiatura ───────
CREATE OR REPLACE FUNCTION tg_insc_genera_adeudo_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_count INT; v_id_periodo INT;
  v_id_concepto INT; v_monto NUMERIC(10,2); v_ref VARCHAR(30);
BEGIN
  SELECT g.id_periodo INTO v_id_periodo FROM grupos g WHERE g.id_grupo = NEW.id_grupo;

  SELECT COUNT(*) INTO v_count
  FROM inscripciones i JOIN grupos g ON g.id_grupo = i.id_grupo
  WHERE i.id_alumno = NEW.id_alumno AND g.id_periodo = v_id_periodo;

  -- Solo en la primera inscripción del período
  IF v_count = 1 THEN
    SELECT id_concepto, monto INTO v_id_concepto, v_monto
    FROM conceptos_pago WHERE clave = 'COLEG' AND activo = TRUE LIMIT 1;

    IF v_id_concepto IS NOT NULL THEN
      v_ref := 'COL' || NEW.id_alumno::TEXT || v_id_periodo::TEXT || FLOOR(RANDOM() * 1000)::TEXT;
      INSERT INTO adeudos (id_alumno, id_concepto, id_periodo, monto, fecha_gen, fecha_venc, ref_bancaria)
      VALUES (NEW.id_alumno, v_id_concepto, v_id_periodo, v_monto, CURRENT_DATE,
              CURRENT_DATE + INTERVAL '30 days', v_ref);
    END IF;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_insc_genera_adeudo ON inscripciones;
CREATE TRIGGER tg_insc_genera_adeudo
AFTER INSERT ON inscripciones
FOR EACH ROW EXECUTE FUNCTION tg_insc_genera_adeudo_fn();

-- ── USUARIOS → bloqueo por intentos fallidos ─────────
CREATE OR REPLACE FUNCTION tg_user_bloqueo_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.intentos_fallidos >= 5 AND NOT OLD.bloqueado THEN
    NEW.bloqueado := TRUE;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_user_bloqueo ON usuarios;
CREATE TRIGGER tg_user_bloqueo
BEFORE UPDATE ON usuarios
FOR EACH ROW EXECUTE FUNCTION tg_user_bloqueo_fn();

-- ── ALUMNOS → marcar irregular si reprueba 3 veces ───
CREATE OR REPLACE FUNCTION tg_kardex_irregular_fn()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_reprob INT;
BEGIN
  IF NEW.estatus = 'reprobada' THEN
    SELECT COUNT(*) INTO v_reprob
    FROM kardex WHERE id_alumno = NEW.id_alumno AND id_materia = NEW.id_materia AND estatus = 'reprobada';
    IF v_reprob >= 3 THEN
      UPDATE alumnos SET estatus = 'irregular' WHERE id_alumno = NEW.id_alumno AND estatus = 'activo';
    END IF;
  END IF;
  RETURN NEW;
END; $$;

DROP TRIGGER IF EXISTS tg_kardex_irregular ON kardex;
CREATE TRIGGER tg_kardex_irregular
AFTER INSERT ON kardex
FOR EACH ROW EXECUTE FUNCTION tg_kardex_irregular_fn();
