-- ============================================================
-- GRANTS — Esquema devices
-- Archivo: 03_dcl/01_grants/003_grants_devices.sql
-- Descripción: Otorga privilegios sobre los objetos del
--              esquema devices a los roles de PostgreSQL.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/003_create_devices_tables.sql
-- ============================================================

GRANT USAGE ON SCHEMA devices TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA devices TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA devices TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA devices TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA devices TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA devices TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA devices
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA devices
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA devices
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;