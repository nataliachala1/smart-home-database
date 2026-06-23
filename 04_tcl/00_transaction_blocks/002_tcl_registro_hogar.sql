-- ============================================================
-- TRANSACTION BLOCK — Registro de hogar
-- Archivo: 04_tcl/00_transaction_blocks/002_tcl_registro_hogar.sql
-- Descripción: Garantiza que el registro de un nuevo hogar
--              sea atómico. Incluye la creación del hogar,
--              asignación del usuario como propietario y
--              registro en auditoría.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF2.1
-- Dependencias: 01_ddl/03_tables/002_create_homes_tables.sql
-- ============================================================

BEGIN;

  -- 1. Insertar nuevo hogar
  INSERT INTO homes.home (
    id_home, id_user, nombre, estrato, estado, created_at, updated_at
  )
  VALUES (
    :id_home, :id_user, :nombre, :estrato, 'activo', NOW(), NOW()
  );

  SAVEPOINT sp_hogar_creado;

  -- 2. Registrar al usuario como propietario del hogar
  INSERT INTO homes.home_member (
    id_home_member, id_home, id_user, rol_en_hogar, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_home, :id_user, 'propietario', NOW()
  );

  SAVEPOINT sp_miembro_registrado;

  -- 3. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'crear', 'hogares',
    'home', :id_home, 'exitoso',
    CONCAT('Registro de nuevo hogar: ', :nombre),
    NOW()
  );

COMMIT;

-- En caso de error:
-- ROLLBACK;