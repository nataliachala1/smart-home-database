-- ============================================================
-- TEST DATA — Lecturas de Consumo de Prueba
-- Archivo: 02_dml/00_test_data/004_test_consumption.sql
-- Descripción: Inserta lecturas de consumo ficticias para
--              los dispositivos de prueba, cubriendo los
--              últimos 7 días con varias lecturas por día.
--              Permite probar gráficos (RF4.3), dashboard
--              en tiempo real (RF4.2), reportes (RF4.1) y
--              las vistas materializadas de resumen.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- ⚠️ SOLO PARA DESARROLLO Y PRUEBAS — NO ejecutar en producción
-- Dependencias: 02_dml/00_test_data/002_test_homes.sql,
--               02_dml/00_test_data/003_test_devices.sql
-- ============================================================

-- ============================================================
-- Generación de lecturas de consumo de los últimos 7 días
-- cada 6 horas (4 lecturas diarias por dispositivo) para
-- los dispositivos que están conectados y encendidos.
--
-- Tarifa usada para el cálculo de costo_estimado:
--   Hogar Karen (c1000000-...-001): 850 COP/kWh
--   Hogar Kevin (c1000000-...-002): 920 COP/kWh
-- ============================================================

INSERT INTO consumption.consumption (
  id_consumption, id_device, id_home, watts,
  kwh_acumulado, costo_estimado, fecha_lectura
)
SELECT
  uuid_generate_v4(),
  d.id_device,
  d.id_home,
  -- Watts con variación aleatoria leve alrededor del consumo base
  ROUND((d.watts_base + (random() * d.watts_base * 0.15 - d.watts_base * 0.075))::NUMERIC, 2) AS watts,
  -- kWh acumulado: watts * 6 horas / 1000
  ROUND(((d.watts_base * 6) / 1000.0)::NUMERIC, 6) AS kwh_acumulado,
  -- Costo estimado según tarifa del hogar
  ROUND((((d.watts_base * 6) / 1000.0) * d.tarifa)::NUMERIC, 4) AS costo_estimado,
  d.fecha_lectura
FROM (
  SELECT
    dev.id_device,
    dev.id_home,
    CASE dev.id_device
      WHEN 'e1000000-0000-0000-0000-000000000001' THEN 12.50   -- Lámpara Sala Karen
      WHEN 'e1000000-0000-0000-0000-000000000002' THEN 120.00  -- Televisor Sala Karen
      WHEN 'e1000000-0000-0000-0000-000000000003' THEN 150.00  -- Nevera Cocina Karen
      WHEN 'e1000000-0000-0000-0000-000000000005' THEN 1400.00 -- Aire Dormitorio Karen
      WHEN 'e1000000-0000-0000-0000-000000000006' THEN 12.50   -- Lámpara Sala Kevin
      WHEN 'e1000000-0000-0000-0000-000000000007' THEN 200.00  -- Computador Habitación Kevin
    END AS watts_base,
    CASE dev.id_home
      WHEN 'c1000000-0000-0000-0000-000000000001' THEN 850.0
      WHEN 'c1000000-0000-0000-0000-000000000002' THEN 920.0
    END AS tarifa,
    fecha_lectura
  FROM devices.device dev
  CROSS JOIN LATERAL (
    SELECT generate_series(
      NOW() - INTERVAL '7 days',
      NOW(),
      INTERVAL '6 hours'
    ) AS fecha_lectura
  ) fechas
  WHERE dev.id_device IN (
    'e1000000-0000-0000-0000-000000000001',
    'e1000000-0000-0000-0000-000000000002',
    'e1000000-0000-0000-0000-000000000003',
    'e1000000-0000-0000-0000-000000000005',
    'e1000000-0000-0000-0000-000000000006',
    'e1000000-0000-0000-0000-000000000007'
  )
) d
ON CONFLICT DO NOTHING;

-- ============================================================
-- Lectura "ahora mismo" para cada dispositivo conectado,
-- usada por el dashboard de monitoreo en tiempo real
-- (consumption.vw_consumo_tiempo_real)
-- ============================================================
INSERT INTO consumption.consumption (
  id_consumption, id_device, id_home, watts,
  kwh_acumulado, costo_estimado, fecha_lectura
)
VALUES
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 12.50,  0.075,  0.0638, NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 118.30, 0.710,  0.6034, NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000001', 148.90, 0.893,  0.7592, NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000006', 'c1000000-0000-0000-0000-000000000002', 12.40,  0.074,  0.0681, NOW()),
  (uuid_generate_v4(), 'e1000000-0000-0000-0000-000000000007', 'c1000000-0000-0000-0000-000000000002', 205.60, 1.234,  1.1349, NOW())
ON CONFLICT DO NOTHING;

-- ============================================================
-- NOTA: Las vistas materializadas consumption.mv_resumen_diario_hogar,
-- consumption.mv_resumen_mensual_hogar y consumption.mv_ranking_dispositivos
-- deben refrescarse manualmente tras insertar estos datos de prueba:
--
--   REFRESH MATERIALIZED VIEW CONCURRENTLY consumption.mv_resumen_diario_hogar;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY consumption.mv_resumen_mensual_hogar;
--   REFRESH MATERIALIZED VIEW CONCURRENTLY consumption.mv_ranking_dispositivos;
-- ============================================================