-- ============================================================
-- ROLES — Roles de PostgreSQL
-- Archivo: 03_dcl/00_roles/001_create_roles.sql
-- Descripción: Crea los tres roles de PostgreSQL del sistema
--              Smart Home. Estos roles son independientes de
--              los roles del sistema (auth.role) y controlan
--              qué puede hacer el motor de base de datos
--              con cada conexión.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: ninguna
-- ============================================================

-- ============================================================
-- ROL: smarthome_admin
-- Acceso total a la base de datos
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'smarthome_admin') THEN
    CREATE ROLE smarthome_admin
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      INHERIT
      NOREPLICATION;
    COMMENT ON ROLE smarthome_admin IS
      'Rol administrativo con acceso total a los esquemas y tablas del sistema Smart Home.';
  END IF;
END $$;

-- ============================================================
-- ROL: smarthome_app
-- Rol del backend / API
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'smarthome_app') THEN
    CREATE ROLE smarthome_app
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      INHERIT
      NOREPLICATION;
    COMMENT ON ROLE smarthome_app IS
      'Rol utilizado por el servidor de aplicaciones (API). Tiene permisos de lectura y escritura sobre las tablas del sistema Smart Home.';
  END IF;
END $$;

-- ============================================================
-- ROL: smarthome_readonly
-- Solo lectura para reportes y auditorías externas
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'smarthome_readonly') THEN
    CREATE ROLE smarthome_readonly
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      INHERIT
      NOREPLICATION;
    COMMENT ON ROLE smarthome_readonly IS
      'Rol de solo lectura para herramientas de reportes, BI o auditorías externas del sistema Smart Home.';
  END IF;
END $$;