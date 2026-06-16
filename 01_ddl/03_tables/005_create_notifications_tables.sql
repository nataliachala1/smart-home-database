-- ============================================================
-- TABLAS — Esquema notifications
-- Archivo: 01_ddl/03_tables/006_create_notifications_tables.sql
-- Descripción: Creación de las 3 tablas del esquema
--              notifications para gestión de notificaciones,
--              alertas por umbral y recordatorios programados
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, auth.user,
--               homes.home, devices.device,
--               devices.threshold_rule
-- ============================================================

-- ============================================================
-- TABLA: notifications.notification
-- Descripción: Almacena todas las notificaciones generadas
--              por el sistema hacia los usuarios, incluyendo
--              alertas, recomendaciones y eventos del sistema
-- Referencia SRS: RF4.5, RF4.6, RNF4.3
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications.notification (
  id_notification UUID         NOT NULL DEFAULT uuid_generate_v4(),
  id_user         UUID         NOT NULL,
  id_home         UUID         NULL,
  id_device       UUID         NULL,
  tipo            VARCHAR(30)  NOT NULL,
  titulo          VARCHAR(200) NOT NULL,
  mensaje         TEXT         NOT NULL,
  prioridad       VARCHAR(10)  NOT NULL DEFAULT 'media',
  leida           BOOLEAN      NOT NULL DEFAULT FALSE,
  canal           VARCHAR(20)  NOT NULL DEFAULT 'app',
  created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at      TIMESTAMPTZ  NULL,

  CONSTRAINT pk_notification              PRIMARY KEY (id_notification),
  CONSTRAINT fk_notification_user         FOREIGN KEY (id_user)   REFERENCES auth.user (id_user),
  CONSTRAINT fk_notification_home         FOREIGN KEY (id_home)   REFERENCES homes.home (id_home),
  CONSTRAINT fk_notification_device       FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT ck_notification_tipo         CHECK (tipo IN (
    'consumo_elevado',
    'dispositivo_desconectado',
    'nueva_recomendacion',
    'umbral_superado',
    'sistema'
  )),
  CONSTRAINT ck_notification_prioridad    CHECK (prioridad IN ('alta', 'media', 'baja')),
  CONSTRAINT ck_notification_canal        CHECK (canal IN ('app', 'email', 'push'))
);

COMMENT ON TABLE  notifications.notification                IS 'Notificaciones generadas por el sistema hacia los usuarios.';
COMMENT ON COLUMN notifications.notification.id_notification IS 'Identificador único de la notificación.';
COMMENT ON COLUMN notifications.notification.id_user         IS 'Usuario destinatario de la notificación.';
COMMENT ON COLUMN notifications.notification.id_home         IS 'Hogar relacionado con la notificación (opcional).';
COMMENT ON COLUMN notifications.notification.id_device       IS 'Dispositivo relacionado con la notificación (opcional).';
COMMENT ON COLUMN notifications.notification.tipo            IS 'Tipo de notificación: consumo_elevado, dispositivo_desconectado, nueva_recomendacion, umbral_superado, sistema.';
COMMENT ON COLUMN notifications.notification.titulo          IS 'Título descriptivo de la notificación.';
COMMENT ON COLUMN notifications.notification.mensaje         IS 'Contenido detallado de la notificación.';
COMMENT ON COLUMN notifications.notification.prioridad       IS 'Prioridad de la notificación: alta, media, baja.';
COMMENT ON COLUMN notifications.notification.leida           IS 'Indica si la notificación fue leída por el usuario.';
COMMENT ON COLUMN notifications.notification.canal           IS 'Canal por el que se envió: app, email, push.';
COMMENT ON COLUMN notifications.notification.created_at      IS 'Fecha de creación de la notificación.';
COMMENT ON COLUMN notifications.notification.updated_at      IS 'Fecha de última actualización.';
COMMENT ON COLUMN notifications.notification.deleted_at      IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: notifications.alert
-- Descripción: Alertas específicas generadas cuando un
--              dispositivo supera los umbrales de consumo
--              configurados por el usuario
-- Referencia SRS: RF3.2, RF3.5, RF4.5
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications.alert (
  id_alert                UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_threshold_rule       UUID          NOT NULL,
  id_device               UUID          NOT NULL,
  id_home                 UUID          NOT NULL,
  consumo_detectado_kwh   NUMERIC(12,6) NOT NULL,
  limite_kwh              NUMERIC(10,4) NOT NULL,
  accion_ejecutada        VARCHAR(20)   NULL,
  created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_alert                   PRIMARY KEY (id_alert),
  CONSTRAINT fk_alert_threshold_rule    FOREIGN KEY (id_threshold_rule) REFERENCES devices.threshold_rule (id_threshold_rule),
  CONSTRAINT fk_alert_device            FOREIGN KEY (id_device)         REFERENCES devices.device (id_device),
  CONSTRAINT fk_alert_home              FOREIGN KEY (id_home)           REFERENCES homes.home (id_home),
  CONSTRAINT ck_alert_consumo           CHECK (consumo_detectado_kwh > 0),
  CONSTRAINT ck_alert_limite            CHECK (limite_kwh > 0),
  CONSTRAINT ck_alert_accion            CHECK (
    accion_ejecutada IS NULL OR
    accion_ejecutada IN ('alertar', 'apagar')
  ),
  CONSTRAINT ck_alert_consumo_supera    CHECK (consumo_detectado_kwh > limite_kwh)
);

COMMENT ON TABLE  notifications.alert                          IS 'Alertas generadas cuando un dispositivo supera su umbral de consumo.';
COMMENT ON COLUMN notifications.alert.id_alert                 IS 'Identificador único de la alerta.';
COMMENT ON COLUMN notifications.alert.id_threshold_rule        IS 'Regla de umbral que disparó la alerta.';
COMMENT ON COLUMN notifications.alert.id_device                IS 'Dispositivo que generó la alerta.';
COMMENT ON COLUMN notifications.alert.id_home                  IS 'Hogar al que pertenece el dispositivo.';
COMMENT ON COLUMN notifications.alert.consumo_detectado_kwh    IS 'Consumo detectado al momento de generar la alerta.';
COMMENT ON COLUMN notifications.alert.limite_kwh               IS 'Límite configurado que fue superado.';
COMMENT ON COLUMN notifications.alert.accion_ejecutada         IS 'Acción ejecutada al superar el umbral: alertar o apagar.';
COMMENT ON COLUMN notifications.alert.created_at               IS 'Fecha y hora exacta de la alerta.';

-- ============================================================
-- TABLA: notifications.reminder_notification
-- Descripción: Recordatorios programados para enviar
--              a los usuarios en fechas y horas específicas
-- Referencia SRS: RF4.5, RF4.6
-- ============================================================
CREATE TABLE IF NOT EXISTS notifications.reminder_notification (
  id_reminder_notification UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user                  UUID        NOT NULL,
  id_home                  UUID        NULL,
  mensaje                  TEXT        NOT NULL,
  programado_para          TIMESTAMPTZ NOT NULL,
  enviado                  BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at               TIMESTAMPTZ NULL,

  CONSTRAINT pk_reminder_notification         PRIMARY KEY (id_reminder_notification),
  CONSTRAINT fk_reminder_notification_user    FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT fk_reminder_notification_home    FOREIGN KEY (id_home) REFERENCES homes.home (id_home),
  CONSTRAINT ck_reminder_notification_fecha   CHECK (programado_para > created_at)
);

COMMENT ON TABLE  notifications.reminder_notification                          IS 'Recordatorios programados para enviar a usuarios en fecha y hora específica.';
COMMENT ON COLUMN notifications.reminder_notification.id_reminder_notification IS 'Identificador único del recordatorio.';
COMMENT ON COLUMN notifications.reminder_notification.id_user                  IS 'Usuario destinatario del recordatorio.';
COMMENT ON COLUMN notifications.reminder_notification.id_home                  IS 'Hogar relacionado con el recordatorio (opcional).';
COMMENT ON COLUMN notifications.reminder_notification.mensaje                  IS 'Contenido del recordatorio.';
COMMENT ON COLUMN notifications.reminder_notification.programado_para          IS 'Fecha y hora programada para el envío.';
COMMENT ON COLUMN notifications.reminder_notification.enviado                  IS 'Indica si el recordatorio ya fue enviado.';
COMMENT ON COLUMN notifications.reminder_notification.created_at               IS 'Fecha de creación del recordatorio.';
COMMENT ON COLUMN notifications.reminder_notification.updated_at               IS 'Fecha de última actualización.';
COMMENT ON COLUMN notifications.reminder_notification.deleted_at               IS 'Fecha de eliminación lógica (soft delete).';