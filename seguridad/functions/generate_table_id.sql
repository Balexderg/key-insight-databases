-- Funciones para generación de IDs por tabla (secuencias por tabla bajo esquema `seg`).
-- generate_table_id(p_table_name text) -> bigint
-- Crea una secuencia `seg.<table>_id_seq` si no existe y devuelve nextval.
-- Si la tabla ya tiene datos, posiciona la secuencia por encima del MAX(pk).

CREATE SCHEMA IF NOT EXISTS seg;

CREATE OR REPLACE FUNCTION seg.generate_table_id(p_table_name TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    seq_name TEXT := p_table_name || '_id_seq';
    full_seq TEXT := 'seg.' || seq_name;
    exists_seq BOOLEAN;
    tbl_reg regclass;
    pk_col TEXT;
    maxval BIGINT;
BEGIN
    -- Verificar existencia de la secuencia en el esquema `seg`
    SELECT EXISTS(
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'S' AND n.nspname = 'seg' AND c.relname = seq_name
    ) INTO exists_seq;

    IF NOT exists_seq THEN
        EXECUTE format('CREATE SEQUENCE %I.%I START 1;', 'seg', seq_name);
    END IF;

    -- Si la tabla existe y tiene PK, posicionar la secuencia por encima del máximo PK existente
    BEGIN
        tbl_reg := format('seg.%I', p_table_name)::regclass;

        SELECT a.attname INTO pk_col
        FROM pg_index idx
        JOIN pg_attribute a ON a.attrelid = idx.indrelid AND a.attnum = ANY(idx.indkey)
        WHERE idx.indrelid = tbl_reg AND idx.indisprimary
        LIMIT 1;

        IF pk_col IS NOT NULL THEN
            EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM %s', pk_col, tbl_reg) INTO maxval;
            IF maxval IS NULL THEN
                maxval := 0;
            END IF;
            -- posicionar la secuencia para no colisionar con datos existentes
            EXECUTE format('SELECT setval(%L, %s, false)', full_seq, (maxval + 1));
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Silenciar errores no críticos: si no se puede determinar MAX, dejamos la secuencia como está
        NULL;
    END;

    -- Devolver el siguiente valor
    RETURN nextval(full_seq::regclass);
END;
$$;

-- Función auxiliar para generar un ID de auditoría (UUID como texto)
CREATE OR REPLACE FUNCTION seg.generate_audit_id()
RETURNS TEXT LANGUAGE sql AS $$
    SELECT gen_random_uuid()::text;
$$;

-- Versión que acepta columna PK explícita para posicionar la secuencia (más control)
CREATE OR REPLACE FUNCTION seg.generate_table_id(p_table_name TEXT, p_pk_col TEXT)
RETURNS BIGINT LANGUAGE plpgsql AS $$
DECLARE
    seq_name TEXT := p_table_name || '_id_seq';
    full_seq TEXT := 'seg.' || seq_name;
    exists_seq BOOLEAN;
    tbl_reg regclass;
    maxval BIGINT;
BEGIN
    -- Verificar existencia de la secuencia en el esquema `seg`
    SELECT EXISTS(
        SELECT 1
        FROM pg_class c
        JOIN pg_namespace n ON c.relnamespace = n.oid
        WHERE c.relkind = 'S' AND n.nspname = 'seg' AND c.relname = seq_name
    ) INTO exists_seq;

    IF NOT exists_seq THEN
        EXECUTE format('CREATE SEQUENCE %I.%I START 1;', 'seg', seq_name);
    END IF;

    -- Si la tabla existe y se pasa columna PK, posicionar la secuencia por encima del máximo PK existente
    BEGIN
        tbl_reg := format('seg.%I', p_table_name)::regclass;
        IF p_pk_col IS NOT NULL THEN
            EXECUTE format('SELECT COALESCE(MAX(%I),0) FROM %s', p_pk_col, tbl_reg) INTO maxval;
            IF maxval IS NULL THEN
                maxval := 0;
            END IF;
            EXECUTE format('SELECT setval(%L, %s, false)', full_seq, (maxval + 1));
        END IF;
    EXCEPTION WHEN OTHERS THEN
        NULL;
    END;

    RETURN nextval(full_seq::regclass);
END;
$$;
