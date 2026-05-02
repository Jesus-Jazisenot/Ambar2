-- ====================================================
-- SISTEMA ESCOLAR - FUNCIONES  -  02_funciones.sql
-- ====================================================

-- Promedio ponderado por créditos (solo aprobadas)
CREATE OR REPLACE FUNCTION fn_promedio_alumno(p_id_alumno INT)
RETURNS NUMERIC(4,2) LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(calificacion * creditos) / NULLIF(SUM(creditos), 0)
    FROM kardex
    WHERE id_alumno = p_id_alumno
      AND estatus IN ('aprobada','equivalencia','revalidacion')
  ), 0);
END; $$;

-- Créditos acumulados (kardex + extracurriculares)
CREATE OR REPLACE FUNCTION fn_creditos_acumulados(p_id_alumno INT)
RETURNS SMALLINT LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(creditos) FROM kardex
    WHERE id_alumno = p_id_alumno
      AND estatus IN ('aprobada','equivalencia','revalidacion')
  ), 0) + COALESCE((
    SELECT SUM(creditos) FROM creditos_extra WHERE id_alumno = p_id_alumno
  ), 0);
END; $$;

-- Porcentaje de asistencia (P=1, J=1, R=0.5, F=0)
CREATE OR REPLACE FUNCTION fn_porc_asistencia(p_id_inscripcion INT)
RETURNS NUMERIC(5,2) LANGUAGE plpgsql STABLE AS $$
DECLARE v_total INT; v_score NUMERIC(8,2);
BEGIN
  SELECT COUNT(*),
         SUM(CASE estado WHEN 'P' THEN 1 WHEN 'J' THEN 1 WHEN 'R' THEN 0.5 ELSE 0 END)
    INTO v_total, v_score
  FROM asistencias WHERE id_inscripcion = p_id_inscripcion;
  IF v_total = 0 THEN RETURN 0; END IF;
  RETURN ROUND((v_score / v_total) * 100, 2);
END; $$;

-- Validar prerequisitos de una materia
CREATE OR REPLACE FUNCTION fn_cumple_prerequisitos(p_id_alumno INT, p_id_materia INT)
RETURNS BOOLEAN LANGUAGE plpgsql STABLE AS $$
DECLARE v_total INT; v_aprobados INT;
BEGIN
  SELECT COUNT(*) INTO v_total FROM prerrequisitos WHERE id_materia = p_id_materia;
  IF v_total = 0 THEN RETURN TRUE; END IF;
  SELECT COUNT(*) INTO v_aprobados
  FROM prerrequisitos pr
  JOIN kardex k ON k.id_materia = pr.id_prerreq
  WHERE pr.id_materia = p_id_materia
    AND k.id_alumno   = p_id_alumno
    AND k.estatus IN ('aprobada','equivalencia','revalidacion');
  RETURN v_aprobados = v_total;
END; $$;

-- Total adeudado (pendiente + vencido)
CREATE OR REPLACE FUNCTION fn_total_adeudo(p_id_alumno INT)
RETURNS NUMERIC(10,2) LANGUAGE plpgsql STABLE AS $$
BEGIN
  RETURN COALESCE((
    SELECT SUM(monto) FROM adeudos
    WHERE id_alumno = p_id_alumno AND estado IN ('pendiente','vencido')
  ), 0);
END; $$;

-- Nivel de riesgo académico (bajo / medio / alto)
CREATE OR REPLACE FUNCTION fn_riesgo_alumno(p_id_alumno INT)
RETURNS VARCHAR(10) LANGUAGE plpgsql STABLE AS $$
DECLARE v_prom NUMERIC(4,2); v_faltas INT;
BEGIN
  SELECT promedio_gral INTO v_prom FROM alumnos WHERE id_alumno = p_id_alumno;
  SELECT COUNT(*) INTO v_faltas
  FROM asistencias a
  JOIN inscripciones i ON i.id_inscripcion = a.id_inscripcion
  JOIN grupos g ON g.id_grupo = i.id_grupo
  JOIN periodos p ON p.id_periodo = g.id_periodo
  WHERE i.id_alumno = p_id_alumno
    AND a.estado = 'F'
    AND p.estado IN ('en_curso','inscripcion');
  IF v_prom < 7 OR v_faltas > 5 THEN RETURN 'alto';
  ELSIF v_prom < 8 OR v_faltas > 3 THEN RETURN 'medio';
  ELSE RETURN 'bajo';
  END IF;
END; $$;

-- Código corto de verificación (para actas/constancias)
CREATE OR REPLACE FUNCTION fn_genera_codigo_verif(p_prefijo VARCHAR(5))
RETURNS VARCHAR(20) LANGUAGE plpgsql AS $$
BEGIN
  RETURN p_prefijo || '-' || TO_CHAR(NOW(), 'YYMMDD') || '-' ||
         UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 6));
END; $$;

-- Avance de carrera en %
CREATE OR REPLACE FUNCTION fn_avance_carrera(p_id_alumno INT)
RETURNS NUMERIC(5,2) LANGUAGE plpgsql STABLE AS $$
DECLARE v_acum SMALLINT; v_total SMALLINT;
BEGIN
  SELECT fn_creditos_acumulados(p_id_alumno) INTO v_acum;
  SELECT c.creditos_total INTO v_total
  FROM alumnos a JOIN carreras c ON c.id_carrera = a.id_carrera
  WHERE a.id_alumno = p_id_alumno;
  IF v_total = 0 THEN RETURN 0; END IF;
  RETURN ROUND((v_acum::NUMERIC / v_total) * 100, 2);
END; $$;
