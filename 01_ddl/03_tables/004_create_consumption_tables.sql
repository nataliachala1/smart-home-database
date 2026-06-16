-- ============================================================
-- TABLAS — Esquema consumption
-- Archivo: 01_ddl/03_tables/005_create_consumption_tables.sql
-- Descripción: Creación de las 3 tablas del esquema consumption
--              para gestión de lecturas de consumo energético
--              en tiempo real, métricas agregadas y
--              recomendaciones de ahorro
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, auth.user,
--               homes.home, devices.device
-- ============================================================

-- ============================================================
-- TABLA: consumption.consumption
-- Descripción: Almacena las lecturas de consumo eléctrico
--              en tiempo real de cada dispositivo.
--              Esta tabla puede crecer muy rápidamente,
--              se recomienda particionar por mes
-- Referencia SRS: RF4.1, RF4.2, RNF1.5
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption.consumption (
  id_consumption   UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_device        UUID          NOT NULL,
  id_home          UUID          NOT NULL,
  watts            NUMERIC(10,4) NOT NULL,
  kwh_acumulado    NUMERIC(12,6) NOT NULL DEFAULT 0,
  costo_estimado   NUMERIC(12,4) NULL,
  fecha_lectura    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_consumption          PRIMARY KEY (id_consumption),
  CONSTRAINT fk_consumption_device   FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT fk_consumption_home     FOREIGN KEY (id_home)   REFERENCES homes.home (id_home),
  CONSTRAINT ck_consumption_watts    CHECK (watts >= 0),
  CONSTRAINT ck_consumption_kwh      CHECK (kwh_acumulado >= 0),
  CONSTRAINT ck_consumption_costo    CHECK (costo_estimado IS NULL OR costo_estimado >= 0)
);

COMMENT ON TABLE  consumption.consumption                IS 'Lecturas de consumo eléctrico en tiempo real por dispositivo.';
COMMENT ON COLUMN consumption.consumption.id_consumption IS 'Identificador único de la lectura.';
COMMENT ON COLUMN consumption.consumption.id_device      IS 'Dispositivo que generó la lectura.';
COMMENT ON COLUMN consumption.consumption.id_home        IS 'Hogar al que pertenece el dispositivo.';
COMMENT ON COLUMN consumption.consumption.watts          IS 'Consumo instantáneo en Watts al momento de la lectura.';
COMMENT ON COLUMN consumption.consumption.kwh_acumulado  IS 'Consumo acumulado en kWh desde el inicio del día.';
COMMENT ON COLUMN consumption.consumption.costo_estimado IS 'Costo estimado según la tarifa eléctrica vigente del hogar.';
COMMENT ON COLUMN consumption.consumption.fecha_lectura  IS 'Fecha y hora exacta de la lectura de consumo.';

-- ============================================================
-- TABLA: consumption.consumption_metric
-- Descripción: Métricas agregadas de consumo por periodo
--              para optimizar gráficos y reportes sin
--              consultar lecturas individuales
-- Referencia SRS: RF4.2, RF4.3, RF4.1
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption.consumption_metric (
  id_consumption_metric UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_device             UUID          NOT NULL,
  id_home               UUID          NOT NULL,
  periodo               VARCHAR(10)   NOT NULL,
  fecha_inicio          TIMESTAMPTZ   NOT NULL,
  fecha_fin             TIMESTAMPTZ   NOT NULL,
  kwh_total             NUMERIC(12,6) NOT NULL DEFAULT 0,
  costo_total           NUMERIC(12,4) NULL,
  watts_promedio        NUMERIC(10,4) NULL,
  watts_maximo          NUMERIC(10,4) NULL,
  watts_minimo          NUMERIC(10,4) NULL,
  created_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_consumption_metric          PRIMARY KEY (id_consumption_metric),
  CONSTRAINT uq_consumption_metric          UNIQUE (id_device, periodo, fecha_inicio),
  CONSTRAINT fk_consumption_metric_device   FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT fk_consumption_metric_home     FOREIGN KEY (id_home)   REFERENCES homes.home (id_home),
  CONSTRAINT ck_consumption_metric_periodo  CHECK (periodo IN ('hora', 'dia', 'semana', 'mes')),
  CONSTRAINT ck_consumption_metric_fechas   CHECK (fecha_fin > fecha_inicio),
  CONSTRAINT ck_consumption_metric_kwh      CHECK (kwh_total >= 0),
  CONSTRAINT ck_consumption_metric_costo    CHECK (costo_total IS NULL OR costo_total >= 0),
  CONSTRAINT ck_consumption_metric_watts    CHECK (
    (watts_promedio IS NULL OR watts_promedio >= 0) AND
    (watts_maximo   IS NULL OR watts_maximo   >= 0) AND
    (watts_minimo   IS NULL OR watts_minimo   >= 0)
  ),
  CONSTRAINT ck_consumption_metric_max_min  CHECK (
    watts_maximo IS NULL OR
    watts_minimo IS NULL OR
    watts_maximo >= watts_minimo
  )
);

COMMENT ON TABLE  consumption.consumption_metric                    IS 'Métricas agregadas de consumo por periodo para reportes y gráficos.';
COMMENT ON COLUMN consumption.consumption_metric.id_consumption_metric IS 'Identificador único de la métrica.';
COMMENT ON COLUMN consumption.consumption_metric.id_device             IS 'Dispositivo al que pertenece la métrica.';
COMMENT ON COLUMN consumption.consumption_metric.id_home               IS 'Hogar al que pertenece la métrica.';
COMMENT ON COLUMN consumption.consumption_metric.periodo               IS 'Periodo de agregación: hora, dia, semana, mes.';
COMMENT ON COLUMN consumption.consumption_metric.fecha_inicio          IS 'Fecha y hora de inicio del periodo.';
COMMENT ON COLUMN consumption.consumption_metric.fecha_fin             IS 'Fecha y hora de fin del periodo.';
COMMENT ON COLUMN consumption.consumption_metric.kwh_total             IS 'Total de kWh consumidos en el periodo.';
COMMENT ON COLUMN consumption.consumption_metric.costo_total           IS 'Costo total del periodo según tarifa vigente.';
COMMENT ON COLUMN consumption.consumption_metric.watts_promedio        IS 'Consumo promedio en Watts durante el periodo.';
COMMENT ON COLUMN consumption.consumption_metric.watts_maximo          IS 'Consumo máximo en Watts registrado en el periodo.';
COMMENT ON COLUMN consumption.consumption_metric.watts_minimo          IS 'Consumo mínimo en Watts registrado en el periodo.';
COMMENT ON COLUMN consumption.consumption_metric.created_at            IS 'Fecha de creación de la métrica.';
COMMENT ON COLUMN consumption.consumption_metric.updated_at            IS 'Fecha de última actualización de la métrica.';

-- ============================================================
-- TABLA: consumption.recommendation
-- Descripción: Recomendaciones de ahorro energético generadas
--              automáticamente por el sistema para cada hogar
--              basadas en análisis del consumo histórico
-- Referencia SRS: RF4.4, RF4.4.1
-- ============================================================
CREATE TABLE IF NOT EXISTS consumption.recommendation (
  id_recommendation      UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_home                UUID          NOT NULL,
  id_device              UUID          NULL,
  titulo                 VARCHAR(200)  NOT NULL,
  descripcion            TEXT          NOT NULL,
  ahorro_estimado_kwh    NUMERIC(10,4) NULL,
  ahorro_estimado_costo  NUMERIC(12,4) NULL,
  prioridad              VARCHAR(10)   NOT NULL DEFAULT 'media',
  estado                 VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
  created_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at             TIMESTAMPTZ   NULL,

  CONSTRAINT pk_recommendation          PRIMARY KEY (id_recommendation),
  CONSTRAINT fk_recommendation_home     FOREIGN KEY (id_home)   REFERENCES homes.home (id_home),
  CONSTRAINT fk_recommendation_device   FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT ck_recommendation_prioridad CHECK (prioridad IN ('alta', 'media', 'baja')),
  CONSTRAINT ck_recommendation_estado   CHECK (estado IN ('pendiente', 'implementada', 'descartada')),
  CONSTRAINT ck_recommendation_ahorro_kwh  CHECK (ahorro_estimado_kwh  IS NULL OR ahorro_estimado_kwh  > 0),
  CONSTRAINT ck_recommendation_ahorro_cost CHECK (ahorro_estimado_costo IS NULL OR ahorro_estimado_costo > 0)
);

COMMENT ON TABLE  consumption.recommendation                      IS 'Recomendaciones de ahorro energético por hogar.';
COMMENT ON COLUMN consumption.recommendation.id_recommendation    IS 'Identificador único de la recomendación.';
COMMENT ON COLUMN consumption.recommendation.id_home              IS 'Hogar al que aplica la recomendación.';
COMMENT ON COLUMN consumption.recommendation.id_device            IS 'Dispositivo relacionado con la recomendación (opcional).';
COMMENT ON COLUMN consumption.recommendation.titulo               IS 'Título descriptivo de la recomendación.';
COMMENT ON COLUMN consumption.recommendation.descripcion          IS 'Descripción detallada y pasos para implementar.';
COMMENT ON COLUMN consumption.recommendation.ahorro_estimado_kwh  IS 'Ahorro potencial estimado en kWh por mes.';
COMMENT ON COLUMN consumption.recommendation.ahorro_estimado_costo IS 'Ahorro potencial estimado en costo por mes.';
COMMENT ON COLUMN consumption.recommendation.prioridad            IS 'Prioridad de la recomendación: alta, media, baja.';
COMMENT ON COLUMN consumption.recommendation.estado               IS 'Estado: pendiente, implementada, descartada.';
COMMENT ON COLUMN consumption.recommendation.created_at           IS 'Fecha de generación de la recomendación.';
COMMENT ON COLUMN consumption.recommendation.updated_at           IS 'Fecha de última actualización.';
COMMENT ON COLUMN consumption.recommendation.deleted_at           IS 'Fecha de eliminación lógica (soft delete).';