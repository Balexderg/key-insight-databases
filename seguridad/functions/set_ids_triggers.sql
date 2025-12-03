-- Triggers para asignar IDs usando seg.generate_table_id() cuando no se provee (COALESCE behaviour)
-- Para cada tabla con columna id se crea una función específica que setea NEW.<id_col> si es NULL.

CREATE SCHEMA IF NOT EXISTS seg;

-- seg_estado_usuario
CREATE OR REPLACE FUNCTION seg.set_seg_estado_usuario_id()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.id_estado IS NULL THEN
        NEW.id_estado := seg.generate_table_id('seg_estado_usuario','id_estado');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_seg_estado_usuario_id ON seg_estado_usuario;
CREATE TRIGGER trg_set_seg_estado_usuario_id
BEFORE INSERT ON seg_estado_usuario
FOR EACH ROW EXECUTE FUNCTION seg.set_seg_estado_usuario_id();

-- seg_rol
CREATE OR REPLACE FUNCTION seg.set_seg_rol_id()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.id_rol IS NULL THEN
        NEW.id_rol := seg.generate_table_id('seg_rol','id_rol');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_seg_rol_id ON seg_rol;
CREATE TRIGGER trg_set_seg_rol_id
BEFORE INSERT ON seg_rol
FOR EACH ROW EXECUTE FUNCTION seg.set_seg_rol_id();

-- seg_permiso
CREATE OR REPLACE FUNCTION seg.set_seg_permiso_id()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.id_permiso IS NULL THEN
        NEW.id_permiso := seg.generate_table_id('seg_permiso','id_permiso');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_seg_permiso_id ON seg_permiso;
CREATE TRIGGER trg_set_seg_permiso_id
BEFORE INSERT ON seg_permiso
FOR EACH ROW EXECUTE FUNCTION seg.set_seg_permiso_id();

-- seg_usuario
CREATE OR REPLACE FUNCTION seg.set_seg_usuario_id()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.id_usuario IS NULL THEN
        NEW.id_usuario := seg.generate_table_id('seg_usuario','id_usuario');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_seg_usuario_id ON seg_usuario;
CREATE TRIGGER trg_set_seg_usuario_id
BEFORE INSERT ON seg_usuario
FOR EACH ROW EXECUTE FUNCTION seg.set_seg_usuario_id();

-- seg_auditoria (cuando insertan manualmente registros de auditoría desde código)
CREATE OR REPLACE FUNCTION seg.set_seg_auditoria_id()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.id_auditoria IS NULL THEN
        NEW.id_auditoria := seg.generate_table_id('seg_auditoria','id_auditoria');
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_set_seg_auditoria_id ON seg_auditoria;
CREATE TRIGGER trg_set_seg_auditoria_id
BEFORE INSERT ON seg_auditoria
FOR EACH ROW EXECUTE FUNCTION seg.set_seg_auditoria_id();
