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
