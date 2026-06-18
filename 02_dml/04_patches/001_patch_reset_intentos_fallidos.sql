-- ============================================================
-- PATCH — Reset de intentos fallidos
-- Archivo: 02_dml/04_patches/001_patch_reset_intentos_fallidos.sql
-- Descripción: Resetea el contador de intentos fallidos y
--              desbloquea cuentas cuyo tiempo de bloqueo
--              ya expiró. Puede ejecutarse como job
--              programado periódicamente.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.2
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

UPDATE auth.user
SET
  intentos_fallidos = 0,
  bloqueado_hasta   = NULL,
  estado            = 'activo',
  updated_at        = NOW()
WHERE estado          = 'bloqueado'
  AND bloqueado_hasta < NOW()
  AND deleted_at      IS NULL;