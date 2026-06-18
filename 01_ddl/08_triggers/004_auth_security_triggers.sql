-- ============================================================
-- TRIGGERS: auth_security
-- Archivo: 01_ddl/06_triggers/004_trg_auth_security.sql
-- Descripción: Aplica las funciones de seguridad de
--              autenticación sobre las tablas críticas
--              del esquema auth
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/auth,
--               05_functions/004_fn_auth_security.sql
-- ============================================================

-- ============================================================
-- TRIGGER: trg_auth_intentos_fallidos
-- Descripción: Gestiona el bloqueo automático de cuenta
--              al superar el límite de intentos fallidos
--              y cierra sesiones al desactivar o bloquear
-- ============================================================
CREATE TRIGGER trg_auth_intentos_fallidos
  BEFORE UPDATE ON auth.user
  FOR EACH ROW EXECUTE FUNCTION fn_auth_intentos_fallidos();

COMMENT ON TRIGGER trg_auth_intentos_fallidos ON auth.user
  IS 'Bloquea automáticamente la cuenta tras 5 intentos fallidos y cierra sesiones al desactivar o bloquear.';

-- ============================================================
-- TRIGGER: trg_auth_cambio_password
-- Descripción: Revoca sesiones activas cuando el usuario
--              cambia su contraseña
-- ============================================================
CREATE TRIGGER trg_auth_cambio_password
  BEFORE UPDATE ON auth.user
  FOR EACH ROW EXECUTE FUNCTION fn_auth_cambio_password();

COMMENT ON TRIGGER trg_auth_cambio_password ON auth.user
  IS 'Revoca todas las sesiones activas y registra tokens en blacklist al cambiar la contraseña.';

-- ============================================================
-- TRIGGER: trg_auth_mfa_reset
-- Descripción: Resetea intentos fallidos de MFA al
--              completar verificación exitosamente
-- ============================================================
CREATE TRIGGER trg_auth_mfa_reset
  AFTER UPDATE ON auth.recovery_token
  FOR EACH ROW EXECUTE FUNCTION fn_auth_mfa_reset();

COMMENT ON TRIGGER trg_auth_mfa_reset ON auth.recovery_token
  IS 'Resetea el contador de intentos fallidos de MFA tras verificación exitosa del segundo factor.';