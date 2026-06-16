-- ============================================================
-- TABLAS — Esquema config
-- Archivo: 01_ddl/03_tables/002_create_config_tables.sql
-- Descripción: Creación de la tabla del esquema config
--              para gestión de preferencias de usuario,
--              internacionalización y personalización
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, auth.user
-- ============================================================

-- ============================================================
-- TABLA: config.configuration_user
-- Descripción: Almacena las preferencias de configuración
--              personal de cada usuario, incluyendo idioma,
--              tema visual y preferencias de notificaciones
-- Referencia SRS: RF6.1, RF6.2, RF4.5, RF4.6
-- ============================================================
CREATE TABLE IF NOT EXISTS config.configuration_user (
  id_configuration_user    UUID         NOT NULL DEFAULT uuid_generate_v4(),
  id_user                  UUID         NOT NULL,
  idioma                   VARCHAR(10)  NOT NULL DEFAULT 'es',
  tema                     VARCHAR(10)  NOT NULL DEFAULT 'claro',
  formato_fecha            VARCHAR(20)  NOT NULL DEFAULT 'DD/MM/YYYY',
  formato_hora             VARCHAR(5)   NOT NULL DEFAULT '24h',
  moneda                   VARCHAR(10)  NOT NULL DEFAULT 'COP',
  unidad_temperatura       VARCHAR(5)   NOT NULL DEFAULT 'C',

  -- Preferencias de notificaciones por tipo
  notif_consumo_elevado    BOOLEAN      NOT NULL DEFAULT TRUE,
  notif_dispositivos       BOOLEAN      NOT NULL DEFAULT TRUE,
  notif_recomendaciones    BOOLEAN      NOT NULL DEFAULT TRUE,
  notif_seguridad          BOOLEAN      NOT NULL DEFAULT TRUE,

  -- Canales de notificación
  notif_canal_app          BOOLEAN      NOT NULL DEFAULT TRUE,
  notif_canal_email        BOOLEAN      NOT NULL DEFAULT TRUE,
  notif_canal_push         BOOLEAN      NOT NULL DEFAULT TRUE,

  -- Modo No Molestar
  no_molestar_inicio       TIME         NULL,
  no_molestar_fin          TIME         NULL,

  -- Recomendaciones automáticas
  recomendaciones_activas       BOOLEAN      NOT NULL DEFAULT TRUE,
  frecuencia_recomendaciones    VARCHAR(10)  NOT NULL DEFAULT 'semanal',

  created_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_configuration_user
    PRIMARY KEY (id_configuration_user),
  CONSTRAINT uq_configuration_user_id_user
    UNIQUE (id_user),
  CONSTRAINT fk_configuration_user_user
    FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_configuration_user_idioma
    CHECK (idioma IN ('es', 'en', 'fr', 'de')),
  CONSTRAINT ck_configuration_user_tema
    CHECK (tema IN ('claro', 'oscuro', 'automatico')),
  CONSTRAINT ck_configuration_user_formato_hora
    CHECK (formato_hora IN ('12h', '24h')),
  CONSTRAINT ck_configuration_user_unidad_temp
    CHECK (unidad_temperatura IN ('C', 'F')),
  CONSTRAINT ck_configuration_user_frecuencia
    CHECK (frecuencia_recomendaciones IN ('diaria', 'semanal', 'mensual')),
  CONSTRAINT ck_configuration_user_no_molestar
    CHECK (
      (no_molestar_inicio IS NULL AND no_molestar_fin IS NULL)
      OR
      (no_molestar_inicio IS NOT NULL AND no_molestar_fin IS NOT NULL
       AND no_molestar_inicio <> no_molestar_fin)
    )
);

COMMENT ON TABLE  config.configuration_user
  IS 'Preferencias de configuración personal por usuario.';
COMMENT ON COLUMN config.configuration_user.id_configuration_user
  IS 'Identificador único de la configuración.';
COMMENT ON COLUMN config.configuration_user.id_user
  IS 'Usuario dueño de la configuración (uno a uno con auth.user).';
COMMENT ON COLUMN config.configuration_user.idioma
  IS 'Idioma de la interfaz: es, en, fr, de.';
COMMENT ON COLUMN config.configuration_user.tema
  IS 'Tema visual: claro, oscuro, automatico.';
COMMENT ON COLUMN config.configuration_user.formato_fecha
  IS 'Formato de fecha según región (ej: DD/MM/YYYY, MM/DD/YYYY).';
COMMENT ON COLUMN config.configuration_user.formato_hora
  IS 'Formato de hora: 12h o 24h.';
COMMENT ON COLUMN config.configuration_user.moneda
  IS 'Moneda para reportes de costos (ej: COP, USD).';
COMMENT ON COLUMN config.configuration_user.unidad_temperatura
  IS 'Unidad de temperatura: C (Celsius) o F (Fahrenheit).';
COMMENT ON COLUMN config.configuration_user.notif_consumo_elevado
  IS 'Activar notificaciones cuando el consumo sea elevado.';
COMMENT ON COLUMN config.configuration_user.notif_dispositivos
  IS 'Activar notificaciones relacionadas con dispositivos.';
COMMENT ON COLUMN config.configuration_user.notif_recomendaciones
  IS 'Activar notificaciones de nuevas recomendaciones de ahorro.';
COMMENT ON COLUMN config.configuration_user.notif_seguridad
  IS 'Activar notificaciones de eventos de seguridad.';
COMMENT ON COLUMN config.configuration_user.notif_canal_app
  IS 'Recibir notificaciones dentro de la aplicación.';
COMMENT ON COLUMN config.configuration_user.notif_canal_email
  IS 'Recibir notificaciones por correo electrónico.';
COMMENT ON COLUMN config.configuration_user.notif_canal_push
  IS 'Recibir notificaciones push en el dispositivo móvil.';
COMMENT ON COLUMN config.configuration_user.no_molestar_inicio
  IS 'Hora de inicio del modo No Molestar.';
COMMENT ON COLUMN config.configuration_user.no_molestar_fin
  IS 'Hora de fin del modo No Molestar.';
COMMENT ON COLUMN config.configuration_user.recomendaciones_activas
  IS 'Indica si la generación automática de recomendaciones está activa.';
COMMENT ON COLUMN config.configuration_user.frecuencia_recomendaciones
  IS 'Frecuencia de generación de recomendaciones: diaria, semanal, mensual.';
COMMENT ON COLUMN config.configuration_user.created_at
  IS 'Fecha de creación del registro.';
COMMENT ON COLUMN config.configuration_user.updated_at
  IS 'Fecha de última actualización.';