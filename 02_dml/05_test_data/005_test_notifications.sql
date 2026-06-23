-- ============================================================
-- TEST DATA — Notificaciones y Alertas de Prueba
-- Archivo: 02_dml/00_test_data/005_test_notifications.sql
-- Descripción: Inserta notificaciones, alertas de umbral y
--              recordatorios ficticios para probar el centro
--              de notificaciones (RF4.5), la configuración
--              de notificaciones (RF4.6) y las alertas
--              generadas por umbral de consumo (RF3.2, RF3.5)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- ⚠️ SOLO PARA DESARROLLO Y PRUEBAS — NO ejecutar en producción
-- Dependencias: 02_dml/00_test_data/001_test_users.sql,
--               02_dml/00_test_data/002_test_homes.sql,
--               02_dml/00_test_data/003_test_devices.sql
-- ============================================================

-- ============================================================
-- 1. Notificaciones de prueba para Karen
-- ============================================================
INSERT INTO notifications.notification (
  id_notification, id_user, id_home, id_device,
  tipo, titulo, mensaje, prioridad, leida, canal,
  created_at, updated_at
)
VALUES
  -- Consumo elevado del aire acondicionado (no leída, alta prioridad)
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000005',
    'consumo_elevado',
    'Consumo elevado detectado',
    'El Aire Dormitorio ha superado el umbral diario configurado de 3 kWh.',
    'alta', FALSE, 'app',
    NOW() - INTERVAL '2 hours', NOW() - INTERVAL '2 hours'
  ),
  -- Nueva recomendación de ahorro (no leída, prioridad media)
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    NULL,
    'nueva_recomendacion',
    'Nueva recomendación de ahorro disponible',
    'Hemos identificado una oportunidad de ahorro en tu hogar. Revisa la sección de recomendaciones.',
    'media', FALSE, 'app',
    NOW() - INTERVAL '1 day', NOW() - INTERVAL '1 day'
  ),
  -- Dispositivo desconectado (leída, prioridad media)
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000004',
    'dispositivo_desconectado',
    'Dispositivo desconectado',
    'El Microondas Cocina se desconectó inesperadamente.',
    'media', TRUE, 'app',
    NOW() - INTERVAL '3 days', NOW() - INTERVAL '3 days'
  ),
  -- Notificación de sistema (leída, prioridad baja)
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    NULL,
    NULL,
    'sistema',
    'Bienvenida a Smart Home',
    'Tu cuenta ha sido activada exitosamente. ¡Comienza a monitorear tu consumo!',
    'baja', TRUE, 'email',
    NOW() - INTERVAL '10 days', NOW() - INTERVAL '10 days'
  )
ON CONFLICT (id_notification) DO NOTHING;

-- ============================================================
-- 2. Notificaciones de prueba para Kevin
-- ============================================================
INSERT INTO notifications.notification (
  id_notification, id_user, id_home, id_device,
  tipo, titulo, mensaje, prioridad, leida, canal,
  created_at, updated_at
)
VALUES
  -- Umbral superado en computador (no leída, alta prioridad)
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000002',
    'c1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000007',
    'umbral_superado',
    'Umbral de consumo superado',
    'El Computador Habitación ha superado el límite diario de 2 kWh configurado.',
    'alta', FALSE, 'push',
    NOW() - INTERVAL '5 hours', NOW() - INTERVAL '5 hours'
  ),
  -- Notificación de sistema (no leída, prioridad baja)
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000002',
    NULL,
    NULL,
    'sistema',
    'Actualización disponible',
    'Hay una nueva versión de la aplicación Smart Home disponible.',
    'baja', FALSE, 'app',
    NOW() - INTERVAL '6 hours', NOW() - INTERVAL '6 hours'
  )
ON CONFLICT (id_notification) DO NOTHING;

-- ============================================================
-- 3. Notificación de prueba para Natalia (invitada)
-- ============================================================
INSERT INTO notifications.notification (
  id_notification, id_user, id_home, id_device,
  tipo, titulo, mensaje, prioridad, leida, canal,
  created_at, updated_at
)
VALUES
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000003',
    'c1000000-0000-0000-0000-000000000001',
    NULL,
    'sistema',
    'Has sido agregada a un hogar',
    'Karen Daniela Holguín Cruz te agregó como miembro de "Casa Karen".',
    'media', FALSE, 'email',
    NOW() - INTERVAL '4 days', NOW() - INTERVAL '4 days'
  )
ON CONFLICT (id_notification) DO NOTHING;

-- ============================================================
-- 4. Alertas de umbral de prueba
-- Vinculadas a las reglas creadas en 003_test_devices.sql
-- ============================================================
INSERT INTO notifications.alert (
  id_alert, id_threshold_rule, id_device, id_home,
  consumo_detectado_kwh, limite_kwh, accion_ejecutada, created_at
)
SELECT
  uuid_generate_v4(),
  tr.id_threshold_rule,
  tr.id_device,
  dev.id_home,
  -- Consumo detectado simulado: 15% por encima del límite
  ROUND((tr.limite_kwh * 1.15)::NUMERIC, 4),
  tr.limite_kwh,
  tr.accion,
  NOW() - INTERVAL '2 hours'
FROM devices.threshold_rule tr
JOIN devices.device         dev ON dev.id_device = tr.id_device
WHERE tr.id_device = 'e1000000-0000-0000-0000-000000000005'  -- Aire Dormitorio Karen
  AND tr.tipo       = 'diario'
ON CONFLICT DO NOTHING;

INSERT INTO notifications.alert (
  id_alert, id_threshold_rule, id_device, id_home,
  consumo_detectado_kwh, limite_kwh, accion_ejecutada, created_at
)
SELECT
  uuid_generate_v4(),
  tr.id_threshold_rule,
  tr.id_device,
  dev.id_home,
  ROUND((tr.limite_kwh * 1.10)::NUMERIC, 4),
  tr.limite_kwh,
  tr.accion,
  NOW() - INTERVAL '5 hours'
FROM devices.threshold_rule tr
JOIN devices.device         dev ON dev.id_device = tr.id_device
WHERE tr.id_device = 'e1000000-0000-0000-0000-000000000007'  -- Computador Habitación Kevin
  AND tr.tipo       = 'diario'
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. Recordatorio de prueba
-- ============================================================
INSERT INTO notifications.reminder_notification (
  id_reminder_notification, id_user, id_home,
  mensaje, programado_para, enviado, created_at, updated_at
)
VALUES
  (
    uuid_generate_v4(),
    'b1000000-0000-0000-0000-000000000001',
    'c1000000-0000-0000-0000-000000000001',
    'Recuerda revisar el consumo de tu hogar esta semana.',
    NOW() + INTERVAL '2 days',
    FALSE,
    NOW(), NOW()
  )
ON CONFLICT (id_reminder_notification) DO NOTHING;