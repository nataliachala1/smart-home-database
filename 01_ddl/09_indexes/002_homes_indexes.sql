-- ============================================================
-- ÍNDICES — Esquema homes
-- Archivo: 01_ddl/09_indexes/002_homes_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema homes. Cubre los patrones
--              de consulta de hogares, zonas, tarifas y
--              miembros del hogar.
-- ============================================================
-- TABLA: homes.home
-- ============================================================

-- Búsqueda de hogares por usuario propietario
CREATE INDEX IF NOT EXISTS idx_home_id_user
  ON homes.home (id_user)
  WHERE deleted_at IS NULL;

-- Filtrado por estado del hogar (activo, desactivado)
CREATE INDEX IF NOT EXISTS idx_home_estado
  ON homes.home (estado)
  WHERE deleted_at IS NULL;

-- Compuesto: usuario + estado (hogares activos de un usuario)
CREATE INDEX IF NOT EXISTS idx_home_id_user_estado
  ON homes.home (id_user, estado)
  WHERE deleted_at IS NULL;

-- Compuesto: usuario + nombre (validación de nombre único por usuario)
CREATE INDEX IF NOT EXISTS idx_home_id_user_nombre
  ON homes.home (id_user, nombre)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: homes.area
-- ============================================================

-- Búsqueda de zonas por hogar
CREATE INDEX IF NOT EXISTS idx_area_id_home
  ON homes.area (id_home)
  WHERE deleted_at IS NULL;

-- Filtrado por tipo de zona (sala, cocina, dormitorio, etc.)
CREATE INDEX IF NOT EXISTS idx_area_tipo
  ON homes.area (tipo)
  WHERE deleted_at IS NULL;

-- Compuesto: hogar + nombre (validación de nombre único por hogar)
CREATE INDEX IF NOT EXISTS idx_area_id_home_nombre
  ON homes.area (id_home, nombre)
  WHERE deleted_at IS NULL;

-- ============================================================
-- TABLA: homes.tariff
-- ============================================================

-- Búsqueda de tarifas por hogar
CREATE INDEX IF NOT EXISTS idx_tariff_id_home
  ON homes.tariff (id_home)
  WHERE deleted_at IS NULL;

-- Filtrado por vigencia de tarifa (tarifa activa actual)
CREATE INDEX IF NOT EXISTS idx_tariff_vigente_desde
  ON homes.tariff (id_home, vigente_desde DESC)
  WHERE deleted_at IS NULL;

-- Tarifa actual por hogar (vigente_hasta NULL = tarifa vigente)
CREATE INDEX IF NOT EXISTS idx_tariff_vigente_actual
  ON homes.tariff (id_home, vigente_desde)
  WHERE vigente_hasta IS NULL AND deleted_at IS NULL;

-- ============================================================
-- TABLA: homes.home_member
-- ============================================================

-- Búsqueda de miembros por hogar
CREATE INDEX IF NOT EXISTS idx_home_member_id_home
  ON homes.home_member (id_home)
  WHERE deleted_at IS NULL;

-- Búsqueda de hogares a los que pertenece un usuario
CREATE INDEX IF NOT EXISTS idx_home_member_id_user
  ON homes.home_member (id_user)
  WHERE deleted_at IS NULL;

-- Compuesto: hogar + rol (miembros con un rol específico en el hogar)
CREATE INDEX IF NOT EXISTS idx_home_member_id_home_rol
  ON homes.home_member (id_home, rol_en_hogar)
  WHERE deleted_at IS NULL;