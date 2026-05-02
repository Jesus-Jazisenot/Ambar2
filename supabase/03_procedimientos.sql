-- ====================================================
-- SISTEMA ESCOLAR - PROCEDIMIENTOS  -  03_procedimientos.sql
-- Retornan JSONB → usar con supabase.rpc('nombre', params)
-- El FOR UPDATE dentro de cada función garantiza que dos
-- peticiones simultáneas no lean el mismo cupo libre:
-- la segunda espera el COMMIT de la primera antes de leer.
-- ====================================================

-- ── inscribir_alumno ─────────────────────────────────
-- Nivel READ COMMITTED + FOR UPDATE = protección completa
-- ante inscripciones concurrentes sin serializar todo.
CREATE OR REPLACE FUNCTION inscribir_alumno(p_id_alumno INT, p_id_grupo INT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_cupo_max    SMALLINT; v_cupo_actual SMALLINT;
  v_id_materia  INT;      v_id_periodo  INT;
  v_estado      t_estado_grupo;
  v_existe      INT;      v_choque      INT;
BEGIN
  SELECT cupo_max, cupo_actual, id_materia, id_periodo, estado
    INTO v_cupo_max, v_cupo_actual, v_id_materia, v_id_periodo, v_estado
  FROM grupos WHERE id_grupo = p_id_grupo FOR UPDATE;

  IF NOT FOUND THEN
    RETURN '{"resultado":"ERROR","mensaje":"Grupo no encontrado."}'::JSONB;
  END IF;

  IF v_estado <> 'abierto' THEN
    RETURN jsonb_build_object('resultado','SIN_CUPO','mensaje','El grupo no está disponible para inscripción.');
  END IF;

  -- Duplicada
  SELECT COUNT(*) INTO v_existe
  FROM inscripciones i JOIN grupos g2 ON g2.id_grupo = i.id_grupo
  WHERE i.id_alumno = p_id_alumno
    AND g2.id_materia = v_id_materia AND g2.id_periodo = v_id_periodo
    AND i.estado IN ('inscrito','en_curso');
  IF v_existe > 0 THEN
    RETURN jsonb_build_object('resultado','DUPLICADA','mensaje','Ya estás inscrito en esta materia.');
  END IF;

  -- Prerequisitos
  IF NOT fn_cumple_prerequisitos(p_id_alumno, v_id_materia) THEN
    RETURN jsonb_build_object('resultado','SIN_PREREQ','mensaje','No cumples con los prerequisitos de esta materia.');
  END IF;

  -- Adeudos
  IF fn_total_adeudo(p_id_alumno) > 0 THEN
    RETURN jsonb_build_object('resultado','ADEUDO','mensaje','Tienes adeudos pendientes. Regulariza para inscribirte.');
  END IF;

  -- Conflicto de horario
  SELECT COUNT(*) INTO v_choque
  FROM inscripciones i
  JOIN grupos g3 ON g3.id_grupo = i.id_grupo
  JOIN horarios_grupo h1 ON h1.id_grupo = g3.id_grupo
  JOIN horarios_grupo h2 ON h2.id_grupo = p_id_grupo
  WHERE i.id_alumno = p_id_alumno
    AND i.estado IN ('inscrito','en_curso')
    AND g3.id_periodo = v_id_periodo
    AND h1.dia_semana = h2.dia_semana
    AND h1.hora_inicio < h2.hora_fin
    AND h1.hora_fin    > h2.hora_inicio;
  IF v_choque > 0 THEN
    RETURN jsonb_build_object('resultado','HORARIO','mensaje','Conflicto de horario con otra materia inscrita.');
  END IF;

  -- Cupo
  IF v_cupo_actual >= v_cupo_max THEN
    RETURN jsonb_build_object('resultado','SIN_CUPO','mensaje','No hay cupos disponibles.');
  END IF;

  -- ✓ Inscribir
  INSERT INTO inscripciones (id_alumno, id_grupo, estado)
  VALUES (p_id_alumno, p_id_grupo, 'inscrito');

  UPDATE grupos
     SET cupo_actual = cupo_actual + 1,
         estado = CASE WHEN cupo_actual + 1 >= cupo_max THEN 'lleno'::t_estado_grupo ELSE estado END
   WHERE id_grupo = p_id_grupo;

  RETURN jsonb_build_object('resultado','OK','mensaje','Inscripción registrada correctamente.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;

-- ── baja_inscripcion ─────────────────────────────────
CREATE OR REPLACE FUNCTION baja_inscripcion(p_id_inscripcion INT, p_motivo VARCHAR)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id_grupo INT; v_estado t_estatus_inscripcion;
BEGIN
  SELECT id_grupo, estado INTO v_id_grupo, v_estado
  FROM inscripciones WHERE id_inscripcion = p_id_inscripcion FOR UPDATE;

  IF v_estado = 'baja' THEN
    RETURN jsonb_build_object('resultado','YA_BAJA','mensaje','Esta inscripción ya tiene baja registrada.');
  END IF;

  UPDATE inscripciones
     SET estado = 'baja', fecha_baja = NOW(), motivo_baja = p_motivo
   WHERE id_inscripcion = p_id_inscripcion;

  UPDATE grupos
     SET cupo_actual = GREATEST(cupo_actual - 1, 0),
         estado = CASE WHEN estado = 'lleno' THEN 'abierto'::t_estado_grupo ELSE estado END
   WHERE id_grupo = v_id_grupo;

  RETURN jsonb_build_object('resultado','OK','mensaje','Baja procesada correctamente.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;

-- ── capturar_calificacion_final ──────────────────────
CREATE OR REPLACE FUNCTION capturar_calificacion_final(
  p_id_inscripcion INT, p_calificacion NUMERIC(4,2), p_id_docente INT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_id_alumno INT; v_id_materia INT; v_id_periodo INT; v_creditos SMALLINT;
  v_oport SMALLINT := 1; v_estatus t_estatus_kardex;
BEGIN
  IF p_calificacion < 0 OR p_calificacion > 10 THEN
    RETURN jsonb_build_object('resultado','RANGO_INVALIDO','mensaje','Calificación fuera de rango (0-10).');
  END IF;

  SELECT i.id_alumno, g.id_materia, g.id_periodo, m.creditos
    INTO v_id_alumno, v_id_materia, v_id_periodo, v_creditos
  FROM inscripciones i
  JOIN grupos   g ON g.id_grupo   = i.id_grupo
  JOIN materias m ON m.id_materia = g.id_materia
  WHERE i.id_inscripcion = p_id_inscripcion;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('resultado','ERROR','mensaje','Inscripción no encontrada.');
  END IF;

  SELECT COALESCE(MAX(oportunidad), 0) + 1 INTO v_oport
  FROM kardex WHERE id_alumno = v_id_alumno AND id_materia = v_id_materia;

  v_estatus := CASE WHEN p_calificacion >= 6 THEN 'aprobada'::t_estatus_kardex ELSE 'reprobada'::t_estatus_kardex END;

  UPDATE inscripciones
     SET cal_final = p_calificacion,
         estado = CASE WHEN p_calificacion >= 6 THEN 'acreditada'::t_estatus_inscripcion ELSE 'no_acreditada'::t_estatus_inscripcion END
   WHERE id_inscripcion = p_id_inscripcion;

  INSERT INTO kardex (id_alumno, id_materia, id_periodo, calificacion, oportunidad, estatus, creditos)
  VALUES (v_id_alumno, v_id_materia, v_id_periodo, p_calificacion, v_oport, v_estatus, v_creditos)
  ON CONFLICT (id_alumno, id_materia, oportunidad)
  DO UPDATE SET calificacion = EXCLUDED.calificacion, estatus = EXCLUDED.estatus, fecha_registro = NOW();

  UPDATE alumnos
     SET promedio_gral = fn_promedio_alumno(v_id_alumno),
         creditos_acum = fn_creditos_acumulados(v_id_alumno)
   WHERE id_alumno = v_id_alumno;

  RETURN jsonb_build_object('resultado','OK','mensaje','Calificación capturada correctamente.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;

-- ── firmar_acta ──────────────────────────────────────
CREATE OR REPLACE FUNCTION firmar_acta(p_id_grupo INT, p_id_docente INT)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_pendientes INT; v_contenido TEXT; v_hash TEXT; v_codigo VARCHAR(20);
BEGIN
  SELECT COUNT(*) INTO v_pendientes
  FROM inscripciones WHERE id_grupo = p_id_grupo AND estado IN ('inscrito','en_curso') AND cal_final IS NULL;

  IF v_pendientes > 0 THEN
    RETURN jsonb_build_object('resultado','PENDIENTES','mensaje',
      'Faltan ' || v_pendientes || ' calificaciones por capturar.');
  END IF;

  SELECT STRING_AGG(a.matricula || ':' || i.cal_final::TEXT, '|' ORDER BY a.matricula)
    INTO v_contenido
  FROM inscripciones i JOIN alumnos a ON a.id_alumno = i.id_alumno
  WHERE i.id_grupo = p_id_grupo;

  v_hash   := ENCODE(DIGEST(v_contenido || '|' || NOW()::TEXT || '|' || p_id_docente::TEXT, 'sha256'), 'hex');
  v_codigo := fn_genera_codigo_verif('ACT');

  INSERT INTO actas (id_grupo, fecha_cierre, hash_firma, codigo_verif, firmada_por, estado)
  VALUES (p_id_grupo, NOW(), v_hash, v_codigo, p_id_docente, 'firmada')
  ON CONFLICT (id_grupo) DO UPDATE
    SET fecha_cierre = NOW(), hash_firma = v_hash, codigo_verif = v_codigo,
        firmada_por = p_id_docente, estado = 'firmada';

  RETURN jsonb_build_object('resultado','OK','codigo',v_codigo,'mensaje','Acta firmada correctamente.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;

-- ── registrar_pago ───────────────────────────────────
CREATE OR REPLACE FUNCTION registrar_pago(
  p_id_adeudo INT, p_monto NUMERIC(10,2),
  p_metodo TEXT, p_num_trans VARCHAR(80), p_id_usuario INT
)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_monto_adeudo NUMERIC(10,2); v_estado t_estado_adeudo;
BEGIN
  SELECT monto, estado INTO v_monto_adeudo, v_estado
  FROM adeudos WHERE id_adeudo = p_id_adeudo FOR UPDATE;

  IF NOT FOUND THEN RETURN jsonb_build_object('resultado','ERROR','mensaje','Adeudo no encontrado.'); END IF;
  IF v_estado = 'pagado' THEN RETURN jsonb_build_object('resultado','YA_PAGADO','mensaje','Este adeudo ya fue pagado.'); END IF;
  IF p_monto < v_monto_adeudo THEN RETURN jsonb_build_object('resultado','MONTO_INSUF','mensaje','El monto es insuficiente.'); END IF;

  INSERT INTO pagos (id_adeudo, monto_pagado, metodo, num_transaccion, registrado_por)
  VALUES (p_id_adeudo, p_monto, p_metodo::t_metodo_pago, p_num_trans, p_id_usuario);

  UPDATE adeudos SET estado = 'pagado' WHERE id_adeudo = p_id_adeudo;

  RETURN jsonb_build_object('resultado','OK','mensaje','Pago registrado correctamente.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;

-- ── solicitar_constancia ─────────────────────────────
CREATE OR REPLACE FUNCTION solicitar_constancia(p_id_alumno INT, p_id_tipo INT, p_urgente BOOLEAN DEFAULT FALSE)
RETURNS JSONB LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_id INT;
BEGIN
  IF fn_total_adeudo(p_id_alumno) > 0 THEN
    RETURN jsonb_build_object('resultado','ADEUDO','mensaje','Tienes adeudos pendientes que impiden solicitar constancias.');
  END IF;
  INSERT INTO solicitudes_constancia (id_alumno, id_tipo, urgente, estado)
  VALUES (p_id_alumno, p_id_tipo, p_urgente, 'pendiente') RETURNING id_solicitud INTO v_id;
  RETURN jsonb_build_object('resultado','OK','id_solicitud',v_id,'mensaje','Solicitud registrada. Tiempo de entrega: 24-72 hrs.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;
