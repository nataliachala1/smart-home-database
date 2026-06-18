-- ============================================================
-- INSERT — Usuario administrador por defecto
-- Archivo: 02_dml/00_inserts/005_insert_admin_user.sql
-- Descripción: Crea el usuario administrador inicial del
--              sistema. Este usuario debe cambiar su
--              contraseña en el primer inicio de sesión.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.1, RF1.3
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
--               01_ddl/03_tables/007_create_config_tables.sql
--               02_dml/00_inserts/001_insert_roles.sql
-- ============================================================

-- ⚠️ IMPORTANTE: La contraseña Admin@SmartHome2025 es solo
-- para el arranque inicial. Debe cambiarse obligatoriamente
-- antes de pasar a producción (RF1.7).

-- ============================================================
-- 1. Insertar usuario administrador
-- ============================================================
INSERT INTO auth.user (
  id_user,
  nombre,
  apellido,
  username,
  email,
  password_hash,
  tipo_documento,
  numero_documento,
  estado,
  email_verificado,
  mfa_habilitado,
  created_at,
  updated_at
)
VALUES (
  'a1b2c3d4-9999-0000-0000-000000000001',
  'Administrador',
  'Sistema',
  'admin_smarthome',
  'admin@smarthome.com',
  crypt('Admin@SmartHome2025', gen_salt('bf', 12)),
  'CC',
  '0000000001',
  'activo',
  TRUE,
  FALSE,
  NOW(),
  NOW()
)
ON CONFLICT (id_user) DO NOTHING;

-- ============================================================
-- 2. Asignar rol administrador al usuario
-- ============================================================
INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'a1b2c3d4-0001-0000-0000-000000000001',
  NOW()
)
ON CONFLICT (id_user, id_role) DO NOTHING;

-- ============================================================
-- 3. Crear configuración por defecto para el administrador
-- ============================================================
INSERT INTO config.configuration_user (
  id_configuration_user,
  id_user,
  idioma,
  tema,
  formato_fecha,
  formato_hora,
  moneda,
  created_at,
  updated_at
)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'es',
  'claro',
  'DD/MM/YYYY',
  '24h',
  'COP',
  NOW(),
  NOW()
)
ON CONFLICT (id_user) DO NOTHING;