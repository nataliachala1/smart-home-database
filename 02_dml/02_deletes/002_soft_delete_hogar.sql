-- ============================================================
-- DELETE — Soft delete de hogar
-- Archivo: 02_dml/02_deletes/002_soft_delete_hogar.sql
-- Descripción: Eliminación lógica de un hogar. Desactiva
--              también sus zonas y dispositivos asociados
--              pero conserva todos los datos para
--              futura reactivación.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF2.4
-- Dependencias: 01_ddl/03_tables/002_create_homes_tables.sql
--               01_ddl/03_tables/003_create_devices_tables.sql
--               01_ddl/03_tables/008_create_audit_tables.sql
-- ============================================================

-- ============================================================
-- 1. Soft delete del hogar
-- ============================================================
UPDATE homes.home
SET
  estado     = 'desactivado',
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_home    = :id_hogar
  AND deleted_at IS NULL;

-- ============================================================
-- 2. Soft delete de zonas del hogar
-- ============================================================
UPDATE homes.area
SET deleted_at = NOW()
WHERE id_home    = :id_hogar
  AND deleted_at IS NULL;

-- ============================================================
-- 3. Soft delete de dispositivos del hogar
-- ============================================================
UPDATE devices.device
SET
  estado     = 'desactivado',
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_home    = :id_hogar
  AND deleted_at IS NULL;

-- ============================================================
-- 4. Desactivar horarios de dispositivos del hogar
-- ============================================================
UPDATE devices.schedule
SET
  activo     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device IN (
  SELECT id_device FROM devices.device
  WHERE id_home = :id_hogar
)
AND deleted_at IS NULL;

-- ============================================================
-- 5. Desactivar reglas de umbral del hogar
-- ============================================================
UPDATE devices.threshold_rule
SET
  activa     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device IN (
  SELECT id_device FROM devices.device
  WHERE id_home = :id_hogar
)
AND deleted_at IS NULL;

-- ============================================================
-- 6. Registrar en auditoría
-- ============================================================
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, id_entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(),
  :id_usuario,
  'eliminar',
  'hogares',
  'home',
  :id_hogar,
  'exitoso',
  'Desactivación lógica de hogar, zonas, dispositivos, horarios y umbrales asociados.',
  NOW()
);