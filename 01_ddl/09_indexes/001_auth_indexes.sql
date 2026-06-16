-- ============================================================
-- ÍNDICES — Esquema auth
-- Archivo: 01_ddl/09_indexes/001_auth_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema auth. Incluye índices simples
--              y compuestos para los patrones de consulta más
--              frecuentes del sistema de autenticación.
-- ============================================================
-- TABLA: auth.user
-- ============================================================

-- Búsqueda rápida por correo electrónico (login, recuperación)
CREATE INDEX IF NOT EXISTS idx_user_email
  ON auth.user (email)
  WHERE deleted_at IS NULL;

-- Búsqueda rápida por nombre de usuario
CREATE INDEX IF NOT EXISTS idx_user_username
  ON auth.user (username)
  WHERE deleted_at IS NULL;

-- Búsqueda por número de documento (validación de unicidad)
CREATE INDEX IF NOT EXISTS idx_user_numero_documento
  ON auth.user (numero_documento)
  WHERE deleted_at IS NULL;

-- Filtrado por estado de cuenta (pendiente, activo, desactivado, bloqueado)
CREATE INDEX IF NOT EXISTS idx_user_estado
  ON auth.user (estado)
  WHERE deleted_at IS NULL;

-- Cuentas bloqueadas con tiempo de bloqueo vigente (job de desbloqueo automático)
CREATE INDEX IF NOT EXISTS idx_user_bloqueado_hasta
  ON auth.user (bloqueado_hasta)
  WHERE estado = 'bloqueado' AND deleted_at IS NULL;

-- Compuesto: email + estado (login: busca email y valida estado en una sola pasada)
CREATE INDEX IF NOT EXISTS idx_user_email_estado
  ON auth.user (email, estado)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: auth.role
-- ============================================================

-- Búsqueda por nombre de rol
CREATE INDEX IF NOT EXISTS idx_role_nombre
  ON auth.role (nombre)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: auth.permission
-- ============================================================

-- Filtrado por módulo (consultar permisos de un módulo)
CREATE INDEX IF NOT EXISTS idx_permission_modulo
  ON auth.permission (modulo)
  WHERE deleted_at IS NULL;

-- Filtrado por acción
CREATE INDEX IF NOT EXISTS idx_permission_accion
  ON auth.permission (accion)
  WHERE deleted_at IS NULL;

-- Compuesto: módulo + acción (búsqueda de permiso específico)
CREATE INDEX IF NOT EXISTS idx_permission_modulo_accion
  ON auth.permission (modulo, accion)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: auth.user_role
-- ============================================================

-- Búsqueda de roles asignados a un usuario
CREATE INDEX IF NOT EXISTS idx_user_role_id_user
  ON auth.user_role (id_user)
  WHERE deleted_at IS NULL;

-- Búsqueda de usuarios con un rol específico
CREATE INDEX IF NOT EXISTS idx_user_role_id_role
  ON auth.user_role (id_role)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: auth.role_permission
-- ============================================================

-- Búsqueda de permisos asignados a un rol
CREATE INDEX IF NOT EXISTS idx_role_permission_id_role
  ON auth.role_permission (id_role)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: auth.session
-- ============================================================

-- Búsqueda de sesiones por usuario
CREATE INDEX IF NOT EXISTS idx_session_id_user
  ON auth.session (id_user)
  WHERE deleted_at IS NULL;

-- Validación rápida del token JWT
CREATE INDEX IF NOT EXISTS idx_session_token
  ON auth.session (token)
  WHERE activa = TRUE AND deleted_at IS NULL;

-- Filtrado de sesiones activas
CREATE INDEX IF NOT EXISTS idx_session_activa
  ON auth.session (activa)
  WHERE deleted_at IS NULL;

-- Sesiones expiradas (job de limpieza automática)
CREATE INDEX IF NOT EXISTS idx_session_expira_en
  ON auth.session (expira_en)
  WHERE activa = TRUE;

-- Compuesto: usuario + activa (sesiones activas de un usuario)
CREATE INDEX IF NOT EXISTS idx_session_id_user_activa
  ON auth.session (id_user, activa)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: auth.mfa
-- ============================================================

-- Búsqueda de configuración MFA por usuario
CREATE INDEX IF NOT EXISTS idx_mfa_id_user
  ON auth.mfa (id_user);

-- Configuraciones MFA habilitadas
CREATE INDEX IF NOT EXISTS idx_mfa_habilitado
  ON auth.mfa (habilitado)
  WHERE habilitado = TRUE;

-- ============================================================
-- TABLA: auth.recovery_token
-- ============================================================

-- Validación rápida del token de recuperación
CREATE INDEX IF NOT EXISTS idx_recovery_token_token
  ON auth.recovery_token (token)
  WHERE usado = FALSE;

-- Búsqueda de tokens por usuario
CREATE INDEX IF NOT EXISTS idx_recovery_token_id_user
  ON auth.recovery_token (id_user);

-- Tokens expirados no usados (job de limpieza)
CREATE INDEX IF NOT EXISTS idx_recovery_token_expira_en
  ON auth.recovery_token (expira_en)
  WHERE usado = FALSE;

-- Compuesto: usuario + tipo (buscar token activo de un tipo específico)
CREATE INDEX IF NOT EXISTS idx_recovery_token_user_tipo
  ON auth.recovery_token (id_user, tipo)
  WHERE usado = FALSE;

-- ============================================================
-- TABLA: auth.token_blacklist
-- ============================================================

-- Verificación rápida de tokens revocados (cada request autenticado)
CREATE INDEX IF NOT EXISTS idx_token_blacklist_token
  ON auth.token_blacklist (token);

-- Tokens expirados (job de purga periódica)
CREATE INDEX IF NOT EXISTS idx_token_blacklist_expira_en
  ON auth.token_blacklist (expira_en);