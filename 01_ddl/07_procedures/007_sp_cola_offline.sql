-- ============================================================
-- PROCEDIMIENTO: sp_procesar_cola_offline
-- Archivo: 01_ddl/07_procedures/007_sp_procesar_cola_offline.sql
-- Descripción: Procesa la cola de acciones pendientes
--              realizadas por un usuario en modo offline.
--              Ejecuta cada acción en orden FIFO, actualiza
--              su estado y registra la sincronización
--              completada. Si una acción falla, la marca
--              como fallida sin detener el proceso completo.
--              (RF5.4)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF5.4
-- Dependencias: 03_tables/sync, 03_tables/devices,
--               03_tables/auth,
--               06_triggers/002_trg_audit_log
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_procesar_cola_offline(
  IN  p_id_user            UUID,
  OUT p_total_procesadas   INT,
  OUT p_total_fallidas     INT,
  OUT p_id_synchronization UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_accion        RECORD;
  v_tipo_accion   VARCHAR(50);
  v_payload       JSONB;
  v_id_device     UUID;
  v_encendido     BOOLEAN;
BEGIN
  -- Inicializar contadores
  p_total_procesadas   := 0;
  p_total_fallidas     := 0;
  p_id_synchronization := uuid_generate_v4();

  -- --------------------------------------------------------
  -- 1. Registrar inicio de sincronización
  -- --------------------------------------------------------
  INSERT INTO sync.synchronization (
    id_synchronization, id_user, tipo, estado,
    dispositivos_sincronizados, created_at
  )
  VALUES (
    p_id_synchronization, p_id_user, 'manual', 'exitosa',
    0, NOW()
  );

  -- --------------------------------------------------------
  -- 2. Iterar sobre acciones pendientes en orden FIFO
  -- --------------------------------------------------------
  FOR v_accion IN
    SELECT id_offline_queue, tipo_accion, payload
    FROM sync.offline_queue
    WHERE id_user = p_id_user
      AND estado  = 'pendiente'
    ORDER BY created_at ASC
  LOOP
    BEGIN
      v_tipo_accion := v_accion.tipo_accion;
      v_payload     := v_accion.payload;

      -- ------------------------------------------------------
      -- 2a. Procesar según el tipo de acción
      -- ------------------------------------------------------

      -- Encender dispositivo
      IF v_tipo_accion = 'encender_dispositivo' THEN
        v_id_device := (v_payload->>'id_device')::UUID;

        UPDATE devices.device
        SET
          encendido  = TRUE,
          updated_at = NOW()
        WHERE id_device  = v_id_device
          AND deleted_at IS NULL;

      -- Apagar dispositivo
      ELSIF v_tipo_accion = 'apagar_dispositivo' THEN
        v_id_device := (v_payload->>'id_device')::UUID;

        UPDATE devices.device
        SET
          encendido  = FALSE,
          updated_at = NOW()
        WHERE id_device  = v_id_device
          AND deleted_at IS NULL;

      -- Actualizar configuración de dispositivo
      ELSIF v_tipo_accion = 'actualizar_config' THEN
        v_id_device := (v_payload->>'id_device')::UUID;

        UPDATE devices.device
        SET
          nombre     = COALESCE(v_payload->>'nombre', nombre),
          updated_at = NOW()
        WHERE id_device  = v_id_device
          AND deleted_at IS NULL;

      ELSE
        -- Tipo de acción no reconocido, marcar como fallida
        RAISE EXCEPTION 'Tipo de acción no reconocido: %', v_tipo_accion;
      END IF;

      -- ------------------------------------------------------
      -- 2b. Marcar acción como procesada exitosamente
      -- ------------------------------------------------------
      UPDATE sync.offline_queue
      SET
        estado       = 'procesada',
        procesada_at = NOW()
      WHERE id_offline_queue = v_accion.id_offline_queue;

      p_total_procesadas := p_total_procesadas + 1;

    EXCEPTION
      WHEN OTHERS THEN
        -- --------------------------------------------------
        -- 2c. Marcar acción como fallida sin detener el loop
        -- --------------------------------------------------
        UPDATE sync.offline_queue
        SET
          estado    = 'fallida',
          intentos  = intentos + 1
        WHERE id_offline_queue = v_accion.id_offline_queue;

        p_total_fallidas := p_total_fallidas + 1;
    END;
  END LOOP;

  -- --------------------------------------------------------
  -- 3. Actualizar registro de sincronización con totales
  -- --------------------------------------------------------
  UPDATE sync.synchronization
  SET
    dispositivos_sincronizados = p_total_procesadas,
    estado = CASE
               WHEN p_total_fallidas = 0 THEN 'exitosa'
               WHEN p_total_procesadas = 0 THEN 'fallida'
               ELSE 'parcial'
             END,
    errores = CASE
                WHEN p_total_fallidas > 0
                THEN CONCAT(p_total_fallidas, ' acción(es) no pudieron procesarse.')
                ELSE NULL
              END
  WHERE id_synchronization = p_id_synchronization;

  -- --------------------------------------------------------
  -- 4. Registrar en auditoría
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_user, 'editar', 'sync',
    'offline_queue', p_id_synchronization,
    CASE WHEN p_total_fallidas = 0 THEN 'exitoso' ELSE 'fallido' END,
    CONCAT(
      'Sincronización offline completada. Procesadas: ', p_total_procesadas,
      ', Fallidas: ', p_total_fallidas
    ),
    NOW()
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error crítico al procesar la cola offline: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_procesar_cola_offline(UUID, INT, INT, UUID)
  IS 'Procesa en orden FIFO las acciones pendientes de un usuario en modo offline. Marca cada acción como procesada o fallida individualmente y registra el resultado de la sincronización.';

-- ============================================================
-- EJEMPLO DE USO
-- ============================================================
-- DO $$
-- DECLARE
--   v_procesadas   INT;
--   v_fallidas     INT;
--   v_id_sync      UUID;
-- BEGIN
--   CALL sp_procesar_cola_offline(
--     'uuid-del-usuario'::UUID,
--     v_procesadas,
--     v_fallidas,
--     v_id_sync
--   );
--   RAISE NOTICE 'Procesadas: %, Fallidas: %, Sync ID: %',
--     v_procesadas, v_fallidas, v_id_sync;
-- END;
-- $$;