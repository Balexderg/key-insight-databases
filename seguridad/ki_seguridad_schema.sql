-- ==============================================================================
-- 1. Creación del esquema y configuración
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS seg;                       
SET search_path TO seg, public;                     

-- Activación de extensiones necesarias para PostgreSQL
-- `citext`: permite columnas insensibles a mayúsculas/minúsculas (útil para `username`, `correo`).
CREATE EXTENSION IF NOT EXISTS citext;
-- `pgcrypto`: funciones criptográficas y generación de UUID/hash seguros (ej.: `gen_random_uuid()`).
CREATE EXTENSION IF NOT EXISTS pgcrypto;
-- `unaccent`: normaliza texto quitando acentos para búsquedas más tolerantes.
CREATE EXTENSION IF NOT EXISTS unaccent;
-- `pg_trgm`: índices y funciones para búsqueda por similitud (trigramas).
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- ==============================================================================
-- 2. Tablas de referencia y parámetros
-- ==============================================================================

-- Tabla: seg_estado_usuario
-- Describe los distintos estados posibles para los usuarios del sistema.
CREATE TABLE IF NOT EXISTS seg_estado_usuario (
    id_estado    BIGINT       PRIMARY KEY, -- Identificador numérico autoincremental.
    cod_estado   VARCHAR      UNIQUE NOT NULL,                         -- Código del estado (ej.: 'ACTIVO'). Debe ser único.
    nom_estado   VARCHAR      NOT NULL,                                -- Nombre legible del estado (ej.: 'Activo').
    des_estado   VARCHAR,                                              -- Descripción opcional del estado.
    ind_activo   BOOLEAN      NOT NULL DEFAULT TRUE,                   -- Indicador para habilitar/deshabilitar el registro.
    fec_creacion TIMESTAMPTZ  NOT NULL DEFAULT NOW(),                 -- Fecha y hora de creación del registro.
    CONSTRAINT chk_seg_estado_cod CHECK (cod_estado ~ '^[A-Z0-9_]+$')  -- Validación simple: mayúsculas, números y guion bajo.
);

-- Inserta los estados por defecto. Si ya existen, no se insertan nuevamente.
INSERT INTO seg_estado_usuario (cod_estado, nom_estado, des_estado)
VALUES
    ('ACTIVO',    'Activo',    'Usuario habilitado'),               -- Estado para usuarios activos.
    ('BLOQUEADO', 'Bloqueado', 'Usuario bloqueado por seguridad'),  -- Estado para usuarios bloqueados.
    ('PENDIENTE', 'Pendiente', 'Usuario creado pero sin activar'),  -- Estado para usuarios que aún no han activado su cuenta.
    ('ELIMINADO', 'Eliminado', 'Usuario dado de baja')              -- Estado para usuarios eliminados.
ON CONFLICT (cod_estado) DO NOTHING;                               -- Evita duplicar registros si el código ya existe.

-- ==============================================================================
-- 3. Roles y permisos
-- ==============================================================================

-- Tabla: seg_rol
-- Almacena los roles de acceso del sistema (perfil de permisos).
CREATE TABLE IF NOT EXISTS seg_rol (
    id_rol            BIGINT      PRIMARY KEY, -- Identificador único del rol.
    cod_rol           VARCHAR     UNIQUE NOT NULL,                         -- Código corto (ej.: 'ADMIN').
    nom_rol           VARCHAR     NOT NULL,                                -- Nombre descriptivo (ej.: 'Administrador General').
    des_rol           VARCHAR,                                              -- Descripción detallada del rol.
    ind_activo        BOOLEAN     NOT NULL DEFAULT TRUE,                   -- Indica si el rol está activo.
    fec_creacion      TIMESTAMPTZ NOT NULL DEFAULT NOW(),                  -- Fecha de creación del rol.
    fec_actualizacion TIMESTAMPTZ,                                        -- Fecha de última modificación (puede ser nula).
    CONSTRAINT chk_seg_rol_cod CHECK (cod_rol ~ '^[A-Z0-9_]+$')            -- Validación para códigos de rol.
);

-- Tabla: seg_permiso
-- Define las acciones específicas que se pueden asignar a roles.
CREATE TABLE IF NOT EXISTS seg_permiso (
    id_permiso        BIGINT      PRIMARY KEY, -- Identificador único del permiso.
    cod_permiso       VARCHAR     UNIQUE NOT NULL,                         -- Código del permiso (ej.: 'DOC_VER').
    nom_permiso       VARCHAR     NOT NULL,                                -- Nombre del permiso.
    des_permiso       VARCHAR,                                              -- Descripción del permiso.
    ind_activo        BOOLEAN     NOT NULL DEFAULT TRUE,                   -- Indica si el permiso está activo.
    fec_creacion      TIMESTAMPTZ NOT NULL DEFAULT NOW(),                  -- Fecha de creación del permiso.
    fec_actualizacion TIMESTAMPTZ,                                        -- Fecha de última modificación del permiso.
    CONSTRAINT chk_seg_permiso_cod CHECK (cod_permiso ~ '^[A-Z0-9_]+$')    -- Validación para códigos de permiso.
);

-- Tabla: seg_rol_permiso
-- Tabla intermedia que establece la relación muchos-a-muchos entre roles y permisos.
CREATE TABLE IF NOT EXISTS seg_rol_permiso (
    id_rol         BIGINT   NOT NULL,                  -- Identificador del rol.
    id_permiso     BIGINT   NOT NULL,                  -- Identificador del permiso.
    fec_asignacion TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- Fecha en que se asignó el permiso al rol.
    PRIMARY KEY (id_rol, id_permiso),                  -- Clave primaria compuesta para evitar duplicados.
    CONSTRAINT fk_seg_rol_permiso_rol  FOREIGN KEY (id_rol)    REFERENCES seg_rol (id_rol),
    CONSTRAINT fk_seg_rol_permiso_perm FOREIGN KEY (id_permiso) REFERENCES seg_permiso (id_permiso)
);

-- Inserta roles iniciales. Se evita la duplicidad con ON CONFLICT.
INSERT INTO seg_rol (cod_rol, nom_rol, des_rol)
VALUES
    ('ADMIN',        'Administrador General',        'Acceso total al sistema'),               -- Rol con todos los permisos.
    ('RESP_SGSST',   'Responsable SG‑SST',           'Gestiona el SG‑SST'),                  -- Rol responsable del Sistema de Gestión.
    ('APROBADOR',    'Aprobador de Documentos',      'Autoriza y aprueba documentos'),         -- Rol que aprueba documentos.
    ('AUDITOR',      'Auditor',                      'Consulta y revisa información para auditoría'), -- Rol que revisa sin modificar.
    ('LECTOR',       'Lector',                       'Solo lectura de documentos y registros') -- Rol con permisos de consulta.
ON CONFLICT (cod_rol) DO NOTHING;                                                       -- Evita duplicados si ya existen.

-- Inserta permisos básicos para el sistema.
INSERT INTO seg_permiso (cod_permiso, nom_permiso, des_permiso)
VALUES
    ('CORE_EMPRESA_VER',    'Ver empresas',            'Puede listar y ver detalles de empresas'),
    ('CORE_EMPRESA_EDITAR', 'Crear/editar empresas',   'Puede crear y modificar empresas'),
    ('CORE_OBRA_VER',       'Ver obras',               'Puede ver obras y sedes'),
    ('CORE_OBRA_EDITAR',    'Crear/editar obras',      'Puede crear y modificar obras'),
    ('DOC_VER',             'Ver documentos',          'Puede ver documentos del repositorio'),
    ('DOC_CREAR',           'Crear documentos',        'Puede registrar nuevos documentos'),
    ('DOC_APROBAR',         'Aprobar documentos',      'Puede aprobar documentos en el flujo'),
    ('CAP_VER',             'Ver capacitaciones',      'Puede ver eventos de capacitación'),
    ('CAP_GESTIONAR',       'Gestionar capacitaciones','Puede crear, editar y cerrar capacitaciones')
ON CONFLICT (cod_permiso) DO NOTHING;                                                   -- Evita duplicar permisos.

-- Asignación de permisos a roles

-- Otorga todos los permisos a ADMIN mediante una consulta cruzada (CROSS JOIN).
INSERT INTO seg_rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM seg_rol r CROSS JOIN seg_permiso p
WHERE r.cod_rol = 'ADMIN'
ON CONFLICT DO NOTHING;                                    -- Evita duplicar asignaciones.

-- Asigna permisos al rol Responsable SG‑SST.
INSERT INTO seg_rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM seg_rol r
JOIN seg_permiso p ON p.cod_permiso IN (
    'CORE_EMPRESA_VER', 'CORE_EMPRESA_EDITAR',
    'CORE_OBRA_VER',    'CORE_OBRA_EDITAR',
    'DOC_VER',          'DOC_CREAR',
    'CAP_VER',          'CAP_GESTIONAR'
)
WHERE r.cod_rol = 'RESP_SGSST'
ON CONFLICT DO NOTHING;

-- Asigna permisos al rol Aprobador (solo documentos).
INSERT INTO seg_rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM seg_rol r
JOIN seg_permiso p ON p.cod_permiso IN ('DOC_VER','DOC_APROBAR')
WHERE r.cod_rol = 'APROBADOR'
ON CONFLICT DO NOTHING;

-- Asigna permisos al rol Auditor (solo lectura).
INSERT INTO seg_rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM seg_rol r
JOIN seg_permiso p ON p.cod_permiso IN (
    'CORE_EMPRESA_VER',
    'CORE_OBRA_VER',
    'DOC_VER',
    'CAP_VER'
)
WHERE r.cod_rol = 'AUDITOR'
ON CONFLICT DO NOTHING;

-- Asigna permisos al rol Lector (únicamente ver documentos).
INSERT INTO seg_rol_permiso (id_rol, id_permiso)
SELECT r.id_rol, p.id_permiso
FROM seg_rol r
JOIN seg_permiso p ON p.cod_permiso = 'DOC_VER'
WHERE r.cod_rol = 'LECTOR'
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- 4. Gestión de usuarios, roles asignados y sesiones
-- ==============================================================================

-- Tabla: seg_usuario
-- Contiene las credenciales y datos generales de cada usuario del sistema.
CREATE TABLE IF NOT EXISTS seg_usuario (
    id_usuario        BIGINT       PRIMARY KEY, -- Identificador único del usuario.
    username          CITEXT       NOT NULL UNIQUE,                          -- Nombre de usuario (insensible a mayúsculas/minúsculas).
    correo            CITEXT       NOT NULL UNIQUE,                          -- Correo electrónico insensible a mayúsculas/minúsculas.
    nombre            VARCHAR      NOT NULL,                                -- Nombres del usuario.
    apellido          VARCHAR      NOT NULL,                                -- Apellidos del usuario.
    clave_hash        VARCHAR      NOT NULL,                                -- Hash de la contraseña (se almacena el hash, no la clave).
    id_estado         BIGINT       NOT NULL REFERENCES seg_estado_usuario(id_estado), -- Estado del usuario.
    telefono          VARCHAR,                                               -- Número de contacto (opcional).
    debe_cambiar_clave BOOLEAN     NOT NULL DEFAULT TRUE,                    -- Obliga a cambiar la clave en el próximo inicio de sesión.
    fec_ultimo_acceso TIMESTAMPTZ,                                            -- Fecha y hora del último acceso.
    fec_creacion      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),                   -- Fecha de creación del usuario.
    fec_actualizacion TIMESTAMPTZ,                                           -- Fecha de última modificación (puede ser nula).
    CONSTRAINT chk_seg_usuario_username CHECK (username ~ '^[A-Za-z0-9._-]+$'),
    CONSTRAINT chk_seg_usuario_correo   CHECK (correo   ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
    CONSTRAINT chk_seg_usuario_nombre   CHECK (nombre   ~ '^[A-Za-zÁÉÍÓÚáéíóúÑñüÜ\s]+$'),
    CONSTRAINT chk_seg_usuario_apellido CHECK (apellido ~ '^[A-Za-zÁÉÍÓÚáéíóúÑñüÜ\s]+$'),
    CONSTRAINT chk_seg_usuario_telefono CHECK (telefono IS NULL OR telefono ~ '^[0-9 +()\\-]+$')
);

-- Índice para acelerar consultas por estado de usuario.
CREATE INDEX IF NOT EXISTS idx_seg_usuario_estado ON seg_usuario(id_estado);

-- Tabla: seg_usuario_rol
-- Relaciona usuarios con sus roles (muchos-a-muchos).
CREATE TABLE IF NOT EXISTS seg_usuario_rol (
    id_usuario     BIGINT   NOT NULL,                  -- Identificador del usuario.
    id_rol         BIGINT   NOT NULL,                  -- Identificador del rol.
    fec_asignacion TIMESTAMPTZ NOT NULL DEFAULT NOW(), -- Fecha en que se asignó el rol.
    PRIMARY KEY (id_usuario, id_rol),                  -- Clave primaria compuesta.
    CONSTRAINT fk_seg_usuario_rol_usuario FOREIGN KEY (id_usuario) REFERENCES seg_usuario (id_usuario),
    CONSTRAINT fk_seg_usuario_rol_rol     FOREIGN KEY (id_rol)     REFERENCES seg_rol (id_rol)
);

-- Tabla: seg_sesion
-- Registra las sesiones activas de los usuarios (tokens JWT).
CREATE TABLE IF NOT EXISTS seg_sesion (
    id_sesion            UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY, -- Identificador único (UUID) de la sesión.
    id_usuario           BIGINT NOT NULL REFERENCES seg_usuario(id_usuario),   -- Usuario asociado a la sesión.
    token_jwt            TEXT NOT NULL,                                       -- Token de autenticación JWT o su identificador.
    ip_origen            INET,                                                -- Dirección IP de origen de la sesión (opcional).
    user_agent           VARCHAR,                                             -- Información del navegador/dispositivo (opcional).
    fec_inicio           TIMESTAMPTZ NOT NULL DEFAULT NOW(),                  -- Fecha y hora de inicio de la sesión.
    fec_ultima_actividad TIMESTAMPTZ NOT NULL DEFAULT NOW(),                  -- Fecha y hora de la última actividad.
    ind_activa           BOOLEAN NOT NULL DEFAULT TRUE                        -- Indica si la sesión está activa.
);

-- Índice para buscar sesiones activas de un usuario.
CREATE INDEX IF NOT EXISTS idx_seg_sesion_usuario_activa ON seg_sesion(id_usuario, ind_activa);

-- ==============================================================================
-- 5. Auditoría y recuperación de contraseñas
-- ==============================================================================

-- Tabla: seg_auditoria
-- Almacena eventos de auditoría para rastrear operaciones y accesos.
CREATE TABLE IF NOT EXISTS seg_auditoria (
    id_auditoria     BIGINT      PRIMARY KEY, -- Identificador autoincremental de la auditoría.
    id_usuario       BIGINT,                                                   -- Usuario que realizó la acción (opcional).
    esquema          VARCHAR     NOT NULL,                                      -- Esquema de la tabla afectada.
    tabla            VARCHAR     NOT NULL,                                      -- Nombre de la tabla afectada.
    accion           VARCHAR     NOT NULL,                                      -- Tipo de operación: INSERT, UPDATE, DELETE, LOGIN, LOGOUT, etc.
    id_registro      VARCHAR,                                                     -- Identificador del registro afectado (como texto).
    datos_antes      JSONB,                                                        -- Datos antes del cambio (JSON), si aplica.
    datos_despues    JSONB,                                                        -- Datos después del cambio (JSON), si aplica.
    ip_origen        INET,                                                          -- IP de origen de la acción.
    user_agent       VARCHAR,                                                       -- Información del navegador/dispositivo.
    fecha_evento     TIMESTAMPTZ NOT NULL DEFAULT NOW(),                            -- Fecha y hora en que ocurrió el evento.
    CONSTRAINT chk_seg_auditoria_accion CHECK (accion IN ('INSERT','UPDATE','DELETE','LOGIN','LOGOUT','OTHER'))
);

-- Índice para consultas frecuentes sobre auditoría.
CREATE INDEX IF NOT EXISTS idx_seg_auditoria_busqueda ON seg_auditoria(esquema, tabla, accion, fecha_evento);

-- Tabla: seg_token_recuperacion
-- Permite gestionar tokens para la recuperación de contraseña.
CREATE TABLE IF NOT EXISTS seg_token_recuperacion (
    id_token       UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY, -- Identificador único del token de recuperación.
    id_usuario     BIGINT NOT NULL REFERENCES seg_usuario(id_usuario),  -- Usuario al que pertenece el token.
    token          VARCHAR      NOT NULL,                               -- Token aleatorio generado para recuperar la contraseña.
    fec_expiracion TIMESTAMPTZ NOT NULL,                               -- Fecha y hora en la que expira el token.
    ind_usado      BOOLEAN NOT NULL DEFAULT FALSE                      -- Indica si el token ya fue utilizado.
);
