-- ============================================================
-- PROCEDIMIENTO: sp_registrar_dispositivo
-- Archivo: 01_ddl/07_procedures/003_sp_registrar_dispositivo.sql
-- Descripción: Orquesta el registro de un nuevo dispositivo:
--              valida hogar y zona, inserta el dispositivo,
--              crea su registro extendido (smart o manual)
--              y registra el estado inicial en el historial.
--              La auditoría se genera automáticamente vía
--              trigger (fn_audit_log)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF3.1
-- Dependencias: 03_tables/homes, 03_tables/devices,
--               06_triggers/002_trg_audit_log
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_registrar_dispositivo(
  IN  p_id_home          UUID,
  IN  p_id_area           UUID,
  IN  p_id_type_device    UUID,
  IN  p_nombre            VARCHAR(100),
  IN  p_es_inteligente    BOOLEAN,
  IN  p_modelo            VARCHAR(100),
  IN  p_fabricante        VARCHAR(100),
  IN  p_id_user           UUID,
  OUT p_id_device         UUID
)
LANGUAGE plpgsql
AS $$
BEGIN

  -- --------------------------------------------------------
  -- 1. Validar que el hogar exista y esté activo
  -- --------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM homes.home
    WHERE id_home    = p_id_home
      AND estado     = 'activo'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'El hogar no existe o no está activo.';
  END IF;

  -- --------------------------------------------------------
  -- 2. Validar que la zona pertenezca al hogar (si se indicó)
  -- --------------------------------------------------------
  IF p_id_area IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM homes.area
    WHERE id_area    = p_id_area
      AND id_home    = p_id_home
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'La zona indicada no pertenece a este hogar.';
  END IF;

  -- --------------------------------------------------------
  -- 3. Insertar dispositivo
  --    Dispara: fn_audit_log (registra creación)
  -- --------------------------------------------------------
  p_id_device := uuid_generate_v4();

  INSERT INTO devices.device (
    id_device, id_home, id_area, id_type_device,
    nombre, estado, encendido, created_at, updated_at
  )
  VALUES (
    p_id_device, p_id_home, p_id_area, p_id_type_device,
    p_nombre, 'desconectado', FALSE, NOW(), NOW()
  );

  -- --------------------------------------------------------
  -- 4. Crear registro extendido según el tipo de dispositivo
  -- --------------------------------------------------------
  IF p_es_inteligente THEN
    INSERT INTO devices.smart_device (
      id_smart_device, id_device, modelo, fabricante, created_at, updated_at
    )
    VALUES (
      uuid_generate_v4(), p_id_device, p_modelo, p_fabricante, NOW(), NOW()
    );
  ELSE
    INSERT INTO devices.manual_device (
      id_manual_device, id_device, created_at, updated_at
    )
    VALUES (
      uuid_generate_v4(), p_id_device, NOW(), NOW()
    );
  END IF;

  -- --------------------------------------------------------
  -- 5. Registrar estado inicial en el historial
  -- --------------------------------------------------------
  INSERT INTO devices.device_status_history (
    id_device_status_history, id_device, estado_anterior,
    estado_nuevo, encendido, origen, id_user, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_device, NULL,
    'desconectado', FALSE, 'sistema', p_id_user, NOW()
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Ya existe un dispositivo con ese nombre en este hogar.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al registrar el dispositivo: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_dispositivo(UUID, UUID, UUID, VARCHAR, BOOLEAN, VARCHAR, VARCHAR, UUID, UUID)
  IS 'Registra un nuevo dispositivo validando hogar y zona, crea su registro extendido (smart o manual) y el historial de estado inicial. La auditoría se genera automáticamente vía trigger.';

-- ============================================================
-- EJEMPLO DE USO
-- ============================================================
-- CALL sp_registrar_dispositivo(
--   'a1b2c3d4-0000-0000-0000-000000000001'::UUID,  -- id_home
--   'a1b2c3d4-0000-0000-0000-000000000002'::UUID,  -- id_area
--   'a1b2c3d4-0000-0000-0000-000000000003'::UUID,  -- id_type_device
--   'Lámpara Sala', TRUE, 'Smart Bulb X1', 'Xiaomi',
--   'a1b2c3d4-9999-0000-0000-000000000001'::UUID,  -- id_user
--   NULL  -- parámetro OUT, se completa al ejecutar
-- );