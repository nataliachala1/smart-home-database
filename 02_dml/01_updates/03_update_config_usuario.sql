-- ============================================================
-- UPDATE — Configuración de usuario
-- Archivo: 02_dml/01_updates/003_update_config_usuario.sql
-- Descripción: Scripts de referencia para actualizar las
--              preferencias de un usuario: idioma, tema
--              y configuración de notificaciones.
--              Se usa en los flujos de RF6.1 y RF6.2.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- Referencia SRS: RF6.1, RF6.2, RF4.5, RF4.6
-- Dependencias: 01_ddl/03_tables/007_create_config_tables.sql
-- ============================================================

-- ============================================================
-- Cambiar idioma del usuario (RF6.1)
-- Valores válidos: es, en, fr, de
-- ============================================================
UPDATE config.configuration_user
SET
  idioma     = :nuevo_idioma,
  updated_at = NOW()
WHERE id_user = :id_usuario;

-- ============================================================
-- Cambiar tema visual del usuario (RF6.2)
-- Valores válidos: claro, oscuro, automatico
-- ============================================================
UPDATE config.configuration_user
SET
  tema       = :nuevo_tema,
  updated_at = NOW()
WHERE id_user = :id_usuario;

-- ============================================================
-- Actualizar formato de fecha y hora
-- ============================================================
UPDATE config.configuration_user
SET
  formato_fecha = :formato_fecha,
  formato_hora  = :formato_hora,
  updated_at    = NOW()
WHERE id_user = :id_usuario;

-- ============================================================
-- Actualizar preferencias de notificaciones (RF4.6)
-- ============================================================
UPDATE config.configuration_user
SET
  notif_consumo_elevado = :notif_consumo_elevado,
  notif_dispositivos    = :notif_dispositivos,
  notif_recomendaciones = :notif_recomendaciones,
  notif_seguridad       = :notif_seguridad,
  notif_canal_app       = :notif_canal_app,
  notif_canal_email     = :notif_canal_email,
  notif_canal_push      = :notif_canal_push,
  updated_at            = NOW()
WHERE id_user = :id_usuario;

-- ============================================================
-- Actualizar configuración de recomendaciones (RF4.3.1)
-- ============================================================
UPDATE config.configuration_user
SET
  recomendaciones_activas      = :recomendaciones_activas,
  frecuencia_recomendaciones   = :frecuencia_recomendaciones,
  updated_at                   = NOW()
WHERE id_user = :id_usuario;

-- ============================================================
-- Configurar horario No Molestar (RF4.6)
-- ============================================================
UPDATE config.configuration_user
SET
  no_molestar_inicio = :hora_inicio,
  no_molestar_fin    = :hora_fin,
  updated_at         = NOW()
WHERE id_user = :id_usuario;