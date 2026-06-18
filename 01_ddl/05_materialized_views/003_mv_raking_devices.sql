-- ============================================================
-- VISTA MATERIALIZADA — Ranking de Dispositivos por Consumo
-- Archivo: 01_ddl/05_materialized_views/003_mv_ranking_dispositivos.sql
-- Descripción: Ranking de dispositivos por consumo total en
--              los últimos 30 días, usado para identificar
--              los dispositivos de mayor consumo y generar
--              recomendaciones de ahorro (RF4.4)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/003_create_homes_tables.sql,
--               03_tables/004_create_devices_tables.sql,
--               03_tables/005_create_consumption_tables.sql
--
-- NOTA IMPORTANTE: esta vista NO es para tiempo real (RF4.2).
-- Para monitoreo en tiempo real usar la vista normal
-- consumption.vw_consumo_tiempo_real.
-- ============================================================

-- ============================================================
-- VISTA MATERIALIZADA: consumption.mv_ranking_dispositivos
-- Referencia SRS: RF4.4
-- Frecuencia de refresco recomendada: 1 vez al día
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS consumption.mv_ranking_dispositivos AS
SELECT
  d.id_device,
  d.nombre                          AS nombre_dispositivo,
  d.id_home,
  h.nombre                          AS nombre_hogar,
  td.nombre                         AS tipo_dispositivo,
  SUM(c.kwh_acumulado)              AS kwh_total_30_dias,
  SUM(c.costo_estimado) FILTER (WHERE c.costo_estimado IS NOT NULL) AS costo_total_30_dias,
  COUNT(*) FILTER (WHERE c.costo_estimado IS NULL) AS lecturas_sin_costo,
  AVG(c.watts)                      AS watts_promedio,
  RANK() OVER (
    PARTITION BY d.id_home
    ORDER BY SUM(c.kwh_acumulado) DESC
  )                                  AS ranking_en_hogar
FROM consumption.consumption c
JOIN devices.device            d  ON d.id_device      = c.id_device
                                   AND d.deleted_at     IS NULL
JOIN homes.home                 h  ON h.id_home         = d.id_home
                                   AND h.deleted_at      IS NULL
JOIN devices.type_device        td ON td.id_type_device = d.id_type_device
WHERE c.fecha_lectura > NOW() - INTERVAL '30 days'
GROUP BY d.id_device, d.nombre, d.id_home, h.nombre, td.nombre;

-- Índice único requerido para permitir REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_ranking_dispositivos
  ON consumption.mv_ranking_dispositivos (id_device);

COMMENT ON MATERIALIZED VIEW consumption.mv_ranking_dispositivos
  IS 'Ranking de dispositivos por consumo en los últimos 30 días, agrupado por hogar. Base para recomendaciones de ahorro. Refrescar diariamente.';

-- ============================================================
-- COMANDO DE REFRESCO
-- ============================================================

-- REFRESH MATERIALIZED VIEW CONCURRENTLY consumption.mv_ranking_dispositivos;

-- ============================================================
-- OPCIÓN A — Programación con pg_cron (recomendada)
-- Requiere la extensión pg_cron instalada en el contenedor
-- PostgreSQL (no viene en la imagen oficial 'postgres').
-- Descomentar si pg_cron está disponible.
-- ============================================================

-- CREATE EXTENSION IF NOT EXISTS pg_cron;
--
-- SELECT cron.schedule(
--   'refresh_mv_ranking_dispositivos',
--   '0 1 * * *',  -- todos los días a la 1:00 AM
--   $$REFRESH MATERIALIZED VIEW CONCURRENTLY consumption.mv_ranking_dispositivos$$
-- );

-- ============================================================
-- OPCIÓN B — Programación desde el backend (alternativa)
-- Si pg_cron no está disponible, programar un job
-- (node-cron, Celery, APScheduler) que ejecute diariamente:
--
--   REFRESH MATERIALIZED VIEW CONCURRENTLY consumption.mv_ranking_dispositivos;
--
-- Mismo comando que en la Opción A; solo cambia el disparador.
-- ============================================================