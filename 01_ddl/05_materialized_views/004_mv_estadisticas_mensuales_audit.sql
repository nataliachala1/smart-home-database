-- ============================================================
-- VISTA MATERIALIZADA — Estadísticas Mensuales de Auditoría
-- Archivo: 01_ddl/05_materialized_views/004_mv_estadisticas_mensuales_audit.sql
-- Descripción: Vista materializada con estadísticas mensuales
--              de auditoría agregadas por módulo y acción,
--              usada en reportes administrativos de
--              trazabilidad (RNF8.2, RNF8.4)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/008_create_audit_tables.sql
--
-- NOTA IMPORTANTE: esta vista es para reportes históricos
-- mensuales, no para consulta de logs en vivo. Para logs
-- recientes usar audit.vw_logs_recientes (vista normal).
-- ============================================================

-- ============================================================
-- VISTA MATERIALIZADA: audit.mv_estadisticas_mensuales
-- Referencia SRS: RNF8.2, RNF8.4
-- Frecuencia de refresco recomendada: 1 vez al día
-- ============================================================
CREATE MATERIALIZED VIEW IF NOT EXISTS audit.mv_estadisticas_mensuales AS
SELECT
  DATE_TRUNC('month', al.created_at)::DATE AS mes,
  al.modulo,
  al.accion,
  al.resultado,
  COUNT(*)                                  AS total_registros,
  COUNT(DISTINCT al.id_user)                AS usuarios_distintos
FROM audit.audit_log al
GROUP BY DATE_TRUNC('month', al.created_at), al.modulo, al.accion, al.resultado;

-- Índice único requerido para permitir REFRESH CONCURRENTLY
CREATE UNIQUE INDEX IF NOT EXISTS uq_mv_estadisticas_mensuales
  ON audit.mv_estadisticas_mensuales (mes, modulo, accion, resultado);

COMMENT ON MATERIALIZED VIEW audit.mv_estadisticas_mensuales
  IS 'Estadísticas mensuales de auditoría agregadas por módulo, acción y resultado. Refrescar diariamente. No usar para consulta de logs en vivo.';

-- ============================================================
-- COMANDO DE REFRESCO
-- ============================================================

-- REFRESH MATERIALIZED VIEW CONCURRENTLY audit.mv_estadisticas_mensuales;

-- ============================================================
-- OPCIÓN A — Programación con pg_cron (recomendada)
-- Requiere la extensión pg_cron instalada en el contenedor.
-- Descomentar si pg_cron está disponible.
-- ============================================================

-- CREATE EXTENSION IF NOT EXISTS pg_cron;
--
-- SELECT cron.schedule(
--   'refresh_mv_estadisticas_mensuales',
--   '0 2 * * *',  -- todos los días a las 2:00 AM
--   $$REFRESH MATERIALIZED VIEW CONCURRENTLY audit.mv_estadisticas_mensuales$$
-- );

-- ============================================================
-- OPCIÓN B — Programación desde el backend (alternativa)
-- Si pg_cron no está disponible, programar un job
-- (node-cron, Celery, APScheduler) que ejecute diariamente:
--
--   REFRESH MATERIALIZED VIEW CONCURRENTLY audit.mv_estadisticas_mensuales;
--
-- Mismo comando que en la Opción A; solo cambia el disparador.
-- ============================================================