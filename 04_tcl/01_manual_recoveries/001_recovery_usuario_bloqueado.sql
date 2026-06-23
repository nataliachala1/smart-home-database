-- Recuperación manual de usuario bloqueado
BEGIN;

  UPDATE auth.user
  SET estado = 'activo', intentos_fallidos = 0, updated_at = NOW()
  WHERE id_user = :id_user AND estado = 'bloqueado';

  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  ) VALUES (
    uuid_generate_v4(), :id_user, 'recuperacion', 'auth',
    'user', :id_user, 'exitoso',
    'Recuperación manual de usuario bloqueado', NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
