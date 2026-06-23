-- ============================================================
-- TRANSACTION BLOCK — Desactivar hogar
-- Archivo: 04_tcl/00_transaction_blocks/004_tcl_desactivar_hogar.sql
-- Descripción: Garantiza que la desactivación de un hogar
--              sea atómica. Desactiva el hogar, zonas,
--              dispositivos, horarios y umbrales en una
--              sola operación.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF2.4
-- Dependencias: 01_ddl/03_tables/002_create_homes_tables.sql
--               01_ddl/03_tables/003_create_devices_tables.sql
-- ============================================================

BEGIN;

  -- 1. Soft delete del hogar
  UPDATE homes.home
  SET
    estado     = 'desactivado',
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home    = :id_home
    AND deleted_at IS NULL;

  SAVEPOINT sp_hogar_desactivado;

  -- 2. Soft delete de zonas del hogar
  UPDATE homes.area
  SET deleted_at = NOW()
  WHERE id_home    = :id_home
    AND deleted_at IS NULL;

  SAVEPOINT sp_zonas_desactivadas;

  -- 3. Soft delete de dispositivos del hogar
  UPDATE devices.device
  SET
    estado     = 'desactivado',
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home    = :id_home
    AND deleted_at IS NULL;

  SAVEPOINT sp_dispositivos_desactivados;

  -- 4. Desactivar horarios de dispositivos del hogar
  UPDATE devices.schedule
  SET
    activo     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device
    WHERE id_home = :id_home
  )
  AND deleted_at IS NULL;

  SAVEPOINT sp_horarios_desactivados;

  -- 5. Desactivar reglas de umbral del hogar
  UPDATE devices.threshold_rule
  SET
    activa     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device
    WHERE id_home = :id_home
  )
  AND deleted_at IS NULL;

  SAVEPOINT sp_umbrales_desactivados;

  -- 6. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'eliminar', 'hogares',
    'home', :id_home, 'exitoso',
    'Desactivación lógica de hogar y sus datos asociados.',
    NOW()
  );

COMMIT;

-- En caso de error:
-- ROLLBACK;