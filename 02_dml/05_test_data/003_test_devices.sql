-- ============================================================
-- TEST DATA — Dispositivos de prueba
-- Archivo: 02_dml/05_test_data/003_test_devices.sql
-- Descripción: Inserta dispositivos de prueba vinculados
--              a los hogares y zonas de prueba para validar
--              el registro, configuración, horarios y
--              umbrales de consumo.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- ⚠️ SOLO PARA DESARROLLO Y PRUEBAS — NO ejecutar en producción
-- Dependencias: 02_dml/05_test_data/002_test_homes.sql
--               02_dml/00_inserts/004_insert_tipos_dispositivos.sql
-- ============================================================

-- ============================================================
-- 1. Dispositivos del hogar de Karen
-- ============================================================
INSERT INTO devices.device (
  id_device, id_home, id_area, id_type_device,
  nombre, estado, encendido, consumo_actual_w,
  protocolo, created_at, updated_at
)
VALUES
  -- Lámpara sala
  (
    'e1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Lámpara inteligente'),
    'Lámpara Sala', 'conectado', TRUE, 12.50,
    'wifi', NOW(), NOW()
  ),
  -- Televisor sala
  (
    'e1000000-0000-0000-0000-000000000002',
    'c1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000001',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Televisor'),
    'Televisor Sala', 'conectado', TRUE, 120.00,
    'wifi', NOW(), NOW()
  ),
  -- Nevera cocina
  (
    'e1000000-0000-0000-0000-000000000003',
    'c1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000002',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Nevera'),
    'Nevera Cocina', 'conectado', TRUE, 150.00,
    'wifi', NOW(), NOW()
  ),
  -- Microondas cocina
  (
    'e1000000-0000-0000-0000-000000000004',
    'c1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000002',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Horno microondas'),
    'Microondas Cocina', 'conectado', FALSE, 0.00,
    'wifi', NOW(), NOW()
  ),
  -- Aire acondicionado dormitorio
  (
    'e1000000-0000-0000-0000-000000000005',
    'c1000000-0000-0000-0000-000000000001',
    'd1000000-0000-0000-0000-000000000003',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Aire acondicionado'),
    'Aire Dormitorio', 'conectado', FALSE, 0.00,
    'wifi', NOW(), NOW()
  )
ON CONFLICT (id_device) DO NOTHING;

-- ============================================================
-- 2. Dispositivos del hogar de Kevin
-- ============================================================
INSERT INTO devices.device (
  id_device, id_home, id_area, id_type_device,
  nombre, estado, encendido, consumo_actual_w,
  protocolo, created_at, updated_at
)
VALUES
  -- Lámpara sala
  (
    'e1000000-0000-0000-0000-000000000006',
    'c1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000005',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Lámpara inteligente'),
    'Lámpara Sala', 'conectado', TRUE, 12.50,
    'wifi', NOW(), NOW()
  ),
  -- Computador habitación
  (
    'e1000000-0000-0000-0000-000000000007',
    'c1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000006',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Computador'),
    'Computador Habitación', 'conectado', TRUE, 200.00,
    'wifi', NOW(), NOW()
  ),
  -- Lavadora cocina
  (
    'e1000000-0000-0000-0000-000000000008',
    'c1000000-0000-0000-0000-000000000002',
    'd1000000-0000-0000-0000-000000000007',
    (SELECT id_type_device FROM devices.type_device WHERE nombre = 'Lavadora'),
    'Lavadora', 'conectado', FALSE, 0.00,
    'wifi', NOW(), NOW()
  )
ON CONFLICT (id_device) DO NOTHING;

-- ============================================================
-- 3. Datos extendidos de dispositivos inteligentes
-- ============================================================
INSERT INTO devices.smart_device (
  id_smart_device, id_device, modelo, fabricante,
  capacidad_maxima_w, created_at, updated_at
)
VALUES
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000001', 'SmartBulb A19', 'Philips', 15.00,    NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000002', 'SmartTV 55"',   'Samsung', 200.00,   NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000003', 'RF28R7200SR',   'Samsung', 350.00,   NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000004', 'MS23K3515AK',   'Samsung', 1200.00,  NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000005', 'AS09A6RF',      'Samsung', 1500.00,  NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000006', 'SmartBulb A19', 'Philips', 15.00,    NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000007', 'Inspiron 15',   'Dell',    250.00,   NOW(), NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000008', 'WF45R6100AW',   'Samsung', 500.00,   NOW(), NOW())
ON CONFLICT (id_device) DO NOTHING;

-- ============================================================
-- 4. Horarios automáticos de prueba
-- ============================================================
INSERT INTO devices.schedule (
  id_schedule, id_device, accion, hora,
  dias_semana, activo, created_at, updated_at
)
VALUES
  -- Lámpara sala Karen: encender lunes a viernes a las 6pm
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000001',
    'encender', '18:00:00',
    ARRAY[1,2,3,4,5], TRUE, NOW(), NOW()
  ),
  -- Lámpara sala Karen: apagar todos los días a las 11pm
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000001',
    'apagar', '23:00:00',
    ARRAY[1,2,3,4,5,6,7], TRUE, NOW(), NOW()
  ),
  -- Aire dormitorio Karen: encender lunes a viernes a las 9pm
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000005',
    'encender', '21:00:00',
    ARRAY[1,2,3,4,5], TRUE, NOW(), NOW()
  ),
  -- Aire dormitorio Karen: apagar todos los días a las 6am
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000005',
    'apagar', '06:00:00',
    ARRAY[1,2,3,4,5,6,7], TRUE, NOW(), NOW()
  )
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. Reglas de umbral de prueba
-- ============================================================
INSERT INTO devices.threshold_rule (
  id_threshold_rule, id_device, tipo,
  limite_kwh, accion, activa, created_at, updated_at
)
VALUES
  -- Aire acondicionado Karen: límite diario 3 kWh
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000005',
    'diario', 3.0000, 'alertar', TRUE, NOW(), NOW()
  ),
  -- Nevera Karen: límite mensual 100 kWh
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000003',
    'mensual', 100.0000, 'alertar', TRUE, NOW(), NOW()
  ),
  -- Computador Kevin: límite diario 2 kWh
  (
    uuid_generate_v4(),
    'e1000000-0000-0000-0000-000000000007',
    'diario', 2.0000, 'alertar', TRUE, NOW(), NOW()
  )
ON CONFLICT DO NOTHING;