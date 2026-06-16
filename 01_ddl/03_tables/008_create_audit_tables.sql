-- ============================================================
-- TABLAS — Esquema audit
-- Archivo: 01_ddl/03_tables/008_create_audit_tables.sql
-- Descripción: Creación de la tabla del esquema audit
--              para registro de auditoría y trazabilidad
--              de todas las operaciones críticas del sistema
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, 001_create_auth_tables
-- ============================================================

-- ============================================================
-- TABLA: audit.audit_log
-- Descripción: Registro inmutable de todas las acciones
--              relevantes realizadas en el sistema por
--              usuarios o procesos automáticos.
--              Esta tabla NO permite UPDATE ni DELETE.
-- Referencia SRS: RF7.1, RNF8.2
-- ============================================================
CREATE TABLE IF NOT EXISTS audit.audit_log (
  id_audit_log    UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_user         UUID          NULL,
  accion          VARCHAR(50)   NOT NULL,
  modulo          VARCHAR(50)   NOT NULL,
  entidad         VARCHAR(50)   NULL,
  id_entidad      UUID          NULL,
  datos_anteriores JSONB        NULL,
  datos_nuevos    JSONB         NULL,
  ip_address      VARCHAR(45)   NULL,
  user_agent      TEXT          NULL,
  resultado       VARCHAR(10)   NOT NULL DEFAULT 'exitoso',
  detalle         TEXT          NULL,
  created_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_audit_log          PRIMARY KEY (id_audit_log),
  CONSTRAINT fk_audit_log_user     FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_audit_log_resultado CHECK (resultado IN ('exitoso', 'fallido')),
  CONSTRAINT ck_audit_log_accion    CHECK (accion IN (
    'crear', 'editar', 'eliminar', 'login', 'logout',
    'restaurar', 'exportar', 'configurar', 'asignar', 'revocar'
  ))
);

COMMENT ON TABLE  audit.audit_log                IS 'Registro inmutable de auditoría de todas las operaciones críticas del sistema Smart Home.';
COMMENT ON COLUMN audit.audit_log.id_audit_log   IS 'Identificador único del registro de auditoría.';
COMMENT ON COLUMN audit.audit_log.id_user        IS 'Usuario que realizó la acción. NULL si es proceso automático del sistema.';
COMMENT ON COLUMN audit.audit_log.accion         IS 'Acción realizada: crear, editar, eliminar, login, logout, restaurar, exportar, configurar, asignar, revocar.';
COMMENT ON COLUMN audit.audit_log.modulo         IS 'Módulo del sistema donde ocurrió la acción (ej: usuarios, hogares, dispositivos).';
COMMENT ON COLUMN audit.audit_log.entidad        IS 'Entidad afectada por la acción (ej: user, home, device, session).';
COMMENT ON COLUMN audit.audit_log.id_entidad     IS 'Identificador UUID del registro afectado por la acción.';
COMMENT ON COLUMN audit.audit_log.datos_anteriores IS 'Estado anterior del registro antes de la acción. NULL para creaciones.';
COMMENT ON COLUMN audit.audit_log.datos_nuevos   IS 'Estado nuevo del registro después de la acción. NULL para eliminaciones.';
COMMENT ON COLUMN audit.audit_log.ip_address     IS 'Dirección IP desde donde se realizó la acción (IPv4 o IPv6).';
COMMENT ON COLUMN audit.audit_log.user_agent     IS 'Información del navegador o dispositivo desde donde se realizó la acción.';
COMMENT ON COLUMN audit.audit_log.resultado      IS 'Resultado de la acción: exitoso o fallido.';
COMMENT ON COLUMN audit.audit_log.detalle        IS 'Descripción adicional, mensaje de error o contexto de la acción.';
COMMENT ON COLUMN audit.audit_log.created_at     IS 'Fecha y hora exacta en que ocurrió la acción. Inmutable.';