-- Función de auditoría genérica adaptada al esquema `seg` y tabla `seg_auditoria`.
-- Audita INSERT/UPDATE/DELETE y escribe en `seg_auditoria`.

DROP FUNCTION IF EXISTS seg.audit_changes() CASCADE;
CREATE SCHEMA IF NOT EXISTS seg;

CREATE OR REPLACE FUNCTION seg.audit_changes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    old_data JSONB;
    new_data JSONB;
    table_name TEXT := TG_TABLE_NAME;
    current_user_id BIGINT;
    audit_pk BIGINT;
    record_id TEXT;
BEGIN
    -- Obtener user_id del contexto de la aplicación si está disponible
    BEGIN
        current_user_id := current_setting('app.current_user_id')::BIGINT;
    EXCEPTION WHEN OTHERS THEN
        current_user_id := NULL;
    END;

    -- Preparar datos según operación
    IF TG_OP = 'DELETE' THEN
        old_data := row_to_json(OLD)::jsonb;
        new_data := NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        old_data := row_to_json(OLD)::jsonb;
        new_data := row_to_json(NEW)::jsonb;
    ELSE -- INSERT
        new_data := row_to_json(NEW)::jsonb;
        old_data := NULL;
    END IF;

    -- Determinar record_id (intenta identificar PK si existe id, id_usuario, id_rol, etc.)
    BEGIN
        IF TG_OP = 'DELETE' THEN
            record_id := CASE
                WHEN OLD.tableoid IS NOT NULL THEN NULL
                WHEN (OLD.*) IS NOT NULL THEN COALESCE(OLD.id::TEXT, OLD.id_usuario::TEXT, OLD.id_rol::TEXT, OLD.id_permiso::TEXT, 'unknown')
                ELSE 'unknown'
            END;
        ELSE
            record_id := COALESCE(NEW.id::TEXT, NEW.id_usuario::TEXT, NEW.id_rol::TEXT, NEW.id_permiso::TEXT, 'unknown');
        END IF;
    EXCEPTION WHEN OTHERS THEN
        record_id := 'unknown';
    END;

    -- Generar PK para tabla de auditoría
    BEGIN
        audit_pk := seg.generate_table_id('seg_auditoria','id_auditoria');
    EXCEPTION WHEN OTHERS THEN
        audit_pk := NULL;
    END;

    -- Insertar en seg_auditoria
    BEGIN
        INSERT INTO seg_auditoria (
            id_auditoria, id_usuario, esquema, tabla, accion, id_registro, datos_antes, datos_despues, ip_origen, user_agent, fecha_evento
        ) VALUES (
            audit_pk, current_user_id, TG_TABLE_SCHEMA, table_name, TG_OP, record_id, old_data, new_data, inet_client_addr(), current_setting('application_name', true), CURRENT_TIMESTAMP
        );
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING 'Error en auditoría para %: %', table_name, SQLERRM;
    END;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- Crear triggers AFTER para las tablas que queremos auditar (ejemplos)
-- Evitar auditar la propia tabla de auditoría para no crear recursión.

DROP TRIGGER IF EXISTS trg_audit_seg_usuario ON seg_usuario;
CREATE TRIGGER trg_audit_seg_usuario
AFTER INSERT OR UPDATE OR DELETE ON seg_usuario
FOR EACH ROW EXECUTE FUNCTION seg.audit_changes();

DROP TRIGGER IF EXISTS trg_audit_seg_rol ON seg_rol;
CREATE TRIGGER trg_audit_seg_rol
AFTER INSERT OR UPDATE OR DELETE ON seg_rol
FOR EACH ROW EXECUTE FUNCTION seg.audit_changes();

DROP TRIGGER IF EXISTS trg_audit_seg_permiso ON seg_permiso;
CREATE TRIGGER trg_audit_seg_permiso
AFTER INSERT OR UPDATE OR DELETE ON seg_permiso
FOR EACH ROW EXECUTE FUNCTION seg.audit_changes();

DROP TRIGGER IF EXISTS trg_audit_seg_estado_usuario ON seg_estado_usuario;
CREATE TRIGGER trg_audit_seg_estado_usuario
AFTER INSERT OR UPDATE OR DELETE ON seg_estado_usuario
FOR EACH ROW EXECUTE FUNCTION seg.audit_changes();

DROP TRIGGER IF EXISTS trg_audit_seg_sesion ON seg_sesion;
CREATE TRIGGER trg_audit_seg_sesion
AFTER INSERT OR UPDATE OR DELETE ON seg_sesion
FOR EACH ROW EXECUTE FUNCTION seg.audit_changes();

DROP TRIGGER IF EXISTS trg_audit_seg_token_recuperacion ON seg_token_recuperacion;
CREATE TRIGGER trg_audit_seg_token_recuperacion
AFTER INSERT OR UPDATE OR DELETE ON seg_token_recuperacion
FOR EACH ROW EXECUTE FUNCTION seg.audit_changes();
