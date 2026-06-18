-- ============================================================
-- VISTAS — Esquemas consumption y notifications
-- Archivo: 01_ddl/07_views/004_vw_consumption_views.sql
-- Descripción: Vistas para simplificar consultas frecuentes
--              de consumo en tiempo real, métricas agregadas
--              por hogar, recomendaciones activas y
--              notificaciones/alertas asociadas al consumo
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/003_create_homes_tables.sql,
--               03_tables/004_create_devices_tables.sql,
--               03_tables/005_create_consumption_tables.sql,
--               03_tables/006_create_notifications_tables.sql
-- ============================================================

-- ============================================================
-- VISTA: consumption.vw_consumo_tiempo_real
-- Descripción: Muestra la última lectura de consumo de cada
--              dispositivo activo, con información del hogar
--              y zona. Útil para el dashboard de monitoreo
--              en tiempo real (RF4.2)
-- Referencia SRS: RF4.2, RNF1.5
-- ============================================================
CREATE OR REPLACE VIEW consumption.vw_consumo_tiempo_real AS
SELECT DISTINCT ON (c.id_device)
  c.id_consumption,
  c.id_device,
  d.nombre        AS nombre_dispositivo,
  c.id_home,
  h.nombre        AS nombre_hogar,
  d.id_area,
  a.nombre        AS nombre_zona,
  c.watts,
  c.kwh_acumulado,
  c.costo_estimado,
  c.fecha_lectura
FROM consumption.consumption c
JOIN devices.device          d ON d.id_device   = c.id_device
                                AND d.deleted_at IS NULL
JOIN homes.home               h ON h.id_home     = c.id_home
                                AND h.deleted_at  IS NULL
LEFT JOIN homes.area          a ON a.id_area      = d.id_area
                                AND a.deleted_at   IS NULL
ORDER BY c.id_device, c.fecha_lectura DESC;

COMMENT ON VIEW consumption.vw_consumo_tiempo_real
  IS 'Última lectura de consumo por dispositivo activo, con hogar y zona. Usada en el dashboard de monitoreo en tiempo real.';

-- ============================================================
-- VISTA: consumption.vw_consumo_total_hogar
-- Descripción: Calcula el consumo total instantáneo (watts)
--              y acumulado del día por hogar, sumando todos
--              sus dispositivos activos. Base para el
--              dashboard general del hogar (RF4.2)
-- Referencia SRS: RF4.2
-- ============================================================
CREATE OR REPLACE VIEW consumption.vw_consumo_total_hogar AS
SELECT
  h.id_home,
  h.nombre                          AS nombre_hogar,
  COUNT(DISTINCT d.id_device)       AS total_dispositivos,
  COALESCE(SUM(uc.watts), 0)        AS watts_totales,
  COALESCE(SUM(uc.kwh_acumulado), 0) AS kwh_acumulado_total,
  COALESCE(SUM(uc.costo_estimado), 0) AS costo_estimado_total
FROM homes.home h
LEFT JOIN devices.device          d  ON d.id_home    = h.id_home
                                      AND d.deleted_at IS NULL
LEFT JOIN consumption.vw_consumo_tiempo_real uc
                                      ON uc.id_device = d.id_device
WHERE h.deleted_at IS NULL
  AND h.estado     = 'activo'
GROUP BY h.id_home, h.nombre;

COMMENT ON VIEW consumption.vw_consumo_total_hogar
  IS 'Consumo total instantáneo y acumulado por hogar, agregando todos sus dispositivos activos.';

-- ============================================================
-- VISTA: consumption.vw_metricas_por_hogar
-- Descripción: Muestra las métricas agregadas de consumo
--              (kWh, costo, promedio, máximo, mínimo) con
--              información de hogar y dispositivo. Base
--              para los gráficos de consumo (RF4.3)
-- Referencia SRS: RF4.3
-- ============================================================
CREATE OR REPLACE VIEW consumption.vw_metricas_por_hogar AS
SELECT
  cm.id_consumption_metric,
  cm.id_home,
  h.nombre        AS nombre_hogar,
  cm.id_device,
  d.nombre        AS nombre_dispositivo,
  cm.periodo,
  cm.fecha_inicio,
  cm.fecha_fin,
  cm.kwh_total,
  cm.costo_total,
  cm.watts_promedio,
  cm.watts_maximo,
  cm.watts_minimo
FROM consumption.consumption_metric cm
JOIN homes.home                     h ON h.id_home    = cm.id_home
                                      AND h.deleted_at IS NULL
JOIN devices.device                 d ON d.id_device  = cm.id_device
                                      AND d.deleted_at IS NULL;

COMMENT ON VIEW consumption.vw_metricas_por_hogar
  IS 'Métricas agregadas de consumo por periodo, hogar y dispositivo. Base para gráficos comparativos de consumo.';

-- ============================================================
-- VISTA: consumption.vw_recomendaciones_pendientes
-- Descripción: Muestra las recomendaciones de ahorro
--              pendientes de implementar, ordenadas por
--              prioridad, con información del hogar y
--              dispositivo relacionado (RF4.4)
-- Referencia SRS: RF4.4
-- ============================================================
CREATE OR REPLACE VIEW consumption.vw_recomendaciones_pendientes AS
SELECT
  r.id_recommendation,
  r.id_home,
  h.nombre        AS nombre_hogar,
  r.id_device,
  d.nombre        AS nombre_dispositivo,
  r.titulo,
  r.descripcion,
  r.ahorro_estimado_kwh,
  r.ahorro_estimado_costo,
  r.prioridad,
  r.created_at
FROM consumption.recommendation r
JOIN homes.home                  h ON h.id_home    = r.id_home
                                    AND h.deleted_at IS NULL
LEFT JOIN devices.device         d ON d.id_device  = r.id_device
                                    AND d.deleted_at IS NULL
WHERE r.estado     = 'pendiente'
  AND r.deleted_at IS NULL
ORDER BY
  CASE r.prioridad
    WHEN 'alta'  THEN 1
    WHEN 'media' THEN 2
    WHEN 'baja'  THEN 3
  END,
  r.ahorro_estimado_costo DESC NULLS LAST;

COMMENT ON VIEW consumption.vw_recomendaciones_pendientes
  IS 'Recomendaciones de ahorro pendientes de implementar, ordenadas por prioridad y ahorro estimado.';

-- ============================================================
-- VISTA: notifications.vw_notificaciones_no_leidas
-- Descripción: Muestra las notificaciones no leídas por
--              usuario, ordenadas cronológicamente. Base
--              para el badge del centro de notificaciones
--              (RF4.5)
-- Referencia SRS: RF4.5
-- ============================================================
CREATE OR REPLACE VIEW notifications.vw_notificaciones_no_leidas AS
SELECT
  n.id_notification,
  n.id_user,
  n.id_home,
  n.id_device,
  n.tipo,
  n.titulo,
  n.mensaje,
  n.prioridad,
  n.canal,
  n.created_at
FROM notifications.notification n
WHERE n.leida      = FALSE
  AND n.deleted_at IS NULL
ORDER BY n.created_at DESC;

COMMENT ON VIEW notifications.vw_notificaciones_no_leidas
  IS 'Notificaciones no leídas por usuario, ordenadas de la más reciente a la más antigua.';

-- ============================================================
-- VISTA: notifications.vw_alertas_recientes
-- Descripción: Muestra las alertas de umbral generadas en
--              las últimas 24 horas, con información del
--              dispositivo y hogar afectado (RF3.5, RF4.5)
-- Referencia SRS: RF3.5, RF4.5
-- ============================================================
CREATE OR REPLACE VIEW notifications.vw_alertas_recientes AS
SELECT
  al.id_alert,
  al.id_device,
  d.nombre        AS nombre_dispositivo,
  al.id_home,
  h.nombre        AS nombre_hogar,
  al.consumo_detectado_kwh,
  al.limite_kwh,
  al.accion_ejecutada,
  al.created_at
FROM notifications.alert al
JOIN devices.device       d ON d.id_device = al.id_device
                             AND d.deleted_at IS NULL
JOIN homes.home            h ON h.id_home   = al.id_home
                             AND h.deleted_at IS NULL
WHERE al.created_at > NOW() - INTERVAL '24 hours'
ORDER BY al.created_at DESC;

COMMENT ON VIEW notifications.vw_alertas_recientes
  IS 'Alertas de umbral generadas en las últimas 24 horas, con información del dispositivo y hogar afectado.';