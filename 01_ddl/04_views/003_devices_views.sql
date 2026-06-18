-- ============================================================
-- VISTAS — Esquema devices
-- Archivo: 01_ddl/07_views/003_vw_devices_views.sql
-- Descripción: Vistas para simplificar consultas frecuentes
--              del esquema devices: dispositivos activos,
--              horarios vigentes y reglas de umbral
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/003_create_devices_tables.sql,
--               03_tables/002_create_homes_tables.sql
-- ============================================================

-- ============================================================
-- VISTA: devices.vw_dispositivos_activos
-- Descripción: Muestra todos los dispositivos activos con
--              su hogar, zona y tipo de dispositivo asociado.
--              Excluye dispositivos desactivados (soft delete)
-- Referencia SRS: RF3.1, RF3.5
-- ============================================================
CREATE OR REPLACE VIEW devices.vw_dispositivos_activos AS
SELECT
  d.id_device,
  d.nombre,
  d.estado,
  d.encendido,
  d.consumo_actual_w,
  d.protocolo,
  d.mac_address,
  td.nombre        AS tipo_dispositivo,
  td.icono,
  h.id_home,
  h.nombre          AS nombre_hogar,
  a.id_area,
  a.nombre          AS nombre_zona,
  d.created_at,
  d.updated_at
FROM devices.device      d
JOIN devices.type_device td ON td.id_type_device = d.id_type_device
                            AND td.deleted_at     IS NULL
JOIN homes.home          h  ON h.id_home          = d.id_home
                            AND h.deleted_at       IS NULL
LEFT JOIN homes.area     a  ON a.id_area           = d.id_area
                            AND a.deleted_at       IS NULL
WHERE d.deleted_at IS NULL;

COMMENT ON VIEW devices.vw_dispositivos_activos
  IS 'Dispositivos activos con su hogar, zona y tipo asociado. Excluye dispositivos desactivados.';

-- ============================================================
-- VISTA: devices.vw_dispositivos_desconectados
-- Descripción: Muestra los dispositivos activos que están
--              actualmente desconectados, útil para alertar
--              al usuario sobre dispositivos fuera de línea
-- Referencia SRS: RF3.5
-- ============================================================
CREATE OR REPLACE VIEW devices.vw_dispositivos_desconectados AS
SELECT
  d.id_device,
  d.nombre,
  d.estado,
  h.id_home,
  h.nombre        AS nombre_hogar,
  a.nombre        AS nombre_zona,
  d.updated_at    AS ultima_actualizacion
FROM devices.device  d
JOIN homes.home      h ON h.id_home = d.id_home
                       AND h.deleted_at IS NULL
LEFT JOIN homes.area a ON a.id_area  = d.id_area
                       AND a.deleted_at IS NULL
WHERE d.estado     = 'desconectado'
  AND d.deleted_at IS NULL;

COMMENT ON VIEW devices.vw_dispositivos_desconectados
  IS 'Dispositivos activos actualmente desconectados, para alertar al usuario sobre dispositivos fuera de línea.';

-- ============================================================
-- VISTA: devices.vw_horarios_vigentes
-- Descripción: Muestra los horarios automáticos activos
--              de cada dispositivo, con información del
--              dispositivo y hogar al que pertenecen
-- Referencia SRS: RF3.2
-- ============================================================
CREATE OR REPLACE VIEW devices.vw_horarios_vigentes AS
SELECT
  s.id_schedule,
  s.id_device,
  d.nombre        AS nombre_dispositivo,
  h.id_home,
  h.nombre        AS nombre_hogar,
  s.accion,
  s.hora,
  s.dias_semana,
  s.created_at,
  s.updated_at
FROM devices.schedule s
JOIN devices.device   d ON d.id_device = s.id_device
                        AND d.deleted_at IS NULL
JOIN homes.home       h ON h.id_home   = d.id_home
                        AND h.deleted_at IS NULL
WHERE s.activo     = TRUE
  AND s.deleted_at IS NULL;

COMMENT ON VIEW devices.vw_horarios_vigentes
  IS 'Horarios automáticos activos de cada dispositivo con su hogar correspondiente.';

-- ============================================================
-- VISTA: devices.vw_umbrales_activos
-- Descripción: Muestra las reglas de umbral de consumo
--              activas por dispositivo, con el límite
--              configurado y la acción a ejecutar
-- Referencia SRS: RF3.2
-- ============================================================
CREATE OR REPLACE VIEW devices.vw_umbrales_activos AS
SELECT
  tr.id_threshold_rule,
  tr.id_device,
  d.nombre        AS nombre_dispositivo,
  h.id_home,
  h.nombre        AS nombre_hogar,
  tr.tipo,
  tr.limite_kwh,
  tr.accion,
  tr.created_at,
  tr.updated_at
FROM devices.threshold_rule tr
JOIN devices.device         d ON d.id_device = tr.id_device
                              AND d.deleted_at IS NULL
JOIN homes.home              h ON h.id_home   = d.id_home
                              AND h.deleted_at IS NULL
WHERE tr.activa     = TRUE
  AND tr.deleted_at IS NULL;

COMMENT ON VIEW devices.vw_umbrales_activos
  IS 'Reglas de umbral de consumo activas por dispositivo, con el límite y la acción configurada.';

-- ============================================================
-- VISTA: devices.vw_historial_estados_reciente
-- Descripción: Muestra los últimos cambios de estado de cada
--              dispositivo, incluyendo el origen del cambio
--              (usuario, automático, voz, sistema)
-- Referencia SRS: RF3.5
-- ============================================================
CREATE OR REPLACE VIEW devices.vw_historial_estados_reciente AS
SELECT
  dsh.id_device_status_history,
  dsh.id_device,
  d.nombre        AS nombre_dispositivo,
  dsh.estado_anterior,
  dsh.estado_nuevo,
  dsh.encendido,
  dsh.origen,
  dsh.id_user,
  dsh.created_at
FROM devices.device_status_history dsh
JOIN devices.device                d ON d.id_device = dsh.id_device
                                     AND d.deleted_at IS NULL
WHERE dsh.created_at > NOW() - INTERVAL '30 days'
ORDER BY dsh.created_at DESC;

COMMENT ON VIEW devices.vw_historial_estados_reciente
  IS 'Historial de cambios de estado de dispositivos en los últimos 30 días.';