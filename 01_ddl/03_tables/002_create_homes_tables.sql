-- ============================================================
-- TABLAS — Esquema homes
-- Archivo: 01_ddl/03_tables/003_create_homes_tables.sql
-- Descripción: Creación de las 4 tablas del esquema homes
--              para gestión de hogares, zonas, tarifas
--              y miembros del hogar
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 00_extensions, 01_schemas, auth.user
-- ============================================================

-- ============================================================
-- TABLA: homes.home
-- Descripción: Almacena los hogares registrados en el sistema.
--              Un usuario puede registrar múltiples hogares
-- Referencia SRS: RF2.1, RF2.2, RF2.4
-- ============================================================
CREATE TABLE IF NOT EXISTS homes.home (
  id_home    UUID         NOT NULL DEFAULT uuid_generate_v4(),
  id_user    UUID         NOT NULL,
  nombre     VARCHAR(100) NOT NULL,
  estrato    SMALLINT     NOT NULL,
  estado     VARCHAR(20)  NOT NULL DEFAULT 'activo',
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ  NULL,

  CONSTRAINT pk_home          PRIMARY KEY (id_home),
  CONSTRAINT uq_home_nombre   UNIQUE (id_user, nombre),
  CONSTRAINT fk_home_user     FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_home_estrato  CHECK (estrato BETWEEN 1 AND 6),
  CONSTRAINT ck_home_estado   CHECK (estado IN ('activo', 'desactivado'))
);

COMMENT ON TABLE  homes.home            IS 'Hogares registrados en el sistema Smart Home.';
COMMENT ON COLUMN homes.home.id_home    IS 'Identificador único del hogar.';
COMMENT ON COLUMN homes.home.id_user    IS 'Usuario propietario del hogar.';
COMMENT ON COLUMN homes.home.nombre     IS 'Nombre personalizado del hogar (ej: Casa Principal).';
COMMENT ON COLUMN homes.home.estrato    IS 'Estrato socioeconómico del hogar (1 al 6).';
COMMENT ON COLUMN homes.home.estado     IS 'Estado del hogar: activo, desactivado.';
COMMENT ON COLUMN homes.home.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN homes.home.updated_at IS 'Fecha de última actualización.';
COMMENT ON COLUMN homes.home.deleted_at IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: homes.area
-- Descripción: Representa las zonas o habitaciones dentro
--              de un hogar para organizar dispositivos
--              por ubicación física
-- Referencia SRS: ERF2.1.1
-- ============================================================
CREATE TABLE IF NOT EXISTS homes.area (
  id_area    UUID         NOT NULL DEFAULT uuid_generate_v4(),
  id_home    UUID         NOT NULL,
  nombre     VARCHAR(100) NOT NULL,
  tipo       VARCHAR(50)  NULL,
  created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ  NULL,

  CONSTRAINT pk_area         PRIMARY KEY (id_area),
  CONSTRAINT uq_area_nombre  UNIQUE (id_home, nombre),
  CONSTRAINT fk_area_home    FOREIGN KEY (id_home) REFERENCES homes.home (id_home),
  CONSTRAINT ck_area_tipo    CHECK (
    tipo IS NULL OR
    tipo IN ('sala', 'cocina', 'dormitorio', 'baño', 'exterior', 'otro')
  )
);

COMMENT ON TABLE  homes.area            IS 'Zonas o habitaciones dentro de un hogar.';
COMMENT ON COLUMN homes.area.id_area    IS 'Identificador único de la zona.';
COMMENT ON COLUMN homes.area.id_home    IS 'Hogar al que pertenece la zona.';
COMMENT ON COLUMN homes.area.nombre     IS 'Nombre de la zona (ej: Sala Principal).';
COMMENT ON COLUMN homes.area.tipo       IS 'Tipo de zona: sala, cocina, dormitorio, baño, exterior, otro.';
COMMENT ON COLUMN homes.area.created_at IS 'Fecha de creación del registro.';
COMMENT ON COLUMN homes.area.updated_at IS 'Fecha de última actualización.';
COMMENT ON COLUMN homes.area.deleted_at IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: homes.tariff
-- Descripción: Almacena las tarifas eléctricas configuradas
--              por hogar para calcular costos y proyecciones
--              de facturación mensual
-- Referencia SRS: RF2.5
-- ============================================================
CREATE TABLE IF NOT EXISTS homes.tariff (
  id_tariff      UUID          NOT NULL DEFAULT uuid_generate_v4(),
  id_home        UUID          NOT NULL,
  costo_kwh      NUMERIC(10,4) NOT NULL,
  moneda         VARCHAR(10)   NOT NULL DEFAULT 'COP',
  vigente_desde  DATE          NOT NULL,
  vigente_hasta  DATE          NULL,
  created_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ   NULL,

  CONSTRAINT pk_tariff              PRIMARY KEY (id_tariff),
  CONSTRAINT fk_tariff_home         FOREIGN KEY (id_home) REFERENCES homes.home (id_home),
  CONSTRAINT ck_tariff_costo        CHECK (costo_kwh > 0),
  CONSTRAINT ck_tariff_vigencia     CHECK (
    vigente_hasta IS NULL OR vigente_hasta > vigente_desde
  )
);

COMMENT ON TABLE  homes.tariff               IS 'Tarifas eléctricas configuradas por hogar.';
COMMENT ON COLUMN homes.tariff.id_tariff     IS 'Identificador único de la tarifa.';
COMMENT ON COLUMN homes.tariff.id_home       IS 'Hogar al que aplica la tarifa.';
COMMENT ON COLUMN homes.tariff.costo_kwh     IS 'Costo por kWh en la moneda configurada.';
COMMENT ON COLUMN homes.tariff.moneda        IS 'Moneda de la tarifa (ej: COP, USD).';
COMMENT ON COLUMN homes.tariff.vigente_desde IS 'Fecha desde la que aplica esta tarifa.';
COMMENT ON COLUMN homes.tariff.vigente_hasta IS 'Fecha hasta la que aplica (NULL = tarifa actual vigente).';
COMMENT ON COLUMN homes.tariff.created_at    IS 'Fecha de creación del registro.';
COMMENT ON COLUMN homes.tariff.updated_at    IS 'Fecha de última actualización.';
COMMENT ON COLUMN homes.tariff.deleted_at    IS 'Fecha de eliminación lógica (soft delete).';

-- ============================================================
-- TABLA: homes.home_member
-- Descripción: Gestiona los miembros adicionales de un hogar.
--              Permite que varios usuarios compartan la gestión
--              de un mismo hogar con roles diferenciados
-- Referencia SRS: RF2.3
-- ============================================================
CREATE TABLE IF NOT EXISTS homes.home_member (
  id_home_member UUID        NOT NULL DEFAULT uuid_generate_v4(),
  id_home        UUID        NOT NULL,
  id_user        UUID        NOT NULL,
  rol_en_hogar   VARCHAR(30) NOT NULL DEFAULT 'miembro',
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at     TIMESTAMPTZ NULL,

  CONSTRAINT pk_home_member             PRIMARY KEY (id_home_member),
  CONSTRAINT uq_home_member             UNIQUE (id_home, id_user),
  CONSTRAINT fk_home_member_home        FOREIGN KEY (id_home) REFERENCES homes.home (id_home),
  CONSTRAINT fk_home_member_user        FOREIGN KEY (id_user) REFERENCES auth.user (id_user),
  CONSTRAINT ck_home_member_rol         CHECK (rol_en_hogar IN ('propietario', 'administrador', 'miembro'))
);

COMMENT ON TABLE  homes.home_member                IS 'Miembros vinculados a un hogar con roles diferenciados.';
COMMENT ON COLUMN homes.home_member.id_home_member IS 'Identificador único del miembro en el hogar.';
COMMENT ON COLUMN homes.home_member.id_home        IS 'Hogar al que pertenece el miembro.';
COMMENT ON COLUMN homes.home_member.id_user        IS 'Usuario miembro del hogar.';
COMMENT ON COLUMN homes.home_member.rol_en_hogar   IS 'Rol dentro del hogar: propietario, administrador, miembro.';
COMMENT ON COLUMN homes.home_member.created_at     IS 'Fecha de vinculación al hogar.';
COMMENT ON COLUMN homes.home_member.deleted_at     IS 'Fecha de eliminación lógica (soft delete).';