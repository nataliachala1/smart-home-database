-- ============================================================
-- TEST DATA — Usuarios de prueba
-- Archivo: 02_dml/05_test_data/001_test_users.sql
-- Descripción: Inserta usuarios de prueba con diferentes
--              roles para validar el sistema de autenticación,
--              control de acceso y flujos de negocio.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- ⚠️ SOLO PARA DESARROLLO Y PRUEBAS — NO ejecutar en producción
-- Dependencias: 02_dml/00_inserts/001_insert_roles.sql
-- ============================================================

-- ============================================================
-- 1. Usuarios de prueba
-- ============================================================
INSERT INTO auth.user (
  id_user, nombre, apellido, username, email,
  password_hash, tipo_documento, numero_documento,
  estado, email_verificado, mfa_habilitado,
  created_at, updated_at
)
VALUES
  -- Usuario estándar 1: Karen
  (
    'b1000000-0000-0000-0000-000000000001',
    'Karen Daniela', 'Holguín Cruz',
    'karen_holguin',
    'karen@smarthome.com',
    crypt('Karen@2025!', gen_salt('bf', 12)),
    'CC', '1001000001',
    'activo', TRUE, FALSE,
    NOW(), NOW()
  ),
  -- Usuario estándar 2: Kevin
  (
    'b1000000-0000-0000-0000-000000000002',
    'Kevin Stiven', 'López Amaya',
    'kevin_lopez',
    'kevin@smarthome.com',
    crypt('Kevin@2025!', gen_salt('bf', 12)),
    'CC', '1001000002',
    'activo', TRUE, FALSE,
    NOW(), NOW()
  ),
  -- Usuario invitado
  (
    'b1000000-0000-0000-0000-000000000003',
    'Natalia', 'Chala Chala',
    'natalia_chala',
    'natalia@smarthome.com',
    crypt('Natalia@2025!', gen_salt('bf', 12)),
    'CC', '1001000003',
    'activo', TRUE, FALSE,
    NOW(), NOW()
  )
ON CONFLICT (id_user) DO NOTHING;

-- ============================================================
-- 2. Asignación de roles
-- ============================================================
INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
VALUES
  -- Karen → rol estándar
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    'a1b2c3d4-0001-0000-0000-000000000002',
    NOW()
  ),
  -- Kevin → rol estándar
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000002',
    'a1b2c3d4-0001-0000-0000-000000000002',
    NOW()
  ),
  -- Natalia → rol invitado
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000003',
    'a1b2c3d4-0001-0000-0000-000000000003',
    NOW()
  )
ON CONFLICT (id_user, id_role) DO NOTHING;

-- ============================================================
-- 3. Configuración por defecto para cada usuario
-- ============================================================
INSERT INTO config.configuration_user (
  id_configuration_user, id_user, idioma, tema,
  formato_fecha, formato_hora, moneda,
  created_at, updated_at
)
VALUES
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    'es', 'claro', 'DD/MM/YYYY', '24h', 'COP',
    NOW(), NOW()
  ),
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000002',
    'es', 'oscuro', 'DD/MM/YYYY', '24h', 'COP',
    NOW(), NOW()
  ),
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000003',
    'es', 'automatico', 'DD/MM/YYYY', '12h', 'COP',
    NOW(), NOW()
  )
ON CONFLICT (id_user) DO NOTHING;