-- ============================================================
-- INSERT — Auditoría del seed inicial
-- Archivo: 02_dml/00_inserts/006_insert_auditoria_seed.sql
-- Descripción: Registra en audit.audit_log la ejecución
--              del seed inicial del sistema para garantizar
--              trazabilidad completa desde el primer arranque.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF7.1, RNF8.2
-- Dependencias: 01_ddl/03_tables/008_create_audit_tables.sql
--               02_dml/00_inserts/001_insert_roles.sql
--               02_dml/00_inserts/002_insert_permisos.sql
--               02_dml/00_inserts/003_insert_role_permissions.sql
--               02_dml/00_inserts/004_insert_tipos_dispositivos.sql
--               02_dml/00_inserts/005_insert_admin_user.sql
-- ============================================================

INSERT INTO audit.audit_log (
  id_audit_log,
  id_user,
  accion,
  modulo,
  entidad,
  resultado,
  detalle,
  created_at
)
VALUES
  (
    uuid_generate_v4(),
    'a1b2c3d4-9999-0000-0000-000000000001',
    'crear',
    'sistema',
    'role',
    'exitoso',
    'Seed inicial: inserción de roles base del sistema (administrador, estandar, invitado).',
    NOW()
  ),
  (
    uuid_generate_v4(),
    'a1b2c3d4-9999-0000-0000-000000000001',
    'crear',
    'sistema',
    'permission',
    'exitoso',
    'Seed inicial: inserción de 36 permisos del sistema organizados por módulo.',
    NOW()
  ),
  (
    uuid_generate_v4(),
    'a1b2c3d4-9999-0000-0000-000000000001',
    'crear',
    'sistema',
    'role_permission',
    'exitoso',
    'Seed inicial: asignación de permisos a roles según principio de mínimo privilegio.',
    NOW()
  ),
  (
    uuid_generate_v4(),
    'a1b2c3d4-9999-0000-0000-000000000001',
    'crear',
    'sistema',
    'type_device',
    'exitoso',
    'Seed inicial: inserción de catálogo de 13 tipos de dispositivos IoT.',
    NOW()
  ),
  (
    uuid_generate_v4(),
    'a1b2c3d4-9999-0000-0000-000000000001',
    'crear',
    'sistema',
    'user',
    'exitoso',
    'Seed inicial: creación de usuario administrador por defecto (admin@smarthome.com).',
    NOW()
  );