-- ============================================================
-- VISTAS — Esquema homes
-- Archivo: 01_ddl/07_views/002_vw_homes_views.sql
-- Descripción: Vistas para simplificar consultas frecuentes
--              del esquema homes: hogares activos, zonas,
--              tarifas vigentes y miembros del hogar
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/003_create_homes_tables.sql
-- ============================================================

-- ============================================================
-- VISTA: homes.vw_hogares_activos
-- Descripción: Muestra todos los hogares activos del sistema
--              con información del propietario y conteo
--              de zonas y dispositivos asociados
-- Referencia SRS: RF2.1, RF2.2
-- ============================================================
CREATE OR REPLACE VIEW homes.vw_hogares_activos AS
SELECT
  h.id_home,
  h.id_user,
  u.nombre              AS propietario_nombre,
  u.apellido            AS propietario_apellido,
  u.email               AS propietario_email,
  h.nombre              AS nombre_hogar,
  h.estrato,
  h.estado,
  h.created_at,
  h.updated_at,
  COUNT(DISTINCT a.id_area)     AS total_zonas,
  COUNT(DISTINCT d.id_device)   AS total_dispositivos
FROM homes.home         h
JOIN auth.user          u  ON u.id_user    = h.id_user
                           AND u.deleted_at IS NULL
LEFT JOIN homes.area    a  ON a.id_home    = h.id_home
                           AND a.deleted_at IS NULL
LEFT JOIN devices.device d ON d.id_home    = h.id_home
                           AND d.deleted_at IS NULL
WHERE h.deleted_at IS NULL
  AND h.estado     = 'activo'
GROUP BY
  h.id_home,
  h.id_user,
  u.nombre,
  u.apellido,
  u.email,
  h.nombre,
  h.estrato,
  h.estado,
  h.created_at,
  h.updated_at;

COMMENT ON VIEW homes.vw_hogares_activos
  IS 'Hogares activos con información del propietario y conteo de zonas y dispositivos asociados.';

-- ============================================================
-- VISTA: homes.vw_zonas_con_dispositivos
-- Descripción: Muestra todas las zonas activas con el
--              conteo de dispositivos vinculados y
--              el consumo actual total de la zona
-- Referencia SRS: ERF2.1.1, RF2.3
-- ============================================================
CREATE OR REPLACE VIEW homes.vw_zonas_con_dispositivos AS
SELECT
  a.id_area,
  a.id_home,
  h.nombre                        AS nombre_hogar,
  a.nombre                        AS nombre_zona,
  a.tipo,
  COUNT(d.id_device)              AS total_dispositivos,
  COUNT(
    CASE WHEN d.encendido = TRUE
    THEN 1 END
  )                               AS dispositivos_encendidos,
  COALESCE(
    SUM(d.consumo_actual_w), 0
  )                               AS consumo_actual_zona_w
FROM homes.area          a
JOIN homes.home          h  ON h.id_home    = a.id_home
                            AND h.deleted_at IS NULL
LEFT JOIN devices.device d  ON d.id_area    = a.id_area
                            AND d.deleted_at IS NULL
                            AND d.estado     = 'conectado'
WHERE a.deleted_at IS NULL
GROUP BY
  a.id_area,
  a.id_home,
  h.nombre,
  a.nombre,
  a.tipo;

COMMENT ON VIEW homes.vw_zonas_con_dispositivos
  IS 'Zonas activas con conteo de dispositivos vinculados y consumo actual total de la zona en Watts.';

-- ============================================================
-- VISTA: homes.vw_tarifas_vigentes
-- Descripción: Muestra únicamente la tarifa eléctrica
--              actualmente vigente por cada hogar.
--              Usada para calcular costos en tiempo real
-- Referencia SRS: RF2.5
-- ============================================================
CREATE OR REPLACE VIEW homes.vw_tarifas_vigentes AS
SELECT
  t.id_tariff,
  t.id_home,
  h.nombre          AS nombre_hogar,
  h.id_user,
  t.costo_kwh,
  t.moneda,
  t.vigente_desde
FROM homes.tariff   t
JOIN homes.home     h  ON h.id_home    = t.id_home
                       AND h.deleted_at IS NULL
WHERE t.deleted_at    IS NULL
  AND t.vigente_desde <= CURRENT_DATE
  AND (
    t.vigente_hasta IS NULL OR
    t.vigente_hasta >= CURRENT_DATE
  );

COMMENT ON VIEW homes.vw_tarifas_vigentes
  IS 'Tarifa eléctrica actualmente vigente por hogar. Usada para calcular costos de consumo en tiempo real.';

-- ============================================================
-- VISTA: homes.vw_miembros_hogar
-- Descripción: Muestra todos los miembros activos de cada
--              hogar con su información personal y rol
--              dentro del hogar
-- Referencia SRS: RF2.3
-- ============================================================
CREATE OR REPLACE VIEW homes.vw_miembros_hogar AS
SELECT
  hm.id_home_member,
  hm.id_home,
  h.nombre          AS nombre_hogar,
  h.id_user         AS id_propietario,
  hm.id_user,
  u.nombre          AS miembro_nombre,
  u.apellido        AS miembro_apellido,
  u.email           AS miembro_email,
  hm.rol_en_hogar,
  hm.created_at     AS fecha_vinculacion
FROM homes.home_member  hm
JOIN homes.home         h  ON h.id_home    = hm.id_home
                           AND h.deleted_at IS NULL
JOIN auth.user          u  ON u.id_user    = hm.id_user
                           AND u.deleted_at IS NULL
WHERE hm.deleted_at IS NULL;

COMMENT ON VIEW homes.vw_miembros_hogar
  IS 'Miembros activos de cada hogar con su información personal y rol asignado dentro del hogar.';

-- ============================================================
-- VISTA: homes.vw_resumen_hogar
-- Descripción: Vista resumen completa por hogar con
--              información del propietario, tarifa vigente,
--              conteo de zonas, dispositivos y consumo
--              actual total del hogar
-- Referencia SRS: RF2.1, RF2.5, RF4.2
-- ============================================================
CREATE OR REPLACE VIEW homes.vw_resumen_hogar AS
SELECT
  h.id_home,
  h.nombre                          AS nombre_hogar,
  h.estrato,
  h.estado,
  u.id_user                         AS id_propietario,
  u.nombre                          AS propietario_nombre,
  u.email                           AS propietario_email,
  t.costo_kwh                       AS tarifa_vigente,
  t.moneda,
  COUNT(DISTINCT a.id_area)         AS total_zonas,
  COUNT(DISTINCT d.id_device)       AS total_dispositivos,
  COUNT(
    DISTINCT CASE
      WHEN d.estado = 'conectado'
      THEN d.id_device
    END
  )                                 AS dispositivos_conectados,
  COUNT(
    DISTINCT CASE
      WHEN d.encendido = TRUE
      THEN d.id_device
    END
  )                                 AS dispositivos_encendidos,
  COALESCE(
    SUM(d.consumo_actual_w), 0
  )                                 AS consumo_actual_total_w
FROM homes.home           h
JOIN auth.user            u  ON u.id_user      = h.id_user
                             AND u.deleted_at   IS NULL
LEFT JOIN homes.tariff    t  ON t.id_home       = h.id_home
                             AND t.deleted_at    IS NULL
                             AND t.vigente_desde <= CURRENT_DATE
                             AND (
                               t.vigente_hasta IS NULL OR
                               t.vigente_hasta >= CURRENT_DATE
                             )
LEFT JOIN homes.area      a  ON a.id_home       = h.id_home
                             AND a.deleted_at    IS NULL
LEFT JOIN devices.device  d  ON d.id_home       = h.id_home
                             AND d.deleted_at    IS NULL
WHERE h.deleted_at IS NULL
  AND h.estado     = 'activo'
GROUP BY
  h.id_home,
  h.nombre,
  h.estrato,
  h.estado,
  u.id_user,
  u.nombre,
  u.email,
  t.costo_kwh,
  t.moneda;

COMMENT ON VIEW homes.vw_resumen_hogar
  IS 'Resumen completo por hogar con tarifa vigente, conteo de zonas, dispositivos y consumo actual total en Watts.';