-- ============================================================
-- GRANTS — Esquema auth
-- Archivo: 03_dcl/01_grants/001_grants_auth.sql
-- Descripción: Otorga privilegios sobre los objetos del
--              esquema auth a los roles de PostgreSQL.
--              Las tablas sensibles de autenticación
--              (user, session, mfa, recovery_token,
--              token_blacklist) no son accesibles para
--              smarthome_readonly (RNF5.3).
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_dcl/00_roles/001_create_roles.sql
--               01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

-- Uso del esquema
GRANT USAGE ON SCHEMA auth TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA auth TO smarthome_app;

-- smarthome_readonly: solo tablas no sensibles
GRANT SELECT ON auth.role            TO smarthome_readonly;
GRANT SELECT ON auth.permission      TO smarthome_readonly;
GRANT SELECT ON auth.user_role       TO smarthome_readonly;
GRANT SELECT ON auth.role_permission TO smarthome_readonly;

-- Aplicar a tablas futuras del esquema
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;