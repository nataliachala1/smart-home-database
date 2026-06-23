-- Recuperación manual de hogar desactivado
BEGIN;

  UPDATE homes.home
  SET estado = 'activo', updated_at = NOW()
  WHERE id_home = :id_home AND estado = 'desactivado';

  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  ) VALUES (
    uuid_generate_v4(), :id_user, 'recuperacion', 'homes',
    'home', :id_home, 'exitoso',
    'Recuperación manual de hogar desactivado', NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
