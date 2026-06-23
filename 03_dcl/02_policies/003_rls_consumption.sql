-- ============================================================
-- POLÍTICAS RLS — Esquema consumption
-- Archivo: 03_dcl/02_policies/003_rls_consumption.sql
-- Descripción: Habilita Row Level Security y define
--              políticas de acceso por fila para las
--              tablas del esquema consumption. Garantiza
--              que cada usuario solo acceda al consumo
--              y recomendaciones de sus propios hogares.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/004_create_consumption_tables.sql
-- ============================================================

-- ============================================================
-- RLS: consumption.consumption
-- ============================================================
ALTER TABLE consumption.consumption ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption.consumption FORCE ROW LEVEL SECURITY;

CREATE POLICY consumption_select_policy ON consumption.consumption
  FOR SELECT TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY consumption_insert_policy ON consumption.consumption
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

-- ============================================================
-- RLS: consumption.consumption_metric
-- ============================================================
ALTER TABLE consumption.consumption_metric ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption.consumption_metric FORCE ROW LEVEL SECURITY;

CREATE POLICY consumption_metric_select_policy ON consumption.consumption_metric
  FOR SELECT TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY consumption_metric_insert_policy ON consumption.consumption_metric
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

-- ============================================================
-- RLS: consumption.recommendation
-- ============================================================
ALTER TABLE consumption.recommendation ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption.recommendation FORCE ROW LEVEL SECURITY;

CREATE POLICY recommendation_select_policy ON consumption.recommendation
  FOR SELECT TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY recommendation_insert_policy ON consumption.recommendation
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY recommendation_update_policy ON consumption.recommendation
  FOR UPDATE TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );