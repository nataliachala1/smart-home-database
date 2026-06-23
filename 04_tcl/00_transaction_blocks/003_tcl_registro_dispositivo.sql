-- ============================================================
-- TRANSACTION BLOCK — Registro de dispositivo
-- Archivo: 04_tcl/00_transaction_blocks/003_tcl_registro_dispositivo.sql
-- Descripción: Garantiza que el registro de un nuevo
--              dispositivo sea atómico. Incluye creación
--              del dispositivo, registro extendido,
--              historial de estado inicial y auditoría.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF3.1
-- Dependencias: 01_ddl/03_tables/003_create_devices_tables.sql
-- ============================================================

BEGIN;

  -- 1. Insertar dispositivo
  INSERT INTO devices.device (
    id_device, id_home, id_area, id_type_device,
    nombre, estado, encendido, protocolo, created_at, updated_at
  )
  VALUES (
    :id_device, :id_home, :id_area, :id_type_device,
    :nombre, 'desconectado', FALSE, :protocolo,
    NOW(), NOW()
  );

  SAVEPOINT sp_dispositivo_creado;

  -- 2. Insertar registro extendido (dispositivo inteligente)
  INSERT INTO devices.smart_device (
    id_smart_device, id_device, modelo, fabricante,
    capacidad_maxima_w, created_at, updated_at
  )
  VALUES (
    uuid_generate_v4(), :id_device, :modelo, :fabricante,
    :capacidad_maxima_w, NOW(), NOW()
  );

  SAVEPOINT sp_smart_device_creado;

  -- 3. Registrar estado inicial en historial
  INSERT INTO devices.device_status_history (
    id_device_status_history, id_device, estado_anterior,
    estado_nuevo, encendido, origen, id_user, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_device, NULL,
    'desconectado', FALSE, 'sistema', :id_user, NOW()
  );

  SAVEPOINT sp_historial_creado;

  -- 4. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'crear', 'dispositivos',
    'device', :id_device, 'exitoso',
    CONCAT('Registro de nuevo dispositivo: ', :nombre),
    NOW()
  );

COMMIT;

-- En caso de error:
-- ROLLBACK;