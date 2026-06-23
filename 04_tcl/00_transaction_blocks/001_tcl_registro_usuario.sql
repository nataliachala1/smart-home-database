-- ============================================================
-- TRANSACTION BLOCK — Registro de usuario
-- Archivo: 04_tcl/00_transaction_blocks/001_tcl_registro_usuario.sql
-- Descripción: Garantiza que el registro de un nuevo usuario
--              sea atómico. Incluye creación del usuario,
--              asignación del rol estándar, configuración
--              por defecto y token de confirmación.
--              Si cualquier paso falla, se revierte todo.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.1
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
--               01_ddl/03_tables/007_create_config_tables.sql
-- ============================================================

BEGIN;

  -- 1. Insertar nuevo usuario
  INSERT INTO auth.user (
    id_user, nombre, apellido, username, email, password_hash,
    tipo_documento, numero_documento, estado, email_verificado,
    created_at, updated_at
  )
  VALUES (
    :id_user, :nombre, :apellido, :username, :email,
    crypt(:password, gen_salt('bf', 12)),
    :tipo_documento, :numero_documento,
    'pendiente', FALSE,
    NOW(), NOW()
  );

  SAVEPOINT sp_usuario_creado;

  -- 2. Asignar rol estándar
  INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
  VALUES (
    uuid_generate_v4(), :id_user,
    'a1b2c3d4-0001-0000-0000-000000000002',
    NOW()
  );

  SAVEPOINT sp_rol_asignado;

  -- 3. Crear configuración por defecto
  INSERT INTO config.configuration_user (
    id_configuration_user, id_user, idioma, tema,
    formato_fecha, formato_hora, moneda, created_at, updated_at
  )
  VALUES (
    uuid_generate_v4(), :id_user,
    'es', 'claro', 'DD/MM/YYYY', '24h', 'COP',
    NOW(), NOW()
  );

  SAVEPOINT sp_config_creada;

  -- 4. Crear token de confirmación de correo
  INSERT INTO auth.recovery_token (
    id_recovery_token, id_user, token, tipo, expira_en, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user,
    :token_confirmacion,
    'activacion_cuenta',
    NOW() + INTERVAL '24 hours',
    NOW()
  );

  SAVEPOINT sp_token_creado;

  -- 5. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'crear', 'usuarios',
    'user', :id_user, 'exitoso',
    'Registro de nuevo usuario en el sistema.',
    NOW()
  );

COMMIT;

-- En caso de error en cualquier paso:
-- ROLLBACK;