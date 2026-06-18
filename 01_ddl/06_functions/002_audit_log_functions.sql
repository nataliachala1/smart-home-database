-- ============================================================
-- FUNCIÓN: fn_audit_log
-- Archivo: 01_ddl/05_functions/002_fn_audit_log.sql
-- Descripción: Función genérica que registra automáticamente
--              en audit.audit_log cualquier operación de
--              INSERT, UPDATE o DELETE realizada sobre
--              las tablas críticas del sistema.
--              Captura el estado anterior y nuevo del registro
--              para trazabilidad completa
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 01_schemas, 03_tables/auth,
--               03_tables/audit
-- ============================================================

CREATE OR REPLACE FUNCTION fn_audit_log()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
  v_accion         VARCHAR(50);
  v_datos_ant      JSONB;
  v_datos_nuevos   JSONB;
  v_id_entidad     UUID;
  v_id_user        UUID;
  v_entidad        VARCHAR(50);
BEGIN

  -- --------------------------------------------------------
  -- Determinar la acción realizada
  -- --------------------------------------------------------
  IF TG_OP = 'INSERT' THEN
    v_accion       := 'crear';
    v_datos_ant    := NULL;
    v_datos_nuevos := to_jsonb(NEW);
    v_id_entidad   := (to_jsonb(NEW)->>'id_' || TG_TABLE_NAME)::UUID;

  ELSIF TG_OP = 'UPDATE' THEN
    -- Distinguir entre soft delete y edición normal
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
      v_accion := 'eliminar';
    ELSE
      v_accion := 'editar';
    END IF;
    v_datos_ant    := to_jsonb(OLD);
    v_datos_nuevos := to_jsonb(NEW);
    v_id_entidad   := (to_jsonb(NEW)->>'id_' || TG_TABLE_NAME)::UUID;

  ELSIF TG_OP = 'DELETE' THEN
    v_accion       := 'eliminar';
    v_datos_ant    := to_jsonb(OLD);
    v_datos_nuevos := NULL;
    v_id_entidad   := (to_jsonb(OLD)->>'id_' || TG_TABLE_NAME)::UUID;

  END IF;

  -- --------------------------------------------------------
  -- Intentar obtener el id_user del registro afectado
  -- Si la tabla no tiene id_user se maneja el error
  -- --------------------------------------------------------
  BEGIN
    IF TG_OP = 'DELETE' THEN
      v_id_user := (to_jsonb(OLD)->>'id_user')::UUID;
    ELSE
      v_id_user := (to_jsonb(NEW)->>'id_user')::UUID;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_id_user := NULL;
  END;

  -- --------------------------------------------------------
  -- Nombre de la entidad: esquema.tabla
  -- --------------------------------------------------------
  v_entidad := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;

  -- --------------------------------------------------------
  -- Ofuscar campos sensibles antes de guardar en el log
  -- --------------------------------------------------------
  IF v_datos_ant IS NOT NULL THEN
    v_datos_ant := v_datos_ant
      - 'password_hash'
      - 'token'
      - 'refresh_token'
      - 'access_token'
      - 'codigo_secreto'
      - 'ultimo_codigo_hash';
  END IF;

  IF v_datos_nuevos IS NOT NULL THEN
    v_datos_nuevos := v_datos_nuevos
      - 'password_hash'
      - 'token'
      - 'refresh_token'
      - 'access_token'
      - 'codigo_secreto'
      - 'ultimo_codigo_hash';
  END IF;

  -- --------------------------------------------------------
  -- Insertar registro en audit.audit_log
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log,
    id_user,
    accion,
    modulo,
    entidad,
    id_entidad,
    datos_anteriores,
    datos_nuevos,
    resultado,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    v_id_user,
    v_accion,
    TG_TABLE_SCHEMA,
    v_entidad,
    v_id_entidad,
    v_datos_ant,
    v_datos_nuevos,
    'exitoso',
    NOW()
  );

  -- --------------------------------------------------------
  -- Retornar según la operación
  -- --------------------------------------------------------
  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;

END;
$$;

COMMENT ON FUNCTION fn_audit_log()
  IS 'Registra automáticamente en audit.audit_log cualquier INSERT, UPDATE o DELETE sobre tablas críticas. Ofusca campos sensibles antes de guardar.';