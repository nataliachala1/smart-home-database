-- ============================================================
-- PATCH — Invalidar tokens de sesión expirados
-- Archivo: 02_dml/04_patches/002_patch_invalidar_tokens_expirados.sql
-- Descripción: Marca como inactivas las sesiones cuyo token
--              ya expiró. Puede ejecutarse como job
--              programado diariamente (RNF5.4).
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.4, RNF5.4
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

UPDATE auth.session
SET
  activa     = FALSE,
  updated_at = NOW()
WHERE expira_en  < NOW()
  AND activa     = TRUE
  AND deleted_at IS NULL;