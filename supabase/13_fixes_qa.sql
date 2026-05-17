-- =========================================================
-- 13_fixes_qa.sql
-- Correcciones de QA (sesión de revisión por roles).
-- Depende de 09_fix_completo.sql (funciones auth_rol/auth_id_alumno/auth_id_docente).
-- Idempotente: usa DROP POLICY IF EXISTS antes de cada CREATE.
-- =========================================================

-- ---------------------------------------------------------
-- FIX: el docente no veía los NOMBRES de sus alumnos en
-- "Control de asistencias" / "Lista de clase".
-- Causa: la policy usuarios_own sólo permitía al docente leer
-- su propia fila de usuarios; el join alumnos->usuarios
-- devolvía NULL para los alumnos de sus grupos.
-- Solución: policy SELECT adicional (permisiva, se combina con OR)
-- que deja al docente leer las filas de usuarios de los alumnos
-- inscritos (no dados de baja) en los grupos que imparte.
-- ---------------------------------------------------------
DROP POLICY IF EXISTS usuarios_docente_alumnos ON public.usuarios;
CREATE POLICY usuarios_docente_alumnos ON public.usuarios
  FOR SELECT TO authenticated
  USING (
    public.auth_rol() = 'docente'
    AND EXISTS (
      SELECT 1
      FROM public.alumnos a
      JOIN public.inscripciones i ON i.id_alumno = a.id_alumno
      JOIN public.grupos g ON g.id_grupo = i.id_grupo
      WHERE a.id_usuario = usuarios.id_usuario
        AND i.estado <> 'baja'
        AND g.id_docente = public.auth_id_docente()
    )
  );

-- ---------------------------------------------------------
-- FIX: el docente no podia agendar/registrar reuniones de
-- tutoria. La tabla tutorias_asignacion solo permite INSERT a
-- admin/coordinador (RLS), y tutorias_sesiones exige una
-- asignacion previa, asi que un docente quedaba bloqueado.
-- Solucion: RPC SECURITY DEFINER que verifica que el llamante
-- sea el docente (auth_id_docente()), crea la asignacion
-- tutor-alumno si no existe y registra la sesion.
-- ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.agendar_tutoria(
  p_id_alumno int,
  p_fecha date,
  p_notas text DEFAULT NULL,
  p_nivel text DEFAULT 'bajo',
  p_acciones text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_doc int;
  v_rol text;
  v_periodo int;
  v_asig int;
  v_ses int;
BEGIN
  v_rol := auth_rol();
  v_doc := auth_id_docente();
  IF v_doc IS NULL THEN
    RETURN jsonb_build_object('resultado','FORBIDDEN','mensaje','Tu usuario no esta vinculado a un docente/tutor.');
  END IF;
  IF p_fecha IS NULL THEN
    RETURN jsonb_build_object('resultado','ERROR','mensaje','Indica la fecha de la reunion.');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM alumnos WHERE id_alumno = p_id_alumno) THEN
    RETURN jsonb_build_object('resultado','ERROR','mensaje','El alumno indicado no existe.');
  END IF;

  SELECT id_periodo INTO v_periodo FROM periodos
   WHERE estado IN ('inscripcion','en_curso')
   ORDER BY id_periodo DESC LIMIT 1;
  IF v_periodo IS NULL THEN
    SELECT id_periodo INTO v_periodo FROM periodos ORDER BY id_periodo DESC LIMIT 1;
  END IF;
  IF v_periodo IS NULL THEN
    RETURN jsonb_build_object('resultado','ERROR','mensaje','No hay periodos registrados.');
  END IF;

  SELECT id_asignacion INTO v_asig FROM tutorias_asignacion
   WHERE id_alumno = p_id_alumno AND id_tutor = v_doc AND activa = true
   ORDER BY id_asignacion DESC LIMIT 1;
  IF v_asig IS NULL THEN
    INSERT INTO tutorias_asignacion(id_alumno,id_tutor,id_periodo,fecha_asign,activa)
    VALUES (p_id_alumno, v_doc, v_periodo, CURRENT_DATE, true)
    RETURNING id_asignacion INTO v_asig;
  END IF;

  INSERT INTO tutorias_sesiones(id_asignacion,fecha,notas,nivel_riesgo,acciones)
  VALUES (v_asig, p_fecha, NULLIF(p_notas,''), COALESCE(NULLIF(p_nivel,''),'bajo'), NULLIF(p_acciones,''))
  RETURNING id_sesion INTO v_ses;

  RETURN jsonb_build_object('resultado','OK','id_sesion',v_ses,'id_asignacion',v_asig,'mensaje','Reunion de tutoria registrada.');
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('resultado','ERROR','mensaje',SQLERRM);
END; $$;

GRANT EXECUTE ON FUNCTION public.agendar_tutoria(int,date,text,text,text) TO authenticated;
