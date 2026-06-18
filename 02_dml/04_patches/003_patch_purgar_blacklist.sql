-- ============================================================
-- PATCH — Purgar tokens revocados expirados
-- Archivo: 02_dml/04_patches/003_patch_purgar_blacklist.sql
-- Descripción: Elimina físicamente los tokens revocados
--              cuya fecha de expiración original ya pasó,
--              para mantener la tabla liviana. Es el único
--              caso de DELETE físico permitido en el sistema.
--              Puede ejecutarse como job programado.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.4, RNF5.2
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

-- Los tokens cuya expiración original ya pasó no pueden
-- ser reutilizados, por lo que es seguro eliminarlos
-- físicamente para optimizar el rendimiento de la tabla.
DELETE FROM auth.token_blacklist
WHERE expira_en < NOW() - INTERVAL '1 day';