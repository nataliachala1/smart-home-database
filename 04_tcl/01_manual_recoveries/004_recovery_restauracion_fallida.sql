-- Recuperación manual tras restauración fallida
BEGIN;

  UPDATE sync.synchronization
  SET estado = 'fallido', updated_at = NOW()
  WHERE id_synchronization = :id_synchronization;

  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  ) VALUES (
    uuid_generate_v4(), :id_user, 'recuperacion', 'sync',
    'synchronization', :id_synchronization, 'fallido',
    'Recuperación manual de restauración de backup fallida', NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
