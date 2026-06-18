-- ============================================================
-- INSERT — Asignación de permisos a roles
-- Archivo: 02_dml/00_inserts/003_insert_role_permissions.sql
-- Descripción: Asigna los permisos correspondientes a cada
--              rol del sistema según el principio de mínimo
--              privilegio definido en el SRS (RF1.3).
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.3
-- Dependencias: 02_dml/00_inserts/001_insert_roles.sql
--               02_dml/00_inserts/002_insert_permisos.sql
-- ============================================================

-- ============================================================
-- ROL: administrador
-- Tiene acceso a TODOS los permisos del sistema
-- ============================================================
INSERT INTO auth.role_permission (id_role_permission, id_role, id_permission, created_at)
SELECT
  uuid_generate_v4(),
  'a1b2c3d4-0001-0000-0000-000000000001',
  id_permission,
  NOW()
FROM auth.permission
WHERE deleted_at IS NULL
ON CONFLICT (id_role, id_permission) DO NOTHING;

-- ============================================================
-- ROL: estandar
-- Acceso a gestión de sus propios hogares, dispositivos
-- y consumo. Sin acceso a auditoría, gestión de usuarios
-- ni restaurar backups.
-- ============================================================
INSERT INTO auth.role_permission (id_role_permission, id_role, id_permission, created_at)
SELECT
  uuid_generate_v4(),
  'a1b2c3d4-0001-0000-0000-000000000002',
  id_permission,
  NOW()
FROM auth.permission
WHERE nombre IN (
  -- Módulo 2 — Hogares
  'hogares:leer', 'hogares:crear', 'hogares:editar', 'hogares:desactivar',
  'zonas:crear', 'zonas:editar', 'zonas:eliminar',
  'tarifas:configurar',
  -- Módulo 3 — Dispositivos
  'dispositivos:leer', 'dispositivos:crear', 'dispositivos:editar', 'dispositivos:desactivar',
  'dispositivos:controlar', 'dispositivos:configurar_horarios', 'dispositivos:configurar_umbrales',
  'asistente_voz:vincular',
  -- Módulo 4 — Consumo
  'consumo:leer', 'consumo:reportes', 'consumo:graficos',
  'recomendaciones:leer', 'recomendaciones:configurar',
  'notificaciones:leer', 'notificaciones:configurar',
  -- Módulo 5 — Sync
  'sync:manual',
  -- Módulo 6 — Config
  'config:leer', 'config:editar'
)
AND deleted_at IS NULL
ON CONFLICT (id_role, id_permission) DO NOTHING;

-- ============================================================
-- ROL: invitado
-- Acceso de solo lectura a consumo, dispositivos
-- y notificaciones. Sin capacidad de modificar nada.
-- ============================================================
INSERT INTO auth.role_permission (id_role_permission, id_role, id_permission, created_at)
SELECT
  uuid_generate_v4(),
  'a1b2c3d4-0001-0000-0000-000000000003',
  id_permission,
  NOW()
FROM auth.permission
WHERE nombre IN (
  -- Módulo 2 — Hogares (solo lectura)
  'hogares:leer',
  -- Módulo 3 — Dispositivos (solo lectura)
  'dispositivos:leer',
  -- Módulo 4 — Consumo (solo lectura)
  'consumo:leer', 'consumo:graficos',
  'notificaciones:leer',
  -- Módulo 6 — Config (puede ver y editar su propia config)
  'config:leer', 'config:editar'
)
AND deleted_at IS NULL
ON CONFLICT (id_role, id_permission) DO NOTHING;