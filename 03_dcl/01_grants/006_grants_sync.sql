-- ============================================================
-- GRANTS — Esquema sync
-- Archivo: 03_dcl/01_grants/006_grants_sync.sql
-- Descripción: Otorga privilegios sobre los objetos del
--              esquema sync a los roles de PostgreSQL.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/006_create_sync_tables.sql
-- ============================================================

GRANT USAGE ON SCHEMA sync TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sync TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA sync TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sync TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sync TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA sync TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA sync
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA sync
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA sync
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;