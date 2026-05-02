-- ====================================================
-- SISTEMA ESCOLAR - VISTAS  -  05_vistas.sql
-- Alimentan directo al frontend por PostgREST
-- ====================================================

-- Vista 360° del alumno
CREATE OR REPLACE VIEW v_alumno_resumen AS
SELECT a.id_alumno, a.matricula,
       CONCAT(u.apellido_pat,' ', COALESCE(u.apellido_mat,''), ', ', u.nombres) AS nombre_completo,
       u.email, c.clave AS clave_carrera, c.nombre AS carrera,
       pe.clave_plan, a.semestre_actual, a.estatus,
       a.promedio_gral, a.creditos_acum, c.creditos_total,
       ROUND(a.creditos_acum::NUMERIC / NULLIF(c.creditos_total,0) * 100, 2) AS pct_avance,
       fn_riesgo_alumno(a.id_alumno) AS nivel_riesgo,
       fn_total_adeudo(a.id_alumno)  AS total_adeudo
FROM alumnos a
JOIN usuarios     u  ON u.id_usuario = a.id_usuario
JOIN carreras     c  ON c.id_carrera = a.id_carrera
JOIN planes_estudio pe ON pe.id_plan = a.id_plan;

-- Kárdex completo
CREATE OR REPLACE VIEW v_kardex_alumno AS
SELECT k.id_alumno, k.id_periodo,
       per.clave AS periodo, m.semestre_sug,
       m.clave AS clave_materia, m.nombre AS materia,
       m.creditos, k.calificacion, k.oportunidad, k.estatus, k.fecha_registro
FROM kardex k
JOIN materias  m   ON m.id_materia  = k.id_materia
JOIN periodos  per ON per.id_periodo = k.id_periodo
ORDER BY m.semestre_sug, m.clave;

-- Grupos disponibles para inscripción
CREATE OR REPLACE VIEW v_grupos_disponibles AS
SELECT g.id_grupo, g.clave_grupo,
       m.id_materia, m.clave AS clave_materia, m.nombre AS materia, m.creditos,
       g.cupo_max, g.cupo_actual, (g.cupo_max - g.cupo_actual) AS cupos_libres,
       g.estado,
       CONCAT(u.apellido_pat,' ', u.nombres) AS docente,
       s.clave AS salon, per.clave AS periodo, per.id_periodo
FROM grupos g
JOIN materias     m   ON m.id_materia  = g.id_materia
JOIN docentes     d   ON d.id_docente  = g.id_docente
JOIN usuarios     u   ON u.id_usuario  = d.id_usuario
LEFT JOIN salones s   ON s.id_salon    = g.id_salon
JOIN periodos     per ON per.id_periodo = g.id_periodo
WHERE per.estado IN ('inscripcion','en_curso')
  AND g.estado <> 'cancelado';

-- Horario del alumno
CREATE OR REPLACE VIEW v_horario_alumno AS
SELECT i.id_alumno, g.clave_grupo,
       m.clave AS clave_materia, m.nombre AS materia,
       CONCAT(u.apellido_pat,' ', u.nombres) AS docente,
       h.dia_semana, h.hora_inicio, h.hora_fin,
       s.clave AS salon, per.clave AS periodo
FROM inscripciones i
JOIN grupos       g   ON g.id_grupo   = i.id_grupo
JOIN materias     m   ON m.id_materia = g.id_materia
JOIN docentes     d   ON d.id_docente = g.id_docente
JOIN usuarios     u   ON u.id_usuario = d.id_usuario
JOIN horarios_grupo h ON h.id_grupo   = g.id_grupo
JOIN salones      s   ON s.id_salon   = h.id_salon
JOIN periodos     per ON per.id_periodo = g.id_periodo
WHERE i.estado IN ('inscrito','en_curso')
ORDER BY h.dia_semana, h.hora_inicio;

-- Lista de alumnos por grupo (portal docente)
CREATE OR REPLACE VIEW v_lista_grupo_docente AS
SELECT i.id_inscripcion, i.id_grupo,
       a.matricula,
       CONCAT(u.apellido_pat,' ', COALESCE(u.apellido_mat,''), ', ', u.nombres) AS nombre_completo,
       i.cal_p1, i.cal_p2, i.cal_final, i.porc_asistencia, i.estado
FROM inscripciones i
JOIN alumnos  a ON a.id_alumno  = i.id_alumno
JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE i.estado IN ('inscrito','en_curso','acreditada','no_acreditada')
ORDER BY u.apellido_pat;

-- KPIs para dashboard admin
CREATE OR REPLACE VIEW v_dashboard_kpis AS
SELECT
  (SELECT COUNT(*) FROM alumnos WHERE estatus = 'activo') AS alumnos_activos,
  (SELECT COUNT(*) FROM grupos g JOIN periodos p ON p.id_periodo = g.id_periodo
   WHERE p.estado IN ('inscripcion','en_curso') AND g.estado IN ('abierto','lleno')) AS materias_abiertas,
  (SELECT ROUND(AVG(promedio_gral), 2) FROM alumnos WHERE estatus = 'activo' AND promedio_gral > 0) AS promedio_general,
  (SELECT COUNT(*) FROM docentes WHERE activo = TRUE) AS docentes_activos,
  (SELECT COUNT(*) FROM solicitudes_constancia WHERE estado = 'pendiente') AS constancias_pendientes,
  (SELECT COUNT(*) FROM bajas WHERE estado = 'pendiente') AS bajas_pendientes,
  (SELECT COALESCE(SUM(p.monto_pagado), 0)
   FROM pagos p WHERE DATE_TRUNC('month', p.fecha_pago) = DATE_TRUNC('month', NOW())) AS ingresos_mes;

-- Alumnos en riesgo académico (para tutorías)
CREATE OR REPLACE VIEW v_alumnos_riesgo AS
SELECT a.id_alumno, a.matricula,
       CONCAT(u.apellido_pat,', ', u.nombres) AS nombre,
       a.semestre_actual, a.promedio_gral,
       fn_riesgo_alumno(a.id_alumno) AS nivel_riesgo,
       (SELECT COUNT(*) FROM asistencias asi
        JOIN inscripciones i ON i.id_inscripcion = asi.id_inscripcion
        WHERE i.id_alumno = a.id_alumno AND asi.estado = 'F') AS faltas_total,
       (SELECT COUNT(*) FROM kardex k WHERE k.id_alumno = a.id_alumno AND k.estatus = 'reprobada') AS materias_reprobadas
FROM alumnos a
JOIN usuarios u ON u.id_usuario = a.id_usuario
WHERE a.estatus = 'activo' AND fn_riesgo_alumno(a.id_alumno) <> 'bajo';

-- Estado de cuenta del alumno
CREATE OR REPLACE VIEW v_estado_cuenta AS
SELECT ad.id_adeudo, ad.id_alumno,
       cp.descripcion AS concepto, ad.monto,
       ad.fecha_gen, ad.fecha_venc, ad.ref_bancaria, ad.estado,
       p.fecha_pago, p.metodo,
       EXTRACT(DAY FROM NOW() - ad.fecha_venc::TIMESTAMPTZ)::INT AS dias_vencido
FROM adeudos ad
JOIN conceptos_pago cp ON cp.id_concepto = ad.id_concepto
LEFT JOIN pagos p ON p.id_adeudo = ad.id_adeudo;

-- Cupos por materia (admin)
CREATE OR REPLACE VIEW v_cupos_materia AS
SELECT m.clave AS clave_materia, m.nombre AS materia,
       per.clave AS periodo,
       SUM(g.cupo_max)     AS cupos_total,
       SUM(g.cupo_actual)  AS inscritos,
       SUM(g.cupo_max - g.cupo_actual) AS disponibles,
       ROUND(SUM(g.cupo_actual)::NUMERIC / NULLIF(SUM(g.cupo_max), 0) * 100, 1) AS pct_ocupacion
FROM grupos g
JOIN materias m   ON m.id_materia   = g.id_materia
JOIN periodos per ON per.id_periodo = g.id_periodo
WHERE per.estado IN ('inscripcion','en_curso')
GROUP BY m.clave, m.nombre, per.clave;

-- Promedios de evaluación docente
CREATE OR REPLACE VIEW v_eval_docente_promedios AS
SELECT d.id_docente,
       CONCAT(u.apellido_pat,' ', u.nombres) AS docente,
       m.nombre AS materia, per.clave AS periodo,
       COUNT(DISTINCT ed.id_eval) AS num_evaluaciones,
       ROUND(AVG(er.calificacion), 2) AS promedio_global
FROM eval_docente    ed
JOIN eval_respuestas er  ON er.id_eval     = ed.id_eval
JOIN inscripciones   i   ON i.id_inscripcion = ed.id_inscripcion
JOIN grupos          g   ON g.id_grupo     = i.id_grupo
JOIN docentes        d   ON d.id_docente   = g.id_docente
JOIN usuarios        u   ON u.id_usuario   = d.id_usuario
JOIN materias        m   ON m.id_materia   = g.id_materia
JOIN periodos        per ON per.id_periodo = g.id_periodo
GROUP BY d.id_docente, u.apellido_pat, u.nombres, m.nombre, per.clave;

-- Stats de egresados por carrera/generación
CREATE OR REPLACE VIEW v_egresados_stats AS
SELECT c.clave AS carrera, e.generacion, COUNT(*) AS total,
       SUM(CASE WHEN e.estatus_laboral = 'empleado'    THEN 1 ELSE 0 END) AS empleados,
       SUM(CASE WHEN e.estatus_laboral = 'posgrado'    THEN 1 ELSE 0 END) AS posgrado,
       SUM(CASE WHEN e.estatus_laboral = 'emprendedor' THEN 1 ELSE 0 END) AS emprendedores,
       SUM(CASE WHEN e.estatus_laboral = 'buscando'    THEN 1 ELSE 0 END) AS buscando,
       ROUND(SUM(CASE WHEN e.estatus_laboral = 'empleado' THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*),0) * 100, 1) AS pct_empleabilidad
FROM egresados e
JOIN alumnos  a ON a.id_alumno  = e.id_alumno
JOIN carreras c ON c.id_carrera = a.id_carrera
GROUP BY c.clave, e.generacion;
