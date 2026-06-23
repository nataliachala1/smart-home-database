-- ============================================================
-- POLÍTICAS RLS — Esquema homes
-- Archivo: 03_dcl/02_policies/001_rls_homes.sql
-- Descripción: Habilita Row Level Security y define
--              políticas de acceso por fila para las
--              tablas del esquema homes. Garantiza que
--              cada usuario solo acceda a sus propios
--              hogares y zonas (RNF5.6, Ley 1581/2012).
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/002_create_homes_tables.sql
-- ============================================================

-- ============================================================
-- RLS: homes.home
-- ============================================================
ALTER TABLE homes.home ENABLE ROW LEVEL SECURITY;
ALTER TABLE homes.home FORCE ROW LEVEL SECURITY;

CREATE POLICY home_select_policy ON homes.home
  FOR SELECT TO smarthome_app
  USING (
    id_user    = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

CREATE POLICY home_insert_policy ON homes.home
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY home_update_policy ON homes.home
  FOR UPDATE TO smarthome_app
  USING (
    id_user    = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

CREATE POLICY home_delete_policy ON homes.home
  FOR DELETE TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );

-- ============================================================
-- RLS: homes.area
-- ============================================================
ALTER TABLE homes.area ENABLE ROW LEVEL SECURITY;
ALTER TABLE homes.area FORCE ROW LEVEL SECURITY;

CREATE POLICY area_select_policy ON homes.area
  FOR SELECT TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY area_insert_policy ON homes.area
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY area_update_policy ON homes.area
  FOR UPDATE TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY area_delete_policy ON homes.area
  FOR DELETE TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );