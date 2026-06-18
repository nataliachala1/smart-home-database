-- ============================================================
-- VISTAS — Esquema audit
-- Archivo: 01_ddl/07_views/005_vw_audit_views.sql
-- Descripción: Vistas para simplificar consultas frecuentes
--              del esquema audit: logs recientes, resumen
--              por módulo y detección de eventos críticos
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/001_create_auth_tables.sql,
--               03_tables/008_create_audit_tables.sql
-- ============================================================

-- ============================================================
-- VISTA: audit.vw_logs_recientes
-- Descripción: Muestra los registros de auditoría de los
--              últimos 30 días con información del usuario
--              que ejecutó la acción. Base para la pantalla
--              de consulta de logs del administrador (RF7.1)
-- Referencia SRS: RF7.1
-- ============================================================
CREATE OR REPLACE VIEW audit.vw_logs_recientes AS
SELECT
  al.id_audit_log,
  al.id_user,
  u.nombre        AS nombre_usuario,
  u.apellido      AS apellido_usuario,
  u.email         AS email_usuario,
  al.accion,
  al.modulo,
  al.entidad,
  al.id_entidad,
  al.ip_address,
  al.resultado,
  al.detalle,
  al.created_at
FROM audit.audit_log al
LEFT JOIN auth.user  u ON u.id_user = al.id_user
WHERE al.created_at > NOW() - INTERVAL '30 days'
ORDER BY al.created_at DESC;

COMMENT ON VIEW audit.vw_logs_recientes
  IS 'Registros de auditoría de los últimos 30 días con información del usuario. Base para la consulta de logs del administrador.';

-- ============================================================
-- VISTA: audit.vw_resumen_por_modulo
-- Descripción: Agrega el total de acciones registradas por
--              módulo y resultado en los últimos 30 días.
--              Útil para el panel estadístico de auditoría
--              (RF7.1)
-- Referencia SRS: RF7.1
-- ============================================================
CREATE OR REPLACE VIEW audit.vw_resumen_por_modulo AS
SELECT
  al.modulo,
  al.accion,
  al.resultado,
  COUNT(*)                       AS total_registros,
  MAX(al.created_at)             AS ultima_ocurrencia
FROM audit.audit_log al
WHERE al.created_at > NOW() - INTERVAL '30 days'
GROUP BY al.modulo, al.accion, al.resultado
ORDER BY al.modulo, total_registros DESC;

COMMENT ON VIEW audit.vw_resumen_por_modulo
  IS 'Resumen estadístico de acciones de auditoría agrupadas por módulo, acción y resultado en los últimos 30 días.';

-- ============================================================
-- VISTA: audit.vw_eventos_fallidos
-- Descripción: Muestra únicamente los registros de auditoría
--              con resultado fallido, útil para detectar
--              errores recurrentes o intentos de acceso
--              no autorizados (RNF5.1, RNF8.4)
-- Referencia SRS: RNF5.1, RNF8.4
-- ============================================================
CREATE OR REPLACE VIEW audit.vw_eventos_fallidos AS
SELECT
  al.id_audit_log,
  al.id_user,
  u.nombre        AS nombre_usuario,
  u.email         AS email_usuario,
  al.accion,
  al.modulo,
  al.entidad,
  al.ip_address,
  al.detalle,
  al.created_at
FROM audit.audit_log al
LEFT JOIN auth.user  u ON u.id_user = al.id_user
WHERE al.resultado = 'fallido'
ORDER BY al.created_at DESC;

COMMENT ON VIEW audit.vw_eventos_fallidos
  IS 'Registros de auditoría con resultado fallido, usados para detectar errores recurrentes o accesos no autorizados.';

-- ============================================================
-- VISTA: audit.vw_actividad_por_usuario
-- Descripción: Agrega el total de acciones realizadas por
--              cada usuario en los últimos 30 días,
--              diferenciando entre exitosas y fallidas.
--              Útil para detectar comportamientos anómalos
-- Referencia SRS: RF7.1, RNF8.4
-- ============================================================
CREATE OR REPLACE VIEW audit.vw_actividad_por_usuario AS
SELECT
  al.id_user,
  u.nombre        AS nombre_usuario,
  u.apellido      AS apellido_usuario,
  u.email         AS email_usuario,
  COUNT(*)                                                   AS total_acciones,
  COUNT(*) FILTER (WHERE al.resultado = 'exitoso')            AS acciones_exitosas,
  COUNT(*) FILTER (WHERE al.resultado = 'fallido')            AS acciones_fallidas,
  MAX(al.created_at)                                          AS ultima_actividad
FROM audit.audit_log al
JOIN auth.user        u ON u.id_user = al.id_user
                        AND u.deleted_at IS NULL
WHERE al.created_at > NOW() - INTERVAL '30 days'
GROUP BY al.id_user, u.nombre, u.apellido, u.email
ORDER BY total_acciones DESC;

COMMENT ON VIEW audit.vw_actividad_por_usuario
  IS 'Resumen de actividad por usuario en los últimos 30 días, diferenciando acciones exitosas y fallidas.';

-- ============================================================
-- VISTA: audit.vw_logs_inicio_cierre_sesion
-- Descripción: Filtra específicamente los eventos de login
--              y logout, útil para reportes de seguridad
--              y trazabilidad de accesos al sistema (RNF5.2)
-- Referencia SRS: RNF5.2
-- ============================================================
CREATE OR REPLACE VIEW audit.vw_logs_inicio_cierre_sesion AS
SELECT
  al.id_audit_log,
  al.id_user,
  u.nombre        AS nombre_usuario,
  u.email         AS email_usuario,
  al.accion,
  al.ip_address,
  al.user_agent,
  al.resultado,
  al.created_at
FROM audit.audit_log al
LEFT JOIN auth.user  u ON u.id_user = al.id_user
WHERE al.accion IN ('login', 'logout')
ORDER BY al.created_at DESC;

COMMENT ON VIEW audit.vw_logs_inicio_cierre_sesion
  IS 'Eventos de inicio y cierre de sesión para reportes de seguridad y trazabilidad de accesos.';