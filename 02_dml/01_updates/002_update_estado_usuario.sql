-- ============================================================
-- UPDATE — Estado de usuario
-- Archivo: 02_dml/01_updates/002_update_estado_usuario.sql
-- Descripción: Scripts de referencia para actualizar el
--              estado de un usuario: activar, desactivar
--              y bloquear. Se usa en los flujos de
--              RF1.5 y RF1.6.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.5, RF1.6
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

-- ============================================================
-- Activar cuenta de usuario
-- ============================================================
UPDATE auth.user
SET
  estado            = 'activo',
  intentos_fallidos = 0,
  bloqueado_hasta   = NULL,
  updated_at        = NOW()
WHERE email      = :email_usuario
  AND deleted_at IS NULL;

-- ============================================================
-- Desactivar cuenta de usuario
-- ============================================================
UPDATE auth.user
SET
  estado     = 'desactivado',
  updated_at = NOW()
WHERE email      = :email_usuario
  AND deleted_at IS NULL;

-- ============================================================
-- Bloquear cuenta tras múltiples intentos fallidos
-- ============================================================
UPDATE auth.user
SET
  estado            = 'bloqueado',
  bloqueado_hasta   = NOW() + INTERVAL '15 minutes',
  updated_at        = NOW()
WHERE email      = :email_usuario
  AND deleted_at IS NULL;

-- ============================================================
-- Desbloquear cuentas cuyo tiempo de bloqueo ya expiró
-- (puede ejecutarse como job programado)
-- ============================================================
UPDATE auth.user
SET
  estado            = 'activo',
  intentos_fallidos = 0,
  bloqueado_hasta   = NULL,
  updated_at        = NOW()
WHERE estado         = 'bloqueado'
  AND bloqueado_hasta < NOW()
  AND deleted_at    IS NULL;