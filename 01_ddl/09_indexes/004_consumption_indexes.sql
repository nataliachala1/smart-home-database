-- ============================================================
-- ÍNDICES — Esquema consumption
-- Archivo: 01_ddl/09_indexes/004_consumption_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema consumption. Prioriza el
--              rendimiento de consultas en tiempo real y
--              generación de reportes históricos.
-- ============================================================
-- TABLA: consumption.consumption
-- Nota: Esta tabla crece muy rápidamente (lecturas cada 1-5
-- segundos por dispositivo). Los índices están diseñados para
-- optimizar las consultas de dashboard y reportes sin degradar
-- el rendimiento de las inserciones masivas (RNF1.5).
-- ============================================================

-- Búsqueda de lecturas por dispositivo
CREATE INDEX IF NOT EXISTS idx_consumption_id_device
  ON consumption.consumption (id_device);

-- Búsqueda de lecturas por hogar
CREATE INDEX IF NOT EXISTS idx_consumption_id_home
  ON consumption.consumption (id_home);

-- Filtrado por fecha (columna clave para reportes históricos)
CREATE INDEX IF NOT EXISTS idx_consumption_fecha_lectura
  ON consumption.consumption (fecha_lectura DESC);

-- Compuesto: dispositivo + fecha (consumo de un dispositivo en un periodo)
CREATE INDEX IF NOT EXISTS idx_consumption_device_fecha
  ON consumption.consumption (id_device, fecha_lectura DESC);

-- Compuesto: hogar + fecha (consumo total del hogar en un periodo)
CREATE INDEX IF NOT EXISTS idx_consumption_home_fecha
  ON consumption.consumption (id_home, fecha_lectura DESC);

-- ============================================================
-- TABLA: consumption.consumption_metric
-- Nota: Tabla de métricas agregadas usada por los gráficos
-- y reportes (RF4.2, RF4.3). Los índices optimizan las
-- consultas por periodo y rango de fechas.
-- ============================================================

-- Búsqueda de métricas por dispositivo
CREATE INDEX IF NOT EXISTS idx_consumption_metric_id_device
  ON consumption.consumption_metric (id_device);

-- Búsqueda de métricas por hogar
CREATE INDEX IF NOT EXISTS idx_consumption_metric_id_home
  ON consumption.consumption_metric (id_home);

-- Filtrado por tipo de periodo (hora, dia, semana, mes)
CREATE INDEX IF NOT EXISTS idx_consumption_metric_periodo
  ON consumption.consumption_metric (periodo);

-- Filtrado por fecha de inicio del periodo
CREATE INDEX IF NOT EXISTS idx_consumption_metric_fecha_inicio
  ON consumption.consumption_metric (fecha_inicio DESC);

-- Compuesto: dispositivo + periodo + fecha (métrica específica de un dispositivo)
CREATE INDEX IF NOT EXISTS idx_consumption_metric_device_periodo_fecha
  ON consumption.consumption_metric (id_device, periodo, fecha_inicio DESC);

-- Compuesto: hogar + periodo + fecha (métricas del hogar por tipo de periodo)
CREATE INDEX IF NOT EXISTS idx_consumption_metric_home_periodo_fecha
  ON consumption.consumption_metric (id_home, periodo, fecha_inicio DESC);

-- ============================================================
-- TABLA: consumption.recommendation
-- ============================================================

-- Búsqueda de recomendaciones por hogar
CREATE INDEX IF NOT EXISTS idx_recommendation_id_home
  ON consumption.recommendation (id_home)
  WHERE deleted_at IS NULL;

-- Filtrado por prioridad (alta, media, baja)
CREATE INDEX IF NOT EXISTS idx_recommendation_prioridad
  ON consumption.recommendation (prioridad)
  WHERE deleted_at IS NULL;

-- Filtrado por estado (pendiente, implementada, descartada)
CREATE INDEX IF NOT EXISTS idx_recommendation_estado
  ON consumption.recommendation (estado)
  WHERE deleted_at IS NULL;

-- Compuesto: hogar + estado (recomendaciones pendientes de un hogar)
CREATE INDEX IF NOT EXISTS idx_recommendation_home_estado
  ON consumption.recommendation (id_home, estado)
  WHERE deleted_at IS NULL;

-- Compuesto: hogar + prioridad (recomendaciones ordenadas por impacto)
CREATE INDEX IF NOT EXISTS idx_recommendation_home_prioridad
  ON consumption.recommendation (id_home, prioridad)
  WHERE deleted_at IS NULL;