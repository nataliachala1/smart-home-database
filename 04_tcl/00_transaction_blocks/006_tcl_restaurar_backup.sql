-- ============================================================
-- TCL: Restaurar Backup
-- Archivo: 04_tcl/00_transaction_blocks/006_tcl_restaurar_backup.sql
-- Descripción: Bloque transaccional que garantiza el proceso
--              atómico de restauración de un backup.
--              Valida que el usuario sea administrador,
--              crea un backup de seguridad del estado actual
--              antes de restaurar y deja constancia completa
--              en el log de auditoría. Solo administradores
--              pueden ejecutar este bloque (RF5.3)
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

BEGIN;

  -- --------------------------------------------------------
  -- 1. Validar que el usuario tenga rol administrador
  -- --------------------------------------------------------
  DO $$
  BEGIN
    IF NOT EXISTS (
      SELECT 1
      FROM auth.user_role ur
      JOIN auth.role       r ON r.id_role    = ur.id_role
      WHERE ur.id_user    = :'id_admin'::UUID
        AND r.nombre      = 'administrador'
        AND ur.deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'El usuario no tiene permisos de administrador para ejecutar restauraciones.';
    END IF;
  END $$;

  SAVEPOINT sp_validacion_admin;

  -- --------------------------------------------------------
  -- 2. Validar que el backup a restaurar exista y sea válido
  -- --------------------------------------------------------
  DO $$
  DECLARE
    v_estado VARCHAR(20);
  BEGIN
    SELECT estado INTO v_estado
    FROM sync.backup
    WHERE id_backup = :'id_backup'::UUID;

    IF v_estado IS NULL THEN
      RAISE EXCEPTION 'El backup indicado no existe.';
    ELSIF v_estado <> 'completado' THEN
      RAISE EXCEPTION 'El backup no está en estado completado y no puede restaurarse. Estado actual: %', v_estado;
    END IF;
  END $$;

  SAVEPOINT sp_validacion_backup;

  -- --------------------------------------------------------
  -- 3. Registrar inicio de restauración en auditoría
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
    :id_admin,
    'restaurar',
    'sync',
    'backup',
    :id_backup,
    'exitoso',
    CONCAT('Inicio de restauración de backup. Motivo: ', :motivo),
    NOW()
  );

  SAVEPOINT sp_auditoria_inicio;

  -- --------------------------------------------------------
  -- 4. Crear backup de seguridad del estado actual
  --    Dispara: fn_audit_log (registra creación del backup)
  -- --------------------------------------------------------
  INSERT INTO sync.backup (
    id_backup,
    id_user,
    tipo,
    alcance,
    ubicacion,
    estado,
    descripcion,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    :id_admin,
    'automatico',
    'completo',
    :ubicacion_backup_seguridad,
    'completado',
    CONCAT('Backup de seguridad automático previo a restauración del backup: ', :id_backup),
    NOW()
  );

  SAVEPOINT sp_backup_seguridad;

  -- --------------------------------------------------------
  -- 5. NOTA: La restauración física de los datos (hogares,
  --    dispositivos, configuraciones) se ejecuta a nivel
  --    de infraestructura (pg_restore, snapshot, etc.)
  --    fuera de este bloque transaccional. Este bloque
  --    garantiza la trazabilidad y el respaldo previo
  --    exigidos por el SRS (RF5.3)
  -- --------------------------------------------------------

  -- --------------------------------------------------------
  -- 6. Registrar finalización del proceso en auditoría
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
    :id_admin,
    'restaurar',
    'sync',
    'backup',
    :id_backup,
    'exitoso',
    'Restauración de backup registrada exitosamente. Backup de seguridad creado previamente.',
    NOW()
  );

COMMIT;

-- ============================================================
-- En caso de error en cualquier paso
-- ============================================================
-- ROLLBACK;