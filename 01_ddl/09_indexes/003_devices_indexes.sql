-- ============================================================
-- ÍNDICES — Esquema devices
-- Archivo: 01_ddl/09_indexes/003_devices_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema devices. Cubre los patrones
--              de consulta de dispositivos, horarios, umbrales,
--              historial de estados e integración con asistentes
--              de voz.
-- ============================================================
-- TABLA: devices.type_device
-- ============================================================

-- Búsqueda por nombre de tipo de dispositivo
CREATE INDEX IF NOT EXISTS idx_type_device_nombre
  ON devices.type_device (nombre)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: devices.device
-- ============================================================

-- Búsqueda de dispositivos por hogar
CREATE INDEX IF NOT EXISTS idx_device_id_home
  ON devices.device (id_home)
  WHERE deleted_at IS NULL;

-- Búsqueda de dispositivos por zona
CREATE INDEX IF NOT EXISTS idx_device_id_area
  ON devices.device (id_area)
  WHERE deleted_at IS NULL;

-- Filtrado por estado del dispositivo
CREATE INDEX IF NOT EXISTS idx_device_estado
  ON devices.device (estado)
  WHERE deleted_at IS NULL;

-- Búsqueda por MAC address (identificación física del dispositivo)
CREATE INDEX IF NOT EXISTS idx_device_mac_address
  ON devices.device (mac_address)
  WHERE deleted_at IS NULL;

-- Filtrado por tipo de dispositivo
CREATE INDEX IF NOT EXISTS idx_device_id_type_device
  ON devices.device (id_type_device)
  WHERE deleted_at IS NULL;

-- Dispositivos encendidos por hogar (dashboard en tiempo real)
CREATE INDEX IF NOT EXISTS idx_device_id_home_encendido
  ON devices.device (id_home, encendido)
  WHERE deleted_at IS NULL;

-- Compuesto: hogar + estado (dispositivos activos de un hogar)
CREATE INDEX IF NOT EXISTS idx_device_id_home_estado
  ON devices.device (id_home, estado)
  WHERE deleted_at IS NULL;

-- Compuesto: hogar + nombre (validación de nombre único por hogar)
CREATE INDEX IF NOT EXISTS idx_device_id_home_nombre
  ON devices.device (id_home, nombre)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: devices.smart_device
-- ============================================================

-- Búsqueda por dispositivo
CREATE INDEX IF NOT EXISTS idx_smart_device_id_device
  ON devices.smart_device (id_device);

-- ============================================================
-- TABLA: devices.manual_device
-- ============================================================

-- Búsqueda por dispositivo
CREATE INDEX IF NOT EXISTS idx_manual_device_id_device
  ON devices.manual_device (id_device);

-- ============================================================
-- TABLA: devices.schedule
-- ============================================================

-- Búsqueda de horarios por dispositivo
CREATE INDEX IF NOT EXISTS idx_schedule_id_device
  ON devices.schedule (id_device)
  WHERE deleted_at IS NULL;

-- Filtrado de horarios activos (job de ejecución automática)
CREATE INDEX IF NOT EXISTS idx_schedule_activo
  ON devices.schedule (activo)
  WHERE activo = TRUE AND deleted_at IS NULL;

-- Compuesto: dispositivo + activo (horarios activos de un dispositivo)
CREATE INDEX IF NOT EXISTS idx_schedule_id_device_activo
  ON devices.schedule (id_device, activo)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: devices.threshold_rule
-- ============================================================

-- Búsqueda de reglas por dispositivo
CREATE INDEX IF NOT EXISTS idx_threshold_rule_id_device
  ON devices.threshold_rule (id_device)
  WHERE deleted_at IS NULL;

-- Filtrado de reglas activas (monitoreo continuo de consumo)
CREATE INDEX IF NOT EXISTS idx_threshold_rule_activa
  ON devices.threshold_rule (activa)
  WHERE activa = TRUE AND deleted_at IS NULL;

-- Compuesto: dispositivo + tipo (reglas diarias/mensuales de un dispositivo)
CREATE INDEX IF NOT EXISTS idx_threshold_rule_id_device_tipo
  ON devices.threshold_rule (id_device, tipo)
  WHERE activa = TRUE AND deleted_at IS NULL;

-- ============================================================
-- TABLA: devices.device_status_history
-- ============================================================

-- Búsqueda de historial por dispositivo
CREATE INDEX IF NOT EXISTS idx_device_status_history_id_device
  ON devices.device_status_history (id_device);

-- Filtrado por fecha (consultas de historial por rango)
CREATE INDEX IF NOT EXISTS idx_device_status_history_created_at
  ON devices.device_status_history (created_at DESC);

-- Compuesto: dispositivo + fecha (historial reciente de un dispositivo)
CREATE INDEX IF NOT EXISTS idx_device_status_history_device_created_at
  ON devices.device_status_history (id_device, created_at DESC);

-- Filtrado por origen del cambio (usuario, automatico, voz, sistema)
CREATE INDEX IF NOT EXISTS idx_device_status_history_origen
  ON devices.device_status_history (origen);

-- ============================================================
-- TABLA: devices.voice_assistant_token
-- ============================================================

-- Búsqueda de tokens por usuario
CREATE INDEX IF NOT EXISTS idx_voice_assistant_token_id_user
  ON devices.voice_assistant_token (id_user)
  WHERE deleted_at IS NULL;

-- Tokens activos por usuario (validación de integración)
CREATE INDEX IF NOT EXISTS idx_voice_assistant_token_activo
  ON devices.voice_assistant_token (id_user, activo)
  WHERE activo = TRUE AND deleted_at IS NULL;