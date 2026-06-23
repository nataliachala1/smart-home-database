-- ============================================================
-- GRANTS — Esquema audit
-- Archivo: 03_dcl/01_grants/008_grants_audit.sql
-- Descripción: Otorga privilegios sobre los objetos del
--              esquema audit a los roles de PostgreSQL.
--              ESPECIAL: smarthome_app solo puede SELECT
--              e INSERT. Nunca UPDATE ni DELETE para
--              garantizar la inmutabilidad de los logs
--              (RNF8.2).
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/008_create_audit_tables.sql
-- ============================================================

GRANT USAGE ON SCHEMA audit TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA audit TO smarthome_admin;

-- smarthome_app: solo insertar y consultar (NO UPDATE, NO DELETE)
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA audit TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
  GRANT SELECT, INSERT ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;