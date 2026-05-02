-- ====================================================
-- SISTEMA ESCOLAR - DATOS DE PRUEBA  -  06_seed.sql
-- password de todos los usuarios de prueba: password123
-- ====================================================

-- Roles
INSERT INTO roles (nombre, descripcion) VALUES
  ('alumno',         'Estudiante inscrito'),
  ('docente',        'Profesor de asignatura'),
  ('admin',          'Administrador general'),
  ('serv_escolares', 'Servicios Escolares'),
  ('coordinador',    'Coordinador de carrera'),
  ('vinculacion',    'Departamento de Vinculación')
ON CONFLICT (nombre) DO NOTHING;

-- Permisos básicos
INSERT INTO permisos (modulo, accion, descripcion) VALUES
  ('kardex',         'leer',     'Consultar kárdex'),
  ('calificaciones', 'crear',    'Capturar calificaciones'),
  ('calificaciones', 'editar',   'Modificar calificaciones (auditado)'),
  ('inscripciones',  'crear',    'Inscribir alumno a grupo'),
  ('grupos',         'crear',    'Crear grupos'),
  ('constancias',    'crear',    'Solicitar constancia'),
  ('constancias',    'aprobar',  'Aprobar constancia'),
  ('reportes',       'leer',     'Ver reportes'),
  ('alumnos',        'editar',   'Editar datos de alumno')
ON CONFLICT (modulo, accion) DO NOTHING;

-- Carreras
INSERT INTO carreras (clave, nombre, duracion_sem, creditos_total) VALUES
  ('ISC','Ingeniería en Sistemas Computacionales',9,250),
  ('IGE','Ingeniería en Gestión Empresarial',9,260),
  ('IIA','Ingeniería en Industrias Alimentarias',9,260),
  ('ITC','Ingeniería en Tecnologías de la Información',9,250),
  ('IME','Ingeniería Mecatrónica',9,260)
ON CONFLICT (clave) DO NOTHING;

-- Planes de estudio
INSERT INTO planes_estudio (id_carrera, clave_plan, nombre, anio_vigencia)
SELECT id_carrera,'ISC-2023','Plan ISC 2023',2023 FROM carreras WHERE clave='ISC'
ON CONFLICT (id_carrera, clave_plan) DO NOTHING;
INSERT INTO planes_estudio (id_carrera, clave_plan, nombre, anio_vigencia)
SELECT id_carrera,'IGE-2023','Plan IGE 2023',2023 FROM carreras WHERE clave='IGE'
ON CONFLICT (id_carrera, clave_plan) DO NOTHING;

-- Salones
INSERT INTO salones (clave, nombre, tipo, capacidad, edificio) VALUES
  ('Lab-3',   'Laboratorio de Cómputo 3',  'laboratorio', 35,'A'),
  ('Aula-7',  'Aula 7',                    'aula',        40,'A'),
  ('Aula-2',  'Aula 2',                    'aula',        35,'A'),
  ('Sala-12', 'Sala 12',                   'aula',        35,'B'),
  ('Aula-8',  'Aula 8',                    'aula',        40,'B'),
  ('Lab-Fis', 'Laboratorio de Física',     'laboratorio', 30,'C')
ON CONFLICT (clave) DO NOTHING;

-- Períodos
INSERT INTO periodos (clave, fecha_inicio, fecha_fin, insc_inicio, insc_fin, estado) VALUES
  ('2024-B','2024-08-12','2024-12-13','2024-08-05','2024-08-09','cerrado'),
  ('2025-A','2025-01-13','2025-05-30','2025-01-06','2025-01-10','en_curso'),
  ('2025-B','2025-08-11','2025-12-12','2025-08-04','2025-08-08','programado')
ON CONFLICT (clave) DO NOTHING;

-- Materias plan ISC-2023
WITH plan AS (SELECT id_plan FROM planes_estudio WHERE clave_plan='ISC-2023')
INSERT INTO materias (id_plan, clave, nombre, creditos, horas_teoria, horas_practica, semestre_sug, tipo)
SELECT p.id_plan, m.clave, m.nombre, m.creditos, m.ht, m.hp, m.sem, m.tipo::t_tipo_materia
FROM plan p, (VALUES
  ('MAT-101','Cálculo Integral',         5,3,2,1,'basica'),
  ('INF-101','Fundamentos de Programación',4,2,2,1,'basica'),
  ('MAT-102','Álgebra Lineal',            4,2,2,1,'basica'),
  ('ING-101','Inglés I',                  4,4,0,1,'basica'),
  ('HUM-001','Taller de Ética',           3,3,0,1,'basica'),
  ('MAT-201','Cálculo Diferencial',       5,3,2,2,'basica'),
  ('INF-205','Programación Orientada a Objetos',5,2,3,2,'basica'),
  ('MAT-202','Probabilidad y Estadística',4,2,2,2,'basica'),
  ('ING-201','Inglés II',                 4,4,0,2,'basica'),
  ('ADM-101','Contabilidad Financiera',   3,3,0,2,'basica'),
  ('BDT-201','Base de Datos',             4,2,2,3,'basica'),
  ('RED-201','Fundamentos de Redes',      4,2,2,3,'basica'),
  ('MAT-301','Métodos Numéricos',         4,2,2,3,'basica'),
  ('ING-301','Inglés III',                4,4,0,3,'basica'),
  ('ECO-101','Economía',                  3,3,0,3,'basica'),
  ('FIS-202','Física Aplicada',           5,3,2,3,'basica'),
  ('HUM-101','Ética Profesional',         3,3,0,3,'basica'),
  ('BDT-301','Bases de Datos Avanzadas',  4,2,2,4,'especialidad'),
  ('RED-301','Seguridad en Redes',        4,2,2,4,'especialidad'),
  ('ISW-301','Ingeniería de Software',    4,2,2,4,'especialidad'),
  ('ING-401','Inglés IV',                 4,4,0,4,'basica'),
  ('INF-401','Sistemas Operativos',       4,2,2,4,'basica'),
  ('ISW-401','Arquitectura de Software',  4,2,2,5,'especialidad'),
  ('INT-501','Inteligencia Artificial',   4,2,2,5,'especialidad'),
  ('MOV-501','Desarrollo de Apps Móviles',4,2,2,5,'especialidad'),
  ('ING-501','Inglés V',                  4,4,0,5,'basica'),
  ('ADM-401','Gestión de Proyectos',      3,3,0,5,'especialidad')
) AS m(clave,nombre,creditos,ht,hp,sem,tipo)
ON CONFLICT (id_plan, clave) DO NOTHING;

-- Prerequisitos
INSERT INTO prerrequisitos (id_materia, id_prerreq)
SELECT a.id_materia, b.id_materia
FROM materias a, materias b
WHERE (a.clave='MAT-201' AND b.clave='MAT-101')
   OR (a.clave='INF-205' AND b.clave='INF-101')
   OR (a.clave='ING-201' AND b.clave='ING-101')
   OR (a.clave='ING-301' AND b.clave='ING-201')
   OR (a.clave='ING-401' AND b.clave='ING-301')
   OR (a.clave='ING-501' AND b.clave='ING-401')
   OR (a.clave='BDT-301' AND b.clave='BDT-201')
   OR (a.clave='RED-301' AND b.clave='RED-201')
   OR (a.clave='ISW-401' AND b.clave='ISW-301')
ON CONFLICT DO NOTHING;

-- Conceptos de pago
INSERT INTO conceptos_pago (clave, descripcion, monto, recurrente) VALUES
  ('COLEG', 'Colegiatura mensual',         1850.00, TRUE),
  ('REINSC','Cuota de reinscripción',       1200.00, FALSE),
  ('EXTRA', 'Examen extraordinario',         350.00, FALSE),
  ('CONST', 'Constancia de estudios',         50.00, FALSE),
  ('TIT',   'Derechos de titulación',        3500.00, FALSE)
ON CONFLICT (clave) DO NOTHING;

-- Tipos de constancia
INSERT INTO tipos_constancia (nombre, descripcion, costo, tiempo_entrega, requiere_pago) VALUES
  ('Constancia de Estudios',       'Acredita que eres alumno activo en el semestre actual.',  50.00,'24-48 hrs',TRUE),
  ('Constancia de Inscripción',    'Detalle de materias inscritas en el ciclo vigente.',      50.00,'24 hrs',   TRUE),
  ('Constancia de Calificaciones', 'Historial de calificaciones (kárdex parcial).',           75.00,'48 hrs',   TRUE),
  ('Constancia de No Adeudo',      'Certifica que no tienes deudas con la institución.',       0.00,'72 hrs',   FALSE),
  ('Carta de Pasante',             'Para alumnos que han concluido el 100% de créditos.',    150.00,'3-5 días', TRUE),
  ('Carta de Buena Conducta',      'Expedida por prefectura.',                                50.00,'24 hrs',   TRUE)
ON CONFLICT DO NOTHING;

-- Modalidades de titulación
INSERT INTO modalidades_titulacion (nombre, descripcion) VALUES
  ('Tesis',               'Investigación documental con defensa oral'),
  ('Residencia Profesional','Proyecto en empresa con mínimo 480 hrs'),
  ('CENEVAL (EGEL)',       'Examen General de Egreso del CENEVAL'),
  ('Promedio mínimo 9.0', 'Titulación automática por promedio de excelencia'),
  ('Estudios de Posgrado', 'Por créditos en programa de posgrado')
ON CONFLICT (nombre) DO NOTHING;

-- Preguntas de evaluación docente
INSERT INTO eval_preguntas (texto, orden) VALUES
  ('Dominio del tema',         1),
  ('Puntualidad y asistencia', 2),
  ('Claridad en explicaciones',3),
  ('Atención a dudas',         4),
  ('Material didáctico',       5),
  ('Relación con los alumnos', 6)
ON CONFLICT DO NOTHING;

-- ============================================================
-- USUARIOS DE PRUEBA
-- Los supabase_uid se llenan después de crear los usuarios
-- en Supabase Dashboard → Authentication → Users
-- O ejecuta el script de auth al final de este archivo.
-- ============================================================
INSERT INTO usuarios (email, id_rol, nombres, apellido_pat, apellido_mat) VALUES
  ('21310001@mazatlan.tecnm.mx',(SELECT id_rol FROM roles WHERE nombre='alumno'),        'Ana',     'García',   'Hernández'),
  ('clopez@mazatlan.tecnm.mx',  (SELECT id_rol FROM roles WHERE nombre='docente'),       'Claudia', 'López',    'Ruiz'),
  ('mperez@mazatlan.tecnm.mx',  (SELECT id_rol FROM roles WHERE nombre='admin'),         'Mario',   'Pérez',    'Soto'),
  ('cruiz@mazatlan.tecnm.mx',   (SELECT id_rol FROM roles WHERE nombre='serv_escolares'),'Carmen',  'Ruiz',     'Vega'),
  ('ecampos@mazatlan.tecnm.mx', (SELECT id_rol FROM roles WHERE nombre='coordinador'),   'Ernesto', 'Campos',   'Mora'),
  ('pmora@mazatlan.tecnm.mx',   (SELECT id_rol FROM roles WHERE nombre='vinculacion'),   'Patricia','Mora',     'León'),
  ('21310002@mazatlan.tecnm.mx',(SELECT id_rol FROM roles WHERE nombre='alumno'),        'Carlos',  'López',    'Martínez'),
  ('21310003@mazatlan.tecnm.mx',(SELECT id_rol FROM roles WHERE nombre='alumno'),        'Diana',   'Ramírez',  'Soto'),
  ('21310004@mazatlan.tecnm.mx',(SELECT id_rol FROM roles WHERE nombre='alumno'),        'Eduardo', 'Torres',   'Vega'),
  ('21310005@mazatlan.tecnm.mx',(SELECT id_rol FROM roles WHERE nombre='alumno'),        'Fernanda','Mendoza',  'Cruz'),
  ('cramirez@mazatlan.tecnm.mx',(SELECT id_rol FROM roles WHERE nombre='docente'),       'Carlos',  'Ramírez',  'Núñez')
ON CONFLICT (email) DO NOTHING;

-- Alumno principal (Ana García - id_usuario 1)
INSERT INTO alumnos (id_usuario, matricula, id_carrera, id_plan, fecha_ingreso, semestre_actual, promedio_gral, creditos_acum)
SELECT u.id_usuario,'21310001',c.id_carrera,pe.id_plan,'2023-08-12',5,8.3,80
FROM usuarios u, carreras c, planes_estudio pe
WHERE u.email='21310001@mazatlan.tecnm.mx'
  AND c.clave='ISC' AND pe.clave_plan='ISC-2023'
ON CONFLICT (matricula) DO NOTHING;

-- Alumnos adicionales
INSERT INTO alumnos (id_usuario, matricula, id_carrera, id_plan, fecha_ingreso, semestre_actual)
SELECT u.id_usuario,'21310002',c.id_carrera,pe.id_plan,'2023-08-12',5
FROM usuarios u, carreras c, planes_estudio pe
WHERE u.email='21310002@mazatlan.tecnm.mx' AND c.clave='ISC' AND pe.clave_plan='ISC-2023'
ON CONFLICT (matricula) DO NOTHING;

INSERT INTO alumnos (id_usuario, matricula, id_carrera, id_plan, fecha_ingreso, semestre_actual)
SELECT u.id_usuario,'21310003',c.id_carrera,pe.id_plan,'2023-08-12',5
FROM usuarios u, carreras c, planes_estudio pe
WHERE u.email='21310003@mazatlan.tecnm.mx' AND c.clave='ISC' AND pe.clave_plan='ISC-2023'
ON CONFLICT (matricula) DO NOTHING;

INSERT INTO alumnos (id_usuario, matricula, id_carrera, id_plan, fecha_ingreso, semestre_actual)
SELECT u.id_usuario,'21310004',c.id_carrera,pe.id_plan,'2023-08-12',5
FROM usuarios u, carreras c, planes_estudio pe
WHERE u.email='21310004@mazatlan.tecnm.mx' AND c.clave='ISC' AND pe.clave_plan='ISC-2023'
ON CONFLICT (matricula) DO NOTHING;

INSERT INTO alumnos (id_usuario, matricula, id_carrera, id_plan, fecha_ingreso, semestre_actual)
SELECT u.id_usuario,'21310005',c.id_carrera,pe.id_plan,'2022-08-12',7
FROM usuarios u, carreras c, planes_estudio pe
WHERE u.email='21310005@mazatlan.tecnm.mx' AND c.clave='ISC' AND pe.clave_plan='ISC-2023'
ON CONFLICT (matricula) DO NOTHING;

-- Docentes
INSERT INTO docentes (id_usuario, num_empleado, grado_academico, departamento)
SELECT u.id_usuario,'EMP-0042','doctorado','Sistemas y Computación'
FROM usuarios u WHERE u.email='clopez@mazatlan.tecnm.mx'
ON CONFLICT (num_empleado) DO NOTHING;

INSERT INTO docentes (id_usuario, num_empleado, grado_academico, departamento)
SELECT u.id_usuario,'EMP-0019','doctorado','Ciencias Básicas'
FROM usuarios u WHERE u.email='cramirez@mazatlan.tecnm.mx'
ON CONFLICT (num_empleado) DO NOTHING;

-- Grupos del período 2025-A
INSERT INTO grupos (clave_grupo, id_materia, id_docente, id_periodo, id_salon, cupo_max, cupo_actual, estado)
SELECT 'BDT-201-A',
  (SELECT id_materia FROM materias WHERE clave='BDT-201'),
  (SELECT id_docente FROM docentes WHERE num_empleado='EMP-0042'),
  (SELECT id_periodo FROM periodos WHERE clave='2025-A'),
  (SELECT id_salon   FROM salones  WHERE clave='Lab-3'),
  35,28,'abierto'
ON CONFLICT (clave_grupo, id_periodo) DO NOTHING;

INSERT INTO grupos (clave_grupo, id_materia, id_docente, id_periodo, id_salon, cupo_max, cupo_actual, estado)
SELECT 'INF-205-A',
  (SELECT id_materia FROM materias WHERE clave='INF-205'),
  (SELECT id_docente FROM docentes WHERE num_empleado='EMP-0042'),
  (SELECT id_periodo FROM periodos WHERE clave='2025-A'),
  (SELECT id_salon   FROM salones  WHERE clave='Sala-12'),
  35,35,'lleno'
ON CONFLICT (clave_grupo, id_periodo) DO NOTHING;

INSERT INTO grupos (clave_grupo, id_materia, id_docente, id_periodo, id_salon, cupo_max, cupo_actual, estado)
SELECT 'MAT-201-A',
  (SELECT id_materia FROM materias WHERE clave='MAT-201'),
  (SELECT id_docente FROM docentes WHERE num_empleado='EMP-0019'),
  (SELECT id_periodo FROM periodos WHERE clave='2025-A'),
  (SELECT id_salon   FROM salones  WHERE clave='Aula-8'),
  40,30,'abierto'
ON CONFLICT (clave_grupo, id_periodo) DO NOTHING;

INSERT INTO grupos (clave_grupo, id_materia, id_docente, id_periodo, id_salon, cupo_max, cupo_actual, estado)
SELECT 'ING-401-A',
  (SELECT id_materia FROM materias WHERE clave='ING-401'),
  (SELECT id_docente FROM docentes WHERE num_empleado='EMP-0042'),
  (SELECT id_periodo FROM periodos WHERE clave='2025-A'),
  (SELECT id_salon   FROM salones  WHERE clave='Aula-7'),
  40,20,'abierto'
ON CONFLICT (clave_grupo, id_periodo) DO NOTHING;

INSERT INTO grupos (clave_grupo, id_materia, id_docente, id_periodo, id_salon, cupo_max, cupo_actual, estado)
SELECT 'HUM-101-A',
  (SELECT id_materia FROM materias WHERE clave='HUM-101'),
  (SELECT id_docente FROM docentes WHERE num_empleado='EMP-0042'),
  (SELECT id_periodo FROM periodos WHERE clave='2025-A'),
  (SELECT id_salon   FROM salones  WHERE clave='Aula-2'),
  35,15,'abierto'
ON CONFLICT (clave_grupo, id_periodo) DO NOTHING;

INSERT INTO grupos (clave_grupo, id_materia, id_docente, id_periodo, id_salon, cupo_max, cupo_actual, estado)
SELECT 'FIS-202-A',
  (SELECT id_materia FROM materias WHERE clave='FIS-202'),
  (SELECT id_docente FROM docentes WHERE num_empleado='EMP-0019'),
  (SELECT id_periodo FROM periodos WHERE clave='2025-A'),
  (SELECT id_salon   FROM salones  WHERE clave='Lab-Fis'),
  30,25,'abierto'
ON CONFLICT (clave_grupo, id_periodo) DO NOTHING;

-- Horarios de los grupos
INSERT INTO horarios_grupo (id_grupo, dia_semana, hora_inicio, hora_fin, id_salon)
SELECT g.id_grupo, 1, '11:00', '13:00', s.id_salon
FROM grupos g, salones s WHERE g.clave_grupo='BDT-201-A' AND s.clave='Lab-3'
ON CONFLICT DO NOTHING;

INSERT INTO horarios_grupo (id_grupo, dia_semana, hora_inicio, hora_fin, id_salon)
SELECT g.id_grupo, 3, '11:00', '13:00', s.id_salon
FROM grupos g, salones s WHERE g.clave_grupo='BDT-201-A' AND s.clave='Lab-3'
ON CONFLICT DO NOTHING;

INSERT INTO horarios_grupo (id_grupo, dia_semana, hora_inicio, hora_fin, id_salon)
SELECT g.id_grupo, 2, '09:00', '11:00', s.id_salon
FROM grupos g, salones s WHERE g.clave_grupo='INF-205-A' AND s.clave='Sala-12'
ON CONFLICT DO NOTHING;

INSERT INTO horarios_grupo (id_grupo, dia_semana, hora_inicio, hora_fin, id_salon)
SELECT g.id_grupo, 4, '09:00', '11:00', s.id_salon
FROM grupos g, salones s WHERE g.clave_grupo='INF-205-A' AND s.clave='Sala-12'
ON CONFLICT DO NOTHING;

INSERT INTO horarios_grupo (id_grupo, dia_semana, hora_inicio, hora_fin, id_salon)
SELECT g.id_grupo, 5, '08:00', '12:00', s.id_salon
FROM grupos g, salones s WHERE g.clave_grupo='ING-401-A' AND s.clave='Aula-7'
ON CONFLICT DO NOTHING;

-- Inscripciones de Ana García al período actual
INSERT INTO inscripciones (id_alumno, id_grupo, estado, cal_p1, cal_p2)
SELECT a.id_alumno, g.id_grupo, 'en_curso', 9.2, 8.8
FROM alumnos a, grupos g WHERE a.matricula='21310001' AND g.clave_grupo='BDT-201-A'
ON CONFLICT DO NOTHING;

INSERT INTO inscripciones (id_alumno, id_grupo, estado, cal_p1, cal_p2)
SELECT a.id_alumno, g.id_grupo, 'en_curso', 8.0, 8.5
FROM alumnos a, grupos g WHERE a.matricula='21310001' AND g.clave_grupo='ING-401-A'
ON CONFLICT DO NOTHING;

-- Kárdex de Ana García (semestres anteriores)
INSERT INTO kardex (id_alumno, id_materia, id_periodo, calificacion, oportunidad, estatus, creditos)
SELECT a.id_alumno, m.id_materia, p.id_periodo, c, 1,
       CASE WHEN c >= 6 THEN 'aprobada'::t_estatus_kardex ELSE 'reprobada'::t_estatus_kardex END,
       m.creditos
FROM alumnos a, periodos p,
(VALUES
  ('MAT-101',9.5),('INF-101',8.0),('MAT-102',7.5),('ING-101',9.0),('HUM-001',10.0),
  ('MAT-201',8.8),('INF-205',9.2),('MAT-202',7.0),('ING-201',8.5),('ADM-101',8.0)
) AS kd(clave, c)
JOIN materias m ON m.clave = kd.clave
WHERE a.matricula='21310001' AND p.clave='2024-B'
ON CONFLICT DO NOTHING;

-- Adeudo de ejemplo para Ana
INSERT INTO adeudos (id_alumno, id_concepto, id_periodo, monto, fecha_gen, fecha_venc, ref_bancaria, estado)
SELECT a.id_alumno, cp.id_concepto, p.id_periodo, 1850.00,
       '2025-01-13', '2025-02-13', 'COL21310001251', 'pendiente'
FROM alumnos a, conceptos_pago cp, periodos p
WHERE a.matricula='21310001' AND cp.clave='COLEG' AND p.clave='2025-A'
ON CONFLICT DO NOTHING;

-- Notificaciones de ejemplo (para Ana García)
INSERT INTO notificaciones (id_usuario, tipo, titulo, mensaje)
SELECT u.id_usuario, 'warn', 'Falta registrada', 'No asististe a BDT-201 el día de hoy.'
FROM usuarios u WHERE u.email='21310001@mazatlan.tecnm.mx';

INSERT INTO notificaciones (id_usuario, tipo, titulo, mensaje)
SELECT u.id_usuario, 'info', 'Reinscripción abierta',
       'El período de inscripción para 2025-B inicia el 15 de mayo.'
FROM usuarios u WHERE u.email='21310001@mazatlan.tecnm.mx';

INSERT INTO notificaciones (id_usuario, tipo, titulo, mensaje)
SELECT u.id_usuario, 'info', 'Evaluación docente',
       'Ya puedes evaluar a tus docentes del semestre actual.'
FROM usuarios u WHERE u.email='21310001@mazatlan.tecnm.mx';

-- Datos personales de Ana
INSERT INTO alumnos_datos (id_alumno, curp, fecha_nac, genero, email_personal,
                            telefono_cel, calle_num, colonia, municipio, estado, cp,
                            emerg_nombre, emerg_parentesco, emerg_telefono)
SELECT a.id_alumno,
       'GAHA040310MSLRNN09','2004-03-10','F',
       'ana.garcia04@gmail.com','6691234567',
       'Av. del Mar 245','Las Gaviotas','Mazatlán','Sinaloa','82114',
       'Rosa Hernández Vega','Madre','6693456789'
FROM alumnos a WHERE a.matricula='21310001'
ON CONFLICT DO NOTHING;
