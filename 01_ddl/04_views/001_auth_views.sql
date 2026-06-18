-- ============================================================
-- VISTAS — Esquema auth
-- Archivo: 01_ddl/07_views/001_vw_auth_views.sql
-- Descripción: Vistas para simplificar consultas frecuentes
--              del esquema auth: usuarios con roles,
--              sesiones activas y permisos por usuario
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 03_tables/001_create_auth_tables.sql
-- ============================================================

-- ============================================================
-- VISTA: auth.vw_usuarios_activos
-- Descripción: Muestra todos los usuarios activos del sistema
--              con su información básica, excluyendo campos
--              sensibles como password_hash
-- Referencia SRS: RF1.2, RF1.3
-- ============================================================
CREATE OR REPLACE VIEW auth.vw_usuarios_activos AS
SELECT
  u.id_user,
  u.nombre,
  u.apellido,
  u.username,
  u.email,
  u.tipo_documento,
  u.numero_documento,
  u.estado,
  u.email_verificado,
  u.mfa_habilitado,
  u.intentos_fallidos,
  u.bloqueado_hasta,
  u.created_at,
  u.updated_at
FROM auth.user u
WHERE u.deleted_at IS NULL;

COMMENT ON VIEW auth.vw_usuarios_activos
  IS 'Usuarios del sistema excluyendo eliminados lógicamente y campos sensibles.';

-- ============================================================
-- VISTA: auth.vw_usuarios_con_roles
-- Descripción: Muestra cada usuario con su rol asignado
--              y los permisos correspondientes al rol.
--              Útil para validación de acceso en el backend
-- Referencia SRS: RF1.3, RNF5.1
-- ============================================================
CREATE OR REPLACE VIEW auth.vw_usuarios_con_roles AS
SELECT
  u.id_user,
  u.nombre,
  u.apellido,
  u.username,
  u.email,
  u.estado,
  r.id_role,
  r.nombre        AS rol,
  p.id_permission,
  p.nombre        AS permiso,
  p.modulo,
  p.accion
FROM auth.user            u
JOIN auth.user_role       ur ON ur.id_user       = u.id_user
                             AND ur.deleted_at    IS NULL
JOIN auth.role            r  ON r.id_role         = ur.id_role
                             AND r.deleted_at      IS NULL
JOIN auth.role_permission rp ON rp.id_role        = r.id_role
                             AND rp.deleted_at     IS NULL
JOIN auth.permission      p  ON p.id_permission   = rp.id_permission
                             AND p.deleted_at      IS NULL
WHERE u.deleted_at IS NULL
  AND u.estado     = 'activo';

COMMENT ON VIEW auth.vw_usuarios_con_roles
  IS 'Usuarios activos con sus roles y permisos asociados. Facilita la validación de acceso en el backend.';

-- ============================================================
-- VISTA: auth.vw_sesiones_activas
-- Descripción: Muestra todas las sesiones activas del sistema
--              con información del usuario y tiempo restante
--              antes de expiración
-- Referencia SRS: RF1.2, RF1.4, RNF5.4
-- ============================================================
CREATE OR REPLACE VIEW auth.vw_sesiones_activas AS
SELECT
  s.id_session,
  s.id_user,
  u.nombre,
  u.apellido,
  u.email,
  s.ip_address,
  s.user_agent,
  s.recordar_sesion,
  s.created_at                              AS inicio_sesion,
  s.expira_en,
  EXTRACT(EPOCH FROM (s.expira_en - NOW()))
    / 60                                    AS minutos_restantes
FROM auth.session s
JOIN auth.user    u ON u.id_user    = s.id_user
                    AND u.deleted_at IS NULL
WHERE s.activa     = TRUE
  AND s.deleted_at IS NULL
  AND s.expira_en  > NOW();

COMMENT ON VIEW auth.vw_sesiones_activas
  IS 'Sesiones activas y no expiradas con tiempo restante en minutos antes de expiración.';

-- ============================================================
-- VISTA: auth.vw_cuentas_bloqueadas
-- Descripción: Muestra las cuentas actualmente bloqueadas
--              con el tiempo restante de bloqueo.
--              Útil para el job de desbloqueo automático
-- Referencia SRS: RF1.2, RF1.6
-- ============================================================
CREATE OR REPLACE VIEW auth.vw_cuentas_bloqueadas AS
SELECT
  u.id_user,
  u.nombre,
  u.apellido,
  u.email,
  u.intentos_fallidos,
  u.bloqueado_hasta,
  EXTRACT(EPOCH FROM (u.bloqueado_hasta - NOW()))
    / 60                                      AS minutos_restantes_bloqueo
FROM auth.user u
WHERE u.estado       = 'bloqueado'
  AND u.deleted_at   IS NULL
  AND u.bloqueado_hasta > NOW();

COMMENT ON VIEW auth.vw_cuentas_bloqueadas
  IS 'Cuentas bloqueadas actualmente con tiempo restante de bloqueo en minutos.';

-- ============================================================
-- VISTA: auth.vw_tokens_por_vencer
-- Descripción: Muestra los tokens de recuperación y
--              activación que están próximos a vencer
--              en las próximas 2 horas
-- Referencia SRS: RF1.6, RF1.8
-- ============================================================
CREATE OR REPLACE VIEW auth.vw_tokens_por_vencer AS
SELECT
  rt.id_recovery_token,
  rt.id_user,
  u.email,
  rt.tipo,
  rt.expira_en,
  EXTRACT(EPOCH FROM (rt.expira_en - NOW()))
    / 60                                    AS minutos_restantes
FROM auth.recovery_token rt
JOIN auth.user           u  ON u.id_user = rt.id_user
                            AND u.deleted_at IS NULL
WHERE rt.usado     = FALSE
  AND rt.expira_en > NOW()
  AND rt.expira_en < NOW() + INTERVAL '2 hours';

COMMENT ON VIEW auth.vw_tokens_por_vencer
  IS 'Tokens de recuperación y activación próximos a vencer en las siguientes 2 horas.';