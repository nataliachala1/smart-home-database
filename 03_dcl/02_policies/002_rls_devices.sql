-- ============================================================
-- POLÍTICAS RLS — Esquema devices
-- Archivo: 03_dcl/02_policies/002_rls_devices.sql
-- Descripción: Habilita Row Level Security y define
--              políticas de acceso por fila para las
--              tablas del esquema devices. Garantiza que
--              cada usuario solo acceda a los dispositivos
--              de sus propios hogares.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/003_create_devices_tables.sql
-- ============================================================

-- ============================================================
-- RLS: devices.device
-- ============================================================
ALTER TABLE devices.device ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices.device FORCE ROW LEVEL SECURITY;

CREATE POLICY device_select_policy ON devices.device
  FOR SELECT TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY device_insert_policy ON devices.device
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY device_update_policy ON devices.device
  FOR UPDATE TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY device_delete_policy ON devices.device
  FOR DELETE TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );