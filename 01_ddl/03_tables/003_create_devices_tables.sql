-- ============================================================
-- TABLAS — Esquema devices
-- Archivo: 01_ddl/03_tables/004_create_devices_tables.sql
-- Descripción: Creación de las 7 tablas del esquema devices
--              para gestión de dispositivos IoT, horarios
--              automáticos, umbrales de consumo e historial
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, auth.user,
--               homes.home, homes.area
-- ============================================================

-- ============================================================
-- TABLA: devices.type_device
-- Descripción: Catálogo de tipos de dispositivos disponibles
--              en el sistema Smart Home
-- Referencia SRS: RF3.1
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.type_device (
  id_type_device UUID         NOT NULL DEFAULT uuid_generate_v4(),
  nombre         VARCHAR(100) NOT NULL,
  descripcion    TEXT         NULL,
  icono          VARCHAR(100) NULL,
  created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ  NULL,

  CONSTRAINT pk_type_device       PRIMARY KEY (id_type_device),
  CONSTRAINT uq_type_device_nombre UNIQUE (nombre)
);

COMMENT ON TABLE  devices.type_device               IS 'Catálogo de tipos de dispositivos IoT del sistema.';
COMMENT ON COLUMN devices.type_device.id_type_device IS 'Identificador único del tipo de dispositivo.';
COMMENT ON COLUMN devices.type_device.nombre         IS 'Nombre del tipo de dispositivo (ej: Lámpara inteligente).';
COMMENT ON COLUMN devices.type_device.descripcion    IS 'Descripción del tipo de dispositivo.';
COMMENT ON COLUMN devices.type_device.icono          IS 'Nombre del ícono representativo del tipo.';
COMMENT ON COLUMN devices.type_device.created_at     IS 'Fecha de creación del registro.';
COMMENT ON COLUMN devices.type_device.updated_at     IS 'Fecha de última actualización.';
COMMENT ON COLUMN devices.type_device.deleted_at     IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: devices.device
-- Descripción: Almacena los dispositivos inteligentes o
--              sensores registrados, vinculados a un hogar
--              y zona específica
-- Referencia SRS: RF3.1, RF3.2, RF3.3, RF3.4, RF3.5
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.device (
  id_device        UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_home          UUID          NOT NULL,
  id_area          UUID          NULL,
  id_type_device   UUID          NOT NULL,
  nombre           VARCHAR(100)  NOT NULL,
  estado           VARCHAR(20)   NOT NULL DEFAULT 'desconectado',
  encendido        BOOLEAN       NOT NULL DEFAULT FALSE,
  consumo_actual_w NUMERIC(10,2) NULL,
  mac_address      VARCHAR(17)   NULL,
  protocolo        VARCHAR(20)   NULL,
  created_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ   NULL,

  CONSTRAINT pk_device              PRIMARY KEY (id_device),
  CONSTRAINT uq_device_nombre       UNIQUE (id_home, nombre),
  CONSTRAINT uq_device_mac          UNIQUE (mac_address),
  CONSTRAINT fk_device_home         FOREIGN KEY (id_home)        REFERENCES homes.home (id_home),
  CONSTRAINT fk_device_area         FOREIGN KEY (id_area)        REFERENCES homes.area (id_area),
  CONSTRAINT fk_device_type         FOREIGN KEY (id_type_device) REFERENCES devices.type_device (id_type_device),
  CONSTRAINT ck_device_estado       CHECK (estado IN ('conectado', 'desconectado', 'activo', 'desactivado')),
  CONSTRAINT ck_device_protocolo    CHECK (
    protocolo IS NULL OR
    protocolo IN ('wifi', 'bluetooth', 'mqtt')
  ),
  CONSTRAINT ck_device_consumo      CHECK (consumo_actual_w IS NULL OR consumo_actual_w >= 0),
  CONSTRAINT ck_device_mac          CHECK (
    mac_address IS NULL OR
    mac_address ~ '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'
  )
);

COMMENT ON TABLE  devices.device                  IS 'Dispositivos IoT registrados en el sistema Smart Home.';
COMMENT ON COLUMN devices.device.id_device        IS 'Identificador único del dispositivo (inmutable una vez creado).';
COMMENT ON COLUMN devices.device.id_home          IS 'Hogar al que pertenece el dispositivo.';
COMMENT ON COLUMN devices.device.id_area          IS 'Zona donde está ubicado el dispositivo (opcional).';
COMMENT ON COLUMN devices.device.id_type_device   IS 'Tipo de dispositivo del catálogo.';
COMMENT ON COLUMN devices.device.nombre           IS 'Nombre personalizado del dispositivo.';
COMMENT ON COLUMN devices.device.estado           IS 'Estado del dispositivo: conectado, desconectado, activo, desactivado.';
COMMENT ON COLUMN devices.device.encendido        IS 'Indica si el dispositivo está encendido en este momento.';
COMMENT ON COLUMN devices.device.consumo_actual_w IS 'Consumo eléctrico actual en Watts.';
COMMENT ON COLUMN devices.device.mac_address      IS 'Dirección MAC del dispositivo físico.';
COMMENT ON COLUMN devices.device.protocolo        IS 'Protocolo de comunicación: wifi, bluetooth, mqtt.';
COMMENT ON COLUMN devices.device.created_at       IS 'Fecha de registro del dispositivo.';
COMMENT ON COLUMN devices.device.updated_at       IS 'Fecha de última actualización.';
COMMENT ON COLUMN devices.device.deleted_at       IS 'Fecha de eliminación lógica (desactivación).';

-- ============================================================
-- TABLA: devices.smart_device
-- Descripción: Datos extendidos para dispositivos inteligentes
--              con capacidades avanzadas de control
-- Referencia SRS: RF3.1, RF3.5
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.smart_device (
  id_smart_device    UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_device          UUID          NOT NULL,
  firmware_version   VARCHAR(50)   NULL,
  modelo             VARCHAR(100)  NULL,
  fabricante         VARCHAR(100)  NULL,
  capacidad_maxima_w NUMERIC(10,2) NULL,
  created_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_smart_device           PRIMARY KEY (id_smart_device),
  CONSTRAINT uq_smart_device_device    UNIQUE (id_device),
  CONSTRAINT fk_smart_device_device    FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT ck_smart_device_capacidad CHECK (capacidad_maxima_w IS NULL OR capacidad_maxima_w > 0)
);

COMMENT ON TABLE  devices.smart_device                    IS 'Datos extendidos para dispositivos inteligentes.';
COMMENT ON COLUMN devices.smart_device.id_smart_device    IS 'Identificador único del registro extendido.';
COMMENT ON COLUMN devices.smart_device.id_device          IS 'Dispositivo al que pertenece (uno a uno).';
COMMENT ON COLUMN devices.smart_device.firmware_version   IS 'Versión del firmware instalado en el dispositivo.';
COMMENT ON COLUMN devices.smart_device.modelo             IS 'Modelo del dispositivo físico.';
COMMENT ON COLUMN devices.smart_device.fabricante         IS 'Fabricante del dispositivo.';
COMMENT ON COLUMN devices.smart_device.capacidad_maxima_w IS 'Capacidad máxima de consumo en Watts.';
COMMENT ON COLUMN devices.smart_device.created_at         IS 'Fecha de creación del registro.';
COMMENT ON COLUMN devices.smart_device.updated_at         IS 'Fecha de última actualización.';

-- ============================================================
-- TABLA: devices.manual_device
-- Descripción: Datos extendidos para dispositivos manuales
--              cuyo consumo se registra de forma estimada
-- Referencia SRS: RF3.1
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.manual_device (
  id_manual_device    UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_device           UUID          NOT NULL,
  consumo_estimado_w  NUMERIC(10,2) NULL,
  horas_uso_diario    NUMERIC(5,2)  NULL,
  created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_manual_device              PRIMARY KEY (id_manual_device),
  CONSTRAINT uq_manual_device_device       UNIQUE (id_device),
  CONSTRAINT fk_manual_device_device       FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT ck_manual_device_consumo      CHECK (consumo_estimado_w IS NULL OR consumo_estimado_w > 0),
  CONSTRAINT ck_manual_device_horas        CHECK (
    horas_uso_diario IS NULL OR
    horas_uso_diario BETWEEN 0 AND 24
  )
);

COMMENT ON TABLE  devices.manual_device                   IS 'Datos extendidos para dispositivos de consumo estimado.';
COMMENT ON COLUMN devices.manual_device.id_manual_device  IS 'Identificador único del registro extendido.';
COMMENT ON COLUMN devices.manual_device.id_device         IS 'Dispositivo al que pertenece (uno a uno).';
COMMENT ON COLUMN devices.manual_device.consumo_estimado_w IS 'Consumo estimado en Watts.';
COMMENT ON COLUMN devices.manual_device.horas_uso_diario  IS 'Horas de uso diario estimadas (0 a 24).';
COMMENT ON COLUMN devices.manual_device.created_at        IS 'Fecha de creación del registro.';
COMMENT ON COLUMN devices.manual_device.updated_at        IS 'Fecha de última actualización.';

-- ============================================================
-- TABLA: devices.schedule
-- Descripción: Horarios automáticos para encender o apagar
--              dispositivos en días y horas específicas
-- Referencia SRS: RF3.2
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.schedule (
  id_schedule  UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_device    UUID        NOT NULL,
  accion       VARCHAR(10) NOT NULL,
  hora         TIME        NOT NULL,
  dias_semana  SMALLINT[]  NOT NULL,
  activo       BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ NULL,

  CONSTRAINT pk_schedule          PRIMARY KEY (id_schedule),
  CONSTRAINT fk_schedule_device   FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT ck_schedule_accion   CHECK (accion IN ('encender', 'apagar'))
);

COMMENT ON TABLE  devices.schedule             IS 'Horarios automáticos de encendido y apagado de dispositivos.';
COMMENT ON COLUMN devices.schedule.id_schedule IS 'Identificador único del horario.';
COMMENT ON COLUMN devices.schedule.id_device   IS 'Dispositivo al que aplica el horario.';
COMMENT ON COLUMN devices.schedule.accion      IS 'Acción programada: encender o apagar.';
COMMENT ON COLUMN devices.schedule.hora        IS 'Hora de ejecución del horario.';
COMMENT ON COLUMN devices.schedule.dias_semana IS 'Días de la semana (1=lunes ... 7=domingo).';
COMMENT ON COLUMN devices.schedule.activo      IS 'Indica si el horario está activo.';
COMMENT ON COLUMN devices.schedule.created_at  IS 'Fecha de creación del registro.';
COMMENT ON COLUMN devices.schedule.updated_at  IS 'Fecha de última actualización.';
COMMENT ON COLUMN devices.schedule.deleted_at  IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: devices.threshold_rule
-- Descripción: Reglas de umbral de consumo por dispositivo.
--              Genera alertas o acciones automáticas cuando
--              se supera el límite configurado
-- Referencia SRS: RF3.2, RF3.5
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.threshold_rule (
  id_threshold_rule UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_device         UUID          NOT NULL,
  tipo              VARCHAR(20)   NOT NULL,
  limite_kwh        NUMERIC(10,4) NOT NULL,
  accion            VARCHAR(20)   NOT NULL DEFAULT 'alertar',
  activa            BOOLEAN       NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ   NULL,

  CONSTRAINT pk_threshold_rule          PRIMARY KEY (id_threshold_rule),
  CONSTRAINT fk_threshold_rule_device   FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT ck_threshold_rule_tipo     CHECK (tipo IN ('diario', 'mensual')),
  CONSTRAINT ck_threshold_rule_accion   CHECK (accion IN ('alertar', 'apagar')),
  CONSTRAINT ck_threshold_rule_limite   CHECK (limite_kwh > 0)
);

COMMENT ON TABLE  devices.threshold_rule                  IS 'Reglas de umbral de consumo por dispositivo.';
COMMENT ON COLUMN devices.threshold_rule.id_threshold_rule IS 'Identificador único de la regla.';
COMMENT ON COLUMN devices.threshold_rule.id_device         IS 'Dispositivo al que aplica la regla.';
COMMENT ON COLUMN devices.threshold_rule.tipo              IS 'Tipo de umbral: diario o mensual.';
COMMENT ON COLUMN devices.threshold_rule.limite_kwh        IS 'Límite de consumo en kWh que activa la regla.';
COMMENT ON COLUMN devices.threshold_rule.accion            IS 'Acción al superar el umbral: alertar o apagar.';
COMMENT ON COLUMN devices.threshold_rule.activa            IS 'Indica si la regla está activa.';
COMMENT ON COLUMN devices.threshold_rule.created_at        IS 'Fecha de creación del registro.';
COMMENT ON COLUMN devices.threshold_rule.updated_at        IS 'Fecha de última actualización.';
COMMENT ON COLUMN devices.threshold_rule.deleted_at        IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: devices.device_status_history
-- Descripción: Historial inmutable de cambios de estado
--              de cada dispositivo para trazabilidad
-- Referencia SRS: RF3.5
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.device_status_history (
  id_device_status_history UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_device                UUID        NOT NULL,
  estado_anterior          VARCHAR(20) NULL,
  estado_nuevo             VARCHAR(20) NOT NULL,
  encendido                BOOLEAN     NOT NULL,
  origen                   VARCHAR(20) NOT NULL DEFAULT 'usuario',
  id_user                  UUID        NULL,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_device_status_history       PRIMARY KEY (id_device_status_history),
  CONSTRAINT fk_device_status_history_dev   FOREIGN KEY (id_device) REFERENCES devices.device (id_device),
  CONSTRAINT fk_device_status_history_user  FOREIGN KEY (id_user)   REFERENCES auth.user (id_user),
  CONSTRAINT ck_device_status_history_nuevo CHECK (estado_nuevo IN ('conectado', 'desconectado', 'activo', 'desactivado')),
  CONSTRAINT ck_device_status_history_ant   CHECK (
    estado_anterior IS NULL OR
    estado_anterior IN ('conectado', 'desconectado', 'activo', 'desactivado')
  ),
  CONSTRAINT ck_device_status_history_orig  CHECK (origen IN ('usuario', 'automatico', 'voz', 'sistema'))
);

COMMENT ON TABLE  devices.device_status_history                          IS 'Historial inmutable de cambios de estado de dispositivos.';
COMMENT ON COLUMN devices.device_status_history.id_device_status_history IS 'Identificador único del registro de historial.';
COMMENT ON COLUMN devices.device_status_history.id_device                IS 'Dispositivo al que pertenece el registro.';
COMMENT ON COLUMN devices.device_status_history.estado_anterior          IS 'Estado previo del dispositivo.';
COMMENT ON COLUMN devices.device_status_history.estado_nuevo             IS 'Nuevo estado del dispositivo.';
COMMENT ON COLUMN devices.device_status_history.encendido                IS 'Estado de encendido al momento del registro.';
COMMENT ON COLUMN devices.device_status_history.origen                   IS 'Origen del cambio: usuario, automatico, voz, sistema.';
COMMENT ON COLUMN devices.device_status_history.id_user                  IS 'Usuario que realizó el cambio (NULL si es automático).';
COMMENT ON COLUMN devices.device_status_history.created_at               IS 'Fecha y hora exacta del cambio de estado.';

-- ============================================================
-- TABLA: devices.voice_assistant_token
-- Descripción: Tokens de integración con asistentes de voz
--              como Alexa para control por comandos de voz
-- Referencia SRS: RF3.6
-- ============================================================
CREATE TABLE IF NOT EXISTS devices.voice_assistant_token (
  id_voice_assistant_token UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user                  UUID        NOT NULL,
  asistente                VARCHAR(30) NOT NULL,
  access_token             TEXT        NOT NULL,
  refresh_token            TEXT        NULL,
  expira_en                TIMESTAMPTZ NULL,
  activo                   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at               TIMESTAMPTZ NULL,

  CONSTRAINT pk_voice_assistant_token       PRIMARY KEY (id_voice_assistant_token),
  CONSTRAINT uq_voice_assistant_token       UNIQUE (id_user, asistente),
  CONSTRAINT fk_voice_assistant_token_user  FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_voice_assistant_token_asist CHECK (asistente IN ('alexa'))
);

COMMENT ON TABLE  devices.voice_assistant_token                          IS 'Tokens de integración con asistentes de voz.';
COMMENT ON COLUMN devices.voice_assistant_token.id_voice_assistant_token IS 'Identificador único del token de integración.';
COMMENT ON COLUMN devices.voice_assistant_token.id_user                  IS 'Usuario dueño de la integración.';
COMMENT ON COLUMN devices.voice_assistant_token.asistente                IS 'Nombre del asistente de voz: alexa.';
COMMENT ON COLUMN devices.voice_assistant_token.access_token             IS 'Token de acceso cifrado del asistente.';
COMMENT ON COLUMN devices.voice_assistant_token.refresh_token            IS 'Token de renovación cifrado del asistente.';
COMMENT ON COLUMN devices.voice_assistant_token.expira_en                IS 'Fecha de expiración del token de acceso.';
COMMENT ON COLUMN devices.voice_assistant_token.activo                   IS 'Indica si la integración está activa.';
COMMENT ON COLUMN devices.voice_assistant_token.created_at               IS 'Fecha de vinculación con el asistente.';
COMMENT ON COLUMN devices.voice_assistant_token.updated_at               IS 'Fecha de última actualización.';
COMMENT ON COLUMN devices.voice_assistant_token.deleted_at               IS 'Fecha de eliminación lógica (soft delete).';