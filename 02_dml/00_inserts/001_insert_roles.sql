-- ============================================================
-- INSERT — Roles del sistema
-- Archivo: 02_dml/00_inserts/001_insert_roles.sql
-- Descripción: Inserta los tres roles base del sistema
--              definidos en el SRS (RF1.3). Estos roles
--              determinan el nivel de acceso de cada usuario.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF1.3
-- Dependencias: 01_ddl/03_tables/001_create_auth_tables.sql
-- ============================================================

INSERT INTO auth.role (id_role, nombre, descripcion, created_at, updated_at)
VALUES
  (
    'a1b2c3d4-0001-0000-0000-000000000001',
    'administrador',
    'Acceso total al sistema. Puede gestionar usuarios, roles, backups, logs de auditoría y toda la configuración del sistema.',
    NOW(), NOW()
  ),
  (
    'a1b2c3d4-0001-0000-0000-000000000002',
    'estandar',
    'Acceso a funcionalidades propias del hogar. Puede gestionar hogares, dispositivos, consumo y configuración personal.',
    NOW(), NOW()
  ),
  (
    'a1b2c3d4-0001-0000-0000-000000000003',
    'invitado',
    'Acceso de solo lectura. Puede visualizar consumo y estado de dispositivos sin realizar cambios.',
    NOW(), NOW()
  )
ON CONFLICT (id_role) DO NOTHING;