-- ============================================================
-- FUNCIÓN: fn_config_user
-- Archivo: 01_ddl/05_functions/003_fn_config_user.sql
-- Descripción: Función que crea automáticamente un registro
--              en config.configuration_user con valores
--              por defecto cada vez que se registra un
--              nuevo usuario en el sistema. Garantiza que
--              todo usuario tenga siempre una configuración
--              asociada desde el momento de su creación
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Dependencias: 01_schemas, 03_tables/auth.user,
--               03_tables/config.configuration_user
-- ============================================================

CREATE OR REPLACE FUNCTION fn_config_user()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN

  -- --------------------------------------------------------
  -- Solo ejecutar en INSERT de nuevos usuarios
  -- No ejecutar si el usuario ya tiene configuración
  -- (caso de restauración desde backup)
  -- --------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1
    FROM config.configuration_user
    WHERE id_user = NEW.id_user
  ) THEN

    INSERT INTO config.configuration_user (
      id_configuration_user,
      id_user,
      idioma,
      tema,
      formato_fecha,
      formato_hora,
      moneda,
      unidad_temperatura,
      notif_consumo_elevado,
      notif_dispositivos,
      notif_recomendaciones,
      notif_seguridad,
      notif_canal_app,
      notif_canal_email,
      notif_canal_push,
      no_molestar_inicio,
      no_molestar_fin,
      recomendaciones_activas,
      frecuencia_recomendaciones,
      created_at,
      updated_at
    )
    VALUES (
      uuid_generate_v4(),
      NEW.id_user,
      'es',           -- idioma por defecto: español
      'claro',        -- tema por defecto: claro
      'DD/MM/YYYY',   -- formato fecha Colombia
      '24h',          -- formato hora 24h
      'COP',          -- moneda por defecto: pesos colombianos
      'C',            -- temperatura en Celsius
      TRUE,           -- notif consumo elevado activa
      TRUE,           -- notif dispositivos activa
      TRUE,           -- notif recomendaciones activa
      TRUE,           -- notif seguridad activa
      TRUE,           -- canal app activo
      TRUE,           -- canal email activo
      TRUE,           -- canal push activo
      NULL,           -- sin modo No Molestar por defecto
      NULL,           -- sin modo No Molestar por defecto
      TRUE,           -- recomendaciones automáticas activas
      'semanal',      -- frecuencia semanal por defecto
      NOW(),
      NOW()
    );

  END IF;

  RETURN NEW;

END;
$$;

COMMENT ON FUNCTION fn_config_user()
  IS 'Crea automáticamente config.configuration_user con valores por defecto al registrar un nuevo usuario. Verifica que no exista configuración previa para soportar restauraciones desde backup.';