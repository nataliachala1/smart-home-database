-- ============================================================
-- TABLAS — Esquema auth
-- Archivo: 01_ddl/03_tables/001_create_auth_tables.sql
-- Descripción: Creación de las 9 tablas del esquema auth
--              para gestión de usuarios, autenticación,
--              roles, permisos y seguridad del sistema
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas
-- ============================================================

-- ============================================================
-- TABLA: auth.role
-- Descripción: Define los roles disponibles en el sistema
--              que determinan los niveles de acceso
-- Referencia SRS: RF1.3
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.role (
  id_role     UUID          NOT NULL DEFAULT uuid_generate_v4(),
  nombre      VARCHAR(50)   NOT NULL,
  descripcion TEXT          NULL,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at  TIMESTAMPTZ   NULL,

  CONSTRAINT pk_role PRIMARY KEY (id_role),
  CONSTRAINT uq_role_nombre UNIQUE (nombre)
);

COMMENT ON TABLE  auth.role             IS 'Roles disponibles en el sistema Smart Home.';
COMMENT ON COLUMN auth.role.id_role     IS 'Identificador único del rol.';
COMMENT ON COLUMN auth.role.nombre      IS 'Nombre del rol: administrador, estandar, invitado.';
COMMENT ON COLUMN auth.role.descripcion IS 'Descripción del propósito del rol.';
COMMENT ON COLUMN auth.role.created_at  IS 'Fecha de creación del registro.';
COMMENT ON COLUMN auth.role.updated_at  IS 'Fecha de última actualización.';
COMMENT ON COLUMN auth.role.deleted_at  IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: auth.permission
-- Descripción: Catálogo de permisos disponibles en el sistema,
--              asociados a módulos y acciones específicas
-- Referencia SRS: RF1.3
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.permission (
  id_permission UUID          NOT NULL DEFAULT uuid_generate_v4(),
  nombre        VARCHAR(100)  NOT NULL,
  modulo        VARCHAR(50)   NOT NULL,
  accion        VARCHAR(50)   NOT NULL,
  descripcion   TEXT          NULL,
  created_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ   NULL,

  CONSTRAINT pk_permission PRIMARY KEY (id_permission),
  CONSTRAINT uq_permission_nombre UNIQUE (nombre)
);

COMMENT ON TABLE  auth.permission               IS 'Catálogo de permisos del sistema por módulo y acción.';
COMMENT ON COLUMN auth.permission.id_permission IS 'Identificador único del permiso.';
COMMENT ON COLUMN auth.permission.nombre        IS 'Nombre único del permiso (ej: hogares:crear).';
COMMENT ON COLUMN auth.permission.modulo        IS 'Módulo al que pertenece el permiso.';
COMMENT ON COLUMN auth.permission.accion        IS 'Acción que habilita: leer, crear, editar, eliminar.';
COMMENT ON COLUMN auth.permission.descripcion   IS 'Descripción detallada del permiso.';
COMMENT ON COLUMN auth.permission.created_at    IS 'Fecha de creación del registro.';
COMMENT ON COLUMN auth.permission.updated_at    IS 'Fecha de última actualización.';
COMMENT ON COLUMN auth.permission.deleted_at    IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: auth.user
-- Descripción: Almacena los usuarios registrados en el sistema.
--              Incluye datos personales, credenciales y estado
-- Referencia SRS: RF1.1, RF1.2, RF1.5, RF1.6, RF1.7, RF1.8
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.user (
  id_user           UUID          NOT NULL DEFAULT uuid_generate_v4(),
  nombre            VARCHAR(100)  NOT NULL,
  apellido          VARCHAR(100)  NOT NULL,
  username          VARCHAR(50)   NOT NULL,
  email             VARCHAR(255)  NOT NULL,
  password_hash     TEXT          NOT NULL,
  tipo_documento    VARCHAR(20)   NOT NULL,
  numero_documento  VARCHAR(30)   NOT NULL,
  estado            VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
  email_verificado  BOOLEAN       NOT NULL DEFAULT FALSE,
  intentos_fallidos SMALLINT      NOT NULL DEFAULT 0,
  bloqueado_hasta   TIMESTAMPTZ   NULL,
  mfa_habilitado    BOOLEAN       NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ   NULL,

  CONSTRAINT pk_user                PRIMARY KEY (id_user),
  CONSTRAINT uq_user_email          UNIQUE (email),
  CONSTRAINT uq_user_username       UNIQUE (username),
  CONSTRAINT uq_user_documento      UNIQUE (numero_documento),
  CONSTRAINT ck_user_estado         CHECK (estado IN ('pendiente', 'activo', 'desactivado', 'bloqueado')),
  CONSTRAINT ck_user_tipo_documento CHECK (tipo_documento IN ('CC', 'CE', 'PAS')),
  CONSTRAINT ck_user_intentos       CHECK (intentos_fallidos >= 0)
);

COMMENT ON TABLE  auth.user                   IS 'Usuarios registrados en el sistema Smart Home.';
COMMENT ON COLUMN auth.user.id_user           IS 'Identificador único del usuario.';
COMMENT ON COLUMN auth.user.nombre            IS 'Nombre del usuario.';
COMMENT ON COLUMN auth.user.apellido          IS 'Apellido del usuario.';
COMMENT ON COLUMN auth.user.username          IS 'Nombre de usuario único en el sistema.';
COMMENT ON COLUMN auth.user.email             IS 'Correo electrónico único del usuario.';
COMMENT ON COLUMN auth.user.password_hash     IS 'Contraseña encriptada con pgcrypto (bcrypt).';
COMMENT ON COLUMN auth.user.tipo_documento    IS 'Tipo de documento: CC, CE, PAS.';
COMMENT ON COLUMN auth.user.numero_documento  IS 'Número de documento de identidad único.';
COMMENT ON COLUMN auth.user.estado            IS 'Estado de la cuenta: pendiente, activo, desactivado, bloqueado.';
COMMENT ON COLUMN auth.user.email_verificado  IS 'Indica si el correo fue verificado.';
COMMENT ON COLUMN auth.user.intentos_fallidos IS 'Contador de intentos fallidos de inicio de sesión.';
COMMENT ON COLUMN auth.user.bloqueado_hasta   IS 'Fecha y hora hasta la que la cuenta está bloqueada.';
COMMENT ON COLUMN auth.user.mfa_habilitado    IS 'Indica si la autenticación multifactor está activa.';
COMMENT ON COLUMN auth.user.created_at        IS 'Fecha de creación del registro.';
COMMENT ON COLUMN auth.user.updated_at        IS 'Fecha de última actualización.';
COMMENT ON COLUMN auth.user.deleted_at        IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: auth.user_role
-- Descripción: Relación muchos a muchos entre usuarios y roles
-- Referencia SRS: RF1.3
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.user_role (
  id_user_role UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user      UUID        NOT NULL,
  id_role      UUID        NOT NULL,
  asignado_por UUID        NULL,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ NULL,

  CONSTRAINT pk_user_role          PRIMARY KEY (id_user_role),
  CONSTRAINT uq_user_role          UNIQUE (id_user, id_role),
  CONSTRAINT fk_user_role_user     FOREIGN KEY (id_user)      REFERENCES auth.user (id_user),
  CONSTRAINT fk_user_role_role     FOREIGN KEY (id_role)      REFERENCES auth.role (id_role),
  CONSTRAINT fk_user_role_asignado FOREIGN KEY (asignado_por) REFERENCES auth.user (id_user)
);

COMMENT ON TABLE  auth.user_role               IS 'Asignación de roles a usuarios del sistema.';
COMMENT ON COLUMN auth.user_role.id_user_role  IS 'Identificador único de la asignación.';
COMMENT ON COLUMN auth.user_role.id_user       IS 'Usuario al que se asigna el rol.';
COMMENT ON COLUMN auth.user_role.id_role       IS 'Rol asignado al usuario.';
COMMENT ON COLUMN auth.user_role.asignado_por  IS 'Administrador que realizó la asignación.';
COMMENT ON COLUMN auth.user_role.created_at    IS 'Fecha de asignación del rol.';
COMMENT ON COLUMN auth.user_role.deleted_at    IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: auth.role_permission
-- Descripción: Relación muchos a muchos entre roles y permisos
-- Referencia SRS: RF1.3
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.role_permission (
  id_role_permission UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_role            UUID        NOT NULL,
  id_permission      UUID        NOT NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at         TIMESTAMPTZ NULL,

  CONSTRAINT pk_role_permission      PRIMARY KEY (id_role_permission),
  CONSTRAINT uq_role_permission      UNIQUE (id_role, id_permission),
  CONSTRAINT fk_role_permission_role FOREIGN KEY (id_role)       REFERENCES auth.role (id_role),
  CONSTRAINT fk_role_permission_perm FOREIGN KEY (id_permission) REFERENCES auth.permission (id_permission)
);

COMMENT ON TABLE  auth.role_permission                  IS 'Asignación de permisos a roles del sistema.';
COMMENT ON COLUMN auth.role_permission.id_role_permission IS 'Identificador único de la asignación.';
COMMENT ON COLUMN auth.role_permission.id_role            IS 'Rol al que se asigna el permiso.';
COMMENT ON COLUMN auth.role_permission.id_permission      IS 'Permiso asignado al rol.';
COMMENT ON COLUMN auth.role_permission.created_at         IS 'Fecha de asignación del permiso.';
COMMENT ON COLUMN auth.role_permission.deleted_at         IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: auth.session
-- Descripción: Registra las sesiones activas de los usuarios,
--              incluyendo token de acceso y datos del dispositivo
-- Referencia SRS: RF1.2, RF1.4, RNF5.4
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.session (
  id_session    UUID         NOT NULL DEFAULT uuid_generate_v4(),
  id_user       UUID         NOT NULL,
  token         TEXT         NOT NULL,
  refresh_token TEXT         NULL,
  ip_address    VARCHAR(45)  NULL,
  user_agent    TEXT         NULL,
  recordar_sesion BOOLEAN    NOT NULL DEFAULT FALSE,
  expira_en     TIMESTAMPTZ  NOT NULL,
  activa        BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at    TIMESTAMPTZ  NULL,

  CONSTRAINT pk_session           PRIMARY KEY (id_session),
  CONSTRAINT uq_session_token     UNIQUE (token),
  CONSTRAINT uq_session_refresh   UNIQUE (refresh_token),
  CONSTRAINT fk_session_user      FOREIGN KEY (id_user) REFERENCES auth.user (id_user)
);

COMMENT ON TABLE  auth.session                IS 'Sesiones activas de usuarios en el sistema.';
COMMENT ON COLUMN auth.session.id_session     IS 'Identificador único de la sesión.';
COMMENT ON COLUMN auth.session.id_user        IS 'Usuario dueño de la sesión.';
COMMENT ON COLUMN auth.session.token          IS 'Token JWT de la sesión.';
COMMENT ON COLUMN auth.session.refresh_token  IS 'Token de renovación de sesión.';
COMMENT ON COLUMN auth.session.ip_address     IS 'Dirección IP desde donde se inició sesión.';
COMMENT ON COLUMN auth.session.user_agent     IS 'Información del navegador o dispositivo.';
COMMENT ON COLUMN auth.session.recordar_sesion IS 'Indica si el usuario seleccionó recordar sesión.';
COMMENT ON COLUMN auth.session.expira_en      IS 'Fecha y hora de expiración del token.';
COMMENT ON COLUMN auth.session.activa         IS 'Indica si la sesión está activa.';
COMMENT ON COLUMN auth.session.created_at     IS 'Fecha de creación de la sesión.';
COMMENT ON COLUMN auth.session.updated_at     IS 'Fecha de última actualización.';
COMMENT ON COLUMN auth.session.deleted_at     IS 'Fecha de cierre o eliminación lógica.';

-- ============================================================
-- TABLA: auth.mfa
-- Descripción: Almacena la configuración de autenticación
--              multifactor (MFA) por usuario
-- Referencia SRS: RF1.3.1
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.mfa (
  id_mfa            UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user           UUID        NOT NULL,
  metodo            VARCHAR(20) NOT NULL,
  codigo_secreto    TEXT        NULL,
  habilitado        BOOLEAN     NOT NULL DEFAULT FALSE,
  ultimo_codigo_hash TEXT       NULL,
  expira_en         TIMESTAMPTZ NULL,
  intentos_fallidos SMALLINT    NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_mfa         PRIMARY KEY (id_mfa),
  CONSTRAINT uq_mfa_user    UNIQUE (id_user),
  CONSTRAINT fk_mfa_user    FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_mfa_metodo  CHECK (metodo IN ('sms', 'email', 'app')),
  CONSTRAINT ck_mfa_intentos CHECK (intentos_fallidos >= 0)
);

COMMENT ON TABLE  auth.mfa                    IS 'Configuración de autenticación multifactor por usuario.';
COMMENT ON COLUMN auth.mfa.id_mfa             IS 'Identificador único de la configuración MFA.';
COMMENT ON COLUMN auth.mfa.id_user            IS 'Usuario dueño de la configuración MFA.';
COMMENT ON COLUMN auth.mfa.metodo             IS 'Método MFA: sms, email, app.';
COMMENT ON COLUMN auth.mfa.codigo_secreto     IS 'Secreto cifrado para apps autenticadoras.';
COMMENT ON COLUMN auth.mfa.habilitado         IS 'Indica si MFA está activo para el usuario.';
COMMENT ON COLUMN auth.mfa.ultimo_codigo_hash IS 'Hash del último código generado para evitar reutilización.';
COMMENT ON COLUMN auth.mfa.expira_en          IS 'Fecha de expiración del último código generado.';
COMMENT ON COLUMN auth.mfa.intentos_fallidos  IS 'Intentos fallidos de verificación MFA.';
COMMENT ON COLUMN auth.mfa.created_at         IS 'Fecha de creación del registro.';
COMMENT ON COLUMN auth.mfa.updated_at         IS 'Fecha de última actualización.';

-- ============================================================
-- TABLA: auth.recovery_token
-- Descripción: Tokens temporales para recuperación de contraseña
--              y activación/reactivación de cuenta
-- Referencia SRS: RF1.6, RF1.8
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.recovery_token (
  id_recovery_token UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_user           UUID        NOT NULL,
  token             TEXT        NOT NULL,
  tipo              VARCHAR(30) NOT NULL,
  expira_en         TIMESTAMPTZ NOT NULL,
  usado             BOOLEAN     NOT NULL DEFAULT FALSE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  CONSTRAINT pk_recovery_token      PRIMARY KEY (id_recovery_token),
  CONSTRAINT uq_recovery_token      UNIQUE (token),
  CONSTRAINT fk_recovery_token_user FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_recovery_token_tipo CHECK (tipo IN ('recuperacion_password', 'activacion_cuenta', 'reactivacion_cuenta'))
);

COMMENT ON TABLE  auth.recovery_token               IS 'Tokens temporales para recuperación y activación de cuentas.';
COMMENT ON COLUMN auth.recovery_token.id_recovery_token IS 'Identificador único del token.';
COMMENT ON COLUMN auth.recovery_token.id_user           IS 'Usuario al que pertenece el token.';
COMMENT ON COLUMN auth.recovery_token.token             IS 'Token único de recuperación.';
COMMENT ON COLUMN auth.recovery_token.tipo              IS 'Tipo de token: recuperacion_password, activacion_cuenta, reactivacion_cuenta.';
COMMENT ON COLUMN auth.recovery_token.expira_en         IS 'Fecha y hora de expiración del token.';
COMMENT ON COLUMN auth.recovery_token.usado             IS 'Indica si el token ya fue utilizado.';
COMMENT ON COLUMN auth.recovery_token.created_at        IS 'Fecha de creación del token.';

-- ============================================================
-- TABLA: auth.token_blacklist
-- Descripción: Registra los tokens JWT revocados para impedir
--              su reutilización después del cierre de sesión
-- Referencia SRS: RF1.4, RNF5.2
-- ============================================================
CREATE TABLE IF NOT EXISTS auth.token_blacklist (
  id_token_blacklist UUID        NOT NULL DEFAULT uuid_generate_v4(),
  token              TEXT        NOT NULL,
  id_user            UUID        NOT NULL,
  motivo             VARCHAR(50) NULL,
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expira_en          TIMESTAMPTZ NOT NULL,

  CONSTRAINT pk_token_blacklist      PRIMARY KEY (id_token_blacklist),
  CONSTRAINT uq_token_blacklist      UNIQUE (token),
  CONSTRAINT fk_token_blacklist_user FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_token_blacklist_motivo CHECK (motivo IN ('logout', 'cambio_password', 'desactivacion', 'expiracion'))
);

COMMENT ON TABLE  auth.token_blacklist                    IS 'Tokens JWT revocados para prevenir reutilización.';
COMMENT ON COLUMN auth.token_blacklist.id_token_blacklist IS 'Identificador único del registro.';
COMMENT ON COLUMN auth.token_blacklist.token              IS 'Token JWT revocado.';
COMMENT ON COLUMN auth.token_blacklist.id_user            IS 'Usuario al que pertenecía el token.';
COMMENT ON COLUMN auth.token_blacklist.motivo             IS 'Motivo de revocación: logout, cambio_password, desactivacion, expiracion.';
COMMENT ON COLUMN auth.token_blacklist.created_at         IS 'Fecha de revocación del token.';
COMMENT ON COLUMN auth.token_blacklist.expira_en          IS 'Fecha de expiración original del token.';