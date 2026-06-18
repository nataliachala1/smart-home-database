-- ============================================================
-- TRIGGER: trg_config_user
-- Archivo: 01_ddl/06_triggers/003_trg_config_user.sql
-- Descripción: Aplica la función fn_config_user después de
--              insertar un nuevo usuario en auth.user para
--              garantizar que siempre tenga una configuración
--              personal asociada desde su creación
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/auth.user,
--               03_tables/config.configuration_user,
--               05_functions/003_fn_config_user.sql
-- ============================================================

CREATE TRIGGER trg_config_user
  AFTER INSERT ON auth.user
  FOR EACH ROW EXECUTE FUNCTION fn_config_user();

COMMENT ON TRIGGER trg_config_user ON auth.user
  IS 'Crea automáticamente la configuración personal del usuario al registrarse en el sistema.';