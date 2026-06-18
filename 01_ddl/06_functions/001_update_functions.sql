-- ============================================================
-- FUNCIÓN: fn_updated_at
-- Archivo: 01_ddl/05_functions/001_fn_updated_at.sql
-- Descripción: Función genérica que actualiza automáticamente
--              el campo updated_at al momento exacto en que
--              se modifica cualquier registro. Se reutiliza
--              en todas las tablas que tienen este campo
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 01_schemas
-- ============================================================

CREATE OR REPLACE FUNCTION fn_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION fn_updated_at()
  IS 'Actualiza automáticamente updated_at al momento del UPDATE. Se reutiliza en todas las tablas del sistema.';