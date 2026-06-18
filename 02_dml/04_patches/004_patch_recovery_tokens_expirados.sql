-- ============================================================
-- PATCH — Marcar tokens de recuperación expirados
-- Archivo: 02_dml/04_patches/004_patch_recovery_tokens_expirados.sql
-- Descripción: Marca como usados los tokens de recuperación
--              que ya expiraron sin ser utilizados, para
--              evitar intentos de uso sobre tokens vencidos.
--              Puede ejecutarse como job programado.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.6, RF1.8
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

UPDATE auth.recovery_token
SET usado = TRUE
WHERE expira_en < NOW()
  AND usado     = FALSE;