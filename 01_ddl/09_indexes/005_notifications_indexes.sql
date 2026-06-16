-- ============================================================
-- ÍNDICES — Esquema notifications
-- Archivo: 01_ddl/09_indexes/005_notifications_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema notifications. Optimiza
--              la entrega en tiempo real y la consulta del
--              centro de notificaciones (delay máx. 2 seg).

-- ============================================================
-- TABLA: notifications.notification
-- ============================================================

-- Búsqueda de notificaciones por usuario (centro de notificaciones)
CREATE INDEX IF NOT EXISTS idx_notification_id_user
  ON notifications.notification (id_user)
  WHERE deleted_at IS NULL;

-- Notificaciones no leídas por usuario (badge counter)
CREATE INDEX IF NOT EXISTS idx_notification_leida
  ON notifications.notification (id_user, leida)
  WHERE leida = FALSE AND deleted_at IS NULL;

-- Filtrado por tipo de notificación
CREATE INDEX IF NOT EXISTS idx_notification_tipo
  ON notifications.notification (tipo)
  WHERE deleted_at IS NULL;

-- Ordenamiento cronológico (más recientes primero)
CREATE INDEX IF NOT EXISTS idx_notification_created_at
  ON notifications.notification (created_at DESC)
  WHERE deleted_at IS NULL;

-- Filtrado por prioridad (alertas críticas)
CREATE INDEX IF NOT EXISTS idx_notification_prioridad
  ON notifications.notification (prioridad)
  WHERE deleted_at IS NULL;

-- Compuesto: usuario + fecha (notificaciones recientes de un usuario)
CREATE INDEX IF NOT EXISTS idx_notification_user_created_at
  ON notifications.notification (id_user, created_at DESC)
  WHERE deleted_at IS NULL;

-- Compuesto: usuario + tipo (filtrar notificaciones por categoría)
CREATE INDEX IF NOT EXISTS idx_notification_user_tipo
  ON notifications.notification (id_user, tipo)
  WHERE deleted_at IS NULL;

-- Compuesto: usuario + no leída + fecha (bandeja de entrada)
CREATE INDEX IF NOT EXISTS idx_notification_user_leida_fecha
  ON notifications.notification (id_user, leida, created_at DESC)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: notifications.alert
-- ============================================================

-- Búsqueda de alertas por dispositivo
CREATE INDEX IF NOT EXISTS idx_alert_id_device
  ON notifications.alert (id_device);

-- Búsqueda de alertas por hogar
CREATE INDEX IF NOT EXISTS idx_alert_id_home
  ON notifications.alert (id_home);

-- Filtrado por fecha (historial de alertas)
CREATE INDEX IF NOT EXISTS idx_alert_created_at
  ON notifications.alert (created_at DESC);

-- Búsqueda por regla de umbral que generó la alerta
CREATE INDEX IF NOT EXISTS idx_alert_id_threshold_rule
  ON notifications.alert (id_threshold_rule);

-- Compuesto: hogar + fecha (alertas recientes del hogar)
CREATE INDEX IF NOT EXISTS idx_alert_home_created_at
  ON notifications.alert (id_home, created_at DESC);

-- Compuesto: dispositivo + fecha (historial de alertas por dispositivo)
CREATE INDEX IF NOT EXISTS idx_alert_device_created_at
  ON notifications.alert (id_device, created_at DESC);

-- ============================================================
-- TABLA: notifications.reminder_notification
-- ============================================================

-- Búsqueda de recordatorios por usuario
CREATE INDEX IF NOT EXISTS idx_reminder_notification_id_user
  ON notifications.reminder_notification (id_user)
  WHERE deleted_at IS NULL;

-- Recordatorios pendientes de envío (job de envío programado)
CREATE INDEX IF NOT EXISTS idx_reminder_notification_programado_para
  ON notifications.reminder_notification (programado_para)
  WHERE enviado = FALSE AND deleted_at IS NULL;

-- Compuesto: usuario + enviado (recordatorios pendientes de un usuario)
CREATE INDEX IF NOT EXISTS idx_reminder_notification_user_enviado
  ON notifications.reminder_notification (id_user, enviado)
  WHERE deleted_at IS NULL;