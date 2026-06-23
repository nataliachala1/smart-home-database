-- ============================================================
-- POLÍTICAS RLS — Esquema config
-- Archivo: 03_dcl/02_policies/005_rls_config.sql
-- Descripción: Habilita Row Level Security y define
--              políticas de acceso por fila para las
--              tablas del esquema config. Garantiza que
--              cada usuario solo acceda y modifique su
--              propia configuración.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/007_create_config_tables.sql
-- ============================================================

-- ============================================================
-- RLS: config.configuration_user
-- ============================================================
ALTER TABLE config.configuration_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE config.configuration_user FORCE ROW LEVEL SECURITY;

CREATE POLICY configuration_user_select_policy ON config.configuration_user
  FOR SELECT TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY configuration_user_insert_policy ON config.configuration_user
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY configuration_user_update_policy ON config.configuration_user
  FOR UPDATE TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );