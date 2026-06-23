-- ============================================================
-- TCL: Desactivar Dispositivo
-- Archivo: 04_tcl/00_transaction_blocks/005_tcl_desactivar_dispositivo.sql
-- Descripción: Bloque transaccional que garantiza la
--              desactivación atómica de un dispositivo:
--              desactiva el dispositivo, cancela sus horarios
--              y reglas de umbral, y registra el cambio
--              de estado en el historial
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF3.4
-- Dependencias: 03_tables/devices, 06_triggers/002_trg_audit_log
-- ============================================================

BEGIN;

  -- --------------------------------------------------------
  -- 1. Soft delete del dispositivo
  --    Dispara: fn_audit_log (registra desactivación)
  --    Dispara: fn_updated_at (actualiza updated_at)
  -- --------------------------------------------------------
  UPDATE devices.device
  SET
    estado     = 'desactivado',
    encendido  = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device  = :id_device
    AND deleted_at IS NULL;

  -- Verificar que se actualizó al menos un registro
  IF NOT FOUND THEN
    RAISE EXCEPTION 'El dispositivo no existe o ya está desactivado.';
  END IF;

  SAVEPOINT sp_dispositivo_desactivado;

  -- --------------------------------------------------------
  -- 2. Desactivar horarios del dispositivo
  --    Dispara: fn_audit_log por cada horario
  --    Dispara: fn_updated_at por cada horario
  -- --------------------------------------------------------
  UPDATE devices.schedule
  SET
    activo     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device  = :id_device
    AND deleted_at IS NULL;

  SAVEPOINT sp_horarios_desactivados;

  -- --------------------------------------------------------
  -- 3. Desactivar reglas de umbral del dispositivo
  --    Dispara: fn_audit_log por cada regla
  --    Dispara: fn_updated_at por cada regla
  -- --------------------------------------------------------
  UPDATE devices.threshold_rule
  SET
    activa     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device  = :id_device
    AND deleted_at IS NULL;

  SAVEPOINT sp_umbrales_desactivados;

  -- --------------------------------------------------------
  -- 4. Registrar cambio de estado en el historial
  -- --------------------------------------------------------
  INSERT INTO devices.device_status_history (
    id_device_status_history,
    id_device,
    estado_anterior,
    estado_nuevo,
    encendido,
    origen,
    id_user,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    :id_device,
    :estado_anterior,
    'desactivado',
    FALSE,
    'usuario',
    :id_user,
    NOW()
  );

  SAVEPOINT sp_historial_registrado;

  -- --------------------------------------------------------
  -- 5. Registrar resumen en auditoría
  --    (evento agregado que el trigger individual
  --    de devices.device no cubre completamente)
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log,
    id_user,
    accion,
    modulo,
    entidad,
    id_entidad,
    resultado,
    detalle,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    :id_user,
    'eliminar',
    'dispositivos',
    'device',
    :id_device,
    'exitoso',
    'Desactivación lógica de dispositivo y sus configuraciones asociadas (horarios y umbrales)',
    NOW()
  );

COMMIT;

-- ============================================================
-- En caso de error en cualquier paso
-- ============================================================
-- ROLLBACK;