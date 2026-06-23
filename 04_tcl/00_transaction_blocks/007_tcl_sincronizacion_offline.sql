-- ============================================================
-- TCL: Sincronización de Cola Offline
-- Archivo: 04_tcl/00_transaction_blocks/007_tcl_sincronizacion_offline.sql
-- Descripción: Bloque transaccional que procesa la cola de
--              acciones realizadas en modo offline. Cada
--              acción se procesa individualmente con su
--              propio SAVEPOINT: si una falla, solo se
--              revierte esa acción y las demás continúan.
--              Al finalizar registra la sincronización
--              en sync.synchronization (RF5.4)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF5.4, RNF4.5
-- Dependencias: 03_tables/sync, 03_tables/auth
-- ============================================================

BEGIN;

  -- --------------------------------------------------------
  -- 1. Verificar que el usuario tenga acciones pendientes
  -- --------------------------------------------------------
  DO $$
  BEGIN
    IF NOT EXISTS (
      SELECT 1
      FROM sync.offline_queue
      WHERE id_user = :'id_user'::UUID
        AND estado  = 'pendiente'
    ) THEN
      RAISE NOTICE 'No hay acciones pendientes de sincronización para este usuario.';
    END IF;
  END $$;

  SAVEPOINT sp_verificacion_cola;

  -- --------------------------------------------------------
  -- 2. Procesar cada acción pendiente individualmente
  --
  --    El backend itera sobre las acciones pendientes y
  --    por cada una ejecuta el siguiente bloque:
  --
  --    SAVEPOINT sp_antes_accion;
  --
  --    [Ejecutar la acción correspondiente según tipo_accion]
  --    [ej: encender dispositivo, actualizar configuración]
  --
  --    -- Si la acción fue exitosa:
  --    UPDATE sync.offline_queue
  --    SET
  --      estado       = 'procesada',
  --      procesada_at = NOW()
  --    WHERE id_offline_queue = :id_accion
  --      AND estado           = 'pendiente';
  --
  --    -- Si la acción falló:
  --    ROLLBACK TO SAVEPOINT sp_antes_accion;
  --    UPDATE sync.offline_queue
  --    SET
  --      estado       = 'fallida',
  --      intentos     = intentos + 1,
  --      procesada_at = NOW()
  --    WHERE id_offline_queue = :id_accion;
  -- --------------------------------------------------------

  -- Ejemplo para una acción individual:
  SAVEPOINT sp_antes_accion;

  UPDATE sync.offline_queue
  SET
    estado       = 'procesada',
    procesada_at = NOW()
  WHERE id_offline_queue = :id_accion
    AND estado           = 'pendiente';

  SAVEPOINT sp_accion_procesada;

  -- --------------------------------------------------------
  -- 3. Registrar la sincronización completada
  --    en sync.synchronization
  -- --------------------------------------------------------
  INSERT INTO sync.synchronization (
    id_synchronization,
    id_user,
    tipo,
    estado,
    dispositivos_sincronizados,
    errores,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    :id_user,
    'manual',
    'exitosa',
    :total_dispositivos_sincronizados,
    NULL,
    NOW()
  );

  SAVEPOINT sp_sincronizacion_registrada;

  -- --------------------------------------------------------
  -- 4. Registrar en auditoría
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log,
    id_user,
    accion,
    modulo,
    resultado,
    detalle,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    :id_user,
    'configurar',
    'sync',
    'exitoso',
    CONCAT(
      'Sincronización offline completada. Acciones procesadas: ',
      :total_dispositivos_sincronizados
    ),
    NOW()
  );

COMMIT;

-- ============================================================
-- En caso de error total (no recuperable)
-- ============================================================
-- ROLLBACK;

-- ============================================================
-- NOTA SOBRE ACCIONES FALLIDAS INDIVIDUALES
-- ============================================================
-- Si una acción individual falla durante el procesamiento
-- (paso 2), el patrón correcto es:
--
--   ROLLBACK TO SAVEPOINT sp_antes_accion;
--   UPDATE sync.offline_queue
--   SET estado = 'fallida', intentos = intentos + 1, procesada_at = NOW()
--   WHERE id_offline_queue = :id_accion;
--
-- Esto revierte SOLO esa acción sin afectar el resto de la
-- transacción ni las acciones ya procesadas exitosamente.
-- Las acciones fallidas pueden reintentarse en la próxima
-- sincronización mientras intentos < máximo permitido.
-- ============================================================