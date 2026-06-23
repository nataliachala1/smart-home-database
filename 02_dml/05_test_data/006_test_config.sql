-- ============================================================
-- TEST DATA — Configuraciones de Usuario de Prueba
-- Archivo: 02_dml/00_test_data/006_test_config.sql
-- Descripción: Amplía las configuraciones base creadas en
--              001_test_users.sql con escenarios variados de
--              notificaciones, modo No Molestar y preferencias
--              de recomendaciones, para probar RF6.1, RF6.2,
--              RF4.5 y RF4.6 con distintas combinaciones.
-- Autor: Karen Daniela Holguín Cruz, Natalia Chala Chala,
--        Kevin Stiven López Amaya
-- Institución: SENA — Análisis y Desarrollo de Software
-- Ficha: 3145555
-- Versión: 1.0.0
-- Fecha: 2025
-- ⚠️ SOLO PARA DESARROLLO Y PRUEBAS — NO ejecutar en producción
-- Dependencias: 02_dml/00_test_data/001_test_users.sql
--               (crea la fila base de configuration_user
--               por cada usuario; este script la actualiza)
-- ============================================================

-- ============================================================
-- 1. Configuración de Karen
--    Escenario: usuario con todas las notificaciones activas,
--    sin modo No Molestar, recomendaciones semanales
-- ============================================================
UPDATE config.configuration_user
SET
  idioma                      = 'es',
  tema                        = 'claro',
  formato_fecha               = 'DD/MM/YYYY',
  formato_hora                = '24h',
  moneda                      = 'COP',
  unidad_temperatura           = 'C',
  notif_consumo_elevado        = TRUE,
  notif_dispositivos           = TRUE,
  notif_recomendaciones        = TRUE,
  notif_seguridad              = TRUE,
  notif_canal_app              = TRUE,
  notif_canal_email            = TRUE,
  notif_canal_push             = TRUE,
  no_molestar_inicio           = NULL,
  no_molestar_fin              = NULL,
  recomendaciones_activas      = TRUE,
  frecuencia_recomendaciones   = 'semanal',
  updated_at                   = NOW()
WHERE id_user = 'b1000000-0000-0000-0000-000000000001';

-- ============================================================
-- 2. Configuración de Kevin
--    Escenario: usuario con tema oscuro, modo No Molestar
--    nocturno activo y solo notificaciones críticas por push
-- ============================================================
UPDATE config.configuration_user
SET
  idioma                      = 'es',
  tema                        = 'oscuro',
  formato_fecha               = 'DD/MM/YYYY',
  formato_hora                = '24h',
  moneda                      = 'COP',
  unidad_temperatura           = 'C',
  notif_consumo_elevado        = TRUE,
  notif_dispositivos           = TRUE,
  notif_recomendaciones        = FALSE,
  notif_seguridad              = TRUE,
  notif_canal_app              = TRUE,
  notif_canal_email            = FALSE,
  notif_canal_push             = TRUE,
  no_molestar_inicio           = '22:00:00',
  no_molestar_fin              = '06:00:00',
  recomendaciones_activas      = FALSE,
  frecuencia_recomendaciones   = 'mensual',
  updated_at                   = NOW()
WHERE id_user = 'b1000000-0000-0000-0000-000000000002';

-- ============================================================
-- 3. Configuración de Natalia
--    Escenario: usuario invitado, tema automático, idioma
--    inglés para probar internacionalización (RF6.1),
--    solo notificaciones de seguridad
-- ============================================================
UPDATE config.configuration_user
SET
  idioma                      = 'en',
  tema                        = 'automatico',
  formato_fecha               = 'MM/DD/YYYY',
  formato_hora                = '12h',
  moneda                      = 'COP',
  unidad_temperatura           = 'F',
  notif_consumo_elevado        = FALSE,
  notif_dispositivos           = FALSE,
  notif_recomendaciones        = FALSE,
  notif_seguridad              = TRUE,
  notif_canal_app              = TRUE,
  notif_canal_email            = TRUE,
  notif_canal_push             = FALSE,
  no_molestar_inicio           = NULL,
  no_molestar_fin              = NULL,
  recomendaciones_activas      = FALSE,
  frecuencia_recomendaciones   = 'semanal',
  updated_at                   = NOW()
WHERE id_user = 'b1000000-0000-0000-0000-000000000003';

-- ============================================================
-- NOTA: Si por algún motivo el usuario de prueba todavía no
-- tiene fila en config.configuration_user (por ejemplo, si
-- este script se ejecuta antes que 001_test_users.sql o el
-- trigger fn_config_user no llegó a dispararse), se crea
-- aquí como respaldo con los mismos valores de cada UPDATE.
-- ============================================================
INSERT INTO config.configuration_user (
  id_configuration_user, id_user, idioma, tema,
  formato_fecha, formato_hora, moneda, unidad_temperatura,
  notif_consumo_elevado, notif_dispositivos, notif_recomendaciones,
  notif_seguridad, notif_canal_app, notif_canal_email, notif_canal_push,
  no_molestar_inicio, no_molestar_fin,
  recomendaciones_activas, frecuencia_recomendaciones,
  created_at, updated_at
)
SELECT
  uuid_generate_v4(), u.id_user, 'es', 'claro',
  'DD/MM/YYYY', '24h', 'COP', 'C',
  TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
  NULL, NULL, TRUE, 'semanal',
  NOW(), NOW()
FROM auth.user u
WHERE u.id_user IN (
  'b1000000-0000-0000-0000-000000000001',
  'b1000000-0000-0000-0000-000000000002',
  'b1000000-0000-0000-0000-000000000003'
)
AND NOT EXISTS (
  SELECT 1 FROM config.configuration_user cu
  WHERE cu.id_user = u.id_user
);