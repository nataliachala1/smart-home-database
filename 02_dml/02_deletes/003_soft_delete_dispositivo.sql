-- ============================================================
-- DELETE — Soft delete de dispositivo
-- Archivo: 02_dml/02_deletes/003_soft_delete_dispositivo.sql
-- Descripción: Eliminación lógica de un dispositivo.
--              Desactiva también sus horarios y reglas de
--              umbral asociadas. Conserva el historial de
--              consumo y estados para consulta futura.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF3.4
-- Dependencias: 01_ddl/03_tables/003_create_devices_tables.sql
--               01_ddl/03_tables/008_create_audit_tables.sql
-- ============================================================

-- ============================================================
-- 1. Soft delete del dispositivo
-- ============================================================
UPDATE devices.device
SET
  estado     = 'desactivado',
  encendido  = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device  = :id_dispositivo
  AND deleted_at IS NULL;

-- ============================================================
-- 2. Desactivar horarios del dispositivo
-- ============================================================
UPDATE devices.schedule
SET
  activo     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device  = :id_dispositivo
  AND deleted_at IS NULL;

-- ============================================================
-- 3. Desactivar reglas de umbral del dispositivo
-- ============================================================
UPDATE devices.threshold_rule
SET
  activa     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device  = :id_dispositivo
  AND deleted_at IS NULL;

-- ============================================================
-- 4. Registrar cambio de estado en historial
-- ============================================================
INSERT INTO devices.device_status_history (
  id_device_status_history,
  id_device,
  estado_anterior,
  estado_nuevo,
  encendido,
  origen,
  id_user,
  created_at
)
VALUES (
  uuid_generate_v4(),
  :id_dispositivo,
  :estado_anterior,
  'desactivado',
  FALSE,
  'usuario',
  :id_usuario,
  NOW()
);

-- ============================================================
-- 5. Registrar en auditoría
-- ============================================================
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, id_entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(),
  :id_usuario,
  'eliminar',
  'dispositivos',
  'device',
  :id_dispositivo,
  'exitoso',
  'Desactivación lógica de dispositivo, horarios y umbrales asociados.',
  NOW()
);