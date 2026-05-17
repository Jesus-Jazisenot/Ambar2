-- =========================================================
-- 14_seed_qa.sql
-- Datos de ejemplo para poder PROBAR modulos que estaban
-- vacios (no eran bugs de codigo, faltaban registros):
-- Vinculacion (empresas/servicio_social/residencias),
-- Bajas, Expedientes (documentos_alumno) y reticula IGE.
-- Idempotente: cada bloque usa WHERE NOT EXISTS.
-- Alumnos existentes: id 1..10 · Docentes: 1,2 · Plan IGE = 2
-- =========================================================

-- ---------- empresas ----------
INSERT INTO empresas (nombre,rfc,sector,contacto_nombre,contacto_email,contacto_tel,direccion,convenio_inicio,convenio_fin,estado)
SELECT 'Tecnologica del Pacifico S.A.','TPA210101AB1','Tecnologias de la Informacion','Ing. Laura Beltran','vinculacion@tecpacifico.mx','669-111-2233','Av. Insurgentes 100, Mazatlan','2025-01-15','2027-01-15','vigente'
WHERE NOT EXISTS (SELECT 1 FROM empresas WHERE nombre='Tecnologica del Pacifico S.A.');

INSERT INTO empresas (nombre,rfc,sector,contacto_nombre,contacto_email,contacto_tel,direccion,convenio_inicio,convenio_fin,estado)
SELECT 'Grupo Industrial Sinaloa','GIS180505CD2','Manufactura','Lic. Mario Quintero','rh@gisinaloa.com','669-222-3344','Parque Industrial Alfredo V. Bonfil','2024-08-01','2026-08-01','vigente'
WHERE NOT EXISTS (SELECT 1 FROM empresas WHERE nombre='Grupo Industrial Sinaloa');

INSERT INTO empresas (nombre,rfc,sector,contacto_nombre,contacto_email,contacto_tel,direccion,convenio_inicio,convenio_fin,estado)
SELECT 'Hotelera Costa Azul SA de CV','HCA150909EF3','Turismo','Mtra. Sofia Rivas','convenios@costaazul.mx','669-333-4455','Zona Dorada s/n, Mazatlan','2023-06-01','2025-06-01','por_renovar'
WHERE NOT EXISTS (SELECT 1 FROM empresas WHERE nombre='Hotelera Costa Azul SA de CV');

-- ---------- servicio_social ----------
INSERT INTO servicio_social (id_alumno,id_empresa,fecha_inicio,fecha_fin,horas_total,horas_acumul,estado)
SELECT 1,(SELECT id_empresa FROM empresas WHERE nombre='Tecnologica del Pacifico S.A.'),
       '2026-02-01','2026-08-01',480,260,'activo'
WHERE NOT EXISTS (SELECT 1 FROM servicio_social WHERE id_alumno=1);

INSERT INTO servicio_social (id_alumno,id_empresa,fecha_inicio,fecha_fin,horas_total,horas_acumul,estado)
SELECT 2,(SELECT id_empresa FROM empresas WHERE nombre='Hotelera Costa Azul SA de CV'),
       '2025-08-01','2026-02-01',480,480,'liberado'
WHERE NOT EXISTS (SELECT 1 FROM servicio_social WHERE id_alumno=2);

INSERT INTO servicio_social (id_alumno,id_empresa,horas_total,horas_acumul,estado)
SELECT 3,NULL,480,0,'pendiente'
WHERE NOT EXISTS (SELECT 1 FROM servicio_social WHERE id_alumno=3);

-- ---------- residencias ----------
INSERT INTO residencias (id_alumno,id_empresa,id_asesor,proyecto,fecha_inicio,fecha_fin,horas_total,horas_acumul,estado)
SELECT 5,(SELECT id_empresa FROM empresas WHERE nombre='Tecnologica del Pacifico S.A.'),1,
       'Sistema de control de inventarios con lectura de codigo de barras','2026-02-01','2026-07-31',480,300,'en_curso'
WHERE NOT EXISTS (SELECT 1 FROM residencias WHERE id_alumno=5);

INSERT INTO residencias (id_alumno,id_empresa,id_asesor,proyecto,fecha_inicio,fecha_fin,horas_total,horas_acumul,estado,calificacion)
SELECT 3,(SELECT id_empresa FROM empresas WHERE nombre='Grupo Industrial Sinaloa'),2,
       'Optimizacion de la linea de produccion mediante metodos numericos','2025-08-01','2026-01-31',480,480,'terminada',95
WHERE NOT EXISTS (SELECT 1 FROM residencias WHERE id_alumno=3);

-- ---------- bajas ----------
INSERT INTO bajas (id_alumno,tipo,motivo,fecha_sol,estado,docs_completos)
SELECT 4,'temporal','Motivos de salud; solicita baja temporal por un semestre.',CURRENT_DATE-15,'pendiente',false
WHERE NOT EXISTS (SELECT 1 FROM bajas WHERE id_alumno=4);

INSERT INTO bajas (id_alumno,tipo,motivo,fecha_sol,fecha_efectiva,estado,docs_completos)
SELECT 7,'definitiva','Cambio de residencia a otra ciudad.',CURRENT_DATE-40,CURRENT_DATE-30,'aprobada',true
WHERE NOT EXISTS (SELECT 1 FROM bajas WHERE id_alumno=7);

-- ---------- documentos_alumno (Expedientes) ----------
-- Alumno 1: expediente completo (4 verificados) ; Alumno 2: parcial
INSERT INTO documentos_alumno (id_alumno,tipo,estado,fecha_verif)
SELECT v.id_alumno,v.tipo,v.estado::t_estado_doc,
       CASE WHEN v.estado='verificado' THEN now() ELSE NULL END
FROM (VALUES
  (1,'CURP','verificado'),
  (1,'Acta de nacimiento','verificado'),
  (1,'Cert. de bachillerato','verificado'),
  (1,'Fotografia','verificado'),
  (1,'Comprobante domicilio','pendiente'),
  (2,'CURP','verificado'),
  (2,'Acta de nacimiento','pendiente'),
  (5,'CURP','verificado'),
  (5,'Cert. de bachillerato','pendiente')
) AS v(id_alumno,tipo,estado)
WHERE NOT EXISTS (
  SELECT 1 FROM documentos_alumno d WHERE d.id_alumno=v.id_alumno AND d.tipo=v.tipo
);

-- ---------- materias del plan IGE-2023 (id_plan=2) ----------
INSERT INTO materias (id_plan,clave,nombre,creditos,horas_teoria,horas_practica,semestre_sug,tipo,activa)
SELECT 2,v.clave,v.nombre,v.creditos,v.ht,v.hp,v.sem,v.tipo::t_tipo_materia,true
FROM (VALUES
  ('IGE-101','Fundamentos de Gestion Empresarial',5,3,2,1,'basica'),
  ('IGE-102','Contabilidad General',5,3,2,1,'basica'),
  ('IGE-201','Microeconomia',4,3,1,2,'basica'),
  ('IGE-202','Estadistica para los Negocios',5,3,2,2,'basica'),
  ('IGE-301','Administracion de Operaciones',5,3,2,3,'basica'),
  ('IGE-302','Mercadotecnia',4,3,1,3,'basica'),
  ('IGE-401','Gestion del Capital Humano',4,3,1,4,'especialidad'),
  ('IGE-402','Plan de Negocios',5,2,3,4,'especialidad'),
  ('IGE-OPT1','Comercio Electronico',4,2,2,5,'optativa')
) AS v(clave,nombre,creditos,ht,hp,sem,tipo)
WHERE NOT EXISTS (
  SELECT 1 FROM materias m WHERE m.id_plan=2 AND m.clave=v.clave
);
