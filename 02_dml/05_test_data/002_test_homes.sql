-- ============================================================
-- TEST DATA — Hogares y zonas de prueba
-- Archivo: 02_dml/05_test_data/002_test_homes.sql
-- Descripción: Inserta hogares y zonas de prueba asociados
--              a los usuarios de prueba para validar la
--              gestión de hogares, zonas y tarifas.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- ⚠️ SOLO PARA DESARROLLO Y PRUEBAS — NO ejecutar en producción
-- Dependencias: 02_dml/05_test_data/001_test_users.sql
-- ============================================================

-- ============================================================
-- 1. Hogares de prueba
-- ============================================================
INSERT INTO homes.home (
  id_home, id_user, nombre, estrato, estado, created_at, updated_at
)
VALUES
  -- Hogar de Karen (estrato 3)
  (
    'c1000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000001',
    'Casa Karen', 3, 'activo',
    NOW(), NOW()
  ),
  -- Hogar de Kevin (estrato 4)
  (
    'c1000000-0000-0000-0000-000000000002',
    'b1000000-0000-0000-0000-000000000002',
    'Apartamento Kevin', 4, 'activo',
    NOW(), NOW()
  )
ON CONFLICT (id_home) DO NOTHING;

-- ============================================================
-- 2. Miembros de hogar
-- Karen y Kevin son propietarios de sus hogares
-- Natalia es miembro invitado del hogar de Karen
-- ============================================================
INSERT INTO homes.home_member (
  id_home_member, id_home, id_user, rol_en_hogar, created_at
)
VALUES
  (
    uuid_generate_v4(),
    'c1000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000001',
    'propietario', NOW()
  ),
  (
    uuid_generate_v4(),
    'c1000000-0000-0000-0000-000000000002',
    'b1000000-0000-0000-0000-000000000002',
    'propietario', NOW()
  ),
  (
    uuid_generate_v4(),
    'c1000000-0000-0000-0000-000000000001',
    'b1000000-0000-0000-0000-000000000003',
    'miembro', NOW()
  )
ON CONFLICT (id_home, id_user) DO NOTHING;

-- ============================================================
-- 3. Zonas del hogar de Karen
-- ============================================================
INSERT INTO homes.area (
  id_area, id_home, nombre, tipo, created_at, updated_at
)
VALUES
  (
    'd1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'Sala Principal', 'sala', NOW(), NOW()
  ),
  (
    'd1000000-0000-0000-0000-000000000002',
    'c1000000-0000-0000-0000-000000000001',
    'Cocina', 'cocina', NOW(), NOW()
  ),
  (
    'd1000000-0000-0000-0000-000000000003',
    'c1000000-0000-0000-0000-000000000001',
    'Dormitorio Principal', 'dormitorio', NOW(), NOW()
  ),
  (
    'd1000000-0000-0000-0000-000000000004',
    'c1000000-0000-0000-0000-000000000001',
    'Baño', 'baño', NOW(), NOW()
  )
ON CONFLICT (id_area) DO NOTHING;

-- ============================================================
-- 4. Zonas del hogar de Kevin
-- ============================================================
INSERT INTO homes.area (
  id_area, id_home, nombre, tipo, created_at, updated_at
)
VALUES
  (
    'd1000000-0000-0000-0000-000000000005',
    'c1000000-0000-0000-0000-000000000002',
    'Sala', 'sala', NOW(), NOW()
  ),
  (
    'd1000000-0000-0000-0000-000000000006',
    'c1000000-0000-0000-0000-000000000002',
    'Habitación', 'dormitorio', NOW(), NOW()
  ),
  (
    'd1000000-0000-0000-0000-000000000007',
    'c1000000-0000-0000-0000-000000000002',
    'Cocina', 'cocina', NOW(), NOW()
  )
ON CONFLICT (id_area) DO NOTHING;

-- ============================================================
-- 5. Tarifas eléctricas de prueba
-- ============================================================
INSERT INTO homes.tariff (
  id_tariff, id_home, costo_kwh, moneda,
  vigente_desde, vigente_hasta, created_at, updated_at
)
VALUES
  -- Tarifa hogar Karen
  (
    uuid_generate_v4(),
    'c1000000-0000-0000-0000-000000000001',
    850.0000, 'COP',
    '2025-01-01', NULL,
    NOW(), NOW()
  ),
  -- Tarifa hogar Kevin
  (
    uuid_generate_v4(),
    'c1000000-0000-0000-0000-000000000002',
    920.0000, 'COP',
    '2025-01-01', NULL,
    NOW(), NOW()
  )
ON CONFLICT DO NOTHING;