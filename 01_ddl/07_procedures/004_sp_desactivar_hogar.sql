-- ============================================================
-- PROCEDIMIENTO: sp_desactivar_hogar
-- Archivo: 01_ddl/07_procedures/004_sp_desactivar_hogar.sql
-- Descripción: Orquesta la desactivación completa de un
--              hogar: desactiva el hogar, sus zonas y los
--              dispositivos vinculados, además de cancelar
--              horarios y reglas de umbral asociadas.
--              La auditoría de homes.home se genera vía
--              trigger (fn_audit_log); las demás tablas
--              afectadas no tienen trigger de auditoría
--              individual, por lo que se registra un
--              resumen manual en audit.audit_log
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF2.4
-- Dependencias: 03_tables/homes, 03_tables/devices,
--               03_tables/audit, 06_triggers/002_trg_audit_log
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_desactivar_hogar(
  IN p_id_home UUID,
  IN p_id_user UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_nombre_hogar      VARCHAR(100);
  v_total_dispositivos INTEGER;
BEGIN

  -- --------------------------------------------------------
  -- 1. Validar que el hogar exista y esté activo
  -- --------------------------------------------------------
  SELECT nombre INTO v_nombre_hogar
  FROM homes.home
  WHERE id_home    = p_id_home
    AND estado     = 'activo'
    AND deleted_at IS NULL;

  IF v_nombre_hogar IS NULL THEN
    RAISE EXCEPTION 'El hogar no existe o ya está desactivado.';
  END IF;

  -- --------------------------------------------------------
  -- 2. Desactivar el hogar
  --    Dispara: fn_audit_log (registra desactivación)
  -- --------------------------------------------------------
  UPDATE homes.home
  SET
    estado     = 'desactivado',
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home = p_id_home;

  -- --------------------------------------------------------
  -- 3. Desactivar zonas del hogar
  --    Dispara: fn_audit_log por cada zona (registra edición)
  -- --------------------------------------------------------
  UPDATE homes.area
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE id_home    = p_id_home
    AND deleted_at IS NULL;

  -- --------------------------------------------------------
  -- 4. Contar y desactivar dispositivos del hogar
  --    Dispara: fn_audit_log por cada dispositivo
  -- --------------------------------------------------------
  SELECT COUNT(*) INTO v_total_dispositivos
  FROM devices.device
  WHERE id_home    = p_id_home
    AND deleted_at IS NULL;

  UPDATE devices.device
  SET
    estado     = 'desactivado',
    encendido  = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home    = p_id_home
    AND deleted_at IS NULL;

  -- --------------------------------------------------------
  -- 5. Desactivar horarios de los dispositivos del hogar
  --    Dispara: fn_audit_log por cada horario
  -- --------------------------------------------------------
  UPDATE devices.schedule
  SET
    activo     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device WHERE id_home = p_id_home
  )
  AND deleted_at IS NULL;

  -- --------------------------------------------------------
  -- 6. Desactivar reglas de umbral de los dispositivos
  --    Dispara: fn_audit_log por cada regla
  -- --------------------------------------------------------
  UPDATE devices.threshold_rule
  SET
    activa     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device WHERE id_home = p_id_home
  )
  AND deleted_at IS NULL;

  -- --------------------------------------------------------
  -- 7. Registrar resumen manual en auditoría
  --    (no cubierto por trigger porque es un evento agregado,
  --    no una operación individual sobre una sola tabla)
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_user, 'eliminar', 'hogares',
    'home', p_id_home, 'exitoso',
    CONCAT(
      'Desactivación completa del hogar "', v_nombre_hogar,
      '". Dispositivos afectados: ', v_total_dispositivos
    ),
    NOW()
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al desactivar el hogar: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_desactivar_hogar(UUID, UUID)
  IS 'Desactiva un hogar, sus zonas, dispositivos, horarios y reglas de umbral asociadas. Registra un resumen manual en auditoría además de los triggers automáticos por tabla.';

-- ============================================================
-- EJEMPLO DE USO
-- ============================================================
-- CALL sp_desactivar_hogar(
--   'a1b2c3d4-0000-0000-0000-000000000001'::UUID,  -- id_home
--   'a1b2c3d4-9999-0000-0000-000000000001'::UUID   -- id_user
-- );