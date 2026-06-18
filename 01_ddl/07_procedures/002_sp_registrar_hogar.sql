-- ============================================================
-- PROCEDIMIENTO: sp_registrar_hogar
-- Archivo: 01_ddl/07_procedures/002_sp_registrar_hogar.sql
-- Descripción: Orquesta el registro de un nuevo hogar y
--              registra automáticamente al usuario creador
--              como propietario en homes.home_member.
--              La auditoría se genera automáticamente vía
--              trigger (fn_audit_log)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF2.1
-- Dependencias: 03_tables/homes, 06_triggers/002_trg_audit_log
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_registrar_hogar(
  IN  p_id_user  UUID,
  IN  p_nombre   VARCHAR(100),
  IN  p_estrato  SMALLINT,
  OUT p_id_home  UUID
)
LANGUAGE plpgsql
AS $$
BEGIN

  -- --------------------------------------------------------
  -- 1. Validar que el usuario exista y esté activo
  -- --------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM auth.user
    WHERE id_user    = p_id_user
      AND estado     = 'activo'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'El usuario no existe o no está activo.';
  END IF;

  -- --------------------------------------------------------
  -- 2. Insertar hogar
  --    Dispara: fn_audit_log (registra creación)
  -- --------------------------------------------------------
  p_id_home := uuid_generate_v4();

  INSERT INTO homes.home (
    id_home, id_user, nombre, estrato, estado, created_at, updated_at
  )
  VALUES (
    p_id_home, p_id_user, p_nombre, p_estrato, 'activo', NOW(), NOW()
  );

  -- --------------------------------------------------------
  -- 3. Registrar al usuario como propietario del hogar
  -- --------------------------------------------------------
  INSERT INTO homes.home_member (
    id_home_member, id_home, id_user, rol_en_hogar, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_home, p_id_user, 'propietario', NOW()
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Ya tienes un hogar registrado con ese nombre.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al registrar el hogar: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_hogar(UUID, VARCHAR, SMALLINT, UUID)
  IS 'Registra un nuevo hogar y vincula al usuario creador como propietario. La auditoría se genera automáticamente vía trigger.';

-- ============================================================
-- EJEMPLO DE USO
-- ============================================================
-- CALL sp_registrar_hogar(
--   'a1b2c3d4-9999-0000-0000-000000000001'::UUID,
--   'Casa Principal', 3,
--   NULL  -- parámetro OUT, se completa al ejecutar
-- );