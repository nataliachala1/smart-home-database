-- ============================================================
-- POLÍTICAS RLS — Esquema notifications
-- Archivo: 03_dcl/02_policies/004_rls_notifications.sql
-- Descripción: Habilita Row Level Security y define
--              políticas de acceso por fila para las
--              tablas del esquema notifications. Garantiza
--              que cada usuario solo acceda a sus propias
--              notificaciones.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/005_create_notifications_tables.sql
-- ============================================================

-- ============================================================
-- RLS: notifications.notification
-- ============================================================
ALTER TABLE notifications.notification ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.notification FORCE ROW LEVEL SECURITY;

CREATE POLICY notification_select_policy ON notifications.notification
  FOR SELECT TO smarthome_app
  USING (
    id_user    = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

CREATE POLICY notification_insert_policy ON notifications.notification
  FOR INSERT TO smarthome_app
  WITH CHECK (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY notification_update_policy ON notifications.notification
  FOR UPDATE TO smarthome_app
  USING (
    id_user    = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

CREATE POLICY notification_delete_policy ON notifications.notification
  FOR DELETE TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );