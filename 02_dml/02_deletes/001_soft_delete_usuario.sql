-- ============================================================
-- DELETE — Soft delete de usuario
-- Archivo: 02_dml/02_deletes/001_soft_delete_usuario.sql
-- Descripción: Eliminación lógica de un usuario. No elimina
--              físicamente el registro. Revoca sesiones
--              activas y registra la acción en auditoría.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.5
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
--               01_ddl/03_tables/008_create_audit_tables.sql
-- ============================================================

-- ============================================================
-- 1. Soft delete del usuario
-- ============================================================
UPDATE auth.user
SET
  deleted_at = NOW(),
  estado     = 'desactivado',
  updated_at = NOW()
WHERE id_user    = :id_usuario
  AND deleted_at IS NULL;

-- ============================================================
-- 2. Revocar todas las sesiones activas del usuario
-- ============================================================
UPDATE auth.session
SET
  activa     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_user    = :id_usuario
  AND activa     = TRUE
  AND deleted_at IS NULL;

-- ============================================================
-- 3. Invalidar tokens de recuperación pendientes
-- ============================================================
UPDATE auth.recovery_token
SET usado = TRUE
WHERE id_user = :id_usuario
  AND usado   = FALSE;

-- ============================================================
-- 4. Registrar en auditoría
-- ============================================================
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, id_entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(),
  :id_admin,
  'eliminar',
  'usuarios',
  'user',
  :id_usuario,
  'exitoso',
  'Eliminación lógica de usuario. Sesiones revocadas y tokens invalidados.',
  NOW()
);