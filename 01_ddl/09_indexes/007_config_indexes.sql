-- ============================================================
-- ÍNDICES — Esquema config
-- Archivo: 01_ddl/09_indexes/007_config_indexes.sql
-- Descripción: Índices de búsqueda y optimización para las
--              tablas del esquema config. Cubre los patrones
--              de consulta de configuración de usuario,
--              preferencias de idioma, tema y notificaciones.

-- ============================================================
-- TABLA: config.configuration_user
-- ============================================================

-- Búsqueda de configuración por usuario (consulta más frecuente)
CREATE INDEX IF NOT EXISTS idx_configuration_user_id_user
  ON config.configuration_user (id_user);

-- Filtrado por idioma (estadísticas de uso por idioma)
CREATE INDEX IF NOT EXISTS idx_configuration_user_idioma
  ON config.configuration_user (idioma);

-- Filtrado por tema visual (estadísticas claro/oscuro/automatico)
CREATE INDEX IF NOT EXISTS idx_configuration_user_tema
  ON config.configuration_user (tema);

-- Usuarios con recomendaciones activas (job de generación de recomendaciones)
CREATE INDEX IF NOT EXISTS idx_configuration_user_recomendaciones
  ON config.configuration_user (recomendaciones_activas, frecuencia_recomendaciones)
  WHERE recomendaciones_activas = TRUE;