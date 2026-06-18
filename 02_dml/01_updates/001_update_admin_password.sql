-- ============================================================
-- UPDATE — Contraseña del administrador
-- Archivo: 02_dml/01_updates/001_update_admin_password.sql
-- Descripción: Actualiza la contraseña del usuario
--              administrador por defecto. Debe ejecutarse
--              antes de pasar a producción.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.7
-- Dependencias: 02_dml/00_inserts/005_insert_admin_user.sql
-- ============================================================

-- ⚠️ IMPORTANTE: Reemplazar NUEVA_CONTRASEÑA_SEGURA con la
-- contraseña real antes de ejecutar este script.
-- La contraseña debe cumplir: mínimo 8 caracteres,
-- una mayúscula, un número y un carácter especial.

UPDATE auth.user
SET
  password_hash = crypt('NUEVA_CONTRASEÑA_SEGURA', gen_salt('bf', 12)),
  updated_at    = NOW()
WHERE id_user    = 'a1b2c3d4-9999-0000-0000-000000000001'
  AND deleted_at IS NULL;

-- Registrar cambio en auditoría
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, id_entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'editar',
  'usuarios',
  'user',
  'a1b2c3d4-9999-0000-0000-000000000001',
  'exitoso',
  'Actualización de contraseña del usuario administrador por defecto.',
  NOW()
);