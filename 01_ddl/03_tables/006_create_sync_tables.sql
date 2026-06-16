-- ============================================================
-- TABLAS — Esquema sync
-- Archivo: 01_ddl/03_tables/007_create_sync_tables.sql
-- Descripción: Creación de las 3 tablas del esquema sync
--              para gestión de sincronización multidispositivo,
--              cola de acciones en modo offline y
--              copias de seguridad del sistema
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, auth.user
-- ============================================================

-- ============================================================
-- TABLA: sync.offline_queue
-- Descripción: Cola de acciones realizadas por el usuario
--              en modo offline que se sincronizan al
--              restablecer la conexión a internet
-- Referencia SRS: RF5.4, RNF4.5
-- ============================================================
CREATE TABLE IF NOT EXISTS sync.offline_queue (
  id_offline_queue UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user          UUID        NOT NULL,
  tipo_accion      VARCHAR(50) NOT NULL,
  payload          JSONB       NOT NULL,
  estado           VARCHAR(20) NOT NULL DEFAULT 'pendiente',
  intentos         SMALLINT    NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  procesada_at     TIMESTAMPTZ NULL,

  CONSTRAINT pk_offline_queue           PRIMARY KEY (id_offline_queue),
  CONSTRAINT fk_offline_queue_user      FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_offline_queue_tipo      CHECK (tipo_accion IN (
    'encender_dispositivo',
    'apagar_dispositivo',
    'actualizar_config',
    'vincular_dispositivo',
    'desvincular_dispositivo',
    'actualizar_dispositivo'
  )),
  CONSTRAINT ck_offline_queue_estado    CHECK (estado IN ('pendiente', 'procesada', 'fallida')),
  CONSTRAINT ck_offline_queue_intentos  CHECK (intentos >= 0),
  CONSTRAINT ck_offline_queue_procesada CHECK (
    (estado = 'pendiente' AND procesada_at IS NULL) OR
    (estado IN ('procesada', 'fallida') AND procesada_at IS NOT NULL)
  )
);

COMMENT ON TABLE  sync.offline_queue                  IS 'Cola de acciones pendientes de sincronización en modo offline.';
COMMENT ON COLUMN sync.offline_queue.id_offline_queue IS 'Identificador único de la acción en cola.';
COMMENT ON COLUMN sync.offline_queue.id_user          IS 'Usuario que realizó la acción en modo offline.';
COMMENT ON COLUMN sync.offline_queue.tipo_accion      IS 'Tipo de acción: encender_dispositivo, apagar_dispositivo, actualizar_config, vincular_dispositivo, desvincular_dispositivo, actualizar_dispositivo.';
COMMENT ON COLUMN sync.offline_queue.payload          IS 'Datos de la acción en formato JSON (parámetros necesarios para ejecutarla).';
COMMENT ON COLUMN sync.offline_queue.estado           IS 'Estado de la acción: pendiente, procesada, fallida.';
COMMENT ON COLUMN sync.offline_queue.intentos         IS 'Número de intentos de sincronización realizados.';
COMMENT ON COLUMN sync.offline_queue.created_at       IS 'Fecha y hora en que se registró la acción offline.';
COMMENT ON COLUMN sync.offline_queue.procesada_at     IS 'Fecha y hora en que fue procesada o marcada como fallida.';

-- ============================================================
-- TABLA: sync.synchronization
-- Descripción: Registra el historial de sincronizaciones
--              realizadas entre dispositivos y el servidor,
--              tanto automáticas como manuales
-- Referencia SRS: RF5.1, RF5.2
-- ============================================================
CREATE TABLE IF NOT EXISTS sync.synchronization (
  id_synchronization           UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user                      UUID        NOT NULL,
  tipo                         VARCHAR(20) NOT NULL,
  estado                       VARCHAR(20) NOT NULL,
  dispositivos_sincronizados   SMALLINT    NULL,
  errores                      TEXT        NULL,
  created_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_synchronization         PRIMARY KEY (id_synchronization),
  CONSTRAINT fk_synchronization_user    FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_synchronization_tipo    CHECK (tipo   IN ('automatica', 'manual')),
  CONSTRAINT ck_synchronization_estado  CHECK (estado IN ('exitosa', 'fallida', 'parcial')),
  CONSTRAINT ck_synchronization_dispos  CHECK (
    dispositivos_sincronizados IS NULL OR
    dispositivos_sincronizados >= 0
  ),
  CONSTRAINT ck_synchronization_errores CHECK (
    (estado = 'exitosa' AND errores IS NULL) OR
    (estado IN ('fallida', 'parcial'))
  )
);

COMMENT ON TABLE  sync.synchronization                              IS 'Historial de sincronizaciones entre dispositivos y servidor.';
COMMENT ON COLUMN sync.synchronization.id_synchronization          IS 'Identificador único de la sincronización.';
COMMENT ON COLUMN sync.synchronization.id_user                     IS 'Usuario que realizó la sincronización.';
COMMENT ON COLUMN sync.synchronization.tipo                        IS 'Tipo de sincronización: automatica o manual.';
COMMENT ON COLUMN sync.synchronization.estado                      IS 'Resultado: exitosa, fallida o parcial.';
COMMENT ON COLUMN sync.synchronization.dispositivos_sincronizados  IS 'Número de dispositivos sincronizados correctamente.';
COMMENT ON COLUMN sync.synchronization.errores                     IS 'Descripción de errores encontrados (NULL si fue exitosa).';
COMMENT ON COLUMN sync.synchronization.created_at                  IS 'Fecha y hora de la sincronización.';

-- ============================================================
-- TABLA: sync.backup
-- Descripción: Registra las copias de seguridad generadas
--              del sistema, tanto automáticas como manuales.
--              Solo administradores pueden ejecutar
--              restauraciones (RF5.3)
-- Referencia SRS: RF5.3, RNF4.4, RNF5.5
-- ============================================================
CREATE TABLE IF NOT EXISTS sync.backup (
  id_backup      UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user        UUID        NULL,
  tipo           VARCHAR(20) NOT NULL,
  alcance        VARCHAR(20) NOT NULL DEFAULT 'completo',
  ubicacion      TEXT        NOT NULL,
  tamanio_bytes  BIGINT      NULL,
  estado         VARCHAR(20) NOT NULL DEFAULT 'completado',
  descripcion    TEXT        NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_backup           PRIMARY KEY (id_backup),
  CONSTRAINT fk_backup_user      FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_backup_tipo      CHECK (tipo    IN ('automatico', 'manual')),
  CONSTRAINT ck_backup_alcance   CHECK (alcance IN ('completo', 'parcial')),
  CONSTRAINT ck_backup_estado    CHECK (estado  IN ('en_proceso', 'completado', 'fallido')),
  CONSTRAINT ck_backup_tamanio   CHECK (tamanio_bytes IS NULL OR tamanio_bytes > 0)
);

COMMENT ON TABLE  sync.backup               IS 'Registro de copias de seguridad del sistema Smart Home.';
COMMENT ON COLUMN sync.backup.id_backup     IS 'Identificador único del backup.';
COMMENT ON COLUMN sync.backup.id_user       IS 'Usuario al que pertenecen los datos (NULL si es backup global del sistema).';
COMMENT ON COLUMN sync.backup.tipo          IS 'Tipo de backup: automatico o manual.';
COMMENT ON COLUMN sync.backup.alcance       IS 'Alcance del backup: completo o parcial.';
COMMENT ON COLUMN sync.backup.ubicacion     IS 'Ruta o URL del archivo de backup almacenado.';
COMMENT ON COLUMN sync.backup.tamanio_bytes IS 'Tamaño del archivo de backup en bytes.';
COMMENT ON COLUMN sync.backup.estado        IS 'Estado del backup: en_proceso, completado, fallido.';
COMMENT ON COLUMN sync.backup.descripcion   IS 'Descripción o notas adicionales del backup.';
COMMENT ON COLUMN sync.backup.created_at    IS 'Fecha y hora de creación del backup.';