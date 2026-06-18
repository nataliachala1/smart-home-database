-- ============================================================
-- PROCEDIMIENTO: sp_restaurar_backup
-- Archivo: 01_ddl/07_procedures/006_sp_restaurar_backup.sql
-- Descripción: Orquesta el proceso de restauración de un
--              backup. Valida que el usuario tenga rol de
--              administrador, registra un backup de
--              seguridad del estado actual antes de
--              restaurar y deja constancia del proceso.
--              Solo administradores pueden ejecutar este
--              procedimiento (RF5.3)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF5.3
-- Dependencias: 03_tables/auth, 03_tables/sync,
--               06_triggers/002_trg_audit_log
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_restaurar_backup(
  IN  p_id_admin               UUID,
  IN  p_id_backup_a_restaurar  UUID,
  IN  p_motivo                 TEXT,
  IN  p_ubicacion_backup_seg   TEXT,
  OUT p_id_backup_seguridad    UUID
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_estado_backup VARCHAR(20);
BEGIN

  -- --------------------------------------------------------
  -- 1. Validar que el usuario tenga rol administrador
  -- --------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1
    FROM auth.user_role ur
    JOIN auth.role       r ON r.id_role = ur.id_role
    WHERE ur.id_user    = p_id_admin
      AND r.nombre      = 'administrador'
      AND ur.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'El usuario no tiene permisos de administrador para ejecutar restauraciones.';
  END IF;

  -- --------------------------------------------------------
  -- 2. Validar que el backup a restaurar exista y sea válido
  -- --------------------------------------------------------
  SELECT estado INTO v_estado_backup
  FROM sync.backup
  WHERE id_backup = p_id_backup_a_restaurar;

  IF v_estado_backup IS NULL THEN
    RAISE EXCEPTION 'El backup indicado no existe.';
  ELSIF v_estado_backup <> 'completado' THEN
    RAISE EXCEPTION 'El backup no está en estado completado y no puede restaurarse.';
  END IF;

  -- --------------------------------------------------------
  -- 3. Crear backup de seguridad del estado actual
  --    Dispara: fn_audit_log (registra creación del backup)
  -- --------------------------------------------------------
  p_id_backup_seguridad := uuid_generate_v4();

  INSERT INTO sync.backup (
    id_backup, id_user, tipo, alcance,
    ubicacion, estado, descripcion, created_at
  )
  VALUES (
    p_id_backup_seguridad, p_id_admin, 'automatico', 'completo',
    p_ubicacion_backup_seg, 'completado',
    CONCAT('Backup de seguridad automático previo a restauración del backup: ', p_id_backup_a_restaurar),
    NOW()
  );

  -- --------------------------------------------------------
  -- 4. Registrar inicio del proceso de restauración
  --    (evento informativo, no cubierto por trigger porque
  --    no corresponde a un INSERT/UPDATE sobre sync.backup)
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_admin, 'restaurar', 'sync',
    'backup', p_id_backup_a_restaurar, 'exitoso',
    CONCAT('Inicio de restauración de backup. Motivo: ', p_motivo),
    NOW()
  );

  -- --------------------------------------------------------
  -- 5. NOTA: La restauración física de los datos (hogares,
  -- dispositivos, configuraciones) depende de la herramienta
  -- de backup utilizada (pg_restore, snapshot, etc.) y se
  -- ejecuta fuera de este procedimiento, a nivel de
  -- infraestructura. Este procedimiento garantiza la
  -- trazabilidad y el respaldo previo exigidos por el SRS.
  -- --------------------------------------------------------

  -- --------------------------------------------------------
  -- 6. Registrar finalización del proceso
  -- --------------------------------------------------------
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_admin, 'restaurar', 'sync',
    'backup', p_id_backup_a_restaurar, 'exitoso',
    'Restauración registrada exitosamente. Backup de seguridad creado previamente.',
    NOW()
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al restaurar el backup: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_restaurar_backup(UUID, UUID, TEXT, TEXT, UUID)
  IS 'Valida permisos de administrador, crea un backup de seguridad del estado actual y registra el proceso de restauración. Solo administradores pueden ejecutarlo.';

-- ============================================================
-- EJEMPLO DE USO
-- ============================================================
-- CALL sp_restaurar_backup(
--   'a1b2c3d4-9999-0000-0000-000000000001'::UUID,  -- id_admin
--   'a1b2c3d4-0000-0000-0000-000000000010'::UUID,  -- id_backup_a_restaurar
--   'El usuario reportó pérdida de datos de sus hogares',
--   's3://smarthome-backups/seguridad/2025-06-17.sql',
--   NULL  -- parámetro OUT, se completa al ejecutar
-- );