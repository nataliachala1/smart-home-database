-- ============================================================
-- ÍNDICES — Esquema sync
-- Archivo: 01_ddl/09_indexes/006_sync_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema sync. Cubre los patrones
--              de consulta de la cola offline, historial de
--              sincronizaciones y backups.

-- ============================================================
-- TABLA: sync.offline_queue
-- ============================================================

-- Búsqueda de acciones pendientes por usuario
CREATE INDEX IF NOT EXISTS idx_offline_queue_id_user
  ON sync.offline_queue (id_user);

-- Filtrado por estado (pendiente, procesada, fallida)
CREATE INDEX IF NOT EXISTS idx_offline_queue_estado
  ON sync.offline_queue (estado);

-- Acciones pendientes ordenadas por fecha (procesamiento FIFO)
CREATE INDEX IF NOT EXISTS idx_offline_queue_pendiente_created_at
  ON sync.offline_queue (created_at ASC)
  WHERE estado = 'pendiente';

-- Compuesto: usuario + estado (acciones pendientes de un usuario)
CREATE INDEX IF NOT EXISTS idx_offline_queue_user_estado
  ON sync.offline_queue (id_user, estado);

-- Compuesto: usuario + pendiente + fecha (cola FIFO por usuario)
CREATE INDEX IF NOT EXISTS idx_offline_queue_user_pendiente_fecha
  ON sync.offline_queue (id_user, created_at ASC)
  WHERE estado = 'pendiente';

-- ============================================================
-- TABLA: sync.synchronization
-- ============================================================

-- Búsqueda de sincronizaciones por usuario
CREATE INDEX IF NOT EXISTS idx_synchronization_id_user
  ON sync.synchronization (id_user);

-- Filtrado por fecha (historial de sincronizaciones)
CREATE INDEX IF NOT EXISTS idx_synchronization_created_at
  ON sync.synchronization (created_at DESC);

-- Filtrado por tipo (automatica, manual)
CREATE INDEX IF NOT EXISTS idx_synchronization_tipo
  ON sync.synchronization (tipo);

-- Filtrado por estado (exitosa, fallida, parcial)
CREATE INDEX IF NOT EXISTS idx_synchronization_estado
  ON sync.synchronization (estado);

-- Compuesto: usuario + fecha (sincronizaciones recientes de un usuario)
CREATE INDEX IF NOT EXISTS idx_synchronization_user_created_at
  ON sync.synchronization (id_user, created_at DESC);

-- ============================================================
-- TABLA: sync.backup
-- ============================================================

-- Búsqueda de backups por usuario
CREATE INDEX IF NOT EXISTS idx_backup_id_user
  ON sync.backup (id_user);

-- Filtrado por tipo de backup (automatico, manual)
CREATE INDEX IF NOT EXISTS idx_backup_tipo
  ON sync.backup (tipo);

-- Filtrado por fecha de creación (listado de backups disponibles)
CREATE INDEX IF NOT EXISTS idx_backup_created_at
  ON sync.backup (created_at DESC);

-- Filtrado por estado del backup (en_proceso, completado, fallido)
CREATE INDEX IF NOT EXISTS idx_backup_estado
  ON sync.backup (estado);

-- Compuesto: usuario + estado + fecha (backups completados de un usuario)
CREATE INDEX IF NOT EXISTS idx_backup_user_estado_fecha
  ON sync.backup (id_user, estado, created_at DESC);

-- Backups automáticos completados (listado para restauración)
CREATE INDEX IF NOT EXISTS idx_backup_automatico_completado
  ON sync.backup (created_at DESC)
  WHERE tipo = 'automatico' AND estado = 'completado';