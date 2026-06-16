-- pgcrypto: Cifrado de datos sensibles
-- Requerido por: auth.user (password_hash), auth.mfa (codigo_secreto),
--                devices.voice_assistant_token (access_token, refresh_token)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";