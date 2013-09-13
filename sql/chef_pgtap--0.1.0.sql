CREATE OR REPLACE FUNCTION @extschema@._table_permissions(
  p_table_schema NAME,
  p_role_name NAME,
  p_permissions TEXT[],
  p_table_type TEXT)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
   RETURN QUERY
   SELECT table_privs_are(p_table_schema,
                          table_name,
                          p_role_name,
                          p_permissions,
                          'Role ' || p_role_name || ' should be granted ' ||
                          array_to_string(p_permissions, ', ') || ' on ' ||
                          CASE p_table_type
                            WHEN 'BASE TABLE' THEN 'table '
                            WHEN 'VIEW' THEN 'view '
                          END ||
                          p_table_schema || '.' || table_name)
   FROM information_schema.tables
   WHERE table_schema = p_table_schema
     AND table_type   = p_table_type;
END
$$;

CREATE OR REPLACE FUNCTION @extschema@.all_table_permissions(
  p_table_schema NAME,
  p_role_name NAME,
  p_permissions TEXT[])
RETURNS SETOF TEXT
LANGUAGE SQL
AS $$
   SELECT @extschema@._table_permissions($1, $2, $3, 'BASE TABLE')
$$;

CREATE OR REPLACE FUNCTION @extschema@.all_view_permissions(
  p_table_schema NAME,
  p_role_name NAME,
  p_permissions TEXT[])
RETURNS SETOF TEXT
LANGUAGE SQL
AS $$
   SELECT @extschema@._table_permissions($1, $2, $3, 'VIEW')
$$;

-- These wrap the built-in `has_index` functions from pgTAP.  Since we
-- don't currently use schemas in our databases, neither do these
-- functions.  Their main use is to generate nicer test descriptions
--
-- You can either pass an ARRAY of column names (for multi-column
-- indexes), or a single column name (if it's a single-column index)
CREATE OR REPLACE FUNCTION @extschema@.has_index(
       p_table_name NAME,
       p_index_name NAME,
       p_indexed_columns TEXT[])
RETURNS TEXT LANGUAGE SQL
AS $$
   SELECT has_index(p_table_name, p_index_name, p_indexed_columns,
     'Columns ' || p_table_name ||
     '(' || array_to_string(p_indexed_columns, ', ') ||
     ') should be indexed by index "' || p_index_name || '"' );
$$;

CREATE OR REPLACE FUNCTION @extschema@.has_index(
       p_table_name NAME,
       p_index_name NAME,
       p_indexed_column TEXT)
RETURNS TEXT LANGUAGE SQL
AS $$
   SELECT @extschema@.has_index(p_table_name, p_index_name, ARRAY[p_indexed_column]);
$$;


-- See
-- http://www.postgresql.org/docs/current/interactive/storage-toast.html
-- for a description of the storage types
CREATE TYPE @extschema@.attr_storage AS ENUM(
  'PLAIN',
  'MAIN',
  'EXTENDED',
  'EXTERNAL'
);

CREATE FUNCTION @extschema@.col_is_storage_type(p_table_name NAME,
                                                p_column_name NAME,
                                                p_storage_type @extschema@.attr_storage)
RETURNS TEXT
LANGUAGE SQL
AS $$
-- See http://www.postgresql.org/docs/9.3/static/catalog-pg-type.html
-- for the single-letter codes used for each storage type
SELECT is(CASE WHEN attstorage = 'p'
               THEN 'PLAIN'
               WHEN attstorage = 'm'
               THEN 'MAIN'
               WHEN attstorage = 'x'
               THEN 'EXTENDED'
               WHEN attstorage = 'e'
               THEN 'EXTERNAL'
          END::@extschema@.attr_storage,
          p_storage_type,
          'Column ' || p_table_name || '.' || p_column_name ||
          ' should have storage type ' || p_storage_type)
FROM pg_attribute
JOIN pg_class
ON pg_class.oid = pg_attribute.attrelid
WHERE relname = p_table_name
  AND attname = p_column_name
$$;

-- See
-- http://www.postgresql.org/docs/current/static/sql-createtable.html
-- for allowable values
CREATE TYPE @extschema@.fk_action AS ENUM(
  'NO ACTION',
  'RESTRICT',
  'CASCADE',
  'SET NULL',
  'SET DEFAULT'
);

CREATE FUNCTION @extschema@.fk_update_action_is(p_fk_name NAME, p_action @extschema@.fk_action)
RETURNS TEXT
LANGUAGE sql
AS $$
  SELECT is(on_update, p_action::TEXT,
            'ON UPDATE action for foreign key ' || p_fk_name || ' should be ' || p_action )
  FROM pg_all_foreign_keys -- special view from pgTAP
  WHERE fk_constraint_name = p_fk_name
$$;

CREATE FUNCTION @extschema@.fk_delete_action_is(p_fk_name NAME, p_action @extschema@.fk_action)
RETURNS TEXT
LANGUAGE sql
AS $$
  SELECT is(on_delete, p_action::TEXT,
            'ON DELETE action for foreign key ' || p_fk_name || ' should be ' || p_action )
  FROM pg_all_foreign_keys -- special view from pgTAP
  WHERE fk_constraint_name = p_fk_name
$$;

-- TODO: I'd like a test function that incorporates the columns
-- involved in a foreign key as well as the name of the foreign key,
-- in order to more clearly associate the definition of the key with
-- the ON DELETE / ON UPDATE actions

CREATE OR REPLACE FUNCTION @extschema@.col_is_uuid(p_table_name NAME,
                                                   p_column_name NAME,
                                                   p_is_unique BOOLEAN)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
   RETURN NEXT has_column(p_table_name, p_column_name);
   RETURN NEXT col_not_null(p_table_name, p_column_name);
   RETURN NEXT col_type_is(p_table_name, p_column_name, 'character(32)');
   RETURN NEXT col_hasnt_default(p_table_name, p_column_name);
   IF p_is_unique THEN
     RETURN NEXT col_is_unique(p_table_name, p_column_name);
     -- TODO: it'd be nice to have a col_isnt_unique function...
   END IF;
END;
$$;

COMMENT ON FUNCTION @extschema@.col_is_uuid(NAME, NAME, BOOLEAN) IS
$$Asserts that the given column is declared as a NOT NULL CHAR(32)
without a default.

If `p_is_unique` is TRUE, a uniqueness check is also performed (this
is not needed on all our UUID columns).$$;

CREATE OR REPLACE FUNCTION @extschema@.col_is_uuid(p_table_name NAME, p_column_name NAME)
RETURNS SETOF TEXT
LANGUAGE SQL
AS $$
   SELECT @extschema@.col_is_uuid(p_table_name, p_column_name, FALSE)
$$;

COMMENT ON FUNCTION @extschema@.col_is_uuid(NAME, NAME) IS
$$Same as `col_is_uuid(NAME, NAME, FALSE); that is, no uniqueness
check is performed.$$;

CREATE OR REPLACE FUNCTION @extschema@.col_is_timestamp(p_table_name NAME, p_column_name NAME)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NEXT has_column(p_table_name, p_column_name);
  RETURN NEXT col_not_null(p_table_name, p_column_name);
  RETURN NEXT col_type_is(p_table_name, p_column_name, 'timestamp without time zone');
  RETURN NEXT col_hasnt_default(p_table_name, p_column_name);
END;
$$;

COMMENT ON FUNCTION @extschema@.col_is_timestamp(NAME, NAME) IS
$$Asserts that the given column is declared as a TIMESTAMP WITHOUT
TIME ZONE NOT NULL without a default.$$;

CREATE OR REPLACE FUNCTION @extschema@.col_is_blob(p_table_name NAME,
                                                   p_column_name NAME,
                                                   p_nullable BOOLEAN DEFAULT FALSE)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NEXT has_column(p_table_name, p_column_name);
  IF p_nullable THEN
    RETURN NEXT col_is_null(p_table_name, p_column_name);
  ELSE
    RETURN NEXT col_not_null(p_table_name, p_column_name);
  END IF;
  RETURN NEXT col_type_is(p_table_name, p_column_name, 'bytea');
  RETURN NEXT col_hasnt_default(p_table_name, p_column_name);
  RETURN NEXT @extschema@.col_is_storage_type(p_table_name, p_column_name,'EXTERNAL');
END;
$$;

COMMENT ON FUNCTION @extschema@.col_is_blob(p_table_name NAME, p_column_name NAME, p_nullable BOOLEAN) IS
$$Asserts that the given column is declared as a NULLable BYTEA, with
no default value, and with EXTERNAL storage.

Really, all our blobs should never be NULL; the p_nullable parameter
is a bandaid until we can properly fix this across the whole
schema.$$;

CREATE OR REPLACE FUNCTION @extschema@.col_is_name(p_table_name NAME, p_column_name NAME)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NEXT has_column(p_table_name, p_column_name);
  RETURN NEXT col_not_null(p_table_name, p_column_name);
  RETURN NEXT col_type_is(p_table_name, p_column_name, 'text');
  RETURN NEXT col_hasnt_default(p_table_name, p_column_name);
END;
$$;

COMMENT ON FUNCTION @extschema@.col_is_name(p_table_name NAME, p_column_name NAME) IS
$$Asserts that the given column is declared as a NOT NULL TEXT, with
no default value$$;

CREATE OR REPLACE FUNCTION @extschema@.col_is_flag(p_table_name NAME, p_column_name NAME, p_default BOOLEAN)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NEXT has_column(p_table_name, p_column_name);
  RETURN NEXT col_not_null(p_table_name, p_column_name);
  RETURN NEXT col_type_is(p_table_name, p_column_name, 'boolean');
  RETURN NEXT col_has_default(p_table_name, p_column_name);
  RETURN NEXT col_default_is(p_table_name, p_column_name,
                              CASE WHEN p_default IS TRUE
                                   THEN 'true'
                                   ELSE 'false'
                              END);
END;
$$;

COMMENT ON FUNCTION @extschema@.col_is_flag(p_table_name NAME, p_column_name NAME, p_default BOOLEAN) IS
$$Asserts that the given column is declared as a NOT NULL BOOLEAN with
the given default value$$;

CREATE OR REPLACE FUNCTION @extschema@.col_is_version_component(p_table_name NAME, p_column_name NAME)
RETURNS SETOF TEXT
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN NEXT has_column(p_table_name, p_column_name);
  RETURN NEXT col_not_null(p_table_name, p_column_name);
  RETURN NEXT col_type_is(p_table_name, p_column_name, 'bigint');
  RETURN NEXT col_hasnt_default(p_table_name, p_column_name);
END;
$$;

COMMENT ON FUNCTION @extschema@.col_is_version_component(p_table_name NAME, p_column_name NAME) IS
$$Asserts that the given column is declared as a NOT NULL BIGINT with no default.$$;

-- TODO: function for testing a column is a serial PK?
