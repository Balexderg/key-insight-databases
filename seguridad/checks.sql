-- checks.sql
-- Consultas para detectar filas que violarían las nuevas CHECK constraints
-- Ejecutar en staging/local antes de aplicar constraints o migración a producción.

-- 1) Correos inválidos
SELECT id_usuario, correo
FROM seg_usuario
WHERE correo !~* '^[^@\s]+@[^@\s]+\.[^@\s]+$';

-- 2) Usernames inválidos
SELECT id_usuario, username
FROM seg_usuario
WHERE username !~ '^[A-Za-z0-9._-]+$';

-- 3) Nombres / apellidos con caracteres no permitidos
SELECT id_usuario, nombre, apellido
FROM seg_usuario
WHERE nombre !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñüÜ\s]+' OR apellido !~ '^[A-Za-zÁÉÍÓÚáéíóúÑñüÜ\s]+';

-- 4) Teléfonos inválidos
SELECT id_usuario, telefono
FROM seg_usuario
WHERE telefono IS NOT NULL AND telefono !~ '^[0-9 +()\-]+$';

-- 5) Códigos de rol/permiso/estado fuera del patrón esperado
SELECT id_rol, cod_rol FROM seg_rol WHERE cod_rol !~ '^[A-Z0-9_]+';
SELECT id_permiso, cod_permiso FROM seg_permiso WHERE cod_permiso !~ '^[A-Z0-9_]+';
SELECT id_estado, cod_estado FROM seg_estado_usuario WHERE cod_estado !~ '^[A-Z0-9_]+';

-- 6) Acciones no permitidas en auditoría
SELECT id_auditoria, accion FROM seg_auditoria WHERE accion NOT IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','OTHER');

-- 7) FK orphans (por si acaso)
SELECT u.id_usuario FROM seg_usuario u LEFT JOIN seg_estado_usuario s ON u.id_estado = s.id_estado WHERE s.id_estado IS NULL;

-- 8) Secuencias existentes (info útil para migraciones)
SELECT n.nspname AS schema, c.relname AS sequence
FROM pg_class c
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE c.relkind = 'S' AND n.nspname = 'seg';
