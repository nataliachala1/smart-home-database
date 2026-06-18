-- ============================================================
-- PROCEDIMIENTO: sp_registrar_usuario
-- Archivo: 01_ddl/07_procedures/001_sp_registrar_usuario.sql
-- Descripción: Orquesta el registro completo de un nuevo
--              usuario: inserta el usuario, asigna el rol
--              estándar y genera el token de confirmación
--              de correo. La configuración por defecto del
--              usuario y el registro de auditoría se generan
--              automáticamente vía triggers
--              (fn_config_user, fn_audit_log)
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.1
-- Dependencias: 03_tables/auth, 06_triggers/002_trg_audit_log,
--               06_triggers/003_trg_config_user
-- ============================================================

CREATE OR REPLACE PROCEDURE sp_registrar_usuario(
  IN  p_nombre           VARCHAR(100),
  IN  p_apellido         VARCHAR(100),
  IN  p_username         VARCHAR(50),
  IN  p_email            VARCHAR(255),
  IN  p_password         TEXT,
  IN  p_tipo_documento   VARCHAR(20),
  IN  p_numero_documento VARCHAR(30),
  OUT p_id_user          UUID,
  OUT p_token            TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
  v_id_role_estandar CONSTANT UUID := 'a1b2c3d4-0001-0000-0000-000000000002';
BEGIN

  -- --------------------------------------------------------
  -- 1. Generar identificadores
  -- --------------------------------------------------------
  p_id_user := uuid_generate_v4();
  p_token   := encode(gen_random_bytes(32), 'hex');

  -- --------------------------------------------------------
  -- 2. Insertar usuario con estado pendiente
  --    Dispara: fn_config_user (crea configuración por
  --    defecto), fn_audit_log (registra creación)
  -- --------------------------------------------------------
  INSERT INTO auth.user (
    id_user, nombre, apellido, username, email, password_hash,
    tipo_documento, numero_documento, estado, email_verificado,
    created_at, updated_at
  )
  VALUES (
    p_id_user, p_nombre, p_apellido, p_username, p_email,
    crypt(p_password, gen_salt('bf', 12)),
    p_tipo_documento, p_numero_documento,
    'pendiente', FALSE,
    NOW(), NOW()
  );

  -- --------------------------------------------------------
  -- 3. Asignar rol estándar
  -- --------------------------------------------------------
  INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
  VALUES (uuid_generate_v4(), p_id_user, v_id_role_estandar, NOW());

  -- --------------------------------------------------------
  -- 4. Crear token de confirmación de cuenta (24 horas)
  -- --------------------------------------------------------
  INSERT INTO auth.recovery_token (
    id_recovery_token, id_user, token, tipo, expira_en, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_user, p_token,
    'activacion_cuenta', NOW() + INTERVAL '24 hours', NOW()
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El correo, username o documento ya están registrados en el sistema.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al registrar el usuario: %', SQLERRM;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_usuario(VARCHAR, VARCHAR, VARCHAR, VARCHAR, TEXT, VARCHAR, VARCHAR, UUID, TEXT)
  IS 'Registra un nuevo usuario, le asigna el rol estándar y genera su token de confirmación. La configuración por defecto y la auditoría se generan automáticamente vía triggers.';

-- ============================================================
-- EJEMPLO DE USO
-- ============================================================
-- CALL sp_registrar_usuario(
--   'Juan', 'Pérez', 'juanperez', 'juan@example.com',
--   'Clave#Segura123', 'CC', '1234567890',
--   NULL, NULL  -- parámetros OUT, se completan al ejecutar
-- );