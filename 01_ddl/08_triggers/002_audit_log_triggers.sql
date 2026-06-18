-- ============================================================
-- TRIGGERS: audit_log
-- Archivo: 01_ddl/06_triggers/002_trg_audit_log.sql
-- Descripción: Aplica la función fn_audit_log a las tablas
--              críticas del sistema para garantizar
--              trazabilidad completa de operaciones.
--              Solo se auditan las tablas definidas en
--              el Módulo 7 del SRS (RF7.1, RNF8.2)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables, 05_functions/002_fn_audit_log.sql
-- ============================================================

-- ============================================================
-- Esquema: auth
-- ============================================================

-- Auditar creación, edición y desactivación de usuarios
CREATE TRIGGER trg_audit_user
  AFTER INSERT OR UPDATE ON auth.user
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar asignación y revocación de roles
CREATE TRIGGER trg_audit_user_role
  AFTER INSERT OR UPDATE ON auth.user_role
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar cambios en roles del sistema
CREATE TRIGGER trg_audit_role
  AFTER INSERT OR UPDATE ON auth.role
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar cambios en permisos del sistema
CREATE TRIGGER trg_audit_permission
  AFTER INSERT OR UPDATE ON auth.permission
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar asignación de permisos a roles
CREATE TRIGGER trg_audit_role_permission
  AFTER INSERT OR UPDATE ON auth.role_permission
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- ============================================================
-- Esquema: homes
-- ============================================================

-- Auditar creación, edición y desactivación de hogares
CREATE TRIGGER trg_audit_home
  AFTER INSERT OR UPDATE ON homes.home
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar gestión de zonas
CREATE TRIGGER trg_audit_area
  AFTER INSERT OR UPDATE ON homes.area
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar configuración de tarifas
CREATE TRIGGER trg_audit_tariff
  AFTER INSERT OR UPDATE ON homes.tariff
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar miembros del hogar
CREATE TRIGGER trg_audit_home_member
  AFTER INSERT OR UPDATE ON homes.home_member
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- ============================================================
-- Esquema: devices
-- ============================================================

-- Auditar registro y desactivación de dispositivos
CREATE TRIGGER trg_audit_device
  AFTER INSERT OR UPDATE ON devices.device
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar configuración de horarios automáticos
CREATE TRIGGER trg_audit_schedule
  AFTER INSERT OR UPDATE ON devices.schedule
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar configuración de umbrales de consumo
CREATE TRIGGER trg_audit_threshold_rule
  AFTER INSERT OR UPDATE ON devices.threshold_rule
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- Auditar vinculación de asistentes de voz
CREATE TRIGGER trg_audit_voice_assistant_token
  AFTER INSERT OR UPDATE ON devices.voice_assistant_token
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- ============================================================
-- Esquema: sync
-- ============================================================

-- Auditar restauraciones de backup (RF5.3)
CREATE TRIGGER trg_audit_backup
  AFTER INSERT ON sync.backup
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();

-- ============================================================
-- Esquema: config
-- ============================================================

-- Auditar cambios en configuración de usuario
CREATE TRIGGER trg_audit_configuration_user
  AFTER INSERT OR UPDATE ON config.configuration_user
  FOR EACH ROW EXECUTE FUNCTION fn_audit_log();