--
-- PostgreSQL database dump
--

\restrict CgwZtV57OqVnlaUZvR8Q0mzXDzRh0e2C6oTaySGnZawyN9I93CtIbUoWuqxWxAt

-- Dumped from database version 15.18 (Debian 15.18-1.pgdg13+1)
-- Dumped by pg_dump version 15.18 (Debian 15.18-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA audit;


--
-- Name: auth; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA auth;


--
-- Name: config; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA config;


--
-- Name: consumption; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA consumption;


--
-- Name: devices; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA devices;


--
-- Name: homes; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA homes;


--
-- Name: notifications; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA notifications;


--
-- Name: sync; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA sync;


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: fn_audit_log(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_audit_log() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_accion         VARCHAR(50);
  v_datos_ant      JSONB;
  v_datos_nuevos   JSONB;
  v_id_entidad     UUID;
  v_id_user        UUID;
  v_entidad        VARCHAR(50);
BEGIN

  IF TG_OP = 'INSERT' THEN
    v_accion       := 'crear';
    v_datos_ant    := NULL;
    v_datos_nuevos := to_jsonb(NEW);
    v_id_entidad   := (to_jsonb(NEW)->>'id_' || TG_TABLE_NAME)::UUID;

  ELSIF TG_OP = 'UPDATE' THEN
    
    IF (to_jsonb(OLD) ? 'deleted_at')
       AND (to_jsonb(OLD)->>'deleted_at') IS NULL
       AND (to_jsonb(NEW)->>'deleted_at') IS NOT NULL THEN
      v_accion := 'eliminar';
    ELSE
      v_accion := 'editar';
    END IF;
    v_datos_ant    := to_jsonb(OLD);
    v_datos_nuevos := to_jsonb(NEW);
    v_id_entidad   := (to_jsonb(NEW)->>'id_' || TG_TABLE_NAME)::UUID;

  ELSIF TG_OP = 'DELETE' THEN
    v_accion       := 'eliminar';
    v_datos_ant    := to_jsonb(OLD);
    v_datos_nuevos := NULL;
    v_id_entidad   := (to_jsonb(OLD)->>'id_' || TG_TABLE_NAME)::UUID;

  END IF;

  BEGIN
    IF TG_OP = 'DELETE' THEN
      v_id_user := (to_jsonb(OLD)->>'id_user')::UUID;
    ELSE
      v_id_user := (to_jsonb(NEW)->>'id_user')::UUID;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_id_user := NULL;
  END;

  v_entidad := TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME;

  IF v_datos_ant IS NOT NULL THEN
    v_datos_ant := v_datos_ant
      - 'password_hash'
      - 'token'
      - 'refresh_token'
      - 'access_token'
      - 'codigo_secreto'
      - 'ultimo_codigo_hash';
  END IF;

  IF v_datos_nuevos IS NOT NULL THEN
    v_datos_nuevos := v_datos_nuevos
      - 'password_hash'
      - 'token'
      - 'refresh_token'
      - 'access_token'
      - 'codigo_secreto'
      - 'ultimo_codigo_hash';
  END IF;

  INSERT INTO audit.audit_log (
    id_audit_log,
    id_user,
    accion,
    modulo,
    entidad,
    id_entidad,
    datos_anteriores,
    datos_nuevos,
    resultado,
    created_at
  )
  VALUES (
    uuid_generate_v4(),
    v_id_user,
    v_accion,
    TG_TABLE_SCHEMA,
    v_entidad,
    v_id_entidad,
    v_datos_ant,
    v_datos_nuevos,
    'exitoso',
    NOW()
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  RETURN NEW;

END;
$$;


--
-- Name: FUNCTION fn_audit_log(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_audit_log() IS 'Registra autom├íticamente en audit.audit_log cualquier INSERT, UPDATE o DELETE sobre tablas cr├¡ticas. Ofusca campos sensibles antes de guardar.';


--
-- Name: fn_auth_cambio_password(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auth_cambio_password() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

  
  
  
  IF NEW.password_hash <> OLD.password_hash THEN

    
    UPDATE auth.session
    SET
      activa     = FALSE,
      updated_at = NOW()
    WHERE id_user    = NEW.id_user
      AND activa     = TRUE
      AND deleted_at IS NULL;

    
    INSERT INTO auth.token_blacklist (
      id_token_blacklist,
      token,
      id_user,
      motivo,
      created_at,
      expira_en
    )
    SELECT
      uuid_generate_v4(),
      token,
      id_user,
      'cambio_password',
      NOW(),
      expira_en
    FROM auth.session
    WHERE id_user    = NEW.id_user
      AND activa     = TRUE
      AND deleted_at IS NULL
      AND token NOT IN (
        SELECT token FROM auth.token_blacklist
      );

  END IF;

  RETURN NEW;

END;
$$;


--
-- Name: FUNCTION fn_auth_cambio_password(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auth_cambio_password() IS 'Revoca todas las sesiones activas y registra tokens en blacklist cuando el usuario cambia su contrase├▒a.';


--
-- Name: fn_auth_intentos_fallidos(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auth_intentos_fallidos() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_max_intentos  CONSTANT SMALLINT    := 5;
  v_tiempo_bloqueo CONSTANT INTERVAL  := INTERVAL '15 minutes';
BEGIN

  
  
  
  
  IF NEW.intentos_fallidos > OLD.intentos_fallidos
    AND NEW.estado = OLD.estado THEN

    
    IF NEW.intentos_fallidos >= v_max_intentos THEN

      
      NEW.estado          = 'bloqueado';
      NEW.bloqueado_hasta = NOW() + v_tiempo_bloqueo;

    END IF;

  END IF;

  
  
  
  
  IF NEW.estado = 'activo'
    AND OLD.estado = 'bloqueado' THEN

    NEW.intentos_fallidos = 0;
    NEW.bloqueado_hasta   = NULL;

  END IF;

  
  
  
  
  IF (NEW.estado IN ('bloqueado', 'desactivado'))
    AND OLD.estado NOT IN ('bloqueado', 'desactivado') THEN

    
    UPDATE auth.session
    SET
      activa     = FALSE,
      updated_at = NOW()
    WHERE id_user    = NEW.id_user
      AND activa     = TRUE
      AND deleted_at IS NULL;

    
    INSERT INTO auth.token_blacklist (
      id_token_blacklist,
      token,
      id_user,
      motivo,
      created_at,
      expira_en
    )
    SELECT
      uuid_generate_v4(),
      token,
      id_user,
      CASE
        WHEN NEW.estado = 'bloqueado'    THEN 'desactivacion'
        WHEN NEW.estado = 'desactivado'  THEN 'desactivacion'
      END,
      NOW(),
      expira_en
    FROM auth.session
    WHERE id_user    = NEW.id_user
      AND activa     = FALSE
      AND deleted_at IS NULL
      AND token NOT IN (
        SELECT token FROM auth.token_blacklist
      );

  END IF;

  RETURN NEW;

END;
$$;


--
-- Name: FUNCTION fn_auth_intentos_fallidos(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auth_intentos_fallidos() IS 'Gestiona intentos fallidos de login, bloqueo autom├ítico de cuenta tras 5 intentos y cierre de sesiones al desactivar o bloquear.';


--
-- Name: fn_auth_mfa_reset(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_auth_mfa_reset() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

  
  
  
  
  IF NEW.usado = TRUE
    AND OLD.usado = FALSE THEN

    
    UPDATE auth.mfa
    SET
      intentos_fallidos = 0,
      updated_at        = NOW()
    WHERE id_user = (
      SELECT id_user
      FROM auth.recovery_token
      WHERE id_recovery_token = NEW.id_recovery_token
    );

  END IF;

  RETURN NEW;

END;
$$;


--
-- Name: FUNCTION fn_auth_mfa_reset(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_auth_mfa_reset() IS 'Resetea el contador de intentos fallidos de MFA cuando el usuario completa exitosamente la verificaci├│n del segundo factor.';


--
-- Name: fn_config_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_config_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN

  
  
  
  
  
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
      'es',           
      'claro',        
      'DD/MM/YYYY',   
      '24h',          
      'COP',          
      'C',            
      TRUE,           
      TRUE,           
      TRUE,           
      TRUE,           
      TRUE,           
      TRUE,           
      TRUE,           
      NULL,           
      NULL,           
      TRUE,           
      'semanal',      
      NOW(),
      NOW()
    );

  END IF;

  RETURN NEW;

END;
$$;


--
-- Name: FUNCTION fn_config_user(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_config_user() IS 'Crea autom├íticamente config.configuration_user con valores por defecto al registrar un nuevo usuario. Verifica que no exista configuraci├│n previa para soportar restauraciones desde backup.';


--
-- Name: fn_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


--
-- Name: FUNCTION fn_updated_at(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.fn_updated_at() IS 'Actualiza autom├íticamente updated_at al momento del UPDATE. Se reutiliza en todas las tablas del sistema.';


--
-- Name: sp_desactivar_hogar(uuid, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_desactivar_hogar(IN p_id_home uuid, IN p_id_user uuid)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_nombre_hogar      VARCHAR(100);
  v_total_dispositivos INTEGER;
BEGIN

  
  
  
  SELECT nombre INTO v_nombre_hogar
  FROM homes.home
  WHERE id_home    = p_id_home
    AND estado     = 'activo'
    AND deleted_at IS NULL;

  IF v_nombre_hogar IS NULL THEN
    RAISE EXCEPTION 'El hogar no existe o ya est├í desactivado.';
  END IF;

  
  
  
  
  UPDATE homes.home
  SET
    estado     = 'desactivado',
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home = p_id_home;

  
  
  
  
  UPDATE homes.area
  SET deleted_at = NOW(), updated_at = NOW()
  WHERE id_home    = p_id_home
    AND deleted_at IS NULL;

  
  
  
  
  SELECT COUNT(*) INTO v_total_dispositivos
  FROM devices.device
  WHERE id_home    = p_id_home
    AND deleted_at IS NULL;

  UPDATE devices.device
  SET
    estado     = 'desactivado',
    encendido  = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home    = p_id_home
    AND deleted_at IS NULL;

  
  
  
  
  UPDATE devices.schedule
  SET
    activo     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device WHERE id_home = p_id_home
  )
  AND deleted_at IS NULL;

  
  
  
  
  UPDATE devices.threshold_rule
  SET
    activa     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device WHERE id_home = p_id_home
  )
  AND deleted_at IS NULL;

  
  
  
  
  
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_user, 'eliminar', 'hogares',
    'home', p_id_home, 'exitoso',
    CONCAT(
      'Desactivaci├│n completa del hogar "', v_nombre_hogar,
      '". Dispositivos afectados: ', v_total_dispositivos
    ),
    NOW()
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al desactivar el hogar: %', SQLERRM;
END;
$$;


--
-- Name: PROCEDURE sp_desactivar_hogar(IN p_id_home uuid, IN p_id_user uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public.sp_desactivar_hogar(IN p_id_home uuid, IN p_id_user uuid) IS 'Desactiva un hogar, sus zonas, dispositivos, horarios y reglas de umbral asociadas. Registra un resumen manual en auditor├¡a adem├ís de los triggers autom├íticos por tabla.';


--
-- Name: sp_registrar_dispositivo(uuid, uuid, uuid, character varying, boolean, character varying, character varying, uuid); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_registrar_dispositivo(IN p_id_home uuid, IN p_id_area uuid, IN p_id_type_device uuid, IN p_nombre character varying, IN p_es_inteligente boolean, IN p_modelo character varying, IN p_fabricante character varying, IN p_id_user uuid, OUT p_id_device uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN

  
  
  
  IF NOT EXISTS (
    SELECT 1 FROM homes.home
    WHERE id_home    = p_id_home
      AND estado     = 'activo'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'El hogar no existe o no est├í activo.';
  END IF;

  
  
  
  IF p_id_area IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM homes.area
    WHERE id_area    = p_id_area
      AND id_home    = p_id_home
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'La zona indicada no pertenece a este hogar.';
  END IF;

  
  
  
  
  p_id_device := uuid_generate_v4();

  INSERT INTO devices.device (
    id_device, id_home, id_area, id_type_device,
    nombre, estado, encendido, created_at, updated_at
  )
  VALUES (
    p_id_device, p_id_home, p_id_area, p_id_type_device,
    p_nombre, 'desconectado', FALSE, NOW(), NOW()
  );

  
  
  
  IF p_es_inteligente THEN
    INSERT INTO devices.smart_device (
      id_smart_device, id_device, modelo, fabricante, created_at, updated_at
    )
    VALUES (
      uuid_generate_v4(), p_id_device, p_modelo, p_fabricante, NOW(), NOW()
    );
  ELSE
    INSERT INTO devices.manual_device (
      id_manual_device, id_device, created_at, updated_at
    )
    VALUES (
      uuid_generate_v4(), p_id_device, NOW(), NOW()
    );
  END IF;

  
  
  
  INSERT INTO devices.device_status_history (
    id_device_status_history, id_device, estado_anterior,
    estado_nuevo, encendido, origen, id_user, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_device, NULL,
    'desconectado', FALSE, 'sistema', p_id_user, NOW()
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Ya existe un dispositivo con ese nombre en este hogar.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al registrar el dispositivo: %', SQLERRM;
END;
$$;


--
-- Name: PROCEDURE sp_registrar_dispositivo(IN p_id_home uuid, IN p_id_area uuid, IN p_id_type_device uuid, IN p_nombre character varying, IN p_es_inteligente boolean, IN p_modelo character varying, IN p_fabricante character varying, IN p_id_user uuid, OUT p_id_device uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public.sp_registrar_dispositivo(IN p_id_home uuid, IN p_id_area uuid, IN p_id_type_device uuid, IN p_nombre character varying, IN p_es_inteligente boolean, IN p_modelo character varying, IN p_fabricante character varying, IN p_id_user uuid, OUT p_id_device uuid) IS 'Registra un nuevo dispositivo validando hogar y zona, crea su registro extendido (smart o manual) y el historial de estado inicial. La auditor├¡a se genera autom├íticamente v├¡a trigger.';


--
-- Name: sp_registrar_hogar(uuid, character varying, smallint); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_registrar_hogar(IN p_id_user uuid, IN p_nombre character varying, IN p_estrato smallint, OUT p_id_home uuid)
    LANGUAGE plpgsql
    AS $$
BEGIN

  
  
  
  IF NOT EXISTS (
    SELECT 1 FROM auth.user
    WHERE id_user    = p_id_user
      AND estado     = 'activo'
      AND deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'El usuario no existe o no est├í activo.';
  END IF;

  
  
  
  
  p_id_home := uuid_generate_v4();

  INSERT INTO homes.home (
    id_home, id_user, nombre, estrato, estado, created_at, updated_at
  )
  VALUES (
    p_id_home, p_id_user, p_nombre, p_estrato, 'activo', NOW(), NOW()
  );

  
  
  
  INSERT INTO homes.home_member (
    id_home_member, id_home, id_user, rol_en_hogar, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_home, p_id_user, 'propietario', NOW()
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Ya tienes un hogar registrado con ese nombre.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al registrar el hogar: %', SQLERRM;
END;
$$;


--
-- Name: PROCEDURE sp_registrar_hogar(IN p_id_user uuid, IN p_nombre character varying, IN p_estrato smallint, OUT p_id_home uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public.sp_registrar_hogar(IN p_id_user uuid, IN p_nombre character varying, IN p_estrato smallint, OUT p_id_home uuid) IS 'Registra un nuevo hogar y vincula al usuario creador como propietario. La auditor├¡a se genera autom├íticamente v├¡a trigger.';


--
-- Name: sp_registrar_usuario(character varying, character varying, character varying, character varying, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_registrar_usuario(IN p_nombre character varying, IN p_apellido character varying, IN p_username character varying, IN p_email character varying, IN p_password text, OUT p_id_user uuid, OUT p_token text)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_id_role_estandar CONSTANT UUID := 'a1b2c3d4-0001-0000-0000-000000000002';
BEGIN

  
  
  
  p_id_user := uuid_generate_v4();
  p_token   := encode(gen_random_bytes(32), 'hex');

  
  
  
  
  
  INSERT INTO auth.user (
    id_user, nombre, apellido, username, email, password_hash, estado, email_verificado,
    created_at, updated_at
  )
  VALUES (
    p_id_user, p_nombre, p_apellido, p_username, p_email,
    crypt(p_password, gen_salt('bf', 12)),
    'pendiente', FALSE,
    NOW(), NOW()
  );

  
  
  
  INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
  VALUES (uuid_generate_v4(), p_id_user, v_id_role_estandar, NOW());

  
  
  
  INSERT INTO auth.recovery_token (
    id_recovery_token, id_user, token, tipo, expira_en, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_user, p_token,
    'activacion_cuenta', NOW() + INTERVAL '24 hours', NOW()
  );

EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'El correo, username ya est├ín registrados en el sistema.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al registrar el usuario: %', SQLERRM;
END;
$$;


--
-- Name: PROCEDURE sp_registrar_usuario(IN p_nombre character varying, IN p_apellido character varying, IN p_username character varying, IN p_email character varying, IN p_password text, OUT p_id_user uuid, OUT p_token text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public.sp_registrar_usuario(IN p_nombre character varying, IN p_apellido character varying, IN p_username character varying, IN p_email character varying, IN p_password text, OUT p_id_user uuid, OUT p_token text) IS 'Registra usuario, asigna rol est├índar y genera token de activaci├│n.';


--
-- Name: sp_restaurar_backup(uuid, uuid, text, text); Type: PROCEDURE; Schema: public; Owner: -
--

CREATE PROCEDURE public.sp_restaurar_backup(IN p_id_admin uuid, IN p_id_backup_a_restaurar uuid, IN p_motivo text, IN p_ubicacion_backup_seg text, OUT p_id_backup_seguridad uuid)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_estado_backup VARCHAR(20);
BEGIN

  
  
  
  IF NOT EXISTS (
    SELECT 1
    FROM auth.user_role ur
    JOIN auth.role       r ON r.id_role = ur.id_role
    WHERE ur.id_user    = p_id_admin
      AND r.nombre      = 'administrador'
      AND ur.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'El usuario no tiene permisos de administrador para ejecutar restauraciones.';
  END IF;

  
  
  
  SELECT estado INTO v_estado_backup
  FROM sync.backup
  WHERE id_backup = p_id_backup_a_restaurar;

  IF v_estado_backup IS NULL THEN
    RAISE EXCEPTION 'El backup indicado no existe.';
  ELSIF v_estado_backup <> 'completado' THEN
    RAISE EXCEPTION 'El backup no est├í en estado completado y no puede restaurarse.';
  END IF;

  
  
  
  
  p_id_backup_seguridad := uuid_generate_v4();

  INSERT INTO sync.backup (
    id_backup, id_user, tipo, alcance,
    ubicacion, estado, descripcion, created_at
  )
  VALUES (
    p_id_backup_seguridad, p_id_admin, 'automatico', 'completo',
    p_ubicacion_backup_seg, 'completado',
    CONCAT('Backup de seguridad autom├ítico previo a restauraci├│n del backup: ', p_id_backup_a_restaurar),
    NOW()
  );

  
  
  
  
  
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_admin, 'restaurar', 'sync',
    'backup', p_id_backup_a_restaurar, 'exitoso',
    CONCAT('Inicio de restauraci├│n de backup. Motivo: ', p_motivo),
    NOW()
  );

  
  
  
  
  
  
  
  

  
  
  
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), p_id_admin, 'restaurar', 'sync',
    'backup', p_id_backup_a_restaurar, 'exitoso',
    'Restauraci├│n registrada exitosamente. Backup de seguridad creado previamente.',
    NOW()
  );

EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error al restaurar el backup: %', SQLERRM;
END;
$$;


--
-- Name: PROCEDURE sp_restaurar_backup(IN p_id_admin uuid, IN p_id_backup_a_restaurar uuid, IN p_motivo text, IN p_ubicacion_backup_seg text, OUT p_id_backup_seguridad uuid); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON PROCEDURE public.sp_restaurar_backup(IN p_id_admin uuid, IN p_id_backup_a_restaurar uuid, IN p_motivo text, IN p_ubicacion_backup_seg text, OUT p_id_backup_seguridad uuid) IS 'Valida permisos de administrador, crea un backup de seguridad del estado actual y registra el proceso de restauraci├│n. Solo administradores pueden ejecutarlo.';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.audit_log (
    id_audit_log uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid,
    accion character varying(50) NOT NULL,
    modulo character varying(50) NOT NULL,
    entidad character varying(50),
    id_entidad uuid,
    datos_anteriores jsonb,
    datos_nuevos jsonb,
    ip_address character varying(45),
    user_agent text,
    resultado character varying(10) DEFAULT 'exitoso'::character varying NOT NULL,
    detalle text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_audit_log_accion CHECK (((accion)::text = ANY ((ARRAY['crear'::character varying, 'editar'::character varying, 'eliminar'::character varying, 'login'::character varying, 'logout'::character varying, 'restaurar'::character varying, 'exportar'::character varying, 'configurar'::character varying, 'asignar'::character varying, 'revocar'::character varying])::text[]))),
    CONSTRAINT ck_audit_log_resultado CHECK (((resultado)::text = ANY ((ARRAY['exitoso'::character varying, 'fallido'::character varying])::text[])))
);


--
-- Name: TABLE audit_log; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON TABLE audit.audit_log IS 'Registro inmutable de auditor├¡a de todas las operaciones cr├¡ticas del sistema Smart Home.';


--
-- Name: COLUMN audit_log.id_audit_log; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.id_audit_log IS 'Identificador ├║nico del registro de auditor├¡a.';


--
-- Name: COLUMN audit_log.id_user; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.id_user IS 'Usuario que realiz├│ la acci├│n. NULL si es proceso autom├ítico del sistema.';


--
-- Name: COLUMN audit_log.accion; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.accion IS 'Acci├│n realizada: crear, editar, eliminar, login, logout, restaurar, exportar, configurar, asignar, revocar.';


--
-- Name: COLUMN audit_log.modulo; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.modulo IS 'M├│dulo del sistema donde ocurri├│ la acci├│n (ej: usuarios, hogares, dispositivos).';


--
-- Name: COLUMN audit_log.entidad; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.entidad IS 'Entidad afectada por la acci├│n (ej: user, home, device, session).';


--
-- Name: COLUMN audit_log.id_entidad; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.id_entidad IS 'Identificador UUID del registro afectado por la acci├│n.';


--
-- Name: COLUMN audit_log.datos_anteriores; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.datos_anteriores IS 'Estado anterior del registro antes de la acci├│n. NULL para creaciones.';


--
-- Name: COLUMN audit_log.datos_nuevos; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.datos_nuevos IS 'Estado nuevo del registro despu├®s de la acci├│n. NULL para eliminaciones.';


--
-- Name: COLUMN audit_log.ip_address; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.ip_address IS 'Direcci├│n IP desde donde se realiz├│ la acci├│n (IPv4 o IPv6).';


--
-- Name: COLUMN audit_log.user_agent; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.user_agent IS 'Informaci├│n del navegador o dispositivo desde donde se realiz├│ la acci├│n.';


--
-- Name: COLUMN audit_log.resultado; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.resultado IS 'Resultado de la acci├│n: exitoso o fallido.';


--
-- Name: COLUMN audit_log.detalle; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.detalle IS 'Descripci├│n adicional, mensaje de error o contexto de la acci├│n.';


--
-- Name: COLUMN audit_log.created_at; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON COLUMN audit.audit_log.created_at IS 'Fecha y hora exacta en que ocurri├│ la acci├│n. Inmutable.';


--
-- Name: mv_estadisticas_mensuales; Type: MATERIALIZED VIEW; Schema: audit; Owner: -
--

CREATE MATERIALIZED VIEW audit.mv_estadisticas_mensuales AS
 SELECT (date_trunc('month'::text, al.created_at))::date AS mes,
    al.modulo,
    al.accion,
    al.resultado,
    count(*) AS total_registros,
    count(DISTINCT al.id_user) AS usuarios_distintos
   FROM audit.audit_log al
  GROUP BY (date_trunc('month'::text, al.created_at)), al.modulo, al.accion, al.resultado
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_estadisticas_mensuales; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON MATERIALIZED VIEW audit.mv_estadisticas_mensuales IS 'Estad├¡sticas mensuales de auditor├¡a agregadas por m├│dulo, acci├│n y resultado. Refrescar diariamente. No usar para consulta de logs en vivo.';


--
-- Name: user; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth."user" (
    id_user uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(100) NOT NULL,
    apellido character varying(100) NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash text NOT NULL,
    tipo_documento character varying(20) NOT NULL,
    numero_documento character varying(30) NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    email_verificado boolean DEFAULT false NOT NULL,
    intentos_fallidos smallint DEFAULT 0 NOT NULL,
    bloqueado_hasta timestamp with time zone,
    mfa_habilitado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_user_estado CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'activo'::character varying, 'desactivado'::character varying, 'bloqueado'::character varying])::text[]))),
    CONSTRAINT ck_user_intentos CHECK ((intentos_fallidos >= 0)),
    CONSTRAINT ck_user_tipo_documento CHECK (((tipo_documento)::text = ANY ((ARRAY['CC'::character varying, 'CE'::character varying, 'PAS'::character varying])::text[])))
);


--
-- Name: TABLE "user"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth."user" IS 'Usuarios registrados en el sistema Smart Home.';


--
-- Name: COLUMN "user".id_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".id_user IS 'Identificador ├║nico del usuario.';


--
-- Name: COLUMN "user".nombre; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".nombre IS 'Nombre del usuario.';


--
-- Name: COLUMN "user".apellido; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".apellido IS 'Apellido del usuario.';


--
-- Name: COLUMN "user".username; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".username IS 'Nombre de usuario ├║nico en el sistema.';


--
-- Name: COLUMN "user".email; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".email IS 'Correo electr├│nico ├║nico del usuario.';


--
-- Name: COLUMN "user".password_hash; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".password_hash IS 'Contrase├▒a encriptada con pgcrypto (bcrypt).';


--
-- Name: COLUMN "user".tipo_documento; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".tipo_documento IS 'Tipo de documento: CC, CE, PAS.';


--
-- Name: COLUMN "user".numero_documento; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".numero_documento IS 'N├║mero de documento de identidad ├║nico.';


--
-- Name: COLUMN "user".estado; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".estado IS 'Estado de la cuenta: pendiente, activo, desactivado, bloqueado.';


--
-- Name: COLUMN "user".email_verificado; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".email_verificado IS 'Indica si el correo fue verificado.';


--
-- Name: COLUMN "user".intentos_fallidos; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".intentos_fallidos IS 'Contador de intentos fallidos de inicio de sesi├│n.';


--
-- Name: COLUMN "user".bloqueado_hasta; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".bloqueado_hasta IS 'Fecha y hora hasta la que la cuenta est├í bloqueada.';


--
-- Name: COLUMN "user".mfa_habilitado; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".mfa_habilitado IS 'Indica si la autenticaci├│n multifactor est├í activa.';


--
-- Name: COLUMN "user".created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN "user".updated_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN "user".deleted_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth."user".deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: vw_actividad_por_usuario; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.vw_actividad_por_usuario AS
 SELECT al.id_user,
    u.nombre AS nombre_usuario,
    u.apellido AS apellido_usuario,
    u.email AS email_usuario,
    count(*) AS total_acciones,
    count(*) FILTER (WHERE ((al.resultado)::text = 'exitoso'::text)) AS acciones_exitosas,
    count(*) FILTER (WHERE ((al.resultado)::text = 'fallido'::text)) AS acciones_fallidas,
    max(al.created_at) AS ultima_actividad
   FROM (audit.audit_log al
     JOIN auth."user" u ON (((u.id_user = al.id_user) AND (u.deleted_at IS NULL))))
  WHERE (al.created_at > (now() - '30 days'::interval))
  GROUP BY al.id_user, u.nombre, u.apellido, u.email
  ORDER BY (count(*)) DESC;


--
-- Name: VIEW vw_actividad_por_usuario; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON VIEW audit.vw_actividad_por_usuario IS 'Resumen de actividad por usuario en los ├║ltimos 30 d├¡as, diferenciando acciones exitosas y fallidas.';


--
-- Name: vw_eventos_fallidos; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.vw_eventos_fallidos AS
 SELECT al.id_audit_log,
    al.id_user,
    u.nombre AS nombre_usuario,
    u.email AS email_usuario,
    al.accion,
    al.modulo,
    al.entidad,
    al.ip_address,
    al.detalle,
    al.created_at
   FROM (audit.audit_log al
     LEFT JOIN auth."user" u ON ((u.id_user = al.id_user)))
  WHERE ((al.resultado)::text = 'fallido'::text)
  ORDER BY al.created_at DESC;


--
-- Name: VIEW vw_eventos_fallidos; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON VIEW audit.vw_eventos_fallidos IS 'Registros de auditor├¡a con resultado fallido, usados para detectar errores recurrentes o accesos no autorizados.';


--
-- Name: vw_logs_inicio_cierre_sesion; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.vw_logs_inicio_cierre_sesion AS
 SELECT al.id_audit_log,
    al.id_user,
    u.nombre AS nombre_usuario,
    u.email AS email_usuario,
    al.accion,
    al.ip_address,
    al.user_agent,
    al.resultado,
    al.created_at
   FROM (audit.audit_log al
     LEFT JOIN auth."user" u ON ((u.id_user = al.id_user)))
  WHERE ((al.accion)::text = ANY ((ARRAY['login'::character varying, 'logout'::character varying])::text[]))
  ORDER BY al.created_at DESC;


--
-- Name: VIEW vw_logs_inicio_cierre_sesion; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON VIEW audit.vw_logs_inicio_cierre_sesion IS 'Eventos de inicio y cierre de sesi├│n para reportes de seguridad y trazabilidad de accesos.';


--
-- Name: vw_logs_recientes; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.vw_logs_recientes AS
 SELECT al.id_audit_log,
    al.id_user,
    u.nombre AS nombre_usuario,
    u.apellido AS apellido_usuario,
    u.email AS email_usuario,
    al.accion,
    al.modulo,
    al.entidad,
    al.id_entidad,
    al.ip_address,
    al.resultado,
    al.detalle,
    al.created_at
   FROM (audit.audit_log al
     LEFT JOIN auth."user" u ON ((u.id_user = al.id_user)))
  WHERE (al.created_at > (now() - '30 days'::interval))
  ORDER BY al.created_at DESC;


--
-- Name: VIEW vw_logs_recientes; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON VIEW audit.vw_logs_recientes IS 'Registros de auditor├¡a de los ├║ltimos 30 d├¡as con informaci├│n del usuario. Base para la consulta de logs del administrador.';


--
-- Name: vw_resumen_por_modulo; Type: VIEW; Schema: audit; Owner: -
--

CREATE VIEW audit.vw_resumen_por_modulo AS
 SELECT al.modulo,
    al.accion,
    al.resultado,
    count(*) AS total_registros,
    max(al.created_at) AS ultima_ocurrencia
   FROM audit.audit_log al
  WHERE (al.created_at > (now() - '30 days'::interval))
  GROUP BY al.modulo, al.accion, al.resultado
  ORDER BY al.modulo, (count(*)) DESC;


--
-- Name: VIEW vw_resumen_por_modulo; Type: COMMENT; Schema: audit; Owner: -
--

COMMENT ON VIEW audit.vw_resumen_por_modulo IS 'Resumen estad├¡stico de acciones de auditor├¡a agrupadas por m├│dulo, acci├│n y resultado en los ├║ltimos 30 d├¡as.';


--
-- Name: mfa; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.mfa (
    id_mfa uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    metodo character varying(20) NOT NULL,
    codigo_secreto text,
    habilitado boolean DEFAULT false NOT NULL,
    ultimo_codigo_hash text,
    expira_en timestamp with time zone,
    intentos_fallidos smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_mfa_intentos CHECK ((intentos_fallidos >= 0)),
    CONSTRAINT ck_mfa_metodo CHECK (((metodo)::text = ANY ((ARRAY['sms'::character varying, 'email'::character varying, 'app'::character varying])::text[])))
);


--
-- Name: TABLE mfa; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.mfa IS 'Configuraci├│n de autenticaci├│n multifactor por usuario.';


--
-- Name: COLUMN mfa.id_mfa; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.id_mfa IS 'Identificador ├║nico de la configuraci├│n MFA.';


--
-- Name: COLUMN mfa.id_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.id_user IS 'Usuario due├▒o de la configuraci├│n MFA.';


--
-- Name: COLUMN mfa.metodo; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.metodo IS 'M├®todo MFA: sms, email, app.';


--
-- Name: COLUMN mfa.codigo_secreto; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.codigo_secreto IS 'Secreto cifrado para apps autenticadoras.';


--
-- Name: COLUMN mfa.habilitado; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.habilitado IS 'Indica si MFA est├í activo para el usuario.';


--
-- Name: COLUMN mfa.ultimo_codigo_hash; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.ultimo_codigo_hash IS 'Hash del ├║ltimo c├│digo generado para evitar reutilizaci├│n.';


--
-- Name: COLUMN mfa.expira_en; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.expira_en IS 'Fecha de expiraci├│n del ├║ltimo c├│digo generado.';


--
-- Name: COLUMN mfa.intentos_fallidos; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.intentos_fallidos IS 'Intentos fallidos de verificaci├│n MFA.';


--
-- Name: COLUMN mfa.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN mfa.updated_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.mfa.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: permission; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.permission (
    id_permission uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(100) NOT NULL,
    modulo character varying(50) NOT NULL,
    accion character varying(50) NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE permission; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.permission IS 'Cat├ílogo de permisos del sistema por m├│dulo y acci├│n.';


--
-- Name: COLUMN permission.id_permission; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.id_permission IS 'Identificador ├║nico del permiso.';


--
-- Name: COLUMN permission.nombre; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.nombre IS 'Nombre ├║nico del permiso (ej: hogares:crear).';


--
-- Name: COLUMN permission.modulo; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.modulo IS 'M├│dulo al que pertenece el permiso.';


--
-- Name: COLUMN permission.accion; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.accion IS 'Acci├│n que habilita: leer, crear, editar, eliminar.';


--
-- Name: COLUMN permission.descripcion; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.descripcion IS 'Descripci├│n detallada del permiso.';


--
-- Name: COLUMN permission.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN permission.updated_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN permission.deleted_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.permission.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: recovery_token; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.recovery_token (
    id_recovery_token uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    token text NOT NULL,
    tipo character varying(30) NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    usado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_recovery_token_tipo CHECK (((tipo)::text = ANY ((ARRAY['recuperacion_password'::character varying, 'activacion_cuenta'::character varying, 'reactivacion_cuenta'::character varying])::text[])))
);


--
-- Name: TABLE recovery_token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.recovery_token IS 'Tokens temporales para recuperaci├│n y activaci├│n de cuentas.';


--
-- Name: COLUMN recovery_token.id_recovery_token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.id_recovery_token IS 'Identificador ├║nico del token.';


--
-- Name: COLUMN recovery_token.id_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.id_user IS 'Usuario al que pertenece el token.';


--
-- Name: COLUMN recovery_token.token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.token IS 'Token ├║nico de recuperaci├│n.';


--
-- Name: COLUMN recovery_token.tipo; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.tipo IS 'Tipo de token: recuperacion_password, activacion_cuenta, reactivacion_cuenta.';


--
-- Name: COLUMN recovery_token.expira_en; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.expira_en IS 'Fecha y hora de expiraci├│n del token.';


--
-- Name: COLUMN recovery_token.usado; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.usado IS 'Indica si el token ya fue utilizado.';


--
-- Name: COLUMN recovery_token.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.recovery_token.created_at IS 'Fecha de creaci├│n del token.';


--
-- Name: role; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.role (
    id_role uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(50) NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE role; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.role IS 'Roles disponibles en el sistema Smart Home.';


--
-- Name: COLUMN role.id_role; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role.id_role IS 'Identificador ├║nico del rol.';


--
-- Name: COLUMN role.nombre; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role.nombre IS 'Nombre del rol: administrador, estandar, invitado.';


--
-- Name: COLUMN role.descripcion; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role.descripcion IS 'Descripci├│n del prop├│sito del rol.';


--
-- Name: COLUMN role.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN role.updated_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN role.deleted_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: role_permission; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.role_permission (
    id_role_permission uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_role uuid NOT NULL,
    id_permission uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE role_permission; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.role_permission IS 'Asignaci├│n de permisos a roles del sistema.';


--
-- Name: COLUMN role_permission.id_role_permission; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role_permission.id_role_permission IS 'Identificador ├║nico de la asignaci├│n.';


--
-- Name: COLUMN role_permission.id_role; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role_permission.id_role IS 'Rol al que se asigna el permiso.';


--
-- Name: COLUMN role_permission.id_permission; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role_permission.id_permission IS 'Permiso asignado al rol.';


--
-- Name: COLUMN role_permission.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role_permission.created_at IS 'Fecha de asignaci├│n del permiso.';


--
-- Name: COLUMN role_permission.deleted_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.role_permission.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: session; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.session (
    id_session uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    token text NOT NULL,
    refresh_token text,
    ip_address character varying(45),
    user_agent text,
    recordar_sesion boolean DEFAULT false NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE session; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.session IS 'Sesiones activas de usuarios en el sistema.';


--
-- Name: COLUMN session.id_session; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.id_session IS 'Identificador ├║nico de la sesi├│n.';


--
-- Name: COLUMN session.id_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.id_user IS 'Usuario due├▒o de la sesi├│n.';


--
-- Name: COLUMN session.token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.token IS 'Token JWT de la sesi├│n.';


--
-- Name: COLUMN session.refresh_token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.refresh_token IS 'Token de renovaci├│n de sesi├│n.';


--
-- Name: COLUMN session.ip_address; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.ip_address IS 'Direcci├│n IP desde donde se inici├│ sesi├│n.';


--
-- Name: COLUMN session.user_agent; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.user_agent IS 'Informaci├│n del navegador o dispositivo.';


--
-- Name: COLUMN session.recordar_sesion; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.recordar_sesion IS 'Indica si el usuario seleccion├│ recordar sesi├│n.';


--
-- Name: COLUMN session.expira_en; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.expira_en IS 'Fecha y hora de expiraci├│n del token.';


--
-- Name: COLUMN session.activa; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.activa IS 'Indica si la sesi├│n est├í activa.';


--
-- Name: COLUMN session.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.created_at IS 'Fecha de creaci├│n de la sesi├│n.';


--
-- Name: COLUMN session.updated_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN session.deleted_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.session.deleted_at IS 'Fecha de cierre o eliminaci├│n l├│gica.';


--
-- Name: token_blacklist; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.token_blacklist (
    id_token_blacklist uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    token text NOT NULL,
    id_user uuid NOT NULL,
    motivo character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expira_en timestamp with time zone NOT NULL,
    CONSTRAINT ck_token_blacklist_motivo CHECK (((motivo)::text = ANY ((ARRAY['logout'::character varying, 'cambio_password'::character varying, 'desactivacion'::character varying, 'expiracion'::character varying])::text[])))
);


--
-- Name: TABLE token_blacklist; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.token_blacklist IS 'Tokens JWT revocados para prevenir reutilizaci├│n.';


--
-- Name: COLUMN token_blacklist.id_token_blacklist; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.token_blacklist.id_token_blacklist IS 'Identificador ├║nico del registro.';


--
-- Name: COLUMN token_blacklist.token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.token_blacklist.token IS 'Token JWT revocado.';


--
-- Name: COLUMN token_blacklist.id_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.token_blacklist.id_user IS 'Usuario al que pertenec├¡a el token.';


--
-- Name: COLUMN token_blacklist.motivo; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.token_blacklist.motivo IS 'Motivo de revocaci├│n: logout, cambio_password, desactivacion, expiracion.';


--
-- Name: COLUMN token_blacklist.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.token_blacklist.created_at IS 'Fecha de revocaci├│n del token.';


--
-- Name: COLUMN token_blacklist.expira_en; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.token_blacklist.expira_en IS 'Fecha de expiraci├│n original del token.';


--
-- Name: user_role; Type: TABLE; Schema: auth; Owner: -
--

CREATE TABLE auth.user_role (
    id_user_role uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    id_role uuid NOT NULL,
    asignado_por uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE user_role; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TABLE auth.user_role IS 'Asignaci├│n de roles a usuarios del sistema.';


--
-- Name: COLUMN user_role.id_user_role; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.user_role.id_user_role IS 'Identificador ├║nico de la asignaci├│n.';


--
-- Name: COLUMN user_role.id_user; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.user_role.id_user IS 'Usuario al que se asigna el rol.';


--
-- Name: COLUMN user_role.id_role; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.user_role.id_role IS 'Rol asignado al usuario.';


--
-- Name: COLUMN user_role.asignado_por; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.user_role.asignado_por IS 'Administrador que realiz├│ la asignaci├│n.';


--
-- Name: COLUMN user_role.created_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.user_role.created_at IS 'Fecha de asignaci├│n del rol.';


--
-- Name: COLUMN user_role.deleted_at; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON COLUMN auth.user_role.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: vw_cuentas_bloqueadas; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_cuentas_bloqueadas AS
 SELECT u.id_user,
    u.nombre,
    u.apellido,
    u.email,
    u.intentos_fallidos,
    u.bloqueado_hasta,
    (EXTRACT(epoch FROM (u.bloqueado_hasta - now())) / (60)::numeric) AS minutos_restantes_bloqueo
   FROM auth."user" u
  WHERE (((u.estado)::text = 'bloqueado'::text) AND (u.deleted_at IS NULL) AND (u.bloqueado_hasta > now()));


--
-- Name: VIEW vw_cuentas_bloqueadas; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_cuentas_bloqueadas IS 'Cuentas bloqueadas actualmente con tiempo restante de bloqueo en minutos.';


--
-- Name: vw_sesiones_activas; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_sesiones_activas AS
 SELECT s.id_session,
    s.id_user,
    u.nombre,
    u.apellido,
    u.email,
    s.ip_address,
    s.user_agent,
    s.recordar_sesion,
    s.created_at AS inicio_sesion,
    s.expira_en,
    (EXTRACT(epoch FROM (s.expira_en - now())) / (60)::numeric) AS minutos_restantes
   FROM (auth.session s
     JOIN auth."user" u ON (((u.id_user = s.id_user) AND (u.deleted_at IS NULL))))
  WHERE ((s.activa = true) AND (s.deleted_at IS NULL) AND (s.expira_en > now()));


--
-- Name: VIEW vw_sesiones_activas; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_sesiones_activas IS 'Sesiones activas y no expiradas con tiempo restante en minutos antes de expiraci├│n.';


--
-- Name: vw_tokens_por_vencer; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_tokens_por_vencer AS
 SELECT rt.id_recovery_token,
    rt.id_user,
    u.email,
    rt.tipo,
    rt.expira_en,
    (EXTRACT(epoch FROM (rt.expira_en - now())) / (60)::numeric) AS minutos_restantes
   FROM (auth.recovery_token rt
     JOIN auth."user" u ON (((u.id_user = rt.id_user) AND (u.deleted_at IS NULL))))
  WHERE ((rt.usado = false) AND (rt.expira_en > now()) AND (rt.expira_en < (now() + '02:00:00'::interval)));


--
-- Name: VIEW vw_tokens_por_vencer; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_tokens_por_vencer IS 'Tokens de recuperaci├│n y activaci├│n pr├│ximos a vencer en las siguientes 2 horas.';


--
-- Name: vw_usuarios_activos; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_usuarios_activos AS
 SELECT u.id_user,
    u.nombre,
    u.apellido,
    u.username,
    u.email,
    u.tipo_documento,
    u.numero_documento,
    u.estado,
    u.email_verificado,
    u.mfa_habilitado,
    u.intentos_fallidos,
    u.bloqueado_hasta,
    u.created_at,
    u.updated_at
   FROM auth."user" u
  WHERE (u.deleted_at IS NULL);


--
-- Name: VIEW vw_usuarios_activos; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_usuarios_activos IS 'Usuarios del sistema excluyendo eliminados l├│gicamente y campos sensibles.';


--
-- Name: vw_usuarios_con_roles; Type: VIEW; Schema: auth; Owner: -
--

CREATE VIEW auth.vw_usuarios_con_roles AS
 SELECT u.id_user,
    u.nombre,
    u.apellido,
    u.username,
    u.email,
    u.estado,
    r.id_role,
    r.nombre AS rol,
    p.id_permission,
    p.nombre AS permiso,
    p.modulo,
    p.accion
   FROM ((((auth."user" u
     JOIN auth.user_role ur ON (((ur.id_user = u.id_user) AND (ur.deleted_at IS NULL))))
     JOIN auth.role r ON (((r.id_role = ur.id_role) AND (r.deleted_at IS NULL))))
     JOIN auth.role_permission rp ON (((rp.id_role = r.id_role) AND (rp.deleted_at IS NULL))))
     JOIN auth.permission p ON (((p.id_permission = rp.id_permission) AND (p.deleted_at IS NULL))))
  WHERE ((u.deleted_at IS NULL) AND ((u.estado)::text = 'activo'::text));


--
-- Name: VIEW vw_usuarios_con_roles; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON VIEW auth.vw_usuarios_con_roles IS 'Usuarios activos con sus roles y permisos asociados. Facilita la validaci├│n de acceso en el backend.';


--
-- Name: configuration_user; Type: TABLE; Schema: config; Owner: -
--

CREATE TABLE config.configuration_user (
    id_configuration_user uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    idioma character varying(10) DEFAULT 'es'::character varying NOT NULL,
    tema character varying(10) DEFAULT 'claro'::character varying NOT NULL,
    formato_fecha character varying(20) DEFAULT 'DD/MM/YYYY'::character varying NOT NULL,
    formato_hora character varying(5) DEFAULT '24h'::character varying NOT NULL,
    moneda character varying(10) DEFAULT 'COP'::character varying NOT NULL,
    unidad_temperatura character varying(5) DEFAULT 'C'::character varying NOT NULL,
    notif_consumo_elevado boolean DEFAULT true NOT NULL,
    notif_dispositivos boolean DEFAULT true NOT NULL,
    notif_recomendaciones boolean DEFAULT true NOT NULL,
    notif_seguridad boolean DEFAULT true NOT NULL,
    notif_canal_app boolean DEFAULT true NOT NULL,
    notif_canal_email boolean DEFAULT true NOT NULL,
    notif_canal_push boolean DEFAULT true NOT NULL,
    no_molestar_inicio time without time zone,
    no_molestar_fin time without time zone,
    recomendaciones_activas boolean DEFAULT true NOT NULL,
    frecuencia_recomendaciones character varying(10) DEFAULT 'semanal'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_configuration_user_formato_hora CHECK (((formato_hora)::text = ANY ((ARRAY['12h'::character varying, '24h'::character varying])::text[]))),
    CONSTRAINT ck_configuration_user_frecuencia CHECK (((frecuencia_recomendaciones)::text = ANY ((ARRAY['diaria'::character varying, 'semanal'::character varying, 'mensual'::character varying])::text[]))),
    CONSTRAINT ck_configuration_user_idioma CHECK (((idioma)::text = ANY ((ARRAY['es'::character varying, 'en'::character varying, 'fr'::character varying, 'de'::character varying])::text[]))),
    CONSTRAINT ck_configuration_user_no_molestar CHECK ((((no_molestar_inicio IS NULL) AND (no_molestar_fin IS NULL)) OR ((no_molestar_inicio IS NOT NULL) AND (no_molestar_fin IS NOT NULL) AND (no_molestar_inicio <> no_molestar_fin)))),
    CONSTRAINT ck_configuration_user_tema CHECK (((tema)::text = ANY ((ARRAY['claro'::character varying, 'oscuro'::character varying, 'automatico'::character varying])::text[]))),
    CONSTRAINT ck_configuration_user_unidad_temp CHECK (((unidad_temperatura)::text = ANY ((ARRAY['C'::character varying, 'F'::character varying])::text[])))
);

ALTER TABLE ONLY config.configuration_user FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE configuration_user; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON TABLE config.configuration_user IS 'Preferencias de configuraci├│n personal por usuario.';


--
-- Name: COLUMN configuration_user.id_configuration_user; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.id_configuration_user IS 'Identificador ├║nico de la configuraci├│n.';


--
-- Name: COLUMN configuration_user.id_user; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.id_user IS 'Usuario due├▒o de la configuraci├│n (uno a uno con auth.user).';


--
-- Name: COLUMN configuration_user.idioma; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.idioma IS 'Idioma de la interfaz: es, en, fr, de.';


--
-- Name: COLUMN configuration_user.tema; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.tema IS 'Tema visual: claro, oscuro, automatico.';


--
-- Name: COLUMN configuration_user.formato_fecha; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.formato_fecha IS 'Formato de fecha seg├║n regi├│n (ej: DD/MM/YYYY, MM/DD/YYYY).';


--
-- Name: COLUMN configuration_user.formato_hora; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.formato_hora IS 'Formato de hora: 12h o 24h.';


--
-- Name: COLUMN configuration_user.moneda; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.moneda IS 'Moneda para reportes de costos (ej: COP, USD).';


--
-- Name: COLUMN configuration_user.unidad_temperatura; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.unidad_temperatura IS 'Unidad de temperatura: C (Celsius) o F (Fahrenheit).';


--
-- Name: COLUMN configuration_user.notif_consumo_elevado; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_consumo_elevado IS 'Activar notificaciones cuando el consumo sea elevado.';


--
-- Name: COLUMN configuration_user.notif_dispositivos; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_dispositivos IS 'Activar notificaciones relacionadas con dispositivos.';


--
-- Name: COLUMN configuration_user.notif_recomendaciones; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_recomendaciones IS 'Activar notificaciones de nuevas recomendaciones de ahorro.';


--
-- Name: COLUMN configuration_user.notif_seguridad; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_seguridad IS 'Activar notificaciones de eventos de seguridad.';


--
-- Name: COLUMN configuration_user.notif_canal_app; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_canal_app IS 'Recibir notificaciones dentro de la aplicaci├│n.';


--
-- Name: COLUMN configuration_user.notif_canal_email; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_canal_email IS 'Recibir notificaciones por correo electr├│nico.';


--
-- Name: COLUMN configuration_user.notif_canal_push; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.notif_canal_push IS 'Recibir notificaciones push en el dispositivo m├│vil.';


--
-- Name: COLUMN configuration_user.no_molestar_inicio; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.no_molestar_inicio IS 'Hora de inicio del modo No Molestar.';


--
-- Name: COLUMN configuration_user.no_molestar_fin; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.no_molestar_fin IS 'Hora de fin del modo No Molestar.';


--
-- Name: COLUMN configuration_user.recomendaciones_activas; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.recomendaciones_activas IS 'Indica si la generaci├│n autom├ítica de recomendaciones est├í activa.';


--
-- Name: COLUMN configuration_user.frecuencia_recomendaciones; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.frecuencia_recomendaciones IS 'Frecuencia de generaci├│n de recomendaciones: diaria, semanal, mensual.';


--
-- Name: COLUMN configuration_user.created_at; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN configuration_user.updated_at; Type: COMMENT; Schema: config; Owner: -
--

COMMENT ON COLUMN config.configuration_user.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: consumption; Type: TABLE; Schema: consumption; Owner: -
--

CREATE TABLE consumption.consumption (
    id_consumption uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    id_home uuid NOT NULL,
    watts numeric(10,4) NOT NULL,
    kwh_acumulado numeric(12,6) DEFAULT 0 NOT NULL,
    costo_estimado numeric(12,4),
    fecha_lectura timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_consumption_costo CHECK (((costo_estimado IS NULL) OR (costo_estimado >= (0)::numeric))),
    CONSTRAINT ck_consumption_kwh CHECK ((kwh_acumulado >= (0)::numeric)),
    CONSTRAINT ck_consumption_watts CHECK ((watts >= (0)::numeric))
);

ALTER TABLE ONLY consumption.consumption FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE consumption; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON TABLE consumption.consumption IS 'Lecturas de consumo el├®ctrico en tiempo real por dispositivo.';


--
-- Name: COLUMN consumption.id_consumption; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.id_consumption IS 'Identificador ├║nico de la lectura.';


--
-- Name: COLUMN consumption.id_device; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.id_device IS 'Dispositivo que gener├│ la lectura.';


--
-- Name: COLUMN consumption.id_home; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.id_home IS 'Hogar al que pertenece el dispositivo.';


--
-- Name: COLUMN consumption.watts; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.watts IS 'Consumo instant├íneo en Watts al momento de la lectura.';


--
-- Name: COLUMN consumption.kwh_acumulado; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.kwh_acumulado IS 'Consumo acumulado en kWh desde el inicio del d├¡a.';


--
-- Name: COLUMN consumption.costo_estimado; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.costo_estimado IS 'Costo estimado seg├║n la tarifa el├®ctrica vigente del hogar.';


--
-- Name: COLUMN consumption.fecha_lectura; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption.fecha_lectura IS 'Fecha y hora exacta de la lectura de consumo.';


--
-- Name: consumption_metric; Type: TABLE; Schema: consumption; Owner: -
--

CREATE TABLE consumption.consumption_metric (
    id_consumption_metric uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    id_home uuid NOT NULL,
    periodo character varying(10) NOT NULL,
    fecha_inicio timestamp with time zone NOT NULL,
    fecha_fin timestamp with time zone NOT NULL,
    kwh_total numeric(12,6) DEFAULT 0 NOT NULL,
    costo_total numeric(12,4),
    watts_promedio numeric(10,4),
    watts_maximo numeric(10,4),
    watts_minimo numeric(10,4),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_consumption_metric_costo CHECK (((costo_total IS NULL) OR (costo_total >= (0)::numeric))),
    CONSTRAINT ck_consumption_metric_fechas CHECK ((fecha_fin > fecha_inicio)),
    CONSTRAINT ck_consumption_metric_kwh CHECK ((kwh_total >= (0)::numeric)),
    CONSTRAINT ck_consumption_metric_max_min CHECK (((watts_maximo IS NULL) OR (watts_minimo IS NULL) OR (watts_maximo >= watts_minimo))),
    CONSTRAINT ck_consumption_metric_periodo CHECK (((periodo)::text = ANY ((ARRAY['hora'::character varying, 'dia'::character varying, 'semana'::character varying, 'mes'::character varying])::text[]))),
    CONSTRAINT ck_consumption_metric_watts CHECK ((((watts_promedio IS NULL) OR (watts_promedio >= (0)::numeric)) AND ((watts_maximo IS NULL) OR (watts_maximo >= (0)::numeric)) AND ((watts_minimo IS NULL) OR (watts_minimo >= (0)::numeric))))
);

ALTER TABLE ONLY consumption.consumption_metric FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE consumption_metric; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON TABLE consumption.consumption_metric IS 'M├®tricas agregadas de consumo por periodo para reportes y gr├íficos.';


--
-- Name: COLUMN consumption_metric.id_consumption_metric; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.id_consumption_metric IS 'Identificador ├║nico de la m├®trica.';


--
-- Name: COLUMN consumption_metric.id_device; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.id_device IS 'Dispositivo al que pertenece la m├®trica.';


--
-- Name: COLUMN consumption_metric.id_home; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.id_home IS 'Hogar al que pertenece la m├®trica.';


--
-- Name: COLUMN consumption_metric.periodo; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.periodo IS 'Periodo de agregaci├│n: hora, dia, semana, mes.';


--
-- Name: COLUMN consumption_metric.fecha_inicio; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.fecha_inicio IS 'Fecha y hora de inicio del periodo.';


--
-- Name: COLUMN consumption_metric.fecha_fin; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.fecha_fin IS 'Fecha y hora de fin del periodo.';


--
-- Name: COLUMN consumption_metric.kwh_total; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.kwh_total IS 'Total de kWh consumidos en el periodo.';


--
-- Name: COLUMN consumption_metric.costo_total; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.costo_total IS 'Costo total del periodo seg├║n tarifa vigente.';


--
-- Name: COLUMN consumption_metric.watts_promedio; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.watts_promedio IS 'Consumo promedio en Watts durante el periodo.';


--
-- Name: COLUMN consumption_metric.watts_maximo; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.watts_maximo IS 'Consumo m├íximo en Watts registrado en el periodo.';


--
-- Name: COLUMN consumption_metric.watts_minimo; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.watts_minimo IS 'Consumo m├¡nimo en Watts registrado en el periodo.';


--
-- Name: COLUMN consumption_metric.created_at; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.created_at IS 'Fecha de creaci├│n de la m├®trica.';


--
-- Name: COLUMN consumption_metric.updated_at; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.consumption_metric.updated_at IS 'Fecha de ├║ltima actualizaci├│n de la m├®trica.';


--
-- Name: device; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.device (
    id_device uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_home uuid NOT NULL,
    id_area uuid,
    id_type_device uuid NOT NULL,
    nombre character varying(100) NOT NULL,
    estado character varying(20) DEFAULT 'desconectado'::character varying NOT NULL,
    encendido boolean DEFAULT false NOT NULL,
    consumo_actual_w numeric(10,2),
    mac_address character varying(17),
    protocolo character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_device_consumo CHECK (((consumo_actual_w IS NULL) OR (consumo_actual_w >= (0)::numeric))),
    CONSTRAINT ck_device_estado CHECK (((estado)::text = ANY ((ARRAY['conectado'::character varying, 'desconectado'::character varying, 'activo'::character varying, 'desactivado'::character varying])::text[]))),
    CONSTRAINT ck_device_mac CHECK (((mac_address IS NULL) OR ((mac_address)::text ~ '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$'::text))),
    CONSTRAINT ck_device_protocolo CHECK (((protocolo IS NULL) OR ((protocolo)::text = ANY ((ARRAY['wifi'::character varying, 'bluetooth'::character varying, 'mqtt'::character varying])::text[]))))
);

ALTER TABLE ONLY devices.device FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.device IS 'Dispositivos IoT registrados en el sistema Smart Home.';


--
-- Name: COLUMN device.id_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.id_device IS 'Identificador ├║nico del dispositivo (inmutable una vez creado).';


--
-- Name: COLUMN device.id_home; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.id_home IS 'Hogar al que pertenece el dispositivo.';


--
-- Name: COLUMN device.id_area; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.id_area IS 'Zona donde est├í ubicado el dispositivo (opcional).';


--
-- Name: COLUMN device.id_type_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.id_type_device IS 'Tipo de dispositivo del cat├ílogo.';


--
-- Name: COLUMN device.nombre; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.nombre IS 'Nombre personalizado del dispositivo.';


--
-- Name: COLUMN device.estado; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.estado IS 'Estado del dispositivo: conectado, desconectado, activo, desactivado.';


--
-- Name: COLUMN device.encendido; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.encendido IS 'Indica si el dispositivo est├í encendido en este momento.';


--
-- Name: COLUMN device.consumo_actual_w; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.consumo_actual_w IS 'Consumo el├®ctrico actual en Watts.';


--
-- Name: COLUMN device.mac_address; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.mac_address IS 'Direcci├│n MAC del dispositivo f├¡sico.';


--
-- Name: COLUMN device.protocolo; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.protocolo IS 'Protocolo de comunicaci├│n: wifi, bluetooth, mqtt.';


--
-- Name: COLUMN device.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.created_at IS 'Fecha de registro del dispositivo.';


--
-- Name: COLUMN device.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN device.deleted_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device.deleted_at IS 'Fecha de eliminaci├│n l├│gica (desactivaci├│n).';


--
-- Name: type_device; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.type_device (
    id_type_device uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    icono character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE type_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.type_device IS 'Cat├ílogo de tipos de dispositivos IoT del sistema.';


--
-- Name: COLUMN type_device.id_type_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.id_type_device IS 'Identificador ├║nico del tipo de dispositivo.';


--
-- Name: COLUMN type_device.nombre; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.nombre IS 'Nombre del tipo de dispositivo (ej: L├ímpara inteligente).';


--
-- Name: COLUMN type_device.descripcion; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.descripcion IS 'Descripci├│n del tipo de dispositivo.';


--
-- Name: COLUMN type_device.icono; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.icono IS 'Nombre del ├¡cono representativo del tipo.';


--
-- Name: COLUMN type_device.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN type_device.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN type_device.deleted_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.type_device.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: home; Type: TABLE; Schema: homes; Owner: -
--

CREATE TABLE homes.home (
    id_home uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    nombre character varying(100) NOT NULL,
    estrato smallint NOT NULL,
    estado character varying(20) DEFAULT 'activo'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_home_estado CHECK (((estado)::text = ANY ((ARRAY['activo'::character varying, 'desactivado'::character varying])::text[]))),
    CONSTRAINT ck_home_estrato CHECK (((estrato >= 1) AND (estrato <= 6)))
);

ALTER TABLE ONLY homes.home FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE home; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON TABLE homes.home IS 'Hogares registrados en el sistema Smart Home.';


--
-- Name: COLUMN home.id_home; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.id_home IS 'Identificador ├║nico del hogar.';


--
-- Name: COLUMN home.id_user; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.id_user IS 'Usuario propietario del hogar.';


--
-- Name: COLUMN home.nombre; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.nombre IS 'Nombre personalizado del hogar (ej: Casa Principal).';


--
-- Name: COLUMN home.estrato; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.estrato IS 'Estrato socioecon├│mico del hogar (1 al 6).';


--
-- Name: COLUMN home.estado; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.estado IS 'Estado del hogar: activo, desactivado.';


--
-- Name: COLUMN home.created_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN home.updated_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN home.deleted_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: mv_ranking_dispositivos; Type: MATERIALIZED VIEW; Schema: consumption; Owner: -
--

CREATE MATERIALIZED VIEW consumption.mv_ranking_dispositivos AS
 SELECT d.id_device,
    d.nombre AS nombre_dispositivo,
    d.id_home,
    h.nombre AS nombre_hogar,
    td.nombre AS tipo_dispositivo,
    sum(c.kwh_acumulado) AS kwh_total_30_dias,
    sum(c.costo_estimado) FILTER (WHERE (c.costo_estimado IS NOT NULL)) AS costo_total_30_dias,
    count(*) FILTER (WHERE (c.costo_estimado IS NULL)) AS lecturas_sin_costo,
    avg(c.watts) AS watts_promedio,
    rank() OVER (PARTITION BY d.id_home ORDER BY (sum(c.kwh_acumulado)) DESC) AS ranking_en_hogar
   FROM (((consumption.consumption c
     JOIN devices.device d ON (((d.id_device = c.id_device) AND (d.deleted_at IS NULL))))
     JOIN homes.home h ON (((h.id_home = d.id_home) AND (h.deleted_at IS NULL))))
     JOIN devices.type_device td ON ((td.id_type_device = d.id_type_device)))
  WHERE (c.fecha_lectura > (now() - '30 days'::interval))
  GROUP BY d.id_device, d.nombre, d.id_home, h.nombre, td.nombre
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_ranking_dispositivos; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON MATERIALIZED VIEW consumption.mv_ranking_dispositivos IS 'Ranking de dispositivos por consumo en los ├║ltimos 30 d├¡as, agrupado por hogar. Base para recomendaciones de ahorro. Refrescar diariamente.';


--
-- Name: mv_resumen_diario_hogar; Type: MATERIALIZED VIEW; Schema: consumption; Owner: -
--

CREATE MATERIALIZED VIEW consumption.mv_resumen_diario_hogar AS
 SELECT h.id_home,
    h.nombre AS nombre_hogar,
    date(c.fecha_lectura) AS fecha,
    sum(c.kwh_acumulado) AS kwh_total_dia,
    sum(c.costo_estimado) FILTER (WHERE (c.costo_estimado IS NOT NULL)) AS costo_total_dia,
    count(*) FILTER (WHERE (c.costo_estimado IS NULL)) AS lecturas_sin_costo,
    avg(c.watts) AS watts_promedio,
    max(c.watts) AS watts_maximo,
    min(c.watts) AS watts_minimo,
    count(DISTINCT c.id_device) AS dispositivos_con_lectura
   FROM (consumption.consumption c
     JOIN homes.home h ON (((h.id_home = c.id_home) AND (h.deleted_at IS NULL))))
  GROUP BY h.id_home, h.nombre, (date(c.fecha_lectura))
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_resumen_diario_hogar; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON MATERIALIZED VIEW consumption.mv_resumen_diario_hogar IS 'Resumen diario de consumo por hogar (kWh, costo, promedio, m├íximo, m├¡nimo). Refrescar diariamente. No usar para tiempo real.';


--
-- Name: mv_resumen_mensual_hogar; Type: MATERIALIZED VIEW; Schema: consumption; Owner: -
--

CREATE MATERIALIZED VIEW consumption.mv_resumen_mensual_hogar AS
 SELECT h.id_home,
    h.nombre AS nombre_hogar,
    (date_trunc('month'::text, c.fecha_lectura))::date AS mes,
    sum(c.kwh_acumulado) AS kwh_total_mes,
    sum(c.costo_estimado) FILTER (WHERE (c.costo_estimado IS NOT NULL)) AS costo_total_mes,
    count(*) FILTER (WHERE (c.costo_estimado IS NULL)) AS lecturas_sin_costo,
    avg(c.watts) AS watts_promedio,
    max(c.watts) AS watts_maximo,
    count(DISTINCT date(c.fecha_lectura)) AS dias_con_datos
   FROM (consumption.consumption c
     JOIN homes.home h ON (((h.id_home = c.id_home) AND (h.deleted_at IS NULL))))
  GROUP BY h.id_home, h.nombre, (date_trunc('month'::text, c.fecha_lectura))
  WITH NO DATA;


--
-- Name: MATERIALIZED VIEW mv_resumen_mensual_hogar; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON MATERIALIZED VIEW consumption.mv_resumen_mensual_hogar IS 'Resumen mensual de consumo por hogar. Base para proyecciones de factura y reportes mensuales. Refrescar diariamente.';


--
-- Name: recommendation; Type: TABLE; Schema: consumption; Owner: -
--

CREATE TABLE consumption.recommendation (
    id_recommendation uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_home uuid NOT NULL,
    id_device uuid,
    titulo character varying(200) NOT NULL,
    descripcion text NOT NULL,
    ahorro_estimado_kwh numeric(10,4),
    ahorro_estimado_costo numeric(12,4),
    prioridad character varying(10) DEFAULT 'media'::character varying NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_recommendation_ahorro_cost CHECK (((ahorro_estimado_costo IS NULL) OR (ahorro_estimado_costo > (0)::numeric))),
    CONSTRAINT ck_recommendation_ahorro_kwh CHECK (((ahorro_estimado_kwh IS NULL) OR (ahorro_estimado_kwh > (0)::numeric))),
    CONSTRAINT ck_recommendation_estado CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'implementada'::character varying, 'descartada'::character varying])::text[]))),
    CONSTRAINT ck_recommendation_prioridad CHECK (((prioridad)::text = ANY ((ARRAY['alta'::character varying, 'media'::character varying, 'baja'::character varying])::text[])))
);

ALTER TABLE ONLY consumption.recommendation FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE recommendation; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON TABLE consumption.recommendation IS 'Recomendaciones de ahorro energ├®tico por hogar.';


--
-- Name: COLUMN recommendation.id_recommendation; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.id_recommendation IS 'Identificador ├║nico de la recomendaci├│n.';


--
-- Name: COLUMN recommendation.id_home; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.id_home IS 'Hogar al que aplica la recomendaci├│n.';


--
-- Name: COLUMN recommendation.id_device; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.id_device IS 'Dispositivo relacionado con la recomendaci├│n (opcional).';


--
-- Name: COLUMN recommendation.titulo; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.titulo IS 'T├¡tulo descriptivo de la recomendaci├│n.';


--
-- Name: COLUMN recommendation.descripcion; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.descripcion IS 'Descripci├│n detallada y pasos para implementar.';


--
-- Name: COLUMN recommendation.ahorro_estimado_kwh; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.ahorro_estimado_kwh IS 'Ahorro potencial estimado en kWh por mes.';


--
-- Name: COLUMN recommendation.ahorro_estimado_costo; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.ahorro_estimado_costo IS 'Ahorro potencial estimado en costo por mes.';


--
-- Name: COLUMN recommendation.prioridad; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.prioridad IS 'Prioridad de la recomendaci├│n: alta, media, baja.';


--
-- Name: COLUMN recommendation.estado; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.estado IS 'Estado: pendiente, implementada, descartada.';


--
-- Name: COLUMN recommendation.created_at; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.created_at IS 'Fecha de generaci├│n de la recomendaci├│n.';


--
-- Name: COLUMN recommendation.updated_at; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN recommendation.deleted_at; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON COLUMN consumption.recommendation.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: area; Type: TABLE; Schema: homes; Owner: -
--

CREATE TABLE homes.area (
    id_area uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_home uuid NOT NULL,
    nombre character varying(100) NOT NULL,
    tipo character varying(50),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_area_tipo CHECK (((tipo IS NULL) OR ((tipo)::text = ANY ((ARRAY['sala'::character varying, 'cocina'::character varying, 'dormitorio'::character varying, 'ba├▒o'::character varying, 'exterior'::character varying, 'otro'::character varying])::text[]))))
);

ALTER TABLE ONLY homes.area FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE area; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON TABLE homes.area IS 'Zonas o habitaciones dentro de un hogar.';


--
-- Name: COLUMN area.id_area; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.id_area IS 'Identificador ├║nico de la zona.';


--
-- Name: COLUMN area.id_home; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.id_home IS 'Hogar al que pertenece la zona.';


--
-- Name: COLUMN area.nombre; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.nombre IS 'Nombre de la zona (ej: Sala Principal).';


--
-- Name: COLUMN area.tipo; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.tipo IS 'Tipo de zona: sala, cocina, dormitorio, ba├▒o, exterior, otro.';


--
-- Name: COLUMN area.created_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN area.updated_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN area.deleted_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.area.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: vw_consumo_tiempo_real; Type: VIEW; Schema: consumption; Owner: -
--

CREATE VIEW consumption.vw_consumo_tiempo_real AS
 SELECT DISTINCT ON (c.id_device) c.id_consumption,
    c.id_device,
    d.nombre AS nombre_dispositivo,
    c.id_home,
    h.nombre AS nombre_hogar,
    d.id_area,
    a.nombre AS nombre_zona,
    c.watts,
    c.kwh_acumulado,
    c.costo_estimado,
    c.fecha_lectura
   FROM (((consumption.consumption c
     JOIN devices.device d ON (((d.id_device = c.id_device) AND (d.deleted_at IS NULL))))
     JOIN homes.home h ON (((h.id_home = c.id_home) AND (h.deleted_at IS NULL))))
     LEFT JOIN homes.area a ON (((a.id_area = d.id_area) AND (a.deleted_at IS NULL))))
  ORDER BY c.id_device, c.fecha_lectura DESC;


--
-- Name: VIEW vw_consumo_tiempo_real; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON VIEW consumption.vw_consumo_tiempo_real IS '├Ültima lectura de consumo por dispositivo activo, con hogar y zona. Usada en el dashboard de monitoreo en tiempo real.';


--
-- Name: vw_consumo_total_hogar; Type: VIEW; Schema: consumption; Owner: -
--

CREATE VIEW consumption.vw_consumo_total_hogar AS
 SELECT h.id_home,
    h.nombre AS nombre_hogar,
    count(DISTINCT d.id_device) AS total_dispositivos,
    COALESCE(sum(uc.watts), (0)::numeric) AS watts_totales,
    COALESCE(sum(uc.kwh_acumulado), (0)::numeric) AS kwh_acumulado_total,
    COALESCE(sum(uc.costo_estimado), (0)::numeric) AS costo_estimado_total
   FROM ((homes.home h
     LEFT JOIN devices.device d ON (((d.id_home = h.id_home) AND (d.deleted_at IS NULL))))
     LEFT JOIN consumption.vw_consumo_tiempo_real uc ON ((uc.id_device = d.id_device)))
  WHERE ((h.deleted_at IS NULL) AND ((h.estado)::text = 'activo'::text))
  GROUP BY h.id_home, h.nombre;


--
-- Name: VIEW vw_consumo_total_hogar; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON VIEW consumption.vw_consumo_total_hogar IS 'Consumo total instant├íneo y acumulado por hogar, agregando todos sus dispositivos activos.';


--
-- Name: vw_metricas_por_hogar; Type: VIEW; Schema: consumption; Owner: -
--

CREATE VIEW consumption.vw_metricas_por_hogar AS
 SELECT cm.id_consumption_metric,
    cm.id_home,
    h.nombre AS nombre_hogar,
    cm.id_device,
    d.nombre AS nombre_dispositivo,
    cm.periodo,
    cm.fecha_inicio,
    cm.fecha_fin,
    cm.kwh_total,
    cm.costo_total,
    cm.watts_promedio,
    cm.watts_maximo,
    cm.watts_minimo
   FROM ((consumption.consumption_metric cm
     JOIN homes.home h ON (((h.id_home = cm.id_home) AND (h.deleted_at IS NULL))))
     JOIN devices.device d ON (((d.id_device = cm.id_device) AND (d.deleted_at IS NULL))));


--
-- Name: VIEW vw_metricas_por_hogar; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON VIEW consumption.vw_metricas_por_hogar IS 'M├®tricas agregadas de consumo por periodo, hogar y dispositivo. Base para gr├íficos comparativos de consumo.';


--
-- Name: vw_recomendaciones_pendientes; Type: VIEW; Schema: consumption; Owner: -
--

CREATE VIEW consumption.vw_recomendaciones_pendientes AS
 SELECT r.id_recommendation,
    r.id_home,
    h.nombre AS nombre_hogar,
    r.id_device,
    d.nombre AS nombre_dispositivo,
    r.titulo,
    r.descripcion,
    r.ahorro_estimado_kwh,
    r.ahorro_estimado_costo,
    r.prioridad,
    r.created_at
   FROM ((consumption.recommendation r
     JOIN homes.home h ON (((h.id_home = r.id_home) AND (h.deleted_at IS NULL))))
     LEFT JOIN devices.device d ON (((d.id_device = r.id_device) AND (d.deleted_at IS NULL))))
  WHERE (((r.estado)::text = 'pendiente'::text) AND (r.deleted_at IS NULL))
  ORDER BY
        CASE r.prioridad
            WHEN 'alta'::text THEN 1
            WHEN 'media'::text THEN 2
            WHEN 'baja'::text THEN 3
            ELSE NULL::integer
        END, r.ahorro_estimado_costo DESC NULLS LAST;


--
-- Name: VIEW vw_recomendaciones_pendientes; Type: COMMENT; Schema: consumption; Owner: -
--

COMMENT ON VIEW consumption.vw_recomendaciones_pendientes IS 'Recomendaciones de ahorro pendientes de implementar, ordenadas por prioridad y ahorro estimado.';


--
-- Name: device_status_history; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.device_status_history (
    id_device_status_history uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    estado_anterior character varying(20),
    estado_nuevo character varying(20) NOT NULL,
    encendido boolean NOT NULL,
    origen character varying(20) DEFAULT 'usuario'::character varying NOT NULL,
    id_user uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_device_status_history_ant CHECK (((estado_anterior IS NULL) OR ((estado_anterior)::text = ANY ((ARRAY['conectado'::character varying, 'desconectado'::character varying, 'activo'::character varying, 'desactivado'::character varying])::text[])))),
    CONSTRAINT ck_device_status_history_nuevo CHECK (((estado_nuevo)::text = ANY ((ARRAY['conectado'::character varying, 'desconectado'::character varying, 'activo'::character varying, 'desactivado'::character varying])::text[]))),
    CONSTRAINT ck_device_status_history_orig CHECK (((origen)::text = ANY ((ARRAY['usuario'::character varying, 'automatico'::character varying, 'voz'::character varying, 'sistema'::character varying])::text[])))
);


--
-- Name: TABLE device_status_history; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.device_status_history IS 'Historial inmutable de cambios de estado de dispositivos.';


--
-- Name: COLUMN device_status_history.id_device_status_history; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.id_device_status_history IS 'Identificador ├║nico del registro de historial.';


--
-- Name: COLUMN device_status_history.id_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.id_device IS 'Dispositivo al que pertenece el registro.';


--
-- Name: COLUMN device_status_history.estado_anterior; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.estado_anterior IS 'Estado previo del dispositivo.';


--
-- Name: COLUMN device_status_history.estado_nuevo; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.estado_nuevo IS 'Nuevo estado del dispositivo.';


--
-- Name: COLUMN device_status_history.encendido; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.encendido IS 'Estado de encendido al momento del registro.';


--
-- Name: COLUMN device_status_history.origen; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.origen IS 'Origen del cambio: usuario, automatico, voz, sistema.';


--
-- Name: COLUMN device_status_history.id_user; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.id_user IS 'Usuario que realiz├│ el cambio (NULL si es autom├ítico).';


--
-- Name: COLUMN device_status_history.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.device_status_history.created_at IS 'Fecha y hora exacta del cambio de estado.';


--
-- Name: manual_device; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.manual_device (
    id_manual_device uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    consumo_estimado_w numeric(10,2),
    horas_uso_diario numeric(5,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_manual_device_consumo CHECK (((consumo_estimado_w IS NULL) OR (consumo_estimado_w > (0)::numeric))),
    CONSTRAINT ck_manual_device_horas CHECK (((horas_uso_diario IS NULL) OR ((horas_uso_diario >= (0)::numeric) AND (horas_uso_diario <= (24)::numeric))))
);


--
-- Name: TABLE manual_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.manual_device IS 'Datos extendidos para dispositivos de consumo estimado.';


--
-- Name: COLUMN manual_device.id_manual_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.manual_device.id_manual_device IS 'Identificador ├║nico del registro extendido.';


--
-- Name: COLUMN manual_device.id_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.manual_device.id_device IS 'Dispositivo al que pertenece (uno a uno).';


--
-- Name: COLUMN manual_device.consumo_estimado_w; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.manual_device.consumo_estimado_w IS 'Consumo estimado en Watts.';


--
-- Name: COLUMN manual_device.horas_uso_diario; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.manual_device.horas_uso_diario IS 'Horas de uso diario estimadas (0 a 24).';


--
-- Name: COLUMN manual_device.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.manual_device.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN manual_device.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.manual_device.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: schedule; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.schedule (
    id_schedule uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    accion character varying(10) NOT NULL,
    hora time without time zone NOT NULL,
    dias_semana smallint[] NOT NULL,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_schedule_accion CHECK (((accion)::text = ANY ((ARRAY['encender'::character varying, 'apagar'::character varying])::text[])))
);


--
-- Name: TABLE schedule; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.schedule IS 'Horarios autom├íticos de encendido y apagado de dispositivos.';


--
-- Name: COLUMN schedule.id_schedule; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.id_schedule IS 'Identificador ├║nico del horario.';


--
-- Name: COLUMN schedule.id_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.id_device IS 'Dispositivo al que aplica el horario.';


--
-- Name: COLUMN schedule.accion; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.accion IS 'Acci├│n programada: encender o apagar.';


--
-- Name: COLUMN schedule.hora; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.hora IS 'Hora de ejecuci├│n del horario.';


--
-- Name: COLUMN schedule.dias_semana; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.dias_semana IS 'D├¡as de la semana (1=lunes ... 7=domingo).';


--
-- Name: COLUMN schedule.activo; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.activo IS 'Indica si el horario est├í activo.';


--
-- Name: COLUMN schedule.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN schedule.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN schedule.deleted_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.schedule.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: smart_device; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.smart_device (
    id_smart_device uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    firmware_version character varying(50),
    modelo character varying(100),
    fabricante character varying(100),
    capacidad_maxima_w numeric(10,2),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_smart_device_capacidad CHECK (((capacidad_maxima_w IS NULL) OR (capacidad_maxima_w > (0)::numeric)))
);


--
-- Name: TABLE smart_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.smart_device IS 'Datos extendidos para dispositivos inteligentes.';


--
-- Name: COLUMN smart_device.id_smart_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.id_smart_device IS 'Identificador ├║nico del registro extendido.';


--
-- Name: COLUMN smart_device.id_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.id_device IS 'Dispositivo al que pertenece (uno a uno).';


--
-- Name: COLUMN smart_device.firmware_version; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.firmware_version IS 'Versi├│n del firmware instalado en el dispositivo.';


--
-- Name: COLUMN smart_device.modelo; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.modelo IS 'Modelo del dispositivo f├¡sico.';


--
-- Name: COLUMN smart_device.fabricante; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.fabricante IS 'Fabricante del dispositivo.';


--
-- Name: COLUMN smart_device.capacidad_maxima_w; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.capacidad_maxima_w IS 'Capacidad m├íxima de consumo en Watts.';


--
-- Name: COLUMN smart_device.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN smart_device.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.smart_device.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: threshold_rule; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.threshold_rule (
    id_threshold_rule uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_device uuid NOT NULL,
    tipo character varying(20) NOT NULL,
    limite_kwh numeric(10,4) NOT NULL,
    accion character varying(20) DEFAULT 'alertar'::character varying NOT NULL,
    activa boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_threshold_rule_accion CHECK (((accion)::text = ANY ((ARRAY['alertar'::character varying, 'apagar'::character varying])::text[]))),
    CONSTRAINT ck_threshold_rule_limite CHECK ((limite_kwh > (0)::numeric)),
    CONSTRAINT ck_threshold_rule_tipo CHECK (((tipo)::text = ANY ((ARRAY['diario'::character varying, 'mensual'::character varying])::text[])))
);


--
-- Name: TABLE threshold_rule; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.threshold_rule IS 'Reglas de umbral de consumo por dispositivo.';


--
-- Name: COLUMN threshold_rule.id_threshold_rule; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.id_threshold_rule IS 'Identificador ├║nico de la regla.';


--
-- Name: COLUMN threshold_rule.id_device; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.id_device IS 'Dispositivo al que aplica la regla.';


--
-- Name: COLUMN threshold_rule.tipo; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.tipo IS 'Tipo de umbral: diario o mensual.';


--
-- Name: COLUMN threshold_rule.limite_kwh; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.limite_kwh IS 'L├¡mite de consumo en kWh que activa la regla.';


--
-- Name: COLUMN threshold_rule.accion; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.accion IS 'Acci├│n al superar el umbral: alertar o apagar.';


--
-- Name: COLUMN threshold_rule.activa; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.activa IS 'Indica si la regla est├í activa.';


--
-- Name: COLUMN threshold_rule.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN threshold_rule.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN threshold_rule.deleted_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.threshold_rule.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: voice_assistant_token; Type: TABLE; Schema: devices; Owner: -
--

CREATE TABLE devices.voice_assistant_token (
    id_voice_assistant_token uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    asistente character varying(30) NOT NULL,
    access_token text NOT NULL,
    refresh_token text,
    expira_en timestamp with time zone,
    activo boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_voice_assistant_token_asist CHECK (((asistente)::text = 'alexa'::text))
);


--
-- Name: TABLE voice_assistant_token; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON TABLE devices.voice_assistant_token IS 'Tokens de integraci├│n con asistentes de voz.';


--
-- Name: COLUMN voice_assistant_token.id_voice_assistant_token; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.id_voice_assistant_token IS 'Identificador ├║nico del token de integraci├│n.';


--
-- Name: COLUMN voice_assistant_token.id_user; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.id_user IS 'Usuario due├▒o de la integraci├│n.';


--
-- Name: COLUMN voice_assistant_token.asistente; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.asistente IS 'Nombre del asistente de voz: alexa.';


--
-- Name: COLUMN voice_assistant_token.access_token; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.access_token IS 'Token de acceso cifrado del asistente.';


--
-- Name: COLUMN voice_assistant_token.refresh_token; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.refresh_token IS 'Token de renovaci├│n cifrado del asistente.';


--
-- Name: COLUMN voice_assistant_token.expira_en; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.expira_en IS 'Fecha de expiraci├│n del token de acceso.';


--
-- Name: COLUMN voice_assistant_token.activo; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.activo IS 'Indica si la integraci├│n est├í activa.';


--
-- Name: COLUMN voice_assistant_token.created_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.created_at IS 'Fecha de vinculaci├│n con el asistente.';


--
-- Name: COLUMN voice_assistant_token.updated_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN voice_assistant_token.deleted_at; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON COLUMN devices.voice_assistant_token.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: vw_dispositivos_activos; Type: VIEW; Schema: devices; Owner: -
--

CREATE VIEW devices.vw_dispositivos_activos AS
 SELECT d.id_device,
    d.nombre,
    d.estado,
    d.encendido,
    d.consumo_actual_w,
    d.protocolo,
    d.mac_address,
    td.nombre AS tipo_dispositivo,
    td.icono,
    h.id_home,
    h.nombre AS nombre_hogar,
    a.id_area,
    a.nombre AS nombre_zona,
    d.created_at,
    d.updated_at
   FROM (((devices.device d
     JOIN devices.type_device td ON (((td.id_type_device = d.id_type_device) AND (td.deleted_at IS NULL))))
     JOIN homes.home h ON (((h.id_home = d.id_home) AND (h.deleted_at IS NULL))))
     LEFT JOIN homes.area a ON (((a.id_area = d.id_area) AND (a.deleted_at IS NULL))))
  WHERE (d.deleted_at IS NULL);


--
-- Name: VIEW vw_dispositivos_activos; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON VIEW devices.vw_dispositivos_activos IS 'Dispositivos activos con su hogar, zona y tipo asociado. Excluye dispositivos desactivados.';


--
-- Name: vw_dispositivos_desconectados; Type: VIEW; Schema: devices; Owner: -
--

CREATE VIEW devices.vw_dispositivos_desconectados AS
 SELECT d.id_device,
    d.nombre,
    d.estado,
    h.id_home,
    h.nombre AS nombre_hogar,
    a.nombre AS nombre_zona,
    d.updated_at AS ultima_actualizacion
   FROM ((devices.device d
     JOIN homes.home h ON (((h.id_home = d.id_home) AND (h.deleted_at IS NULL))))
     LEFT JOIN homes.area a ON (((a.id_area = d.id_area) AND (a.deleted_at IS NULL))))
  WHERE (((d.estado)::text = 'desconectado'::text) AND (d.deleted_at IS NULL));


--
-- Name: VIEW vw_dispositivos_desconectados; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON VIEW devices.vw_dispositivos_desconectados IS 'Dispositivos activos actualmente desconectados, para alertar al usuario sobre dispositivos fuera de l├¡nea.';


--
-- Name: vw_historial_estados_reciente; Type: VIEW; Schema: devices; Owner: -
--

CREATE VIEW devices.vw_historial_estados_reciente AS
 SELECT dsh.id_device_status_history,
    dsh.id_device,
    d.nombre AS nombre_dispositivo,
    dsh.estado_anterior,
    dsh.estado_nuevo,
    dsh.encendido,
    dsh.origen,
    dsh.id_user,
    dsh.created_at
   FROM (devices.device_status_history dsh
     JOIN devices.device d ON (((d.id_device = dsh.id_device) AND (d.deleted_at IS NULL))))
  WHERE (dsh.created_at > (now() - '30 days'::interval))
  ORDER BY dsh.created_at DESC;


--
-- Name: VIEW vw_historial_estados_reciente; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON VIEW devices.vw_historial_estados_reciente IS 'Historial de cambios de estado de dispositivos en los ├║ltimos 30 d├¡as.';


--
-- Name: vw_horarios_vigentes; Type: VIEW; Schema: devices; Owner: -
--

CREATE VIEW devices.vw_horarios_vigentes AS
 SELECT s.id_schedule,
    s.id_device,
    d.nombre AS nombre_dispositivo,
    h.id_home,
    h.nombre AS nombre_hogar,
    s.accion,
    s.hora,
    s.dias_semana,
    s.created_at,
    s.updated_at
   FROM ((devices.schedule s
     JOIN devices.device d ON (((d.id_device = s.id_device) AND (d.deleted_at IS NULL))))
     JOIN homes.home h ON (((h.id_home = d.id_home) AND (h.deleted_at IS NULL))))
  WHERE ((s.activo = true) AND (s.deleted_at IS NULL));


--
-- Name: VIEW vw_horarios_vigentes; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON VIEW devices.vw_horarios_vigentes IS 'Horarios autom├íticos activos de cada dispositivo con su hogar correspondiente.';


--
-- Name: vw_umbrales_activos; Type: VIEW; Schema: devices; Owner: -
--

CREATE VIEW devices.vw_umbrales_activos AS
 SELECT tr.id_threshold_rule,
    tr.id_device,
    d.nombre AS nombre_dispositivo,
    h.id_home,
    h.nombre AS nombre_hogar,
    tr.tipo,
    tr.limite_kwh,
    tr.accion,
    tr.created_at,
    tr.updated_at
   FROM ((devices.threshold_rule tr
     JOIN devices.device d ON (((d.id_device = tr.id_device) AND (d.deleted_at IS NULL))))
     JOIN homes.home h ON (((h.id_home = d.id_home) AND (h.deleted_at IS NULL))))
  WHERE ((tr.activa = true) AND (tr.deleted_at IS NULL));


--
-- Name: VIEW vw_umbrales_activos; Type: COMMENT; Schema: devices; Owner: -
--

COMMENT ON VIEW devices.vw_umbrales_activos IS 'Reglas de umbral de consumo activas por dispositivo, con el l├¡mite y la acci├│n configurada.';


--
-- Name: home_member; Type: TABLE; Schema: homes; Owner: -
--

CREATE TABLE homes.home_member (
    id_home_member uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_home uuid NOT NULL,
    id_user uuid NOT NULL,
    rol_en_hogar character varying(30) DEFAULT 'miembro'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_home_member_rol CHECK (((rol_en_hogar)::text = ANY ((ARRAY['propietario'::character varying, 'administrador'::character varying, 'miembro'::character varying])::text[])))
);


--
-- Name: TABLE home_member; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON TABLE homes.home_member IS 'Miembros vinculados a un hogar con roles diferenciados.';


--
-- Name: COLUMN home_member.id_home_member; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home_member.id_home_member IS 'Identificador ├║nico del miembro en el hogar.';


--
-- Name: COLUMN home_member.id_home; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home_member.id_home IS 'Hogar al que pertenece el miembro.';


--
-- Name: COLUMN home_member.id_user; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home_member.id_user IS 'Usuario miembro del hogar.';


--
-- Name: COLUMN home_member.rol_en_hogar; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home_member.rol_en_hogar IS 'Rol dentro del hogar: propietario, administrador, miembro.';


--
-- Name: COLUMN home_member.created_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home_member.created_at IS 'Fecha de vinculaci├│n al hogar.';


--
-- Name: COLUMN home_member.deleted_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.home_member.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: tariff; Type: TABLE; Schema: homes; Owner: -
--

CREATE TABLE homes.tariff (
    id_tariff uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_home uuid NOT NULL,
    costo_kwh numeric(10,4) NOT NULL,
    moneda character varying(10) DEFAULT 'COP'::character varying NOT NULL,
    vigente_desde date NOT NULL,
    vigente_hasta date,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_tariff_costo CHECK ((costo_kwh > (0)::numeric)),
    CONSTRAINT ck_tariff_vigencia CHECK (((vigente_hasta IS NULL) OR (vigente_hasta > vigente_desde)))
);


--
-- Name: TABLE tariff; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON TABLE homes.tariff IS 'Tarifas el├®ctricas configuradas por hogar.';


--
-- Name: COLUMN tariff.id_tariff; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.id_tariff IS 'Identificador ├║nico de la tarifa.';


--
-- Name: COLUMN tariff.id_home; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.id_home IS 'Hogar al que aplica la tarifa.';


--
-- Name: COLUMN tariff.costo_kwh; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.costo_kwh IS 'Costo por kWh en la moneda configurada.';


--
-- Name: COLUMN tariff.moneda; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.moneda IS 'Moneda de la tarifa (ej: COP, USD).';


--
-- Name: COLUMN tariff.vigente_desde; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.vigente_desde IS 'Fecha desde la que aplica esta tarifa.';


--
-- Name: COLUMN tariff.vigente_hasta; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.vigente_hasta IS 'Fecha hasta la que aplica (NULL = tarifa actual vigente).';


--
-- Name: COLUMN tariff.created_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.created_at IS 'Fecha de creaci├│n del registro.';


--
-- Name: COLUMN tariff.updated_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN tariff.deleted_at; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON COLUMN homes.tariff.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: vw_hogares_activos; Type: VIEW; Schema: homes; Owner: -
--

CREATE VIEW homes.vw_hogares_activos AS
 SELECT h.id_home,
    h.id_user,
    u.nombre AS propietario_nombre,
    u.apellido AS propietario_apellido,
    u.email AS propietario_email,
    h.nombre AS nombre_hogar,
    h.estrato,
    h.estado,
    h.created_at,
    h.updated_at,
    count(DISTINCT a.id_area) AS total_zonas,
    count(DISTINCT d.id_device) AS total_dispositivos
   FROM (((homes.home h
     JOIN auth."user" u ON (((u.id_user = h.id_user) AND (u.deleted_at IS NULL))))
     LEFT JOIN homes.area a ON (((a.id_home = h.id_home) AND (a.deleted_at IS NULL))))
     LEFT JOIN devices.device d ON (((d.id_home = h.id_home) AND (d.deleted_at IS NULL))))
  WHERE ((h.deleted_at IS NULL) AND ((h.estado)::text = 'activo'::text))
  GROUP BY h.id_home, h.id_user, u.nombre, u.apellido, u.email, h.nombre, h.estrato, h.estado, h.created_at, h.updated_at;


--
-- Name: VIEW vw_hogares_activos; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON VIEW homes.vw_hogares_activos IS 'Hogares activos con informaci├│n del propietario y conteo de zonas y dispositivos asociados.';


--
-- Name: vw_miembros_hogar; Type: VIEW; Schema: homes; Owner: -
--

CREATE VIEW homes.vw_miembros_hogar AS
 SELECT hm.id_home_member,
    hm.id_home,
    h.nombre AS nombre_hogar,
    h.id_user AS id_propietario,
    hm.id_user,
    u.nombre AS miembro_nombre,
    u.apellido AS miembro_apellido,
    u.email AS miembro_email,
    hm.rol_en_hogar,
    hm.created_at AS fecha_vinculacion
   FROM ((homes.home_member hm
     JOIN homes.home h ON (((h.id_home = hm.id_home) AND (h.deleted_at IS NULL))))
     JOIN auth."user" u ON (((u.id_user = hm.id_user) AND (u.deleted_at IS NULL))))
  WHERE (hm.deleted_at IS NULL);


--
-- Name: VIEW vw_miembros_hogar; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON VIEW homes.vw_miembros_hogar IS 'Miembros activos de cada hogar con su informaci├│n personal y rol asignado dentro del hogar.';


--
-- Name: vw_resumen_hogar; Type: VIEW; Schema: homes; Owner: -
--

CREATE VIEW homes.vw_resumen_hogar AS
 SELECT h.id_home,
    h.nombre AS nombre_hogar,
    h.estrato,
    h.estado,
    u.id_user AS id_propietario,
    u.nombre AS propietario_nombre,
    u.email AS propietario_email,
    t.costo_kwh AS tarifa_vigente,
    t.moneda,
    count(DISTINCT a.id_area) AS total_zonas,
    count(DISTINCT d.id_device) AS total_dispositivos,
    count(DISTINCT
        CASE
            WHEN ((d.estado)::text = 'conectado'::text) THEN d.id_device
            ELSE NULL::uuid
        END) AS dispositivos_conectados,
    count(DISTINCT
        CASE
            WHEN (d.encendido = true) THEN d.id_device
            ELSE NULL::uuid
        END) AS dispositivos_encendidos,
    COALESCE(sum(d.consumo_actual_w), (0)::numeric) AS consumo_actual_total_w
   FROM ((((homes.home h
     JOIN auth."user" u ON (((u.id_user = h.id_user) AND (u.deleted_at IS NULL))))
     LEFT JOIN homes.tariff t ON (((t.id_home = h.id_home) AND (t.deleted_at IS NULL) AND (t.vigente_desde <= CURRENT_DATE) AND ((t.vigente_hasta IS NULL) OR (t.vigente_hasta >= CURRENT_DATE)))))
     LEFT JOIN homes.area a ON (((a.id_home = h.id_home) AND (a.deleted_at IS NULL))))
     LEFT JOIN devices.device d ON (((d.id_home = h.id_home) AND (d.deleted_at IS NULL))))
  WHERE ((h.deleted_at IS NULL) AND ((h.estado)::text = 'activo'::text))
  GROUP BY h.id_home, h.nombre, h.estrato, h.estado, u.id_user, u.nombre, u.email, t.costo_kwh, t.moneda;


--
-- Name: VIEW vw_resumen_hogar; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON VIEW homes.vw_resumen_hogar IS 'Resumen completo por hogar con tarifa vigente, conteo de zonas, dispositivos y consumo actual total en Watts.';


--
-- Name: vw_tarifas_vigentes; Type: VIEW; Schema: homes; Owner: -
--

CREATE VIEW homes.vw_tarifas_vigentes AS
 SELECT t.id_tariff,
    t.id_home,
    h.nombre AS nombre_hogar,
    h.id_user,
    t.costo_kwh,
    t.moneda,
    t.vigente_desde
   FROM (homes.tariff t
     JOIN homes.home h ON (((h.id_home = t.id_home) AND (h.deleted_at IS NULL))))
  WHERE ((t.deleted_at IS NULL) AND (t.vigente_desde <= CURRENT_DATE) AND ((t.vigente_hasta IS NULL) OR (t.vigente_hasta >= CURRENT_DATE)));


--
-- Name: VIEW vw_tarifas_vigentes; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON VIEW homes.vw_tarifas_vigentes IS 'Tarifa el├®ctrica actualmente vigente por hogar. Usada para calcular costos de consumo en tiempo real.';


--
-- Name: vw_zonas_con_dispositivos; Type: VIEW; Schema: homes; Owner: -
--

CREATE VIEW homes.vw_zonas_con_dispositivos AS
 SELECT a.id_area,
    a.id_home,
    h.nombre AS nombre_hogar,
    a.nombre AS nombre_zona,
    a.tipo,
    count(d.id_device) AS total_dispositivos,
    count(
        CASE
            WHEN (d.encendido = true) THEN 1
            ELSE NULL::integer
        END) AS dispositivos_encendidos,
    COALESCE(sum(d.consumo_actual_w), (0)::numeric) AS consumo_actual_zona_w
   FROM ((homes.area a
     JOIN homes.home h ON (((h.id_home = a.id_home) AND (h.deleted_at IS NULL))))
     LEFT JOIN devices.device d ON (((d.id_area = a.id_area) AND (d.deleted_at IS NULL) AND ((d.estado)::text = 'conectado'::text))))
  WHERE (a.deleted_at IS NULL)
  GROUP BY a.id_area, a.id_home, h.nombre, a.nombre, a.tipo;


--
-- Name: VIEW vw_zonas_con_dispositivos; Type: COMMENT; Schema: homes; Owner: -
--

COMMENT ON VIEW homes.vw_zonas_con_dispositivos IS 'Zonas activas con conteo de dispositivos vinculados y consumo actual total de la zona en Watts.';


--
-- Name: alert; Type: TABLE; Schema: notifications; Owner: -
--

CREATE TABLE notifications.alert (
    id_alert uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_threshold_rule uuid NOT NULL,
    id_device uuid NOT NULL,
    id_home uuid NOT NULL,
    consumo_detectado_kwh numeric(12,6) NOT NULL,
    limite_kwh numeric(10,4) NOT NULL,
    accion_ejecutada character varying(20),
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_alert_accion CHECK (((accion_ejecutada IS NULL) OR ((accion_ejecutada)::text = ANY ((ARRAY['alertar'::character varying, 'apagar'::character varying])::text[])))),
    CONSTRAINT ck_alert_consumo CHECK ((consumo_detectado_kwh > (0)::numeric)),
    CONSTRAINT ck_alert_consumo_supera CHECK ((consumo_detectado_kwh > limite_kwh)),
    CONSTRAINT ck_alert_limite CHECK ((limite_kwh > (0)::numeric))
);


--
-- Name: TABLE alert; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON TABLE notifications.alert IS 'Alertas generadas cuando un dispositivo supera su umbral de consumo.';


--
-- Name: COLUMN alert.id_alert; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.id_alert IS 'Identificador ├║nico de la alerta.';


--
-- Name: COLUMN alert.id_threshold_rule; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.id_threshold_rule IS 'Regla de umbral que dispar├│ la alerta.';


--
-- Name: COLUMN alert.id_device; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.id_device IS 'Dispositivo que gener├│ la alerta.';


--
-- Name: COLUMN alert.id_home; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.id_home IS 'Hogar al que pertenece el dispositivo.';


--
-- Name: COLUMN alert.consumo_detectado_kwh; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.consumo_detectado_kwh IS 'Consumo detectado al momento de generar la alerta.';


--
-- Name: COLUMN alert.limite_kwh; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.limite_kwh IS 'L├¡mite configurado que fue superado.';


--
-- Name: COLUMN alert.accion_ejecutada; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.accion_ejecutada IS 'Acci├│n ejecutada al superar el umbral: alertar o apagar.';


--
-- Name: COLUMN alert.created_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.alert.created_at IS 'Fecha y hora exacta de la alerta.';


--
-- Name: notification; Type: TABLE; Schema: notifications; Owner: -
--

CREATE TABLE notifications.notification (
    id_notification uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    id_home uuid,
    id_device uuid,
    tipo character varying(30) NOT NULL,
    titulo character varying(200) NOT NULL,
    mensaje text NOT NULL,
    prioridad character varying(10) DEFAULT 'media'::character varying NOT NULL,
    leida boolean DEFAULT false NOT NULL,
    canal character varying(20) DEFAULT 'app'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_notification_canal CHECK (((canal)::text = ANY ((ARRAY['app'::character varying, 'email'::character varying, 'push'::character varying])::text[]))),
    CONSTRAINT ck_notification_prioridad CHECK (((prioridad)::text = ANY ((ARRAY['alta'::character varying, 'media'::character varying, 'baja'::character varying])::text[]))),
    CONSTRAINT ck_notification_tipo CHECK (((tipo)::text = ANY ((ARRAY['consumo_elevado'::character varying, 'dispositivo_desconectado'::character varying, 'nueva_recomendacion'::character varying, 'umbral_superado'::character varying, 'sistema'::character varying])::text[])))
);

ALTER TABLE ONLY notifications.notification FORCE ROW LEVEL SECURITY;


--
-- Name: TABLE notification; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON TABLE notifications.notification IS 'Notificaciones generadas por el sistema hacia los usuarios.';


--
-- Name: COLUMN notification.id_notification; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.id_notification IS 'Identificador ├║nico de la notificaci├│n.';


--
-- Name: COLUMN notification.id_user; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.id_user IS 'Usuario destinatario de la notificaci├│n.';


--
-- Name: COLUMN notification.id_home; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.id_home IS 'Hogar relacionado con la notificaci├│n (opcional).';


--
-- Name: COLUMN notification.id_device; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.id_device IS 'Dispositivo relacionado con la notificaci├│n (opcional).';


--
-- Name: COLUMN notification.tipo; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.tipo IS 'Tipo de notificaci├│n: consumo_elevado, dispositivo_desconectado, nueva_recomendacion, umbral_superado, sistema.';


--
-- Name: COLUMN notification.titulo; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.titulo IS 'T├¡tulo descriptivo de la notificaci├│n.';


--
-- Name: COLUMN notification.mensaje; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.mensaje IS 'Contenido detallado de la notificaci├│n.';


--
-- Name: COLUMN notification.prioridad; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.prioridad IS 'Prioridad de la notificaci├│n: alta, media, baja.';


--
-- Name: COLUMN notification.leida; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.leida IS 'Indica si la notificaci├│n fue le├¡da por el usuario.';


--
-- Name: COLUMN notification.canal; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.canal IS 'Canal por el que se envi├│: app, email, push.';


--
-- Name: COLUMN notification.created_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.created_at IS 'Fecha de creaci├│n de la notificaci├│n.';


--
-- Name: COLUMN notification.updated_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN notification.deleted_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.notification.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: reminder_notification; Type: TABLE; Schema: notifications; Owner: -
--

CREATE TABLE notifications.reminder_notification (
    id_reminder_notification uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    id_home uuid,
    mensaje text NOT NULL,
    programado_para timestamp with time zone NOT NULL,
    enviado boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    CONSTRAINT ck_reminder_notification_fecha CHECK ((programado_para > created_at))
);


--
-- Name: TABLE reminder_notification; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON TABLE notifications.reminder_notification IS 'Recordatorios programados para enviar a usuarios en fecha y hora espec├¡fica.';


--
-- Name: COLUMN reminder_notification.id_reminder_notification; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.id_reminder_notification IS 'Identificador ├║nico del recordatorio.';


--
-- Name: COLUMN reminder_notification.id_user; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.id_user IS 'Usuario destinatario del recordatorio.';


--
-- Name: COLUMN reminder_notification.id_home; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.id_home IS 'Hogar relacionado con el recordatorio (opcional).';


--
-- Name: COLUMN reminder_notification.mensaje; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.mensaje IS 'Contenido del recordatorio.';


--
-- Name: COLUMN reminder_notification.programado_para; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.programado_para IS 'Fecha y hora programada para el env├¡o.';


--
-- Name: COLUMN reminder_notification.enviado; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.enviado IS 'Indica si el recordatorio ya fue enviado.';


--
-- Name: COLUMN reminder_notification.created_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.created_at IS 'Fecha de creaci├│n del recordatorio.';


--
-- Name: COLUMN reminder_notification.updated_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.updated_at IS 'Fecha de ├║ltima actualizaci├│n.';


--
-- Name: COLUMN reminder_notification.deleted_at; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON COLUMN notifications.reminder_notification.deleted_at IS 'Fecha de eliminaci├│n l├│gica (soft delete).';


--
-- Name: vw_alertas_recientes; Type: VIEW; Schema: notifications; Owner: -
--

CREATE VIEW notifications.vw_alertas_recientes AS
 SELECT al.id_alert,
    al.id_device,
    d.nombre AS nombre_dispositivo,
    al.id_home,
    h.nombre AS nombre_hogar,
    al.consumo_detectado_kwh,
    al.limite_kwh,
    al.accion_ejecutada,
    al.created_at
   FROM ((notifications.alert al
     JOIN devices.device d ON (((d.id_device = al.id_device) AND (d.deleted_at IS NULL))))
     JOIN homes.home h ON (((h.id_home = al.id_home) AND (h.deleted_at IS NULL))))
  WHERE (al.created_at > (now() - '24:00:00'::interval))
  ORDER BY al.created_at DESC;


--
-- Name: VIEW vw_alertas_recientes; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON VIEW notifications.vw_alertas_recientes IS 'Alertas de umbral generadas en las ├║ltimas 24 horas, con informaci├│n del dispositivo y hogar afectado.';


--
-- Name: vw_notificaciones_no_leidas; Type: VIEW; Schema: notifications; Owner: -
--

CREATE VIEW notifications.vw_notificaciones_no_leidas AS
 SELECT n.id_notification,
    n.id_user,
    n.id_home,
    n.id_device,
    n.tipo,
    n.titulo,
    n.mensaje,
    n.prioridad,
    n.canal,
    n.created_at
   FROM notifications.notification n
  WHERE ((n.leida = false) AND (n.deleted_at IS NULL))
  ORDER BY n.created_at DESC;


--
-- Name: VIEW vw_notificaciones_no_leidas; Type: COMMENT; Schema: notifications; Owner: -
--

COMMENT ON VIEW notifications.vw_notificaciones_no_leidas IS 'Notificaciones no le├¡das por usuario, ordenadas de la m├ís reciente a la m├ís antigua.';


--
-- Name: databasechangelog; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.databasechangelog (
    id character varying(255) NOT NULL,
    author character varying(255) NOT NULL,
    filename character varying(255) NOT NULL,
    dateexecuted timestamp without time zone NOT NULL,
    orderexecuted integer NOT NULL,
    exectype character varying(10) NOT NULL,
    md5sum character varying(35),
    description character varying(255),
    comments character varying(255),
    tag character varying(255),
    liquibase character varying(20),
    contexts character varying(255),
    labels character varying(255),
    deployment_id character varying(10)
);


--
-- Name: databasechangeloglock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.databasechangeloglock (
    id integer NOT NULL,
    locked boolean NOT NULL,
    lockgranted timestamp without time zone,
    lockedby character varying(255)
);


--
-- Name: backup; Type: TABLE; Schema: sync; Owner: -
--

CREATE TABLE sync.backup (
    id_backup uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid,
    tipo character varying(20) NOT NULL,
    alcance character varying(20) DEFAULT 'completo'::character varying NOT NULL,
    ubicacion text NOT NULL,
    tamanio_bytes bigint,
    estado character varying(20) DEFAULT 'completado'::character varying NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_backup_alcance CHECK (((alcance)::text = ANY ((ARRAY['completo'::character varying, 'parcial'::character varying])::text[]))),
    CONSTRAINT ck_backup_estado CHECK (((estado)::text = ANY ((ARRAY['en_proceso'::character varying, 'completado'::character varying, 'fallido'::character varying])::text[]))),
    CONSTRAINT ck_backup_tamanio CHECK (((tamanio_bytes IS NULL) OR (tamanio_bytes > 0))),
    CONSTRAINT ck_backup_tipo CHECK (((tipo)::text = ANY ((ARRAY['automatico'::character varying, 'manual'::character varying])::text[])))
);


--
-- Name: TABLE backup; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON TABLE sync.backup IS 'Registro de copias de seguridad del sistema Smart Home.';


--
-- Name: COLUMN backup.id_backup; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.id_backup IS 'Identificador ├║nico del backup.';


--
-- Name: COLUMN backup.id_user; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.id_user IS 'Usuario al que pertenecen los datos (NULL si es backup global del sistema).';


--
-- Name: COLUMN backup.tipo; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.tipo IS 'Tipo de backup: automatico o manual.';


--
-- Name: COLUMN backup.alcance; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.alcance IS 'Alcance del backup: completo o parcial.';


--
-- Name: COLUMN backup.ubicacion; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.ubicacion IS 'Ruta o URL del archivo de backup almacenado.';


--
-- Name: COLUMN backup.tamanio_bytes; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.tamanio_bytes IS 'Tama├▒o del archivo de backup en bytes.';


--
-- Name: COLUMN backup.estado; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.estado IS 'Estado del backup: en_proceso, completado, fallido.';


--
-- Name: COLUMN backup.descripcion; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.descripcion IS 'Descripci├│n o notas adicionales del backup.';


--
-- Name: COLUMN backup.created_at; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.backup.created_at IS 'Fecha y hora de creaci├│n del backup.';


--
-- Name: offline_queue; Type: TABLE; Schema: sync; Owner: -
--

CREATE TABLE sync.offline_queue (
    id_offline_queue uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    tipo_accion character varying(50) NOT NULL,
    payload jsonb NOT NULL,
    estado character varying(20) DEFAULT 'pendiente'::character varying NOT NULL,
    intentos smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    procesada_at timestamp with time zone,
    CONSTRAINT ck_offline_queue_estado CHECK (((estado)::text = ANY ((ARRAY['pendiente'::character varying, 'procesada'::character varying, 'fallida'::character varying])::text[]))),
    CONSTRAINT ck_offline_queue_intentos CHECK ((intentos >= 0)),
    CONSTRAINT ck_offline_queue_procesada CHECK (((((estado)::text = 'pendiente'::text) AND (procesada_at IS NULL)) OR (((estado)::text = ANY ((ARRAY['procesada'::character varying, 'fallida'::character varying])::text[])) AND (procesada_at IS NOT NULL)))),
    CONSTRAINT ck_offline_queue_tipo CHECK (((tipo_accion)::text = ANY ((ARRAY['encender_dispositivo'::character varying, 'apagar_dispositivo'::character varying, 'actualizar_config'::character varying, 'vincular_dispositivo'::character varying, 'desvincular_dispositivo'::character varying, 'actualizar_dispositivo'::character varying])::text[])))
);


--
-- Name: TABLE offline_queue; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON TABLE sync.offline_queue IS 'Cola de acciones pendientes de sincronizaci├│n en modo offline.';


--
-- Name: COLUMN offline_queue.id_offline_queue; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.id_offline_queue IS 'Identificador ├║nico de la acci├│n en cola.';


--
-- Name: COLUMN offline_queue.id_user; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.id_user IS 'Usuario que realiz├│ la acci├│n en modo offline.';


--
-- Name: COLUMN offline_queue.tipo_accion; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.tipo_accion IS 'Tipo de acci├│n: encender_dispositivo, apagar_dispositivo, actualizar_config, vincular_dispositivo, desvincular_dispositivo, actualizar_dispositivo.';


--
-- Name: COLUMN offline_queue.payload; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.payload IS 'Datos de la acci├│n en formato JSON (par├ímetros necesarios para ejecutarla).';


--
-- Name: COLUMN offline_queue.estado; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.estado IS 'Estado de la acci├│n: pendiente, procesada, fallida.';


--
-- Name: COLUMN offline_queue.intentos; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.intentos IS 'N├║mero de intentos de sincronizaci├│n realizados.';


--
-- Name: COLUMN offline_queue.created_at; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.created_at IS 'Fecha y hora en que se registr├│ la acci├│n offline.';


--
-- Name: COLUMN offline_queue.procesada_at; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.offline_queue.procesada_at IS 'Fecha y hora en que fue procesada o marcada como fallida.';


--
-- Name: synchronization; Type: TABLE; Schema: sync; Owner: -
--

CREATE TABLE sync.synchronization (
    id_synchronization uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    id_user uuid NOT NULL,
    tipo character varying(20) NOT NULL,
    estado character varying(20) NOT NULL,
    dispositivos_sincronizados smallint,
    errores text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_synchronization_dispos CHECK (((dispositivos_sincronizados IS NULL) OR (dispositivos_sincronizados >= 0))),
    CONSTRAINT ck_synchronization_errores CHECK (((((estado)::text = 'exitosa'::text) AND (errores IS NULL)) OR ((estado)::text = ANY ((ARRAY['fallida'::character varying, 'parcial'::character varying])::text[])))),
    CONSTRAINT ck_synchronization_estado CHECK (((estado)::text = ANY ((ARRAY['exitosa'::character varying, 'fallida'::character varying, 'parcial'::character varying])::text[]))),
    CONSTRAINT ck_synchronization_tipo CHECK (((tipo)::text = ANY ((ARRAY['automatica'::character varying, 'manual'::character varying])::text[])))
);


--
-- Name: TABLE synchronization; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON TABLE sync.synchronization IS 'Historial de sincronizaciones entre dispositivos y servidor.';


--
-- Name: COLUMN synchronization.id_synchronization; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.id_synchronization IS 'Identificador ├║nico de la sincronizaci├│n.';


--
-- Name: COLUMN synchronization.id_user; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.id_user IS 'Usuario que realiz├│ la sincronizaci├│n.';


--
-- Name: COLUMN synchronization.tipo; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.tipo IS 'Tipo de sincronizaci├│n: automatica o manual.';


--
-- Name: COLUMN synchronization.estado; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.estado IS 'Resultado: exitosa, fallida o parcial.';


--
-- Name: COLUMN synchronization.dispositivos_sincronizados; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.dispositivos_sincronizados IS 'N├║mero de dispositivos sincronizados correctamente.';


--
-- Name: COLUMN synchronization.errores; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.errores IS 'Descripci├│n de errores encontrados (NULL si fue exitosa).';


--
-- Name: COLUMN synchronization.created_at; Type: COMMENT; Schema: sync; Owner: -
--

COMMENT ON COLUMN sync.synchronization.created_at IS 'Fecha y hora de la sincronizaci├│n.';


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: audit; Owner: -
--

COPY audit.audit_log (id_audit_log, id_user, accion, modulo, entidad, id_entidad, datos_anteriores, datos_nuevos, ip_address, user_agent, resultado, detalle, created_at) FROM stdin;
42d31d51-15ad-4dda-9809-642792bfc02d	\N	crear	auth	auth.role	\N	\N	{"nombre": "administrador", "id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.540699+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.540699+00:00", "descripcion": "Acceso total al sistema. Puede gestionar usuarios, roles, backups, logs de auditor├¡a y toda la configuraci├│n del sistema."}	\N	\N	exitoso	\N	2026-06-23 17:56:12.540699-05
fb71439b-aa61-47b1-b2b9-100d2417b07b	\N	crear	auth	auth.role	\N	\N	{"nombre": "estandar", "id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.540699+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.540699+00:00", "descripcion": "Acceso a funcionalidades propias del hogar. Puede gestionar hogares, dispositivos, consumo y configuraci├│n personal."}	\N	\N	exitoso	\N	2026-06-23 17:56:12.540699-05
526b6951-1906-4224-ade7-377280221282	\N	crear	auth	auth.role	\N	\N	{"nombre": "invitado", "id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.540699+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.540699+00:00", "descripcion": "Acceso de solo lectura. Puede visualizar consumo y estado de dispositivos sin realizar cambios."}	\N	\N	exitoso	\N	2026-06-23 17:56:12.540699-05
b26bbe25-8562-4b6f-a14d-45bb128be246	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "usuarios", "nombre": "usuarios:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver listado y detalle de usuarios", "id_permission": "036d9d91-49a0-4723-802a-c47f1f124fba"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
5e4123c0-9b63-4fc8-be80-c31a93984cb8	\N	crear	auth	auth.permission	\N	\N	{"accion": "crear", "modulo": "usuarios", "nombre": "usuarios:crear", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Registrar nuevos usuarios", "id_permission": "71259f74-422e-454d-b684-ebdc3d931942"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
5147e931-e225-469a-aacd-8e5921d176b2	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "usuarios", "nombre": "usuarios:editar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Modificar datos de usuarios", "id_permission": "a86a1415-4d28-4bc9-9772-4a57f3ba8030"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
867fbdf0-ae37-44e6-8893-2e7b4355a780	\N	crear	auth	auth.permission	\N	\N	{"accion": "eliminar", "modulo": "usuarios", "nombre": "usuarios:eliminar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Desactivar cuentas de usuarios", "id_permission": "d02d9c15-e610-4f32-aae5-c78ae87946a0"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
9ec81b96-4392-45c0-b9a7-c087c27210d5	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "usuarios", "nombre": "roles:asignar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Asignar y modificar roles de usuarios", "id_permission": "e79efe13-7b22-4997-86b7-a29e15a078d5"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
859d25d2-b720-4afe-8e8b-57e8e3b8cf25	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "usuarios", "nombre": "usuarios:ver_todos", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver todos los usuarios del sistema", "id_permission": "b5a82b0e-7a44-4007-ba8b-d4fe0bb386fc"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
5faa4cdb-236a-460e-a11a-1ba8856d4f97	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "hogares", "nombre": "hogares:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver hogares propios", "id_permission": "ca920d3a-e7a0-4427-a77c-33b9d772d043"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
fabbc4c1-08e6-4f3e-9470-4ba88d3c94cb	\N	crear	auth	auth.permission	\N	\N	{"accion": "crear", "modulo": "hogares", "nombre": "hogares:crear", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Registrar nuevos hogares", "id_permission": "0b12fa15-7b6f-4416-98a7-5c47af781d54"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
1bed762f-d519-4a52-8a8d-5558a1b18d46	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "hogares", "nombre": "hogares:editar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Modificar datos del hogar", "id_permission": "9efe7f3b-994a-457a-982b-f21dfca1fdb0"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
f312410c-4964-4bc6-9639-3fc9c12601b1	\N	crear	auth	auth.permission	\N	\N	{"accion": "eliminar", "modulo": "hogares", "nombre": "hogares:desactivar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Desactivar hogares", "id_permission": "1104d8a4-485c-42df-b10a-6da2f4bd77a5"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
21bc88e8-8c1f-442e-a1d4-fbf9bbbc5104	\N	crear	auth	auth.permission	\N	\N	{"accion": "crear", "modulo": "hogares", "nombre": "zonas:crear", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Crear zonas dentro de un hogar", "id_permission": "eca864ea-922c-4f9f-a778-cd5cf8395978"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
dfd9a2a5-16d6-433a-a448-e5058962eb44	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "hogares", "nombre": "zonas:editar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Editar zonas existentes", "id_permission": "9232d42e-3474-43ff-b055-53ee29136f32"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
a782d528-0a4d-45ff-bd1e-ce4b72aaa41c	\N	crear	auth	auth.permission	\N	\N	{"accion": "eliminar", "modulo": "hogares", "nombre": "zonas:eliminar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Eliminar zonas del hogar", "id_permission": "4bb2ebd2-ef07-4272-82d1-0fc892aa0efc"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
559ff501-751c-40be-81c9-7b5cd1ab76a1	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "hogares", "nombre": "tarifas:configurar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Configurar tarifas el├®ctricas", "id_permission": "72c2af2f-65d8-4772-b4f8-4d22f72e78b5"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
7dee5cfd-81c1-43f4-9853-07e6e0819491	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "dispositivos", "nombre": "dispositivos:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver dispositivos registrados", "id_permission": "38710114-0bc1-4124-bc9b-a0041253b0a3"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
2d893cd1-3746-4515-8ccd-e1bc1503c960	\N	crear	auth	auth.permission	\N	\N	{"accion": "crear", "modulo": "dispositivos", "nombre": "dispositivos:crear", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Registrar nuevos dispositivos", "id_permission": "67a843d8-a286-49c1-b7af-78a155cb5f82"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
d4319eba-407d-4062-9ff6-1e6bf46eefd0	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "dispositivos", "nombre": "dispositivos:editar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Modificar configuraci├│n de dispositivos", "id_permission": "c1fc2a9e-1b7f-42a1-94bc-8355db2fc865"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
b60d1c48-793e-413c-9f47-18d3958b4253	\N	crear	auth	auth.permission	\N	\N	{"accion": "eliminar", "modulo": "dispositivos", "nombre": "dispositivos:desactivar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Desactivar dispositivos", "id_permission": "d671c3c2-6dc9-4359-b5e9-2d637a4a3c90"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
c408fd84-5a9b-4249-8c66-c446ac2abf92	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "dispositivos", "nombre": "dispositivos:controlar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Encender/apagar dispositivos remotamente", "id_permission": "f5bf4f2c-c024-42d7-9f3b-fec37a3df52c"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
b414625e-b5d3-426c-b5ae-a5e0ab3e65f1	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "dispositivos", "nombre": "dispositivos:configurar_horarios", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Configurar horarios autom├íticos", "id_permission": "3ce2eebe-72f8-41b6-a1f2-a330878d0dea"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
bdaba428-94cd-4042-9d38-9ab01b3f9f33	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "dispositivos", "nombre": "dispositivos:configurar_umbrales", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Configurar umbrales de consumo", "id_permission": "ef43cc2c-c8ba-4d26-96ee-bd9db4daafc4"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
174fbc24-731e-47ae-bea0-d4616ba66a95	\N	crear	auth	auth.permission	\N	\N	{"accion": "crear", "modulo": "dispositivos", "nombre": "asistente_voz:vincular", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Vincular asistentes de voz", "id_permission": "5a0dd879-26b8-4705-bc3f-647bdc7dc218"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
9562968f-1602-4223-8b37-723886222b60	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "consumo", "nombre": "consumo:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver consumo en tiempo real", "id_permission": "b8b923c4-9eaa-457e-b8a9-a063762dd061"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
320b116c-6140-4fd8-8c91-632f337b87f2	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "consumo", "nombre": "consumo:reportes", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Generar y ver reportes de consumo", "id_permission": "2b6f812b-aeec-4a98-ac47-ef25d721cfe6"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
ad8842bd-5458-4fd6-a933-09ae0d004e63	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "consumo", "nombre": "consumo:graficos", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver gr├íficos de consumo", "id_permission": "28f8b442-4868-42fd-921e-71498220670d"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
5f17ed1a-22d6-44bf-aa62-73bfd64093c8	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "consumo", "nombre": "recomendaciones:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver recomendaciones de ahorro", "id_permission": "6f145823-fd67-4782-a890-d43921be4120"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
90dc770a-b884-41db-8c08-38c07d6ac376	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "consumo", "nombre": "recomendaciones:configurar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Configurar recomendaciones autom├íticas", "id_permission": "12dbccf7-7c0d-4b49-af14-00c358cef2cf"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
b84a63cd-3f87-43ca-bbe9-3b874646494e	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "consumo", "nombre": "notificaciones:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver notificaciones", "id_permission": "3f07e425-9f2c-4715-80df-a8a3634b9437"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
4d07ab9c-fcc7-48a1-a13a-20635596e7d4	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "consumo", "nombre": "notificaciones:configurar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Configurar preferencias de notificaciones", "id_permission": "a8aea6e0-ce91-48ff-b176-9e78060ace00"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
c6ffc591-447f-465a-b727-28234c4eb1d7	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "sync", "nombre": "sync:manual", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Forzar sincronizaci├│n manual", "id_permission": "b80f9fed-dd68-48f1-a723-36c8a303c30b"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
9b09d103-a972-420f-8bad-a8952dfc6a24	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "sync", "nombre": "backups:restaurar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Restaurar informaci├│n desde backup", "id_permission": "cb1cf89c-6011-4f0f-9422-64c6683054b3"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
aefb10ed-0014-4af1-a402-e991d8ff5be0	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "sync", "nombre": "backups:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver backups disponibles", "id_permission": "bd47441a-5db0-4584-bc3c-e72e473c2d76"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
733ea553-efd7-40a5-94e5-b215c83075c0	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "config", "nombre": "config:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Ver configuraci├│n personal", "id_permission": "093217c1-db09-4162-a01b-6c9ab178816f"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
c8b76047-a2fd-4a91-91a9-f5443526917e	\N	crear	auth	auth.permission	\N	\N	{"accion": "editar", "modulo": "config", "nombre": "config:editar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Modificar configuraci├│n personal", "id_permission": "e4f86d35-893b-45b2-8546-89ae7da9cc09"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
25b8271c-608e-43e6-9f78-240ad3b5d543	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "auditoria", "nombre": "auditoria:leer", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Consultar logs de auditor├¡a", "id_permission": "2b3eb354-e2f8-4fcf-87a3-f42c7e902fbd"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
ad23d14f-acb3-41dc-9ce7-8dc8866621fd	\N	crear	auth	auth.permission	\N	\N	{"accion": "leer", "modulo": "auditoria", "nombre": "auditoria:exportar", "created_at": "2026-06-23T22:56:12.595131+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.595131+00:00", "descripcion": "Exportar registros de auditor├¡a", "id_permission": "2b734aaa-ad41-4710-8773-7397fae51591"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.595131-05
36c2a055-9346-464a-8dd9-14faf11ff388	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "2b3eb354-e2f8-4fcf-87a3-f42c7e902fbd", "id_role_permission": "b3504c5f-7dd6-4610-abcf-14fb07793420"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
67920086-c9f8-40c3-8b2a-a058b86a8668	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "2b734aaa-ad41-4710-8773-7397fae51591", "id_role_permission": "9e11b428-ac55-48d9-8f7b-11361fdeb975"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
50854d70-c750-4877-b345-58d16f0af2b1	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "e4f86d35-893b-45b2-8546-89ae7da9cc09", "id_role_permission": "d4b1c614-93e2-4999-8838-2e643026b899"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
f4f09dfd-b6f9-4a35-8cb5-3fcad6c4509f	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "093217c1-db09-4162-a01b-6c9ab178816f", "id_role_permission": "d931f3cc-2d5c-448d-8dd7-e12dd8b360eb"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
5455725b-7dda-4387-b9ba-e3e01a60b52a	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "12dbccf7-7c0d-4b49-af14-00c358cef2cf", "id_role_permission": "86b3722d-c448-4950-9534-cb0d18a31632"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
c4bdf12b-2b65-4598-a69e-fee464317e40	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "a8aea6e0-ce91-48ff-b176-9e78060ace00", "id_role_permission": "9212a89a-a7fb-4d32-aa6f-e5d2c99d6faf"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
f0499361-d5cd-47e5-9b38-2df6d2e90a61	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "b8b923c4-9eaa-457e-b8a9-a063762dd061", "id_role_permission": "529cc03f-61c8-493b-a049-2bf1b1ef3ced"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
adef5b99-719e-4e6b-8c2a-a04d0950c0c3	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "2b6f812b-aeec-4a98-ac47-ef25d721cfe6", "id_role_permission": "7cd62bda-45cf-4908-90dc-f19a2c4b689f"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
d26fb092-3ede-4ef7-a771-27d07cd89a80	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "28f8b442-4868-42fd-921e-71498220670d", "id_role_permission": "bde9cd20-1661-4c2e-903b-1bf30cae74b5"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
a807432a-4137-4885-9937-6f00201379ab	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "6f145823-fd67-4782-a890-d43921be4120", "id_role_permission": "7a9103ca-6695-4576-8833-872e24703dd9"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
7a3da076-b0ec-4f60-82fb-a8604433f8be	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "3f07e425-9f2c-4715-80df-a8a3634b9437", "id_role_permission": "2b0e5c6f-f27e-47b5-8a0d-85238d8c0181"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
c784f4e6-8920-4786-98c1-98834f8ac85f	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "67a843d8-a286-49c1-b7af-78a155cb5f82", "id_role_permission": "c4a8c279-6ec1-4876-a312-881837a6d947"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
6ae15602-603d-4095-81a0-e1d87b84e2af	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "5a0dd879-26b8-4705-bc3f-647bdc7dc218", "id_role_permission": "83b6fb94-b036-41f4-90c7-435b8cbc3a27"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
2ec3ac8e-579d-4866-9650-517a8483118a	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "c1fc2a9e-1b7f-42a1-94bc-8355db2fc865", "id_role_permission": "fa1a98f1-eecd-4dd7-9695-75e08cb1ba0c"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
d1820c1a-155a-4649-8734-ccfe5f06f2cc	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "f5bf4f2c-c024-42d7-9f3b-fec37a3df52c", "id_role_permission": "7d774769-0370-4334-9322-b65a96b5456d"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
f4c78693-e21e-4c76-9806-f45df3e3f937	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "3ce2eebe-72f8-41b6-a1f2-a330878d0dea", "id_role_permission": "1183c066-914a-461c-b9d2-cb3b41cbe5e1"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
a665b763-83ea-40f3-87b6-f890bf78be39	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "ef43cc2c-c8ba-4d26-96ee-bd9db4daafc4", "id_role_permission": "8cb361e6-a8ef-41c1-a9a9-efa087265b33"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
83d1afcf-1e38-4d47-b334-10fe0a7c3686	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "d671c3c2-6dc9-4359-b5e9-2d637a4a3c90", "id_role_permission": "a07a6c49-61e3-449d-9c3b-d12456f73a26"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
c26ffae4-cfae-4b6f-9190-f281b4ad2f32	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "38710114-0bc1-4124-bc9b-a0041253b0a3", "id_role_permission": "89d34580-4d73-43d8-b8a9-352bbb7c70ca"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
558bb228-cc7d-45f5-bb59-02e0a85abc4e	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "0b12fa15-7b6f-4416-98a7-5c47af781d54", "id_role_permission": "5400aa17-7429-4546-ac2e-277ff7925f62"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
964f6fd3-ad89-4c14-938f-0a96a4eaba78	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "eca864ea-922c-4f9f-a778-cd5cf8395978", "id_role_permission": "ec2cfe0a-2b20-4911-b417-1f63c12155e4"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
7e08f023-092a-4b53-8b6d-e875f7150270	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "9efe7f3b-994a-457a-982b-f21dfca1fdb0", "id_role_permission": "451ae7e0-2985-40ff-af93-d7424ac9b51e"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
753156b3-ae04-4c24-9a56-4069fcf0aae9	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "9232d42e-3474-43ff-b055-53ee29136f32", "id_role_permission": "9f70676b-8cab-4484-8534-9ad527260648"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
6bdfb1c3-1eb8-49eb-9425-da05a16853ba	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "72c2af2f-65d8-4772-b4f8-4d22f72e78b5", "id_role_permission": "b6ce295f-fb53-4c28-897f-b0da04b369e6"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
4c98fe06-b02e-4d7e-a3e2-f22fad46da42	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "1104d8a4-485c-42df-b10a-6da2f4bd77a5", "id_role_permission": "a2af0df4-be58-4d09-8ad3-12ad393c4684"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
dec4996b-365f-446c-9ca4-a80b84081da8	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "4bb2ebd2-ef07-4272-82d1-0fc892aa0efc", "id_role_permission": "9cf2b2f2-08ac-4619-9b96-28dc09fa1013"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
01dfa5bb-b7d3-4fe7-9561-f99340ce45a1	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "ca920d3a-e7a0-4427-a77c-33b9d772d043", "id_role_permission": "5d630d29-15b6-49c1-95c5-804bab6cc4e1"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
293ea015-579b-42b9-a193-15a6cbabd083	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "b80f9fed-dd68-48f1-a723-36c8a303c30b", "id_role_permission": "6f8575fd-c0bb-4812-b9b3-156605f232d2"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
c50d6af1-1bf4-4818-88aa-0d27e9eff81d	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "cb1cf89c-6011-4f0f-9422-64c6683054b3", "id_role_permission": "5857aa2c-1d8c-4d8e-9c41-bfe99f991279"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
4153c9f0-bd5d-44a6-bbd3-79b48c6d8a88	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "bd47441a-5db0-4584-bc3c-e72e473c2d76", "id_role_permission": "0f1f5c58-d934-475f-a7f0-53e7dcee05cb"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
8e64038f-5025-47a9-915a-27cf5de0363d	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "71259f74-422e-454d-b684-ebdc3d931942", "id_role_permission": "afadd52a-1598-4c2b-80ba-aec28db4e62b"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
28657223-2d12-4ec8-a27f-964fc85c9f3d	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "a86a1415-4d28-4bc9-9772-4a57f3ba8030", "id_role_permission": "f0157777-7099-4e22-90a6-7f6d2ceebec3"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
f79d9f1c-fd93-4cb1-a761-0797371676c3	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "e79efe13-7b22-4997-86b7-a29e15a078d5", "id_role_permission": "c624a3bd-f640-4ca5-8af9-724e3ea73b91"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
959b6f79-9b88-432b-8fbc-09253a9b2b25	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "d02d9c15-e610-4f32-aae5-c78ae87946a0", "id_role_permission": "b8c1de4e-c33d-4f39-90db-f7faaae16914"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
aaf457ae-8802-4bf6-a412-8326d265f389	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "036d9d91-49a0-4723-802a-c47f1f124fba", "id_role_permission": "b26f4148-ae59-49bd-b12b-9aa61934b04a"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
d6017a31-04ef-4c7a-a11b-2dcf8f1af219	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "b5a82b0e-7a44-4007-ba8b-d4fe0bb386fc", "id_role_permission": "0466cce1-2e2c-45fa-bd5d-95c28999b934"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
5c591298-e565-465f-ac20-d6eb317b7367	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "e4f86d35-893b-45b2-8546-89ae7da9cc09", "id_role_permission": "0b178dd4-42d4-4b82-8fb5-5b0f720f67c8"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
d92f8660-8351-4d16-89ac-be1cfd81bdc0	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "093217c1-db09-4162-a01b-6c9ab178816f", "id_role_permission": "822d79bb-06e7-4d10-8700-62735fbfc9b9"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
df0d46ca-e31b-46d4-abcf-772b724e911a	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "12dbccf7-7c0d-4b49-af14-00c358cef2cf", "id_role_permission": "cfb8c3e3-5ad5-4cf8-98b8-74508720cb45"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
5bd94fe6-d84d-4622-937f-b1eedb648706	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "a8aea6e0-ce91-48ff-b176-9e78060ace00", "id_role_permission": "b46ac530-8f61-48e2-8ef5-addec342c720"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
de09e43a-b927-47ef-b088-4ddf6b1779bf	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "b8b923c4-9eaa-457e-b8a9-a063762dd061", "id_role_permission": "67269489-005d-43cd-991f-1f67bfcc18dc"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
7732cee6-5549-4ba3-890e-fa76071b6d97	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "2b6f812b-aeec-4a98-ac47-ef25d721cfe6", "id_role_permission": "51082a86-6b0e-4fee-a24c-2da6c3fa90b6"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
ff084137-5017-4906-8af9-b03f4a041d71	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "28f8b442-4868-42fd-921e-71498220670d", "id_role_permission": "508e17f5-3763-4824-88af-f2ca667aec5d"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
7294796b-a59d-4092-a86c-590682222d8d	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "6f145823-fd67-4782-a890-d43921be4120", "id_role_permission": "6878bf77-3009-4762-bac4-82c7a625cb35"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
37c3f7e4-4bc9-4ae6-b9ec-40f350c8762e	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "3f07e425-9f2c-4715-80df-a8a3634b9437", "id_role_permission": "b0956fe2-0cbc-4498-993c-4c2cadda115f"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
f3f5ca2f-da3f-43fe-8bfa-831601f86386	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "67a843d8-a286-49c1-b7af-78a155cb5f82", "id_role_permission": "158afa99-6995-4f75-91a5-e27b72b6d41f"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
16fa80c2-1da1-441e-b10d-6311b44ab7e4	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "5a0dd879-26b8-4705-bc3f-647bdc7dc218", "id_role_permission": "ecb61f2d-df3d-49df-a155-087ed7c13bab"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
59452f40-8ac1-4ec8-a1ac-1412a6def95d	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "c1fc2a9e-1b7f-42a1-94bc-8355db2fc865", "id_role_permission": "372f5c02-f3a7-4aff-82ea-4793dee1dee6"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
7a72c18b-6304-41bc-9856-5236f2ac773c	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "f5bf4f2c-c024-42d7-9f3b-fec37a3df52c", "id_role_permission": "a7b3dcf1-1506-49d6-add2-55cc00d504b3"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
ec32bf21-c3b6-49a4-baf2-0713592ed2a2	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "3ce2eebe-72f8-41b6-a1f2-a330878d0dea", "id_role_permission": "1343887f-fd34-4e6f-b444-3268654abc62"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
4c7baa60-6055-4ee8-ba87-31289bb07232	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "ef43cc2c-c8ba-4d26-96ee-bd9db4daafc4", "id_role_permission": "7d288109-d573-4fb7-aa19-8d1b6694e9ba"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
9d817198-6994-44ad-9fd7-258c1eece1cc	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "d671c3c2-6dc9-4359-b5e9-2d637a4a3c90", "id_role_permission": "14604f68-ba2d-49ba-9db2-019e0a80785d"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
ae87ce6c-9ac7-4344-9ce3-f24dda8e7a69	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "38710114-0bc1-4124-bc9b-a0041253b0a3", "id_role_permission": "44dde1b0-4a70-4b9c-b5b5-7f6afef0ff91"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
76777567-4a5b-4289-bd99-a5f3b27b9c52	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "0b12fa15-7b6f-4416-98a7-5c47af781d54", "id_role_permission": "f8e61eee-a524-41a5-93d3-b189b9122d01"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
c468957e-af87-4dc6-b6a4-83f156ee3bab	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "eca864ea-922c-4f9f-a778-cd5cf8395978", "id_role_permission": "bd67820c-42e1-4c64-90a0-92d5270ee45e"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
6b75d221-e9ed-45cb-bf6c-c7641efb28e2	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "9efe7f3b-994a-457a-982b-f21dfca1fdb0", "id_role_permission": "8011e46e-792a-4295-89e5-b236c3af815c"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
12cc4c32-f832-413b-906c-3e8014aab808	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "9232d42e-3474-43ff-b055-53ee29136f32", "id_role_permission": "86388963-ba39-4b1a-acbb-32273eb0b68c"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
e1da5b02-14e2-4f36-a6b1-29c26d7f3c32	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "72c2af2f-65d8-4772-b4f8-4d22f72e78b5", "id_role_permission": "cb84308f-2ade-41b6-9619-c48a883b9f84"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
0ad09217-7b56-4ae0-8bce-d5b31d6ea3a5	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "1104d8a4-485c-42df-b10a-6da2f4bd77a5", "id_role_permission": "7b9249fc-d632-4e01-ba55-c12769bd4ffe"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
58df4382-4e2a-42ac-8f2f-8dd3416c38f5	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "4bb2ebd2-ef07-4272-82d1-0fc892aa0efc", "id_role_permission": "689d60b6-9652-4148-9ccc-ae4978cafa15"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
c4072867-5504-4d4f-9380-6d76bbb3ac0b	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "ca920d3a-e7a0-4427-a77c-33b9d772d043", "id_role_permission": "cab376e3-5961-4bc0-996e-31a2fe64c7a7"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
eb6f2263-04ba-40c4-a8bb-bdc9794a321a	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "b80f9fed-dd68-48f1-a723-36c8a303c30b", "id_role_permission": "cb08882b-4e06-456e-8a57-705157e38ee2"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
0440169c-c9e3-4fc2-ab09-e1ce342ee59a	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "e4f86d35-893b-45b2-8546-89ae7da9cc09", "id_role_permission": "f43c1e9f-e409-48b1-8c45-ace0b2efdf15"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
b25933e3-8015-44f7-bc3e-255eddb9aadd	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "093217c1-db09-4162-a01b-6c9ab178816f", "id_role_permission": "11dc30dd-089e-4270-9a5a-e4a84d06faf8"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
294f67a0-d484-4868-a675-221a114945f5	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "b8b923c4-9eaa-457e-b8a9-a063762dd061", "id_role_permission": "1107fd7f-b014-46f3-8ffb-798256cc0e70"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
b167f977-6a81-4cdf-beb5-32b7bbe74334	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "28f8b442-4868-42fd-921e-71498220670d", "id_role_permission": "723be752-c139-4bfb-a816-9c79c895b942"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
b2ad2a95-5588-460d-b628-fb1ad2ab146b	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "3f07e425-9f2c-4715-80df-a8a3634b9437", "id_role_permission": "c59fd5b9-2575-4afb-ae2f-d89eb954d8ea"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
0e47fb7c-1de9-4408-be9a-c9ddc1e57f05	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "38710114-0bc1-4124-bc9b-a0041253b0a3", "id_role_permission": "463b7b2f-fc6a-4b66-b73b-90d154681fd9"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
a18680ee-dba4-4c45-93a1-60d573129388	\N	crear	auth	auth.role_permission	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "created_at": "2026-06-23T22:56:12.652868+00:00", "deleted_at": null, "id_permission": "ca920d3a-e7a0-4427-a77c-33b9d772d043", "id_role_permission": "244e7ad6-91d9-4061-8251-32f336eee15e"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.652868-05
22f594d4-23fc-4f78-a9e1-415c77e1eca2	b1000000-0000-0000-0000-000000000001	crear	homes	homes.home	\N	\N	{"estado": "activo", "nombre": "Casa Karen", "estrato": 3, "id_home": "c1000000-0000-0000-0000-000000000001", "id_user": "b1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
2cc2486d-d8c7-437c-a774-18ecf252524f	a1b2c3d4-9999-0000-0000-000000000001	crear	auth	auth.user	\N	\N	{"email": "admin@smarthome.com", "estado": "activo", "nombre": "Administrador", "id_user": "a1b2c3d4-9999-0000-0000-000000000001", "apellido": "Sistema", "username": "admin_smarthome", "created_at": "2026-06-23T22:56:12.791453+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:12.791453+00:00", "mfa_habilitado": false, "tipo_documento": "CC", "bloqueado_hasta": null, "email_verificado": true, "numero_documento": "0000000001", "intentos_fallidos": 0}	\N	\N	exitoso	\N	2026-06-23 17:56:12.791453-05
2dfdee5f-c76d-40dc-a943-0264f44fe08e	a1b2c3d4-9999-0000-0000-000000000001	crear	config	config.configuration_user	\N	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "a1b2c3d4-9999-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.791453+00:00", "updated_at": "2026-06-23T22:56:12.791453+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "a6bc6331-8930-4a47-b071-faabd5a63f6c", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.791453-05
edd1424f-d662-4bb3-8306-1f4a59156dbd	a1b2c3d4-9999-0000-0000-000000000001	crear	auth	auth.user_role	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000001", "id_user": "a1b2c3d4-9999-0000-0000-000000000001", "created_at": "2026-06-23T22:56:12.791453+00:00", "deleted_at": null, "asignado_por": null, "id_user_role": "303c13fc-6712-4f94-be52-d1f3cccc4893"}	\N	\N	exitoso	\N	2026-06-23 17:56:12.791453-05
7ff2a5d0-4864-4de0-a7be-c2e2e0bdf84c	a1b2c3d4-9999-0000-0000-000000000001	crear	sistema	role	\N	\N	\N	\N	\N	exitoso	Seed inicial: inserci├│n de roles base del sistema (administrador, estandar, invitado).	2026-06-23 17:56:13.093513-05
d3090439-c010-4426-9a81-898cbd7f229c	a1b2c3d4-9999-0000-0000-000000000001	crear	sistema	permission	\N	\N	\N	\N	\N	exitoso	Seed inicial: inserci├│n de 36 permisos del sistema organizados por m├│dulo.	2026-06-23 17:56:13.093513-05
a251020d-05e9-4785-b0cf-8996bb31aa31	a1b2c3d4-9999-0000-0000-000000000001	crear	sistema	role_permission	\N	\N	\N	\N	\N	exitoso	Seed inicial: asignaci├│n de permisos a roles seg├║n principio de m├¡nimo privilegio.	2026-06-23 17:56:13.093513-05
db3508cf-9a92-4a90-906b-f3013c4fb180	a1b2c3d4-9999-0000-0000-000000000001	crear	sistema	type_device	\N	\N	\N	\N	\N	exitoso	Seed inicial: inserci├│n de cat├ílogo de 13 tipos de dispositivos IoT.	2026-06-23 17:56:13.093513-05
1df43e0d-7c37-4540-930e-e943ff25bf94	a1b2c3d4-9999-0000-0000-000000000001	crear	sistema	user	\N	\N	\N	\N	\N	exitoso	Seed inicial: creaci├│n de usuario administrador por defecto (admin@smarthome.com).	2026-06-23 17:56:13.093513-05
82f5efb4-dfde-4002-95af-639169f132c0	b1000000-0000-0000-0000-000000000001	crear	auth	auth.user	\N	\N	{"email": "karen@smarthome.com", "estado": "activo", "nombre": "Karen Daniela", "id_user": "b1000000-0000-0000-0000-000000000001", "apellido": "Holgu├¡n Cruz", "username": "karen_holguin", "created_at": "2026-06-23T22:56:45.546819+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:45.546819+00:00", "mfa_habilitado": false, "tipo_documento": "CC", "bloqueado_hasta": null, "email_verificado": true, "numero_documento": "1001000001", "intentos_fallidos": 0}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
7ba4f6eb-8d72-4515-97d2-e9fecb9391da	b1000000-0000-0000-0000-000000000001	crear	config	config.configuration_user	\N	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:45.546819+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "d5d787f8-8a78-4943-8835-9966a089b8a3", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
cb54bc7e-b84a-454f-98b7-c1e006a79de0	b1000000-0000-0000-0000-000000000002	crear	auth	auth.user	\N	\N	{"email": "kevin@smarthome.com", "estado": "activo", "nombre": "Kevin Stiven", "id_user": "b1000000-0000-0000-0000-000000000002", "apellido": "L├│pez Amaya", "username": "kevin_lopez", "created_at": "2026-06-23T22:56:45.546819+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:45.546819+00:00", "mfa_habilitado": false, "tipo_documento": "CC", "bloqueado_hasta": null, "email_verificado": true, "numero_documento": "1001000002", "intentos_fallidos": 0}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
fdf7843c-0e9a-4d50-8141-591a3b18c363	b1000000-0000-0000-0000-000000000002	crear	config	config.configuration_user	\N	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:45.546819+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "41ecb949-8320-466e-9763-0b7399bdc0e7", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
f28f5722-54a2-4fcc-9db6-6c57a0310faa	b1000000-0000-0000-0000-000000000003	crear	auth	auth.user	\N	\N	{"email": "natalia@smarthome.com", "estado": "activo", "nombre": "Natalia", "id_user": "b1000000-0000-0000-0000-000000000003", "apellido": "Chala Chala", "username": "natalia_chala", "created_at": "2026-06-23T22:56:45.546819+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:45.546819+00:00", "mfa_habilitado": false, "tipo_documento": "CC", "bloqueado_hasta": null, "email_verificado": true, "numero_documento": "1001000003", "intentos_fallidos": 0}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
148021d7-6609-470f-aa03-b42fe8317008	b1000000-0000-0000-0000-000000000003	crear	config	config.configuration_user	\N	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000003", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:45.546819+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "3159349e-4c75-4641-a66b-46a53bb569ce", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
c71c2e2c-174f-4f52-bd6d-964c6f689405	b1000000-0000-0000-0000-000000000001	crear	auth	auth.user_role	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "id_user": "b1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:45.546819+00:00", "deleted_at": null, "asignado_por": null, "id_user_role": "251a6b42-cd17-40b5-a3e9-bc9955e8c8a9"}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
799fce19-4dc2-40b9-bb0f-884ecd87c26a	b1000000-0000-0000-0000-000000000002	crear	auth	auth.user_role	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000002", "id_user": "b1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:45.546819+00:00", "deleted_at": null, "asignado_por": null, "id_user_role": "22be4921-93c9-45c8-bd51-1cb680b65a17"}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
41ce76f6-8c91-4c15-9434-e474ab5e270a	b1000000-0000-0000-0000-000000000003	crear	auth	auth.user_role	\N	\N	{"id_role": "a1b2c3d4-0001-0000-0000-000000000003", "id_user": "b1000000-0000-0000-0000-000000000003", "created_at": "2026-06-23T22:56:45.546819+00:00", "deleted_at": null, "asignado_por": null, "id_user_role": "96fa5ce8-b27f-4e16-9d4c-967e7e8a4d06"}	\N	\N	exitoso	\N	2026-06-23 17:56:45.546819-05
bb1e1884-e292-4bf4-9e0a-93d8b5cbf5e1	b1000000-0000-0000-0000-000000000002	crear	homes	homes.home	\N	\N	{"estado": "activo", "nombre": "Apartamento Kevin", "estrato": 4, "id_home": "c1000000-0000-0000-0000-000000000002", "id_user": "b1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
16f064be-bd46-4756-a15b-dc9a8ff62473	b1000000-0000-0000-0000-000000000001	crear	homes	homes.home_member	\N	\N	{"id_home": "c1000000-0000-0000-0000-000000000001", "id_user": "b1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "rol_en_hogar": "propietario", "id_home_member": "79d36885-8f02-4222-a98b-a98af00f3638"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
3d79f171-f4f4-409b-bded-0f5d92fd8b99	b1000000-0000-0000-0000-000000000002	crear	homes	homes.home_member	\N	\N	{"id_home": "c1000000-0000-0000-0000-000000000002", "id_user": "b1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "rol_en_hogar": "propietario", "id_home_member": "dae31a02-5201-4237-99ba-27735b20a675"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
005acb5a-f480-4d3e-898b-5bb50a6a55d2	b1000000-0000-0000-0000-000000000003	crear	homes	homes.home_member	\N	\N	{"id_home": "c1000000-0000-0000-0000-000000000001", "id_user": "b1000000-0000-0000-0000-000000000003", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "rol_en_hogar": "miembro", "id_home_member": "86b24f19-7c82-4d7a-8c9c-2a350acd55a8"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
f0ee9704-a697-4a9c-8d07-5dffe7e48945	\N	crear	homes	homes.area	\N	\N	{"tipo": "sala", "nombre": "Sala Principal", "id_area": "d1000000-0000-0000-0000-000000000001", "id_home": "c1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
03897955-7b38-4b16-9ac7-194dbbabff51	\N	crear	homes	homes.area	\N	\N	{"tipo": "cocina", "nombre": "Cocina", "id_area": "d1000000-0000-0000-0000-000000000002", "id_home": "c1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
997f848f-64e1-45e4-a0e5-2d609d3448d4	\N	crear	homes	homes.area	\N	\N	{"tipo": "dormitorio", "nombre": "Dormitorio Principal", "id_area": "d1000000-0000-0000-0000-000000000003", "id_home": "c1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
c2e97b7c-3bf3-43b4-beb2-40e12f705a41	\N	crear	homes	homes.area	\N	\N	{"tipo": "ba├▒o", "nombre": "Ba├▒o", "id_area": "d1000000-0000-0000-0000-000000000004", "id_home": "c1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
80494b17-c4b8-4dff-9104-5d0de4876762	\N	crear	homes	homes.area	\N	\N	{"tipo": "sala", "nombre": "Sala", "id_area": "d1000000-0000-0000-0000-000000000005", "id_home": "c1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
d2c7cb13-bd97-40e8-8a65-c2790c422d08	\N	crear	homes	homes.area	\N	\N	{"tipo": "dormitorio", "nombre": "Habitaci├│n", "id_area": "d1000000-0000-0000-0000-000000000006", "id_home": "c1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
c34fc887-405f-4493-8349-7885bd275b49	\N	crear	homes	homes.area	\N	\N	{"tipo": "cocina", "nombre": "Cocina", "id_area": "d1000000-0000-0000-0000-000000000007", "id_home": "c1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
b1ae3d46-88e0-4590-85df-a73c52b9dc76	\N	crear	homes	homes.tariff	\N	\N	{"moneda": "COP", "id_home": "c1000000-0000-0000-0000-000000000001", "costo_kwh": 850.0000, "id_tariff": "1311e8b4-ef3f-416d-b964-a1784a8198ff", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00", "vigente_desde": "2025-01-01", "vigente_hasta": null}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
40df6fb5-0615-4a16-8210-42d0486b100d	\N	crear	homes	homes.tariff	\N	\N	{"moneda": "COP", "id_home": "c1000000-0000-0000-0000-000000000002", "costo_kwh": 920.0000, "id_tariff": "a34bf920-9996-4efc-8a5c-b39cc4bd3891", "created_at": "2026-06-23T22:56:46.248438+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.248438+00:00", "vigente_desde": "2025-01-01", "vigente_hasta": null}	\N	\N	exitoso	\N	2026-06-23 17:56:46.248438-05
0002b077-9dc7-4f95-bb20-f9aebc276721	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "L├ímpara Sala", "id_area": "d1000000-0000-0000-0000-000000000001", "id_home": "c1000000-0000-0000-0000-000000000001", "encendido": true, "id_device": "e1000000-0000-0000-0000-000000000001", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "e2aae9c3-dfec-49f9-b4c0-374b35ef840a", "consumo_actual_w": 12.50}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
fc6d2f53-9a62-4864-a4b3-8b59691399bb	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "Televisor Sala", "id_area": "d1000000-0000-0000-0000-000000000001", "id_home": "c1000000-0000-0000-0000-000000000001", "encendido": true, "id_device": "e1000000-0000-0000-0000-000000000002", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "796b8fcc-229c-4d53-829e-32ccc0ee92fe", "consumo_actual_w": 120.00}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
c91aab1c-ca60-45e6-939e-02c2bd2702f8	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "Nevera Cocina", "id_area": "d1000000-0000-0000-0000-000000000002", "id_home": "c1000000-0000-0000-0000-000000000001", "encendido": true, "id_device": "e1000000-0000-0000-0000-000000000003", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "a61035f5-c06e-4c23-b7ff-7a5499a06ef5", "consumo_actual_w": 150.00}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
c59eafb9-7461-4aef-b9ee-1d0f2e1c31cb	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "Microondas Cocina", "id_area": "d1000000-0000-0000-0000-000000000002", "id_home": "c1000000-0000-0000-0000-000000000001", "encendido": false, "id_device": "e1000000-0000-0000-0000-000000000004", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "5f2b256d-a6c8-48db-8fcc-793c644ef92e", "consumo_actual_w": 0.00}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
8bddab08-928a-478e-9870-134f7e8633f3	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "Aire Dormitorio", "id_area": "d1000000-0000-0000-0000-000000000003", "id_home": "c1000000-0000-0000-0000-000000000001", "encendido": false, "id_device": "e1000000-0000-0000-0000-000000000005", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "88605aba-87aa-4785-ad0f-38a294702c4d", "consumo_actual_w": 0.00}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
a9d5f8ea-adf7-4016-aa89-44f0a57bd8c1	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "L├ímpara Sala", "id_area": "d1000000-0000-0000-0000-000000000005", "id_home": "c1000000-0000-0000-0000-000000000002", "encendido": true, "id_device": "e1000000-0000-0000-0000-000000000006", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "e2aae9c3-dfec-49f9-b4c0-374b35ef840a", "consumo_actual_w": 12.50}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
bb6dfafb-f560-4810-9600-a7ce17da35f9	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "Computador Habitaci├│n", "id_area": "d1000000-0000-0000-0000-000000000006", "id_home": "c1000000-0000-0000-0000-000000000002", "encendido": true, "id_device": "e1000000-0000-0000-0000-000000000007", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "bc476a0c-a629-46ef-852b-630804d37020", "consumo_actual_w": 200.00}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
d29e9a37-44b2-4d7c-a894-d5a67fa3545b	\N	crear	devices	devices.device	\N	\N	{"estado": "conectado", "nombre": "Lavadora", "id_area": "d1000000-0000-0000-0000-000000000007", "id_home": "c1000000-0000-0000-0000-000000000002", "encendido": false, "id_device": "e1000000-0000-0000-0000-000000000008", "protocolo": "wifi", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "mac_address": null, "id_type_device": "0f27c00e-7895-42e2-87b1-d15af3aa277c", "consumo_actual_w": 0.00}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
cd11a835-eb47-4541-90f9-a69532e38674	\N	crear	devices	devices.schedule	\N	\N	{"hora": "18:00:00", "accion": "encender", "activo": true, "id_device": "e1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "dias_semana": [1, 2, 3, 4, 5], "id_schedule": "c685591d-be91-45ea-8a46-d07a66acbfff"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
d909576f-cfa0-41a0-8780-ec6b924b662a	\N	crear	devices	devices.schedule	\N	\N	{"hora": "23:00:00", "accion": "apagar", "activo": true, "id_device": "e1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "dias_semana": [1, 2, 3, 4, 5, 6, 7], "id_schedule": "fc216db2-e264-4d96-96b7-c6951e21d42e"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
dff1f4ef-4c05-4101-969e-eb192e9f8318	\N	crear	devices	devices.schedule	\N	\N	{"hora": "21:00:00", "accion": "encender", "activo": true, "id_device": "e1000000-0000-0000-0000-000000000005", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "dias_semana": [1, 2, 3, 4, 5], "id_schedule": "10d2806e-37e2-4a7f-970f-d7e44ed86a2f"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
162e3ba4-f27d-4116-b489-fc852d9e8dde	\N	crear	devices	devices.schedule	\N	\N	{"hora": "06:00:00", "accion": "apagar", "activo": true, "id_device": "e1000000-0000-0000-0000-000000000005", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "updated_at": "2026-06-23T22:56:46.320467+00:00", "dias_semana": [1, 2, 3, 4, 5, 6, 7], "id_schedule": "83f2c693-4e7b-4821-bd31-9ef30176edad"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
fc55ff12-df69-4e94-b2d7-a962e105e591	\N	crear	devices	devices.threshold_rule	\N	\N	{"tipo": "diario", "accion": "alertar", "activa": true, "id_device": "e1000000-0000-0000-0000-000000000005", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "limite_kwh": 3.0000, "updated_at": "2026-06-23T22:56:46.320467+00:00", "id_threshold_rule": "2de2b00a-c5a3-43cd-acd3-2ec6d8396773"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
812ff57f-e06d-459b-a6c1-917916af52b6	\N	crear	devices	devices.threshold_rule	\N	\N	{"tipo": "mensual", "accion": "alertar", "activa": true, "id_device": "e1000000-0000-0000-0000-000000000003", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "limite_kwh": 100.0000, "updated_at": "2026-06-23T22:56:46.320467+00:00", "id_threshold_rule": "3883a798-2380-437f-9e35-835f5952469a"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
ede25006-8d69-4130-9bfe-12750674fa14	\N	crear	devices	devices.threshold_rule	\N	\N	{"tipo": "diario", "accion": "alertar", "activa": true, "id_device": "e1000000-0000-0000-0000-000000000007", "created_at": "2026-06-23T22:56:46.320467+00:00", "deleted_at": null, "limite_kwh": 2.0000, "updated_at": "2026-06-23T22:56:46.320467+00:00", "id_threshold_rule": "49a32962-2df2-4a22-82dc-266ed2c3f96e"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.320467-05
5d2220d4-6898-4f44-bfbc-10642808e9ab	b1000000-0000-0000-0000-000000000001	editar	config	config.configuration_user	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:45.546819+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "d5d787f8-8a78-4943-8835-9966a089b8a3", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000001", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:46.520752+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "d5d787f8-8a78-4943-8835-9966a089b8a3", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.520752-05
920b4593-fc31-4f93-a23a-7ab4bd5081c6	b1000000-0000-0000-0000-000000000002	editar	config	config.configuration_user	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:45.546819+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "41ecb949-8320-466e-9763-0b7399bdc0e7", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	{"tema": "oscuro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000002", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:46.520752+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": "06:00:00", "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": false, "no_molestar_inicio": "22:00:00", "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "41ecb949-8320-466e-9763-0b7399bdc0e7", "notif_consumo_elevado": true, "notif_recomendaciones": false, "recomendaciones_activas": false, "frecuencia_recomendaciones": "mensual"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.520752-05
c294132f-afda-47ee-b454-15add93c24fe	b1000000-0000-0000-0000-000000000003	editar	config	config.configuration_user	\N	{"tema": "claro", "idioma": "es", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000003", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:45.546819+00:00", "formato_hora": "24h", "formato_fecha": "DD/MM/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": true, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": true, "unidad_temperatura": "C", "id_configuration_user": "3159349e-4c75-4641-a66b-46a53bb569ce", "notif_consumo_elevado": true, "notif_recomendaciones": true, "recomendaciones_activas": true, "frecuencia_recomendaciones": "semanal"}	{"tema": "automatico", "idioma": "en", "moneda": "COP", "id_user": "b1000000-0000-0000-0000-000000000003", "created_at": "2026-06-23T22:56:45.546819+00:00", "updated_at": "2026-06-23T22:56:46.520752+00:00", "formato_hora": "12h", "formato_fecha": "MM/DD/YYYY", "no_molestar_fin": null, "notif_canal_app": true, "notif_seguridad": true, "notif_canal_push": false, "notif_canal_email": true, "no_molestar_inicio": null, "notif_dispositivos": false, "unidad_temperatura": "F", "id_configuration_user": "3159349e-4c75-4641-a66b-46a53bb569ce", "notif_consumo_elevado": false, "notif_recomendaciones": false, "recomendaciones_activas": false, "frecuencia_recomendaciones": "semanal"}	\N	\N	exitoso	\N	2026-06-23 17:56:46.520752-05
\.


--
-- Data for Name: mfa; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.mfa (id_mfa, id_user, metodo, codigo_secreto, habilitado, ultimo_codigo_hash, expira_en, intentos_fallidos, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: permission; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.permission (id_permission, nombre, modulo, accion, descripcion, created_at, updated_at, deleted_at) FROM stdin;
036d9d91-49a0-4723-802a-c47f1f124fba	usuarios:leer	usuarios	leer	Ver listado y detalle de usuarios	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
71259f74-422e-454d-b684-ebdc3d931942	usuarios:crear	usuarios	crear	Registrar nuevos usuarios	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
a86a1415-4d28-4bc9-9772-4a57f3ba8030	usuarios:editar	usuarios	editar	Modificar datos de usuarios	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
d02d9c15-e610-4f32-aae5-c78ae87946a0	usuarios:eliminar	usuarios	eliminar	Desactivar cuentas de usuarios	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
e79efe13-7b22-4997-86b7-a29e15a078d5	roles:asignar	usuarios	editar	Asignar y modificar roles de usuarios	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
b5a82b0e-7a44-4007-ba8b-d4fe0bb386fc	usuarios:ver_todos	usuarios	leer	Ver todos los usuarios del sistema	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
ca920d3a-e7a0-4427-a77c-33b9d772d043	hogares:leer	hogares	leer	Ver hogares propios	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
0b12fa15-7b6f-4416-98a7-5c47af781d54	hogares:crear	hogares	crear	Registrar nuevos hogares	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
9efe7f3b-994a-457a-982b-f21dfca1fdb0	hogares:editar	hogares	editar	Modificar datos del hogar	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
1104d8a4-485c-42df-b10a-6da2f4bd77a5	hogares:desactivar	hogares	eliminar	Desactivar hogares	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
eca864ea-922c-4f9f-a778-cd5cf8395978	zonas:crear	hogares	crear	Crear zonas dentro de un hogar	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
9232d42e-3474-43ff-b055-53ee29136f32	zonas:editar	hogares	editar	Editar zonas existentes	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
4bb2ebd2-ef07-4272-82d1-0fc892aa0efc	zonas:eliminar	hogares	eliminar	Eliminar zonas del hogar	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
72c2af2f-65d8-4772-b4f8-4d22f72e78b5	tarifas:configurar	hogares	editar	Configurar tarifas el├®ctricas	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
38710114-0bc1-4124-bc9b-a0041253b0a3	dispositivos:leer	dispositivos	leer	Ver dispositivos registrados	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
67a843d8-a286-49c1-b7af-78a155cb5f82	dispositivos:crear	dispositivos	crear	Registrar nuevos dispositivos	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
c1fc2a9e-1b7f-42a1-94bc-8355db2fc865	dispositivos:editar	dispositivos	editar	Modificar configuraci├│n de dispositivos	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
d671c3c2-6dc9-4359-b5e9-2d637a4a3c90	dispositivos:desactivar	dispositivos	eliminar	Desactivar dispositivos	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
f5bf4f2c-c024-42d7-9f3b-fec37a3df52c	dispositivos:controlar	dispositivos	editar	Encender/apagar dispositivos remotamente	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
3ce2eebe-72f8-41b6-a1f2-a330878d0dea	dispositivos:configurar_horarios	dispositivos	editar	Configurar horarios autom├íticos	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
ef43cc2c-c8ba-4d26-96ee-bd9db4daafc4	dispositivos:configurar_umbrales	dispositivos	editar	Configurar umbrales de consumo	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
5a0dd879-26b8-4705-bc3f-647bdc7dc218	asistente_voz:vincular	dispositivos	crear	Vincular asistentes de voz	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
b8b923c4-9eaa-457e-b8a9-a063762dd061	consumo:leer	consumo	leer	Ver consumo en tiempo real	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
2b6f812b-aeec-4a98-ac47-ef25d721cfe6	consumo:reportes	consumo	leer	Generar y ver reportes de consumo	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
28f8b442-4868-42fd-921e-71498220670d	consumo:graficos	consumo	leer	Ver gr├íficos de consumo	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
6f145823-fd67-4782-a890-d43921be4120	recomendaciones:leer	consumo	leer	Ver recomendaciones de ahorro	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
12dbccf7-7c0d-4b49-af14-00c358cef2cf	recomendaciones:configurar	consumo	editar	Configurar recomendaciones autom├íticas	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
3f07e425-9f2c-4715-80df-a8a3634b9437	notificaciones:leer	consumo	leer	Ver notificaciones	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
a8aea6e0-ce91-48ff-b176-9e78060ace00	notificaciones:configurar	consumo	editar	Configurar preferencias de notificaciones	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
b80f9fed-dd68-48f1-a723-36c8a303c30b	sync:manual	sync	editar	Forzar sincronizaci├│n manual	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
cb1cf89c-6011-4f0f-9422-64c6683054b3	backups:restaurar	sync	editar	Restaurar informaci├│n desde backup	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
bd47441a-5db0-4584-bc3c-e72e473c2d76	backups:leer	sync	leer	Ver backups disponibles	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
093217c1-db09-4162-a01b-6c9ab178816f	config:leer	config	leer	Ver configuraci├│n personal	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
e4f86d35-893b-45b2-8546-89ae7da9cc09	config:editar	config	editar	Modificar configuraci├│n personal	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
2b3eb354-e2f8-4fcf-87a3-f42c7e902fbd	auditoria:leer	auditoria	leer	Consultar logs de auditor├¡a	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
2b734aaa-ad41-4710-8773-7397fae51591	auditoria:exportar	auditoria	leer	Exportar registros de auditor├¡a	2026-06-23 17:56:12.595131-05	2026-06-23 17:56:12.595131-05	\N
\.


--
-- Data for Name: recovery_token; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.recovery_token (id_recovery_token, id_user, token, tipo, expira_en, usado, created_at) FROM stdin;
\.


--
-- Data for Name: role; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.role (id_role, nombre, descripcion, created_at, updated_at, deleted_at) FROM stdin;
a1b2c3d4-0001-0000-0000-000000000001	administrador	Acceso total al sistema. Puede gestionar usuarios, roles, backups, logs de auditor├¡a y toda la configuraci├│n del sistema.	2026-06-23 17:56:12.540699-05	2026-06-23 17:56:12.540699-05	\N
a1b2c3d4-0001-0000-0000-000000000002	estandar	Acceso a funcionalidades propias del hogar. Puede gestionar hogares, dispositivos, consumo y configuraci├│n personal.	2026-06-23 17:56:12.540699-05	2026-06-23 17:56:12.540699-05	\N
a1b2c3d4-0001-0000-0000-000000000003	invitado	Acceso de solo lectura. Puede visualizar consumo y estado de dispositivos sin realizar cambios.	2026-06-23 17:56:12.540699-05	2026-06-23 17:56:12.540699-05	\N
\.


--
-- Data for Name: role_permission; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.role_permission (id_role_permission, id_role, id_permission, created_at, deleted_at) FROM stdin;
b3504c5f-7dd6-4610-abcf-14fb07793420	a1b2c3d4-0001-0000-0000-000000000001	2b3eb354-e2f8-4fcf-87a3-f42c7e902fbd	2026-06-23 17:56:12.652868-05	\N
9e11b428-ac55-48d9-8f7b-11361fdeb975	a1b2c3d4-0001-0000-0000-000000000001	2b734aaa-ad41-4710-8773-7397fae51591	2026-06-23 17:56:12.652868-05	\N
d4b1c614-93e2-4999-8838-2e643026b899	a1b2c3d4-0001-0000-0000-000000000001	e4f86d35-893b-45b2-8546-89ae7da9cc09	2026-06-23 17:56:12.652868-05	\N
d931f3cc-2d5c-448d-8dd7-e12dd8b360eb	a1b2c3d4-0001-0000-0000-000000000001	093217c1-db09-4162-a01b-6c9ab178816f	2026-06-23 17:56:12.652868-05	\N
86b3722d-c448-4950-9534-cb0d18a31632	a1b2c3d4-0001-0000-0000-000000000001	12dbccf7-7c0d-4b49-af14-00c358cef2cf	2026-06-23 17:56:12.652868-05	\N
9212a89a-a7fb-4d32-aa6f-e5d2c99d6faf	a1b2c3d4-0001-0000-0000-000000000001	a8aea6e0-ce91-48ff-b176-9e78060ace00	2026-06-23 17:56:12.652868-05	\N
529cc03f-61c8-493b-a049-2bf1b1ef3ced	a1b2c3d4-0001-0000-0000-000000000001	b8b923c4-9eaa-457e-b8a9-a063762dd061	2026-06-23 17:56:12.652868-05	\N
7cd62bda-45cf-4908-90dc-f19a2c4b689f	a1b2c3d4-0001-0000-0000-000000000001	2b6f812b-aeec-4a98-ac47-ef25d721cfe6	2026-06-23 17:56:12.652868-05	\N
bde9cd20-1661-4c2e-903b-1bf30cae74b5	a1b2c3d4-0001-0000-0000-000000000001	28f8b442-4868-42fd-921e-71498220670d	2026-06-23 17:56:12.652868-05	\N
7a9103ca-6695-4576-8833-872e24703dd9	a1b2c3d4-0001-0000-0000-000000000001	6f145823-fd67-4782-a890-d43921be4120	2026-06-23 17:56:12.652868-05	\N
2b0e5c6f-f27e-47b5-8a0d-85238d8c0181	a1b2c3d4-0001-0000-0000-000000000001	3f07e425-9f2c-4715-80df-a8a3634b9437	2026-06-23 17:56:12.652868-05	\N
c4a8c279-6ec1-4876-a312-881837a6d947	a1b2c3d4-0001-0000-0000-000000000001	67a843d8-a286-49c1-b7af-78a155cb5f82	2026-06-23 17:56:12.652868-05	\N
83b6fb94-b036-41f4-90c7-435b8cbc3a27	a1b2c3d4-0001-0000-0000-000000000001	5a0dd879-26b8-4705-bc3f-647bdc7dc218	2026-06-23 17:56:12.652868-05	\N
fa1a98f1-eecd-4dd7-9695-75e08cb1ba0c	a1b2c3d4-0001-0000-0000-000000000001	c1fc2a9e-1b7f-42a1-94bc-8355db2fc865	2026-06-23 17:56:12.652868-05	\N
7d774769-0370-4334-9322-b65a96b5456d	a1b2c3d4-0001-0000-0000-000000000001	f5bf4f2c-c024-42d7-9f3b-fec37a3df52c	2026-06-23 17:56:12.652868-05	\N
1183c066-914a-461c-b9d2-cb3b41cbe5e1	a1b2c3d4-0001-0000-0000-000000000001	3ce2eebe-72f8-41b6-a1f2-a330878d0dea	2026-06-23 17:56:12.652868-05	\N
8cb361e6-a8ef-41c1-a9a9-efa087265b33	a1b2c3d4-0001-0000-0000-000000000001	ef43cc2c-c8ba-4d26-96ee-bd9db4daafc4	2026-06-23 17:56:12.652868-05	\N
a07a6c49-61e3-449d-9c3b-d12456f73a26	a1b2c3d4-0001-0000-0000-000000000001	d671c3c2-6dc9-4359-b5e9-2d637a4a3c90	2026-06-23 17:56:12.652868-05	\N
89d34580-4d73-43d8-b8a9-352bbb7c70ca	a1b2c3d4-0001-0000-0000-000000000001	38710114-0bc1-4124-bc9b-a0041253b0a3	2026-06-23 17:56:12.652868-05	\N
5400aa17-7429-4546-ac2e-277ff7925f62	a1b2c3d4-0001-0000-0000-000000000001	0b12fa15-7b6f-4416-98a7-5c47af781d54	2026-06-23 17:56:12.652868-05	\N
ec2cfe0a-2b20-4911-b417-1f63c12155e4	a1b2c3d4-0001-0000-0000-000000000001	eca864ea-922c-4f9f-a778-cd5cf8395978	2026-06-23 17:56:12.652868-05	\N
451ae7e0-2985-40ff-af93-d7424ac9b51e	a1b2c3d4-0001-0000-0000-000000000001	9efe7f3b-994a-457a-982b-f21dfca1fdb0	2026-06-23 17:56:12.652868-05	\N
9f70676b-8cab-4484-8534-9ad527260648	a1b2c3d4-0001-0000-0000-000000000001	9232d42e-3474-43ff-b055-53ee29136f32	2026-06-23 17:56:12.652868-05	\N
b6ce295f-fb53-4c28-897f-b0da04b369e6	a1b2c3d4-0001-0000-0000-000000000001	72c2af2f-65d8-4772-b4f8-4d22f72e78b5	2026-06-23 17:56:12.652868-05	\N
a2af0df4-be58-4d09-8ad3-12ad393c4684	a1b2c3d4-0001-0000-0000-000000000001	1104d8a4-485c-42df-b10a-6da2f4bd77a5	2026-06-23 17:56:12.652868-05	\N
9cf2b2f2-08ac-4619-9b96-28dc09fa1013	a1b2c3d4-0001-0000-0000-000000000001	4bb2ebd2-ef07-4272-82d1-0fc892aa0efc	2026-06-23 17:56:12.652868-05	\N
5d630d29-15b6-49c1-95c5-804bab6cc4e1	a1b2c3d4-0001-0000-0000-000000000001	ca920d3a-e7a0-4427-a77c-33b9d772d043	2026-06-23 17:56:12.652868-05	\N
6f8575fd-c0bb-4812-b9b3-156605f232d2	a1b2c3d4-0001-0000-0000-000000000001	b80f9fed-dd68-48f1-a723-36c8a303c30b	2026-06-23 17:56:12.652868-05	\N
5857aa2c-1d8c-4d8e-9c41-bfe99f991279	a1b2c3d4-0001-0000-0000-000000000001	cb1cf89c-6011-4f0f-9422-64c6683054b3	2026-06-23 17:56:12.652868-05	\N
0f1f5c58-d934-475f-a7f0-53e7dcee05cb	a1b2c3d4-0001-0000-0000-000000000001	bd47441a-5db0-4584-bc3c-e72e473c2d76	2026-06-23 17:56:12.652868-05	\N
afadd52a-1598-4c2b-80ba-aec28db4e62b	a1b2c3d4-0001-0000-0000-000000000001	71259f74-422e-454d-b684-ebdc3d931942	2026-06-23 17:56:12.652868-05	\N
f0157777-7099-4e22-90a6-7f6d2ceebec3	a1b2c3d4-0001-0000-0000-000000000001	a86a1415-4d28-4bc9-9772-4a57f3ba8030	2026-06-23 17:56:12.652868-05	\N
c624a3bd-f640-4ca5-8af9-724e3ea73b91	a1b2c3d4-0001-0000-0000-000000000001	e79efe13-7b22-4997-86b7-a29e15a078d5	2026-06-23 17:56:12.652868-05	\N
b8c1de4e-c33d-4f39-90db-f7faaae16914	a1b2c3d4-0001-0000-0000-000000000001	d02d9c15-e610-4f32-aae5-c78ae87946a0	2026-06-23 17:56:12.652868-05	\N
b26f4148-ae59-49bd-b12b-9aa61934b04a	a1b2c3d4-0001-0000-0000-000000000001	036d9d91-49a0-4723-802a-c47f1f124fba	2026-06-23 17:56:12.652868-05	\N
0466cce1-2e2c-45fa-bd5d-95c28999b934	a1b2c3d4-0001-0000-0000-000000000001	b5a82b0e-7a44-4007-ba8b-d4fe0bb386fc	2026-06-23 17:56:12.652868-05	\N
0b178dd4-42d4-4b82-8fb5-5b0f720f67c8	a1b2c3d4-0001-0000-0000-000000000002	e4f86d35-893b-45b2-8546-89ae7da9cc09	2026-06-23 17:56:12.652868-05	\N
822d79bb-06e7-4d10-8700-62735fbfc9b9	a1b2c3d4-0001-0000-0000-000000000002	093217c1-db09-4162-a01b-6c9ab178816f	2026-06-23 17:56:12.652868-05	\N
cfb8c3e3-5ad5-4cf8-98b8-74508720cb45	a1b2c3d4-0001-0000-0000-000000000002	12dbccf7-7c0d-4b49-af14-00c358cef2cf	2026-06-23 17:56:12.652868-05	\N
b46ac530-8f61-48e2-8ef5-addec342c720	a1b2c3d4-0001-0000-0000-000000000002	a8aea6e0-ce91-48ff-b176-9e78060ace00	2026-06-23 17:56:12.652868-05	\N
67269489-005d-43cd-991f-1f67bfcc18dc	a1b2c3d4-0001-0000-0000-000000000002	b8b923c4-9eaa-457e-b8a9-a063762dd061	2026-06-23 17:56:12.652868-05	\N
51082a86-6b0e-4fee-a24c-2da6c3fa90b6	a1b2c3d4-0001-0000-0000-000000000002	2b6f812b-aeec-4a98-ac47-ef25d721cfe6	2026-06-23 17:56:12.652868-05	\N
508e17f5-3763-4824-88af-f2ca667aec5d	a1b2c3d4-0001-0000-0000-000000000002	28f8b442-4868-42fd-921e-71498220670d	2026-06-23 17:56:12.652868-05	\N
6878bf77-3009-4762-bac4-82c7a625cb35	a1b2c3d4-0001-0000-0000-000000000002	6f145823-fd67-4782-a890-d43921be4120	2026-06-23 17:56:12.652868-05	\N
b0956fe2-0cbc-4498-993c-4c2cadda115f	a1b2c3d4-0001-0000-0000-000000000002	3f07e425-9f2c-4715-80df-a8a3634b9437	2026-06-23 17:56:12.652868-05	\N
158afa99-6995-4f75-91a5-e27b72b6d41f	a1b2c3d4-0001-0000-0000-000000000002	67a843d8-a286-49c1-b7af-78a155cb5f82	2026-06-23 17:56:12.652868-05	\N
ecb61f2d-df3d-49df-a155-087ed7c13bab	a1b2c3d4-0001-0000-0000-000000000002	5a0dd879-26b8-4705-bc3f-647bdc7dc218	2026-06-23 17:56:12.652868-05	\N
372f5c02-f3a7-4aff-82ea-4793dee1dee6	a1b2c3d4-0001-0000-0000-000000000002	c1fc2a9e-1b7f-42a1-94bc-8355db2fc865	2026-06-23 17:56:12.652868-05	\N
a7b3dcf1-1506-49d6-add2-55cc00d504b3	a1b2c3d4-0001-0000-0000-000000000002	f5bf4f2c-c024-42d7-9f3b-fec37a3df52c	2026-06-23 17:56:12.652868-05	\N
1343887f-fd34-4e6f-b444-3268654abc62	a1b2c3d4-0001-0000-0000-000000000002	3ce2eebe-72f8-41b6-a1f2-a330878d0dea	2026-06-23 17:56:12.652868-05	\N
7d288109-d573-4fb7-aa19-8d1b6694e9ba	a1b2c3d4-0001-0000-0000-000000000002	ef43cc2c-c8ba-4d26-96ee-bd9db4daafc4	2026-06-23 17:56:12.652868-05	\N
14604f68-ba2d-49ba-9db2-019e0a80785d	a1b2c3d4-0001-0000-0000-000000000002	d671c3c2-6dc9-4359-b5e9-2d637a4a3c90	2026-06-23 17:56:12.652868-05	\N
44dde1b0-4a70-4b9c-b5b5-7f6afef0ff91	a1b2c3d4-0001-0000-0000-000000000002	38710114-0bc1-4124-bc9b-a0041253b0a3	2026-06-23 17:56:12.652868-05	\N
f8e61eee-a524-41a5-93d3-b189b9122d01	a1b2c3d4-0001-0000-0000-000000000002	0b12fa15-7b6f-4416-98a7-5c47af781d54	2026-06-23 17:56:12.652868-05	\N
bd67820c-42e1-4c64-90a0-92d5270ee45e	a1b2c3d4-0001-0000-0000-000000000002	eca864ea-922c-4f9f-a778-cd5cf8395978	2026-06-23 17:56:12.652868-05	\N
8011e46e-792a-4295-89e5-b236c3af815c	a1b2c3d4-0001-0000-0000-000000000002	9efe7f3b-994a-457a-982b-f21dfca1fdb0	2026-06-23 17:56:12.652868-05	\N
86388963-ba39-4b1a-acbb-32273eb0b68c	a1b2c3d4-0001-0000-0000-000000000002	9232d42e-3474-43ff-b055-53ee29136f32	2026-06-23 17:56:12.652868-05	\N
cb84308f-2ade-41b6-9619-c48a883b9f84	a1b2c3d4-0001-0000-0000-000000000002	72c2af2f-65d8-4772-b4f8-4d22f72e78b5	2026-06-23 17:56:12.652868-05	\N
7b9249fc-d632-4e01-ba55-c12769bd4ffe	a1b2c3d4-0001-0000-0000-000000000002	1104d8a4-485c-42df-b10a-6da2f4bd77a5	2026-06-23 17:56:12.652868-05	\N
689d60b6-9652-4148-9ccc-ae4978cafa15	a1b2c3d4-0001-0000-0000-000000000002	4bb2ebd2-ef07-4272-82d1-0fc892aa0efc	2026-06-23 17:56:12.652868-05	\N
cab376e3-5961-4bc0-996e-31a2fe64c7a7	a1b2c3d4-0001-0000-0000-000000000002	ca920d3a-e7a0-4427-a77c-33b9d772d043	2026-06-23 17:56:12.652868-05	\N
cb08882b-4e06-456e-8a57-705157e38ee2	a1b2c3d4-0001-0000-0000-000000000002	b80f9fed-dd68-48f1-a723-36c8a303c30b	2026-06-23 17:56:12.652868-05	\N
f43c1e9f-e409-48b1-8c45-ace0b2efdf15	a1b2c3d4-0001-0000-0000-000000000003	e4f86d35-893b-45b2-8546-89ae7da9cc09	2026-06-23 17:56:12.652868-05	\N
11dc30dd-089e-4270-9a5a-e4a84d06faf8	a1b2c3d4-0001-0000-0000-000000000003	093217c1-db09-4162-a01b-6c9ab178816f	2026-06-23 17:56:12.652868-05	\N
1107fd7f-b014-46f3-8ffb-798256cc0e70	a1b2c3d4-0001-0000-0000-000000000003	b8b923c4-9eaa-457e-b8a9-a063762dd061	2026-06-23 17:56:12.652868-05	\N
723be752-c139-4bfb-a816-9c79c895b942	a1b2c3d4-0001-0000-0000-000000000003	28f8b442-4868-42fd-921e-71498220670d	2026-06-23 17:56:12.652868-05	\N
c59fd5b9-2575-4afb-ae2f-d89eb954d8ea	a1b2c3d4-0001-0000-0000-000000000003	3f07e425-9f2c-4715-80df-a8a3634b9437	2026-06-23 17:56:12.652868-05	\N
463b7b2f-fc6a-4b66-b73b-90d154681fd9	a1b2c3d4-0001-0000-0000-000000000003	38710114-0bc1-4124-bc9b-a0041253b0a3	2026-06-23 17:56:12.652868-05	\N
244e7ad6-91d9-4061-8251-32f336eee15e	a1b2c3d4-0001-0000-0000-000000000003	ca920d3a-e7a0-4427-a77c-33b9d772d043	2026-06-23 17:56:12.652868-05	\N
\.


--
-- Data for Name: session; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.session (id_session, id_user, token, refresh_token, ip_address, user_agent, recordar_sesion, expira_en, activa, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: token_blacklist; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.token_blacklist (id_token_blacklist, token, id_user, motivo, created_at, expira_en) FROM stdin;
\.


--
-- Data for Name: user; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth."user" (id_user, nombre, apellido, username, email, password_hash, tipo_documento, numero_documento, estado, email_verificado, intentos_fallidos, bloqueado_hasta, mfa_habilitado, created_at, updated_at, deleted_at) FROM stdin;
a1b2c3d4-9999-0000-0000-000000000001	Administrador	Sistema	admin_smarthome	admin@smarthome.com	$2a$12$mlisTJJN0erzxgV9GVvgb.ATpCgNYjFf6y.Vf0RQ8qw0gAZTZjg5.	CC	0000000001	activo	t	0	\N	f	2026-06-23 17:56:12.791453-05	2026-06-23 17:56:12.791453-05	\N
b1000000-0000-0000-0000-000000000001	Karen Daniela	Holgu├¡n Cruz	karen_holguin	karen@smarthome.com	$2a$12$EKwJj/YotznhP81PKs.92eboUjI1kGLccQvkJHIBLFS3lJX5c6fLy	CC	1001000001	activo	t	0	\N	f	2026-06-23 17:56:45.546819-05	2026-06-23 17:56:45.546819-05	\N
b1000000-0000-0000-0000-000000000002	Kevin Stiven	L├│pez Amaya	kevin_lopez	kevin@smarthome.com	$2a$12$uTfDuhugq/rV0UGN1ON3dOjcBY0r9unOKWHfIQktO0jeWGgNhqVhO	CC	1001000002	activo	t	0	\N	f	2026-06-23 17:56:45.546819-05	2026-06-23 17:56:45.546819-05	\N
b1000000-0000-0000-0000-000000000003	Natalia	Chala Chala	natalia_chala	natalia@smarthome.com	$2a$12$4tti573sO5PH3q3YQRF7mu4engfvXK/tGb/jfHbSfGdZ79nfk7SrC	CC	1001000003	activo	t	0	\N	f	2026-06-23 17:56:45.546819-05	2026-06-23 17:56:45.546819-05	\N
\.


--
-- Data for Name: user_role; Type: TABLE DATA; Schema: auth; Owner: -
--

COPY auth.user_role (id_user_role, id_user, id_role, asignado_por, created_at, deleted_at) FROM stdin;
303c13fc-6712-4f94-be52-d1f3cccc4893	a1b2c3d4-9999-0000-0000-000000000001	a1b2c3d4-0001-0000-0000-000000000001	\N	2026-06-23 17:56:12.791453-05	\N
251a6b42-cd17-40b5-a3e9-bc9955e8c8a9	b1000000-0000-0000-0000-000000000001	a1b2c3d4-0001-0000-0000-000000000002	\N	2026-06-23 17:56:45.546819-05	\N
22be4921-93c9-45c8-bd51-1cb680b65a17	b1000000-0000-0000-0000-000000000002	a1b2c3d4-0001-0000-0000-000000000002	\N	2026-06-23 17:56:45.546819-05	\N
96fa5ce8-b27f-4e16-9d4c-967e7e8a4d06	b1000000-0000-0000-0000-000000000003	a1b2c3d4-0001-0000-0000-000000000003	\N	2026-06-23 17:56:45.546819-05	\N
\.


--
-- Data for Name: configuration_user; Type: TABLE DATA; Schema: config; Owner: -
--

COPY config.configuration_user (id_configuration_user, id_user, idioma, tema, formato_fecha, formato_hora, moneda, unidad_temperatura, notif_consumo_elevado, notif_dispositivos, notif_recomendaciones, notif_seguridad, notif_canal_app, notif_canal_email, notif_canal_push, no_molestar_inicio, no_molestar_fin, recomendaciones_activas, frecuencia_recomendaciones, created_at, updated_at) FROM stdin;
a6bc6331-8930-4a47-b071-faabd5a63f6c	a1b2c3d4-9999-0000-0000-000000000001	es	claro	DD/MM/YYYY	24h	COP	C	t	t	t	t	t	t	t	\N	\N	t	semanal	2026-06-23 17:56:12.791453-05	2026-06-23 17:56:12.791453-05
d5d787f8-8a78-4943-8835-9966a089b8a3	b1000000-0000-0000-0000-000000000001	es	claro	DD/MM/YYYY	24h	COP	C	t	t	t	t	t	t	t	\N	\N	t	semanal	2026-06-23 17:56:45.546819-05	2026-06-23 17:56:46.520752-05
41ecb949-8320-466e-9763-0b7399bdc0e7	b1000000-0000-0000-0000-000000000002	es	oscuro	DD/MM/YYYY	24h	COP	C	t	t	f	t	t	f	t	22:00:00	06:00:00	f	mensual	2026-06-23 17:56:45.546819-05	2026-06-23 17:56:46.520752-05
3159349e-4c75-4641-a66b-46a53bb569ce	b1000000-0000-0000-0000-000000000003	en	automatico	MM/DD/YYYY	12h	COP	F	f	f	f	t	t	t	f	\N	\N	f	semanal	2026-06-23 17:56:45.546819-05	2026-06-23 17:56:46.520752-05
\.


--
-- Data for Name: consumption; Type: TABLE DATA; Schema: consumption; Owner: -
--

COPY consumption.consumption (id_consumption, id_device, id_home, watts, kwh_acumulado, costo_estimado, fecha_lectura) FROM stdin;
159bfd9b-974b-40dc-8d9f-ca0fe396dc2d	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.3900	0.075000	63.7500	2026-06-16 17:56:46.393651-05
04556e34-750e-4c83-abb8-f4745e86afc6	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	115.5700	0.720000	612.0000	2026-06-16 17:56:46.393651-05
5c594398-86f3-417e-b461-f67380745a31	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	144.6500	0.900000	765.0000	2026-06-16 17:56:46.393651-05
adbdfb3a-d270-4aca-98cd-f0efbef4b5ce	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1467.8700	8.400000	7140.0000	2026-06-16 17:56:46.393651-05
bb4ad9d7-8fb6-40cd-a531-c9333ed8ab68	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.2000	0.075000	69.0000	2026-06-16 17:56:46.393651-05
81af01ab-768d-4678-9f76-dfcee7b83bd7	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	194.6800	1.200000	1104.0000	2026-06-16 17:56:46.393651-05
0090b3a7-152d-45ee-b8e2-e6d66ad3afe1	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.1700	0.075000	63.7500	2026-06-16 23:56:46.393651-05
0ae8fed3-9de2-4c7c-b86b-524dc80ce709	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	121.2800	0.720000	612.0000	2026-06-16 23:56:46.393651-05
551bafd7-c58d-4093-874c-bf203681af99	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	147.5200	0.900000	765.0000	2026-06-16 23:56:46.393651-05
e12c5402-75f3-455a-913c-c7c3fd6e9cfa	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1419.7000	8.400000	7140.0000	2026-06-16 23:56:46.393651-05
e99106e8-e4fe-4050-b12e-9d11ca77a228	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	11.6800	0.075000	69.0000	2026-06-16 23:56:46.393651-05
299274e4-cb77-47a7-9b1c-886d5649572c	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	185.7100	1.200000	1104.0000	2026-06-16 23:56:46.393651-05
acce612d-a0aa-48b8-be83-8118d1a87a03	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.7100	0.075000	63.7500	2026-06-17 05:56:46.393651-05
7a62de76-e0a7-4b37-bf2f-4bb0fc0459e4	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	123.6800	0.720000	612.0000	2026-06-17 05:56:46.393651-05
5c162e21-842b-4b99-8607-48b94bf5f719	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	143.4800	0.900000	765.0000	2026-06-17 05:56:46.393651-05
fff34a7c-a9cc-477e-82dc-0a160483558f	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1418.0400	8.400000	7140.0000	2026-06-17 05:56:46.393651-05
9b95746a-f090-42c2-9f29-ba82e4565954	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.5100	0.075000	69.0000	2026-06-17 05:56:46.393651-05
3270bf7d-7412-413e-b582-eba672e62589	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	185.7100	1.200000	1104.0000	2026-06-17 05:56:46.393651-05
bd76ac9e-0bfc-4b2c-a16d-6a3ec8fbd379	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.3300	0.075000	63.7500	2026-06-17 11:56:46.393651-05
81ee67aa-3d22-4a4f-9327-6c7f3f0a3b2f	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	116.7600	0.720000	612.0000	2026-06-17 11:56:46.393651-05
f1139ad4-fb26-4c1b-9b2d-7070de766941	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	159.9100	0.900000	765.0000	2026-06-17 11:56:46.393651-05
598bdfa9-72f6-4b2f-9484-3f9626ed80f2	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1335.9200	8.400000	7140.0000	2026-06-17 11:56:46.393651-05
3e0d0b74-21ba-47e8-81e7-89e03c6dc3a1	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	13.1600	0.075000	69.0000	2026-06-17 11:56:46.393651-05
7b94ca87-9db7-4e57-967c-3b61a3650130	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	191.2200	1.200000	1104.0000	2026-06-17 11:56:46.393651-05
04e40965-ed80-4596-9359-9a83adb165a6	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.3300	0.075000	63.7500	2026-06-17 17:56:46.393651-05
177de529-a7a4-49c3-8961-d451d486c274	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	117.6500	0.720000	612.0000	2026-06-17 17:56:46.393651-05
34faebee-3d87-4905-b3ea-2de8df6f6bd4	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	158.5100	0.900000	765.0000	2026-06-17 17:56:46.393651-05
66216d5b-4bc6-4673-9370-cbc6d8c5f8ee	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1440.4100	8.400000	7140.0000	2026-06-17 17:56:46.393651-05
49e7d5f1-dcab-428a-899b-7e1ef6451fe8	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.2000	0.075000	69.0000	2026-06-17 17:56:46.393651-05
5b552180-90d3-494b-b92e-0097f4586e88	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	196.3700	1.200000	1104.0000	2026-06-17 17:56:46.393651-05
98344739-1d21-46d9-bd60-550e3b247089	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.5600	0.075000	63.7500	2026-06-17 23:56:46.393651-05
629ef995-1d47-472e-a838-0ebad853992b	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	122.4600	0.720000	612.0000	2026-06-17 23:56:46.393651-05
b87b4012-4a53-4cf0-b457-aa612ff7770d	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	145.8800	0.900000	765.0000	2026-06-17 23:56:46.393651-05
f7326672-0382-485d-a5d7-b7143bcd9410	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1486.6900	8.400000	7140.0000	2026-06-17 23:56:46.393651-05
afa21b66-0d81-4e64-b9d4-1c8c5543b21c	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	11.8300	0.075000	69.0000	2026-06-17 23:56:46.393651-05
d874d1e0-dce1-4ee3-a6fd-2337dfdfcc90	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	197.1800	1.200000	1104.0000	2026-06-17 23:56:46.393651-05
072cce60-2ae4-4350-8079-8a18d1d12d1e	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.3700	0.075000	63.7500	2026-06-18 05:56:46.393651-05
57700813-c414-422a-b9e8-94a09f3d47b4	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	125.7000	0.720000	612.0000	2026-06-18 05:56:46.393651-05
8e81f3b4-a421-43d8-a296-3b5c2d22c78e	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	140.0000	0.900000	765.0000	2026-06-18 05:56:46.393651-05
5dfe263d-45a8-45de-b9cd-604bac2522b9	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1469.2300	8.400000	7140.0000	2026-06-18 05:56:46.393651-05
72a7ce88-69fd-46be-b44c-3566e303302f	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	13.1700	0.075000	69.0000	2026-06-18 05:56:46.393651-05
44ad1a84-387e-4504-85db-e656c267d4ee	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	214.1100	1.200000	1104.0000	2026-06-18 05:56:46.393651-05
a8c537de-7e9d-4325-b8ba-8ca558015f3f	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.6900	0.075000	63.7500	2026-06-18 11:56:46.393651-05
7d14a79d-db83-410c-abec-b15e98985c54	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	122.1900	0.720000	612.0000	2026-06-18 11:56:46.393651-05
ac697e75-dc91-4920-aba7-adc021358664	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	159.5200	0.900000	765.0000	2026-06-18 11:56:46.393651-05
1ddcb668-00bc-49f0-a6a9-639bfe542104	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1493.7100	8.400000	7140.0000	2026-06-18 11:56:46.393651-05
ba2505bb-5101-4607-8a52-82632976db59	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.7800	0.075000	69.0000	2026-06-18 11:56:46.393651-05
f7d344d9-db21-4358-a104-a9412a0bb215	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	190.9100	1.200000	1104.0000	2026-06-18 11:56:46.393651-05
3cec6757-96cd-4f85-bf9f-58f169feac5b	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.9800	0.075000	63.7500	2026-06-18 17:56:46.393651-05
94a3792e-3fb9-4f52-a166-0e1b6f535d39	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	116.9500	0.720000	612.0000	2026-06-18 17:56:46.393651-05
ff8a5f5c-dd42-4a4c-b72b-46e11388a93e	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	158.5200	0.900000	765.0000	2026-06-18 17:56:46.393651-05
c8078ad9-7711-4764-aff5-fd74d2e634c4	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1447.5800	8.400000	7140.0000	2026-06-18 17:56:46.393651-05
ee155724-2c7a-42cb-adb2-d3e846d687f6	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.6800	0.075000	69.0000	2026-06-18 17:56:46.393651-05
61c99a55-8d8d-47e2-bb70-6f36d409287a	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	199.2000	1.200000	1104.0000	2026-06-18 17:56:46.393651-05
72e55ac6-423d-4524-8104-874af894233f	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.0600	0.075000	63.7500	2026-06-18 23:56:46.393651-05
155d8ee8-4f39-40ac-b216-511e12a1f5bf	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	114.3200	0.720000	612.0000	2026-06-18 23:56:46.393651-05
7e79ee45-c788-4136-bbd6-daee1fea8d72	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	153.4200	0.900000	765.0000	2026-06-18 23:56:46.393651-05
16633afc-02e9-41db-a80d-c28bcf3555e4	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1300.1500	8.400000	7140.0000	2026-06-18 23:56:46.393651-05
e1b0c942-474e-4c41-b447-b5a5bbcf2a6e	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	13.0900	0.075000	69.0000	2026-06-18 23:56:46.393651-05
c2512904-7e53-478c-a2eb-952b5e8f09c0	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	196.0500	1.200000	1104.0000	2026-06-18 23:56:46.393651-05
048a9281-30f0-485a-ae74-2929693d7b35	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.9300	0.075000	63.7500	2026-06-19 05:56:46.393651-05
e1933025-01da-4547-ab91-1b38b1ae8493	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	125.7000	0.720000	612.0000	2026-06-19 05:56:46.393651-05
1c16ab6b-7408-4461-b3c7-3d8cac6667a1	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	157.1900	0.900000	765.0000	2026-06-19 05:56:46.393651-05
0086afa1-a9e0-4460-97b8-cde7954db332	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1330.3100	8.400000	7140.0000	2026-06-19 05:56:46.393651-05
22b07fbf-dfd4-40fa-8e12-f19762f83765	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.3600	0.075000	69.0000	2026-06-19 05:56:46.393651-05
5bba698f-926d-44f3-8878-ee9622f73307	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	192.2900	1.200000	1104.0000	2026-06-19 05:56:46.393651-05
5ba8d854-335d-4417-9b6c-9b5e0d3195ba	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.6600	0.075000	63.7500	2026-06-19 11:56:46.393651-05
cf175e63-2524-4f3d-874c-71ab663d0847	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	120.8300	0.720000	612.0000	2026-06-19 11:56:46.393651-05
489b1137-0d7a-45d6-8442-9c0133b7bf36	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	158.2100	0.900000	765.0000	2026-06-19 11:56:46.393651-05
1a838ad2-f695-4580-9364-d9c11fd78fee	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1448.6900	8.400000	7140.0000	2026-06-19 11:56:46.393651-05
2af16bc2-1169-469c-a0b2-ae190785ab12	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.2000	0.075000	69.0000	2026-06-19 11:56:46.393651-05
955e712f-3edc-491b-9274-6e432daf43db	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	192.9700	1.200000	1104.0000	2026-06-19 11:56:46.393651-05
fe7fb3e5-013a-4786-8d2f-828dac398147	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.3600	0.075000	63.7500	2026-06-19 17:56:46.393651-05
e4250252-4461-4b49-a789-842e4f82f497	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	123.0900	0.720000	612.0000	2026-06-19 17:56:46.393651-05
f2e6f257-8aeb-4d5e-950a-a594f8f0ddf1	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	157.3300	0.900000	765.0000	2026-06-19 17:56:46.393651-05
7e9433f9-b109-4a4e-b130-eb330589ef38	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1436.3100	8.400000	7140.0000	2026-06-19 17:56:46.393651-05
11ac39f7-36b2-4e34-9edb-9ed677988ae8	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	11.9900	0.075000	69.0000	2026-06-19 17:56:46.393651-05
387ac754-3b5c-497f-9537-d951e2fef3ce	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	195.0800	1.200000	1104.0000	2026-06-19 17:56:46.393651-05
d3c8efe9-3040-4fa0-8788-561128f0c872	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.6800	0.075000	63.7500	2026-06-19 23:56:46.393651-05
8211eae6-094a-47f7-ba34-2240f6fd3d3c	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	116.9900	0.720000	612.0000	2026-06-19 23:56:46.393651-05
83cb4771-7853-4141-bcd0-4c903adb32fe	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	143.9000	0.900000	765.0000	2026-06-19 23:56:46.393651-05
ea52a2de-8315-4d6a-8a98-4d3a1fa0d22b	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1486.6200	8.400000	7140.0000	2026-06-19 23:56:46.393651-05
56cdf5c5-0c81-4de9-b6d2-b49d4f356ecb	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	11.5800	0.075000	69.0000	2026-06-19 23:56:46.393651-05
d06663d6-b0e2-4ff1-b1f9-7399fcc9ab7a	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	192.5500	1.200000	1104.0000	2026-06-19 23:56:46.393651-05
bbf9c157-1836-484a-a905-3d10dfb2758e	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.4000	0.075000	63.7500	2026-06-20 05:56:46.393651-05
4ac6a23d-b3e1-40ef-a3bc-07ba15c41609	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	116.2500	0.720000	612.0000	2026-06-20 05:56:46.393651-05
5c04589d-a641-4f17-bc43-f70f32ae84f5	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	159.7400	0.900000	765.0000	2026-06-20 05:56:46.393651-05
ce2fa0c7-5508-4d55-85a6-90fcc1376781	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1428.2400	8.400000	7140.0000	2026-06-20 05:56:46.393651-05
8c9d0395-69ce-4483-b90a-f9fb6063d0ba	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.1600	0.075000	69.0000	2026-06-20 05:56:46.393651-05
4f72c135-a082-40ae-8dfd-9e1f5a682919	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	203.5300	1.200000	1104.0000	2026-06-20 05:56:46.393651-05
217d1101-1834-4935-bd5f-8adc364a7dfd	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.7600	0.075000	63.7500	2026-06-20 11:56:46.393651-05
e7804f44-fa60-4097-8ca7-bee7390bba64	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	115.6600	0.720000	612.0000	2026-06-20 11:56:46.393651-05
5fc9854d-90f1-4f47-80a1-14016c724151	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	159.6900	0.900000	765.0000	2026-06-20 11:56:46.393651-05
9fb5a9f8-e152-4e5a-964b-43db8c8afdab	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1331.1900	8.400000	7140.0000	2026-06-20 11:56:46.393651-05
9950a110-6a92-457c-a199-fe982a986741	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.9700	0.075000	69.0000	2026-06-20 11:56:46.393651-05
bc277ca2-0798-4a11-a7fb-ab5f48bf3b03	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	193.0700	1.200000	1104.0000	2026-06-20 11:56:46.393651-05
4c569602-8708-40b6-bbac-92e38af3f4a7	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.2200	0.075000	63.7500	2026-06-20 17:56:46.393651-05
5f28b3c1-2a98-4d4f-b9d9-031f05ce4c60	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	122.1400	0.720000	612.0000	2026-06-20 17:56:46.393651-05
47a9102f-b966-4177-a3b7-3783039d1ad7	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	141.7400	0.900000	765.0000	2026-06-20 17:56:46.393651-05
15864d88-5a91-420f-9417-d47f1d49d2c1	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1322.9900	8.400000	7140.0000	2026-06-20 17:56:46.393651-05
09ad1b4a-f793-470c-bde5-3ae21465c81b	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.9500	0.075000	69.0000	2026-06-20 17:56:46.393651-05
e67f2703-59b6-4755-8695-e8cd5eea68c8	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	195.2500	1.200000	1104.0000	2026-06-20 17:56:46.393651-05
bd777a47-5d89-489d-8d70-180d6d9125ff	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.8600	0.075000	63.7500	2026-06-20 23:56:46.393651-05
5b397744-33a2-4982-9a61-983996102956	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	118.2800	0.720000	612.0000	2026-06-20 23:56:46.393651-05
6f89b467-d8e5-4516-8e66-0a2d7eab6273	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	156.9600	0.900000	765.0000	2026-06-20 23:56:46.393651-05
b73b47f9-2658-4565-8f91-9bce9b26c318	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1424.4700	8.400000	7140.0000	2026-06-20 23:56:46.393651-05
968ea867-5974-4b55-b3df-2d25403ce1da	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	13.1200	0.075000	69.0000	2026-06-20 23:56:46.393651-05
9840168b-4815-438e-9ae7-1cd3735a1f53	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	200.6800	1.200000	1104.0000	2026-06-20 23:56:46.393651-05
d47e1ba6-ee0e-49e6-adb9-3e95e91f2d99	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.5200	0.075000	63.7500	2026-06-21 05:56:46.393651-05
556b968f-ac29-42db-afa3-c417c2f4dfa0	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	126.5700	0.720000	612.0000	2026-06-21 05:56:46.393651-05
cae53ad2-5eaa-43be-a90e-2a6802cf0dd9	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	151.4600	0.900000	765.0000	2026-06-21 05:56:46.393651-05
e77e24f7-132a-431b-9c04-399185613d35	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1354.8400	8.400000	7140.0000	2026-06-21 05:56:46.393651-05
a958ea03-a29c-4911-bee4-778427ce8aa4	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.6800	0.075000	69.0000	2026-06-21 05:56:46.393651-05
7d9dfb2a-6780-44fb-91fa-6c27eb7b9b67	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	200.0300	1.200000	1104.0000	2026-06-21 05:56:46.393651-05
baac544a-b02c-437c-9755-99cc2be45565	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.7500	0.075000	63.7500	2026-06-21 11:56:46.393651-05
b4b57f87-f54f-4de6-810d-a651b5f05df1	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	118.6700	0.720000	612.0000	2026-06-21 11:56:46.393651-05
1d6a9199-1793-45a5-a085-658a5bbfe69b	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	145.3600	0.900000	765.0000	2026-06-21 11:56:46.393651-05
d6a658f9-fec7-4f1c-9529-8a3d0df2d7d0	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1405.1000	8.400000	7140.0000	2026-06-21 11:56:46.393651-05
11234022-dcff-419f-acf7-2b5899626af8	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.4300	0.075000	69.0000	2026-06-21 11:56:46.393651-05
559fce15-199d-4ab3-b2b4-b1c8f9d218cd	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	193.2300	1.200000	1104.0000	2026-06-21 11:56:46.393651-05
62025888-e14a-4044-a10d-a14a9e270ef8	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.8400	0.075000	63.7500	2026-06-21 17:56:46.393651-05
b751e5e7-7ec3-4324-a63f-02ec9466d798	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	111.9000	0.720000	612.0000	2026-06-21 17:56:46.393651-05
35063e37-35c9-4b3a-b508-a373eee6ab73	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	161.0700	0.900000	765.0000	2026-06-21 17:56:46.393651-05
34a93e4d-2fe5-452a-9593-598ea4aaa65d	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1476.9300	8.400000	7140.0000	2026-06-21 17:56:46.393651-05
2aacef48-1bdf-4875-a399-fc1cae531b57	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.8400	0.075000	69.0000	2026-06-21 17:56:46.393651-05
9ce83c17-7c9a-45ab-9cc3-789fbb06b19e	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	196.7500	1.200000	1104.0000	2026-06-21 17:56:46.393651-05
acf3f175-347e-4ded-920e-5c53a945aed5	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.4200	0.075000	63.7500	2026-06-21 23:56:46.393651-05
cfb6e5ce-d915-4b45-b258-6a935053d172	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	127.2100	0.720000	612.0000	2026-06-21 23:56:46.393651-05
d78e52cd-f8e4-4b22-a233-514e89357e88	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	153.6700	0.900000	765.0000	2026-06-21 23:56:46.393651-05
631bbf25-f3aa-464b-a4ad-90713c79bef7	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1448.4400	8.400000	7140.0000	2026-06-21 23:56:46.393651-05
2f18f8dd-ca24-444e-855a-4df94c806418	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.8700	0.075000	69.0000	2026-06-21 23:56:46.393651-05
bb1040d8-d88a-4120-8a2b-2a0feba8872a	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	196.7700	1.200000	1104.0000	2026-06-21 23:56:46.393651-05
fe3fea96-74b7-48d3-99f7-3bc78c441788	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.0700	0.075000	63.7500	2026-06-22 05:56:46.393651-05
f8f651c5-9f71-43f6-aaf4-a2bd22a9969c	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	116.3300	0.720000	612.0000	2026-06-22 05:56:46.393651-05
a48a4f4a-b537-4097-96e0-6c1961e57b7a	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	150.9900	0.900000	765.0000	2026-06-22 05:56:46.393651-05
485cf0c6-d541-48d4-96a7-ff5e8370131f	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1448.8100	8.400000	7140.0000	2026-06-22 05:56:46.393651-05
31c8d8fc-071a-42fb-9486-4d99b345e94c	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	11.7400	0.075000	69.0000	2026-06-22 05:56:46.393651-05
e8654253-6fc6-4865-9808-bf4ee6e02ee1	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	206.0900	1.200000	1104.0000	2026-06-22 05:56:46.393651-05
608fb9fa-09f8-4820-bfee-6199167bbf5c	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.0300	0.075000	63.7500	2026-06-22 11:56:46.393651-05
47e94607-9db4-494a-8e94-315e060c4fed	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	117.7800	0.720000	612.0000	2026-06-22 11:56:46.393651-05
4260e9e7-b510-4de3-86a0-e19c54b95071	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	146.0100	0.900000	765.0000	2026-06-22 11:56:46.393651-05
11820aa6-2cb8-4844-a8a5-74979cd9de6b	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1483.0600	8.400000	7140.0000	2026-06-22 11:56:46.393651-05
6693e387-ba3f-42b8-83e5-2d1b6d1dca69	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.1700	0.075000	69.0000	2026-06-22 11:56:46.393651-05
8e558c65-82ad-4cd4-b519-9f2f03df4963	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	214.7100	1.200000	1104.0000	2026-06-22 11:56:46.393651-05
0004fb30-2237-4c50-b115-ae925281a5b0	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	11.6500	0.075000	63.7500	2026-06-22 17:56:46.393651-05
992f116b-01aa-44d0-a94a-7e9988a55fb2	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	113.0200	0.720000	612.0000	2026-06-22 17:56:46.393651-05
bc857736-3c57-4671-8832-fd6817f1a717	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	143.9300	0.900000	765.0000	2026-06-22 17:56:46.393651-05
6e3d308e-153d-4dc2-9569-fc8b6c03ac1d	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1434.1700	8.400000	7140.0000	2026-06-22 17:56:46.393651-05
0f4f806b-ffc6-430e-8737-2064478cc6b4	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.8800	0.075000	69.0000	2026-06-22 17:56:46.393651-05
1bcbc4af-2e33-47bb-a807-fcaec5174051	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	204.1300	1.200000	1104.0000	2026-06-22 17:56:46.393651-05
de1ef8b8-8586-4885-8b21-9bb37a6a2871	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.5700	0.075000	63.7500	2026-06-22 23:56:46.393651-05
8ac01c8a-2a5b-43e5-8858-74dea8cbccb7	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	122.9800	0.720000	612.0000	2026-06-22 23:56:46.393651-05
dad2bb0c-50b0-4b37-ab07-ac9cfd3e3831	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	140.6900	0.900000	765.0000	2026-06-22 23:56:46.393651-05
9ed2c86d-7e12-4cb3-b835-a95a5d4c2f90	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1496.2200	8.400000	7140.0000	2026-06-22 23:56:46.393651-05
130fd584-6c54-483c-aebd-f4f076bde1f2	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	13.3200	0.075000	69.0000	2026-06-22 23:56:46.393651-05
80b54c7c-9cb5-46e6-ab4e-2b9878f198a0	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	204.5000	1.200000	1104.0000	2026-06-22 23:56:46.393651-05
ddaa7f0d-c3ad-4ffe-955d-a7d96a4236b9	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.6600	0.075000	63.7500	2026-06-23 05:56:46.393651-05
c3b47754-0891-48c4-82f7-b6acdf923ac5	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	124.7000	0.720000	612.0000	2026-06-23 05:56:46.393651-05
debf2a78-bec0-490f-a1a8-77374eba0c43	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	138.7900	0.900000	765.0000	2026-06-23 05:56:46.393651-05
978bd608-87f9-4bb3-b3e9-8bee45783232	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1349.0000	8.400000	7140.0000	2026-06-23 05:56:46.393651-05
17754851-d5b2-4ad7-a7f2-a22d58acc00c	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	11.7600	0.075000	69.0000	2026-06-23 05:56:46.393651-05
39587d18-687f-4e04-acb2-0ffd97006aac	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	205.2600	1.200000	1104.0000	2026-06-23 05:56:46.393651-05
3786a231-9c3f-4f7c-b0ce-ec871f328abe	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.1900	0.075000	63.7500	2026-06-23 11:56:46.393651-05
ecbdce30-d13d-4ece-8a33-eb1c913f94ca	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	117.0300	0.720000	612.0000	2026-06-23 11:56:46.393651-05
cc538699-9bb6-4f69-bf69-9a9bec058175	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	153.7500	0.900000	765.0000	2026-06-23 11:56:46.393651-05
1b71421b-336e-4014-97a5-56ad808fa746	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1383.8900	8.400000	7140.0000	2026-06-23 11:56:46.393651-05
152942f8-79c1-498f-b3c2-c4be3f60f824	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	13.3900	0.075000	69.0000	2026-06-23 11:56:46.393651-05
80c5b5c9-158b-44f4-ace8-81c62f9d04f3	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	200.0200	1.200000	1104.0000	2026-06-23 11:56:46.393651-05
8965b18c-bb03-4c44-8968-9553047a804e	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	13.3200	0.075000	63.7500	2026-06-23 17:56:46.393651-05
c9e08996-b3e5-4f29-b5fa-3705b3ecaa66	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	111.8100	0.720000	612.0000	2026-06-23 17:56:46.393651-05
7b6556f7-3d14-4498-b499-16f7e5ebac0a	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	156.4500	0.900000	765.0000	2026-06-23 17:56:46.393651-05
2bc00f12-7852-4864-8eff-92788d92a265	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	1363.8300	8.400000	7140.0000	2026-06-23 17:56:46.393651-05
fc557027-0010-4244-88d8-b98a676d72a6	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.1900	0.075000	69.0000	2026-06-23 17:56:46.393651-05
133c8a7c-07c7-498c-8057-70fc65e9dcf9	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	189.8700	1.200000	1104.0000	2026-06-23 17:56:46.393651-05
254749b7-4c43-4e71-be1c-f84d92548c87	e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	12.5000	0.075000	0.0638	2026-06-23 17:56:46.393651-05
139b6033-5e5f-458e-939a-858f12be7737	e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	118.3000	0.710000	0.6034	2026-06-23 17:56:46.393651-05
8a7225e8-602c-4a4a-b55f-4b99b09c3f13	e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	148.9000	0.893000	0.7592	2026-06-23 17:56:46.393651-05
756752b7-c77a-41b3-bad4-91e3248695b1	e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	12.4000	0.074000	0.0681	2026-06-23 17:56:46.393651-05
994a81da-d6a5-40a9-a15a-aa9e88297840	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	205.6000	1.234000	1.1349	2026-06-23 17:56:46.393651-05
\.


--
-- Data for Name: consumption_metric; Type: TABLE DATA; Schema: consumption; Owner: -
--

COPY consumption.consumption_metric (id_consumption_metric, id_device, id_home, periodo, fecha_inicio, fecha_fin, kwh_total, costo_total, watts_promedio, watts_maximo, watts_minimo, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: recommendation; Type: TABLE DATA; Schema: consumption; Owner: -
--

COPY consumption.recommendation (id_recommendation, id_home, id_device, titulo, descripcion, ahorro_estimado_kwh, ahorro_estimado_costo, prioridad, estado, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: device; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.device (id_device, id_home, id_area, id_type_device, nombre, estado, encendido, consumo_actual_w, mac_address, protocolo, created_at, updated_at, deleted_at) FROM stdin;
e1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	d1000000-0000-0000-0000-000000000001	e2aae9c3-dfec-49f9-b4c0-374b35ef840a	L├ímpara Sala	conectado	t	12.50	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	d1000000-0000-0000-0000-000000000001	796b8fcc-229c-4d53-829e-32ccc0ee92fe	Televisor Sala	conectado	t	120.00	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	d1000000-0000-0000-0000-000000000002	a61035f5-c06e-4c23-b7ff-7a5499a06ef5	Nevera Cocina	conectado	t	150.00	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000004	c1000000-0000-0000-0000-000000000001	d1000000-0000-0000-0000-000000000002	5f2b256d-a6c8-48db-8fcc-793c644ef92e	Microondas Cocina	conectado	f	0.00	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	d1000000-0000-0000-0000-000000000003	88605aba-87aa-4785-ad0f-38a294702c4d	Aire Dormitorio	conectado	f	0.00	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	d1000000-0000-0000-0000-000000000005	e2aae9c3-dfec-49f9-b4c0-374b35ef840a	L├ímpara Sala	conectado	t	12.50	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	d1000000-0000-0000-0000-000000000006	bc476a0c-a629-46ef-852b-630804d37020	Computador Habitaci├│n	conectado	t	200.00	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
e1000000-0000-0000-0000-000000000008	c1000000-0000-0000-0000-000000000002	d1000000-0000-0000-0000-000000000007	0f27c00e-7895-42e2-87b1-d15af3aa277c	Lavadora	conectado	f	0.00	\N	wifi	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
\.


--
-- Data for Name: device_status_history; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.device_status_history (id_device_status_history, id_device, estado_anterior, estado_nuevo, encendido, origen, id_user, created_at) FROM stdin;
\.


--
-- Data for Name: manual_device; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.manual_device (id_manual_device, id_device, consumo_estimado_w, horas_uso_diario, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: schedule; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.schedule (id_schedule, id_device, accion, hora, dias_semana, activo, created_at, updated_at, deleted_at) FROM stdin;
c685591d-be91-45ea-8a46-d07a66acbfff	e1000000-0000-0000-0000-000000000001	encender	18:00:00	{1,2,3,4,5}	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
fc216db2-e264-4d96-96b7-c6951e21d42e	e1000000-0000-0000-0000-000000000001	apagar	23:00:00	{1,2,3,4,5,6,7}	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
10d2806e-37e2-4a7f-970f-d7e44ed86a2f	e1000000-0000-0000-0000-000000000005	encender	21:00:00	{1,2,3,4,5}	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
83f2c693-4e7b-4821-bd31-9ef30176edad	e1000000-0000-0000-0000-000000000005	apagar	06:00:00	{1,2,3,4,5,6,7}	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
\.


--
-- Data for Name: smart_device; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.smart_device (id_smart_device, id_device, firmware_version, modelo, fabricante, capacidad_maxima_w, created_at, updated_at) FROM stdin;
3aedd2f5-ea78-4f8e-af19-7bf73f4768a7	e1000000-0000-0000-0000-000000000001	\N	SmartBulb A19	Philips	15.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
1420e8c2-50bd-4bea-b673-a13c3f00b31c	e1000000-0000-0000-0000-000000000002	\N	SmartTV 55"	Samsung	200.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
9125cc7d-2c37-4fb8-8cca-03d8272b4724	e1000000-0000-0000-0000-000000000003	\N	RF28R7200SR	Samsung	350.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
79980e43-f21a-423c-a51c-854bffefe2d0	e1000000-0000-0000-0000-000000000004	\N	MS23K3515AK	Samsung	1200.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
a054b8a7-0f78-41e3-abff-ef76cfd1db69	e1000000-0000-0000-0000-000000000005	\N	AS09A6RF	Samsung	1500.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
0ee24013-f07a-4eb8-ad68-769e289b0de2	e1000000-0000-0000-0000-000000000006	\N	SmartBulb A19	Philips	15.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
1e771e13-ce3d-458e-9d7f-cd8ca974be94	e1000000-0000-0000-0000-000000000007	\N	Inspiron 15	Dell	250.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
70d88462-a6fc-4fe4-b5c3-6ba03efc4904	e1000000-0000-0000-0000-000000000008	\N	WF45R6100AW	Samsung	500.00	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05
\.


--
-- Data for Name: threshold_rule; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.threshold_rule (id_threshold_rule, id_device, tipo, limite_kwh, accion, activa, created_at, updated_at, deleted_at) FROM stdin;
2de2b00a-c5a3-43cd-acd3-2ec6d8396773	e1000000-0000-0000-0000-000000000005	diario	3.0000	alertar	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
3883a798-2380-437f-9e35-835f5952469a	e1000000-0000-0000-0000-000000000003	mensual	100.0000	alertar	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
49a32962-2df2-4a22-82dc-266ed2c3f96e	e1000000-0000-0000-0000-000000000007	diario	2.0000	alertar	t	2026-06-23 17:56:46.320467-05	2026-06-23 17:56:46.320467-05	\N
\.


--
-- Data for Name: type_device; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.type_device (id_type_device, nombre, descripcion, icono, created_at, updated_at, deleted_at) FROM stdin;
e2aae9c3-dfec-49f9-b4c0-374b35ef840a	L├ímpara inteligente	Bombilla o l├ímpara con control remoto de encendido/apagado y consumo medible	lamp	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
fb8af6ce-fd53-4636-8b67-6253a9161000	Enchufe inteligente	Enchufe con monitoreo de consumo y control remoto	plug	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
88605aba-87aa-4785-ad0f-38a294702c4d	Aire acondicionado	Sistema de climatizaci├│n con control de temperatura y programaci├│n	ac	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
fa90fcc0-ab50-4760-93d0-127be7d1dde5	Calentador de agua	Calentador el├®ctrico de agua con control de temperatura	heater	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
0f27c00e-7895-42e2-87b1-d15af3aa277c	Lavadora	Electrodom├®stico de lavado con monitoreo de ciclos y consumo	washer	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
a61035f5-c06e-4c23-b7ff-7a5499a06ef5	Nevera	Refrigerador con monitoreo de consumo energ├®tico	fridge	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
796b8fcc-229c-4d53-829e-32ccc0ee92fe	Televisor	Televisor con control remoto y monitoreo de consumo	tv	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
bc476a0c-a629-46ef-852b-630804d37020	Computador	Equipo de c├│mputo con monitoreo de consumo	computer	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
5f2b256d-a6c8-48db-8fcc-793c644ef92e	Horno microondas	Microondas con monitoreo de uso y consumo	microwave	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
26b1044f-66a2-406d-9c8b-3c30f77ff5fe	Sensor de consumo	Sensor gen├®rico de medici├│n de consumo el├®ctrico	sensor	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
2c8f8582-b8c7-4842-bad3-296af919beb4	Ventilador	Ventilador con control remoto y monitoreo de consumo	fan	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
f4ed0c60-c76a-452e-ad18-0f79c8144872	Cargador	Punto de carga para dispositivos m├│viles o veh├¡culos el├®ctricos	charger	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
2ffa2c08-928b-4aa0-b602-6cdf508b7b13	Otro	Dispositivo gen├®rico no clasificado en las categor├¡as anteriores	device	2026-06-23 17:56:12.727228-05	2026-06-23 17:56:12.727228-05	\N
\.


--
-- Data for Name: voice_assistant_token; Type: TABLE DATA; Schema: devices; Owner: -
--

COPY devices.voice_assistant_token (id_voice_assistant_token, id_user, asistente, access_token, refresh_token, expira_en, activo, created_at, updated_at, deleted_at) FROM stdin;
\.


--
-- Data for Name: area; Type: TABLE DATA; Schema: homes; Owner: -
--

COPY homes.area (id_area, id_home, nombre, tipo, created_at, updated_at, deleted_at) FROM stdin;
d1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	Sala Principal	sala	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
d1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000001	Cocina	cocina	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
d1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	Dormitorio Principal	dormitorio	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
d1000000-0000-0000-0000-000000000004	c1000000-0000-0000-0000-000000000001	Ba├▒o	ba├▒o	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
d1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000002	Sala	sala	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
d1000000-0000-0000-0000-000000000006	c1000000-0000-0000-0000-000000000002	Habitaci├│n	dormitorio	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
d1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	Cocina	cocina	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
\.


--
-- Data for Name: home; Type: TABLE DATA; Schema: homes; Owner: -
--

COPY homes.home (id_home, id_user, nombre, estrato, estado, created_at, updated_at, deleted_at) FROM stdin;
c1000000-0000-0000-0000-000000000001	b1000000-0000-0000-0000-000000000001	Casa Karen	3	activo	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
c1000000-0000-0000-0000-000000000002	b1000000-0000-0000-0000-000000000002	Apartamento Kevin	4	activo	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
\.


--
-- Data for Name: home_member; Type: TABLE DATA; Schema: homes; Owner: -
--

COPY homes.home_member (id_home_member, id_home, id_user, rol_en_hogar, created_at, deleted_at) FROM stdin;
79d36885-8f02-4222-a98b-a98af00f3638	c1000000-0000-0000-0000-000000000001	b1000000-0000-0000-0000-000000000001	propietario	2026-06-23 17:56:46.248438-05	\N
dae31a02-5201-4237-99ba-27735b20a675	c1000000-0000-0000-0000-000000000002	b1000000-0000-0000-0000-000000000002	propietario	2026-06-23 17:56:46.248438-05	\N
86b24f19-7c82-4d7a-8c9c-2a350acd55a8	c1000000-0000-0000-0000-000000000001	b1000000-0000-0000-0000-000000000003	miembro	2026-06-23 17:56:46.248438-05	\N
\.


--
-- Data for Name: tariff; Type: TABLE DATA; Schema: homes; Owner: -
--

COPY homes.tariff (id_tariff, id_home, costo_kwh, moneda, vigente_desde, vigente_hasta, created_at, updated_at, deleted_at) FROM stdin;
1311e8b4-ef3f-416d-b964-a1784a8198ff	c1000000-0000-0000-0000-000000000001	850.0000	COP	2025-01-01	\N	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
a34bf920-9996-4efc-8a5c-b39cc4bd3891	c1000000-0000-0000-0000-000000000002	920.0000	COP	2025-01-01	\N	2026-06-23 17:56:46.248438-05	2026-06-23 17:56:46.248438-05	\N
\.


--
-- Data for Name: alert; Type: TABLE DATA; Schema: notifications; Owner: -
--

COPY notifications.alert (id_alert, id_threshold_rule, id_device, id_home, consumo_detectado_kwh, limite_kwh, accion_ejecutada, created_at) FROM stdin;
dd8acf2e-5c40-4ad4-903b-f8fb31df0575	2de2b00a-c5a3-43cd-acd3-2ec6d8396773	e1000000-0000-0000-0000-000000000005	c1000000-0000-0000-0000-000000000001	3.450000	3.0000	alertar	2026-06-23 15:56:46.458297-05
38005643-054e-46e0-b34c-0b5cc5004327	49a32962-2df2-4a22-82dc-266ed2c3f96e	e1000000-0000-0000-0000-000000000007	c1000000-0000-0000-0000-000000000002	2.200000	2.0000	alertar	2026-06-23 12:56:46.458297-05
\.


--
-- Data for Name: notification; Type: TABLE DATA; Schema: notifications; Owner: -
--

COPY notifications.notification (id_notification, id_user, id_home, id_device, tipo, titulo, mensaje, prioridad, leida, canal, created_at, updated_at, deleted_at) FROM stdin;
d60dcb67-f287-41b4-90d9-2ec125006b6e	b1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	e1000000-0000-0000-0000-000000000005	consumo_elevado	Consumo elevado detectado	El Aire Dormitorio ha superado el umbral diario configurado de 3 kWh.	alta	f	app	2026-06-23 15:56:46.458297-05	2026-06-23 15:56:46.458297-05	\N
229854eb-cead-42bf-a669-9f55c528035e	b1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	\N	nueva_recomendacion	Nueva recomendaci├│n de ahorro disponible	Hemos identificado una oportunidad de ahorro en tu hogar. Revisa la secci├│n de recomendaciones.	media	f	app	2026-06-22 17:56:46.458297-05	2026-06-22 17:56:46.458297-05	\N
b7409d3a-f50e-4d2c-ba43-d6218267c02c	b1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	e1000000-0000-0000-0000-000000000004	dispositivo_desconectado	Dispositivo desconectado	El Microondas Cocina se desconect├│ inesperadamente.	media	t	app	2026-06-20 17:56:46.458297-05	2026-06-20 17:56:46.458297-05	\N
5b6d7731-1df0-4a37-a541-ee853a32f16c	b1000000-0000-0000-0000-000000000001	\N	\N	sistema	Bienvenida a Smart Home	Tu cuenta ha sido activada exitosamente. ┬íComienza a monitorear tu consumo!	baja	t	email	2026-06-13 17:56:46.458297-05	2026-06-13 17:56:46.458297-05	\N
0fea6ecf-dec7-4dac-8f06-be3628f1119b	b1000000-0000-0000-0000-000000000002	c1000000-0000-0000-0000-000000000002	e1000000-0000-0000-0000-000000000007	umbral_superado	Umbral de consumo superado	El Computador Habitaci├│n ha superado el l├¡mite diario de 2 kWh configurado.	alta	f	push	2026-06-23 12:56:46.458297-05	2026-06-23 12:56:46.458297-05	\N
a0f025e6-f76a-425d-a8d7-66f0f1dc2dcb	b1000000-0000-0000-0000-000000000002	\N	\N	sistema	Actualizaci├│n disponible	Hay una nueva versi├│n de la aplicaci├│n Smart Home disponible.	baja	f	app	2026-06-23 11:56:46.458297-05	2026-06-23 11:56:46.458297-05	\N
7ea70686-8590-44c9-86f3-7dbd20c12735	b1000000-0000-0000-0000-000000000003	c1000000-0000-0000-0000-000000000001	\N	sistema	Has sido agregada a un hogar	Karen Daniela Holgu├¡n Cruz te agreg├│ como miembro de "Casa Karen".	media	f	email	2026-06-19 17:56:46.458297-05	2026-06-19 17:56:46.458297-05	\N
\.


--
-- Data for Name: reminder_notification; Type: TABLE DATA; Schema: notifications; Owner: -
--

COPY notifications.reminder_notification (id_reminder_notification, id_user, id_home, mensaje, programado_para, enviado, created_at, updated_at, deleted_at) FROM stdin;
582853f9-2263-4957-a0ed-5fe7c2712c2f	b1000000-0000-0000-0000-000000000001	c1000000-0000-0000-0000-000000000001	Recuerda revisar el consumo de tu hogar esta semana.	2026-06-25 17:56:46.458297-05	f	2026-06-23 17:56:46.458297-05	2026-06-23 17:56:46.458297-05	\N
\.


--
-- Data for Name: databasechangelog; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.databasechangelog (id, author, filename, dateexecuted, orderexecuted, exectype, md5sum, description, comments, tag, liquibase, contexts, labels, deployment_id) FROM stdin;
ddl-ext-001-uuid	smarthome-team	01_ddl/00_extensions/changelog.yaml	2026-06-23 22:56:08.907726	1	EXECUTED	9:10ddfaf94e22720d04d82644e8176086	sqlFile path=001_enable_uuid_extension.sql	Instala la extensi├│n uuid-ossp	\N	5.0.2	\N	\N	2255361807
ddl-ext-002-pgcrypto	smarthome-team	01_ddl/00_extensions/changelog.yaml	2026-06-23 22:56:08.963476	2	EXECUTED	9:b263b3021e9508484e436bb93d04a331	sqlFile path=002_enable_pgcrypto_extension.sql	Instala la extensi├│n pgcrypto	\N	5.0.2	\N	\N	2255361807
ddl-sch-001-schemas	smarthome-team	01_ddl/01_schemas/changelog.yaml	2026-06-23 22:56:09.321335	3	EXECUTED	9:4ae919156e3206f89e9cfbe9c3cfef4c	sqlFile path=001_create_schemas.sql; sqlFile path=002_create_schemas.sql; sqlFile path=003_create_schemas.sql; sqlFile path=004_create_schemas.sql; sqlFile path=005_create_schemas.sql; sqlFile path=006_create_schemas.sql; sqlFile path=007_create_s...	Crea los 8 esquemas del sistema Smart Home	\N	5.0.2	\N	\N	2255361807
ddl-tab-001-auth	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:09.497051	4	EXECUTED	9:34cc5b75cce06f6c6df6075ce06ba708	sqlFile path=001_create_auth_tables.sql	Crea las 9 tablas del esquema auth	\N	5.0.2	\N	\N	2255361807
ddl-tab-002-config	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:09.569773	5	EXECUTED	9:fe96cdcadf774195f3eb069f9f221ae0	sqlFile path=007_create_config_tables.sql	Crea la tabla del esquema config	\N	5.0.2	\N	\N	2255361807
ddl-tab-003-homes	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:09.770906	6	EXECUTED	9:b1bccbd6ea791470e67c4ec33b7c3f75	sqlFile path=002_create_homes_tables.sql	Crea las 4 tablas del esquema homes	\N	5.0.2	\N	\N	2255361807
ddl-tab-004-devices	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:09.929524	7	EXECUTED	9:4235d1b279368aabd3ede8b23bb92eac	sqlFile path=003_create_devices_tables.sql	Crea las 8 tablas del esquema devices	\N	5.0.2	\N	\N	2255361807
ddl-tab-005-consumption	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:10.082847	8	EXECUTED	9:f64065b7db9e7ca7b9d64f7cf8bea821	sqlFile path=004_create_consumption_tables.sql	Crea las 3 tablas del esquema consumption	\N	5.0.2	\N	\N	2255361807
ddl-tab-006-notifications	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:10.197752	9	EXECUTED	9:6cd6a71118a396fe5a7a68a9d4547a08	sqlFile path=005_create_notifications_tables.sql	Crea las 3 tablas del esquema notifications	\N	5.0.2	\N	\N	2255361807
ddl-tab-007-sync	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:10.271503	10	EXECUTED	9:8873cf5361b46f890dc7fb68bec41886	sqlFile path=006_create_sync_tables.sql	Crea las 3 tablas del esquema sync	\N	5.0.2	\N	\N	2255361807
ddl-tab-008-audit	smarthome-team	01_ddl/03_tables/changelog.yaml	2026-06-23 22:56:10.429498	11	EXECUTED	9:6221c90185fc7cccda4f0f36227f61e9	sqlFile path=008_create_audit_tables.sql	Crea la tabla del esquema audit	\N	5.0.2	\N	\N	2255361807
ddl-vw-001-auth	smarthome-team	01_ddl/04_views/changelog.yaml	2026-06-23 22:56:10.511958	12	EXECUTED	9:7d92923a880cd26b277754e048058c9d	sqlFile path=001_auth_views.sql	Vistas del esquema auth	\N	5.0.2	\N	\N	2255361807
ddl-vw-002-homes	smarthome-team	01_ddl/04_views/changelog.yaml	2026-06-23 22:56:10.592764	13	EXECUTED	9:41ca6dbf6e5fcc43bac419f357616116	sqlFile path=002_homes_views.sql	Vistas del esquema homes	\N	5.0.2	\N	\N	2255361807
ddl-vw-003-devices	smarthome-team	01_ddl/04_views/changelog.yaml	2026-06-23 22:56:10.659879	14	EXECUTED	9:85b471916224cc20c72ba228fcdafb5b	sqlFile path=003_devices_views.sql	Vistas del esquema devices	\N	5.0.2	\N	\N	2255361807
ddl-vw-004-consumption	smarthome-team	01_ddl/04_views/changelog.yaml	2026-06-23 22:56:10.72391	15	EXECUTED	9:dc268ce7d6eccd70074bf6f8a27afb49	sqlFile path=004_consumption_views.sql	Vistas de los esquemas consumption y notifications	\N	5.0.2	\N	\N	2255361807
ddl-vw-005-audit	smarthome-team	01_ddl/04_views/changelog.yaml	2026-06-23 22:56:10.781846	16	EXECUTED	9:fd8807bd3e491a954fbd5f6b1f6f89ac	sqlFile path=005_audit_views.sql	Vistas del esquema audit	\N	5.0.2	\N	\N	2255361807
ddl-mv-001-resumen-diario	smarthome-team	01_ddl/05_materialized_views/changelog.yaml	2026-06-23 22:56:10.837456	17	EXECUTED	9:6b29ad136c1ff382a1b2abf4faa024c7	sqlFile path=001_mv_resumen_diario_homes.sql	Vista materializada de resumen diario de consumo por hogar	\N	5.0.2	\N	\N	2255361807
ddl-mv-002-resumen-mensual	smarthome-team	01_ddl/05_materialized_views/changelog.yaml	2026-06-23 22:56:10.894712	18	EXECUTED	9:8ad775c10d63ec00c5c3e6b572e3741e	sqlFile path=002_mv_resumen_mensual_homes.sql	Vista materializada de resumen mensual de consumo por hogar	\N	5.0.2	\N	\N	2255361807
ddl-mv-003-ranking-dispositivos	smarthome-team	01_ddl/05_materialized_views/changelog.yaml	2026-06-23 22:56:10.947161	19	EXECUTED	9:43099c8a911aa1f196c27ab49b24f4f5	sqlFile path=003_mv_raking_devices.sql	Vista materializada de ranking de dispositivos por consumo	\N	5.0.2	\N	\N	2255361807
ddl-mv-004-estadisticas-audit	smarthome-team	01_ddl/05_materialized_views/changelog.yaml	2026-06-23 22:56:10.993438	20	EXECUTED	9:f93285deded9ff714e98277f57a4f912	sqlFile path=004_mv_estadisticas_mensuales_audit.sql	Vista materializada de estad├¡sticas mensuales de auditor├¡a	\N	5.0.2	\N	\N	2255361807
ddl-fn-001-updated-at	smarthome-team	01_ddl/06_functions/changelog.yaml	2026-06-23 22:56:11.04386	21	EXECUTED	9:9e6fc485b3890ffa2ed728205466c70f	sqlFile path=001_update_functions.sql	Funci├│n gen├®rica fn_updated_at	\N	5.0.2	\N	\N	2255361807
ddl-fn-002-audit-log	smarthome-team	01_ddl/06_functions/changelog.yaml	2026-06-23 22:56:11.094026	22	EXECUTED	9:25ea8b8478249dea3a2dda68918ace88	sqlFile path=002_audit_log_functions.sql	Funci├│n gen├®rica fn_audit_log	\N	5.0.2	\N	\N	2255361807
ddl-fn-003-config-user	smarthome-team	01_ddl/06_functions/changelog.yaml	2026-06-23 22:56:11.149178	23	EXECUTED	9:c4cdd1503f20be4eb5b362393d7903d8	sqlFile path=003_config_user_functions.sql	Funci├│n fn_config_user	\N	5.0.2	\N	\N	2255361807
ddl-fn-004-auth-security	smarthome-team	01_ddl/06_functions/changelog.yaml	2026-06-23 22:56:11.201339	24	EXECUTED	9:4e370f33e3ac8e51222525cd7c771647	sqlFile path=004_auth_security_functions.sql	Funciones de seguridad de autenticaci├│n (intentos fallidos, cambio de password, reset MFA)	\N	5.0.2	\N	\N	2255361807
ddl-proc-001-registrar-usuario	smarthome-team	01_ddl/07_procedures/changelog.yaml	2026-06-23 22:56:11.248181	25	EXECUTED	9:ab1ea36f12a71412861aef432e4dd432	sqlFile path=001_sp_registrar_usuario.sql	Procedimiento sp_registrar_usuario	\N	5.0.2	\N	\N	2255361807
ddl-proc-002-registrar-hogar	smarthome-team	01_ddl/07_procedures/changelog.yaml	2026-06-23 22:56:11.29748	26	EXECUTED	9:bae41b24433a6d09b410286e986ea428	sqlFile path=002_sp_registrar_hogar.sql	Procedimiento sp_registrar_hogar	\N	5.0.2	\N	\N	2255361807
ddl-proc-003-registrar-dispositivo	smarthome-team	01_ddl/07_procedures/changelog.yaml	2026-06-23 22:56:11.34251	27	EXECUTED	9:f625128d2c63e9411a6fc18a4446f373	sqlFile path=003_sp_registrar_dispositivo.sql	Procedimiento sp_registrar_dispositivo	\N	5.0.2	\N	\N	2255361807
ddl-proc-004-desactivar-hogar	smarthome-team	01_ddl/07_procedures/changelog.yaml	2026-06-23 22:56:11.390938	28	EXECUTED	9:821f436bbac40640b8b1e661594bba51	sqlFile path=004_sp_desactivar_hogar.sql	Procedimiento sp_desactivar_hogar	\N	5.0.2	\N	\N	2255361807
ddl-proc-005-desactivar-dispositivo	smarthome-team	01_ddl/07_procedures/changelog.yaml	2026-06-23 22:56:11.431225	29	EXECUTED	9:f01deb4f054d9620e0ddc9a1cfbdf6c9	sqlFile path=005_sp_desactivar_dispositivo.sql	Procedimiento sp_desactivar_dispositivo	\N	5.0.2	\N	\N	2255361807
ddl-proc-006-restaurar-backup	smarthome-team	01_ddl/07_procedures/changelog.yaml	2026-06-23 22:56:11.481471	30	EXECUTED	9:caf5196da07912584f63ed3aed6f5e7a	sqlFile path=006_sp_restaurar_backup.sql	Procedimiento sp_restaurar_backup	\N	5.0.2	\N	\N	2255361807
ddl-trg-001-updated-at	smarthome-team	01_ddl/08_triggers/changelog.yaml	2026-06-23 22:56:11.541046	31	EXECUTED	9:03727cd4d3cab3813c04d31d5b19baa3	sqlFile path=001_update_triggers.sql	Triggers que invocan fn_updated_at en todas las tablas con ese campo	\N	5.0.2	\N	\N	2255361807
ddl-trg-002-audit-log	smarthome-team	01_ddl/08_triggers/changelog.yaml	2026-06-23 22:56:11.594118	32	EXECUTED	9:16d6348cd83c2dcca86bd29f452bfe1e	sqlFile path=002_audit_log_triggers.sql	Triggers que invocan fn_audit_log sobre tablas cr├¡ticas	\N	5.0.2	\N	\N	2255361807
ddl-trg-003-config-user	smarthome-team	01_ddl/08_triggers/changelog.yaml	2026-06-23 22:56:11.636583	33	EXECUTED	9:70a167f6c1fc8893ab187c012fc035be	sqlFile path=003_config_user_triggers.sql	Trigger que invoca fn_config_user al crear un usuario	\N	5.0.2	\N	\N	2255361807
ddl-trg-004-auth-security	smarthome-team	01_ddl/08_triggers/changelog.yaml	2026-06-23 22:56:11.688411	34	EXECUTED	9:dc68a7d8d51b8558162fa53d158e02f5	sqlFile path=004_auth_security_triggers.sql	Triggers de seguridad de autenticaci├│n	\N	5.0.2	\N	\N	2255361807
ddl-idx-001-auth	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:11.778234	35	EXECUTED	9:637cbe94989e53278560edd86c13d605	sqlFile path=001_auth_indexes.sql	├ìndices adicionales del esquema auth	\N	5.0.2	\N	\N	2255361807
ddl-idx-002-homes	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:11.851312	36	EXECUTED	9:41af5d2c046ad99e2e3d3328181d629a	sqlFile path=002_homes_indexes.sql	├ìndices adicionales del esquema homes	\N	5.0.2	\N	\N	2255361807
ddl-idx-003-devices	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:11.939808	37	EXECUTED	9:0daf511f7e0b5f890a613740bc72fb97	sqlFile path=003_devices_indexes.sql	├ìndices adicionales del esquema devices	\N	5.0.2	\N	\N	2255361807
ddl-idx-004-consumption	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:12.163182	38	EXECUTED	9:1a1b32fe97dd32aba1a452dac3b305e2	sqlFile path=004_consumption_indexes.sql	├ìndices adicionales del esquema consumption	\N	5.0.2	\N	\N	2255361807
ddl-idx-005-notifications	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:12.27217	39	EXECUTED	9:299e6278be8e2849bd43fa731480b44d	sqlFile path=005_notifications_indexes.sql	├ìndices adicionales del esquema notifications	\N	5.0.2	\N	\N	2255361807
ddl-idx-006-sync	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:12.386007	40	EXECUTED	9:624b1a2553463a7860ee81afea30b93d	sqlFile path=006_sync_indexes.sql	├ìndices adicionales del esquema sync	\N	5.0.2	\N	\N	2255361807
ddl-idx-007-config	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:12.447997	41	EXECUTED	9:4a3d6e8ebfaffb31630181846e205a77	sqlFile path=007_config_indexes.sql	├ìndices adicionales del esquema config	\N	5.0.2	\N	\N	2255361807
ddl-idx-008-audit	smarthome-team	01_ddl/09_indexes/changelog.yaml	2026-06-23 22:56:12.52246	42	EXECUTED	9:63f90df950b5b3658177e9bbf6635b64	sqlFile path=008_audit_indexes.sql	├ìndices adicionales del esquema audit	\N	5.0.2	\N	\N	2255361807
ddl-000-tag-v1.0.0	smarthome-team	01_ddl/changelog.yaml	2026-06-23 22:56:12.525329	43	EXECUTED	9:19241f4e7bc7a9aa36aa862d15e66697	tagDatabase	Marca de versi├│n v1.0.0 ÔÇö estructura DDL completa	v1.0.0	5.0.2	\N	\N	2255361807
dml-insert-001-roles	smarthome-team	02_dml/00_inserts/changelog.yaml	2026-06-23 22:56:12.578793	44	EXECUTED	9:2a644a702c09b33f7dc24e5d5b5a136d	sqlFile path=001_insert_roles.sql	Inserta los roles iniciales del sistema	\N	5.0.2	\N	\N	2255361807
dml-insert-002-permissions	smarthome-team	02_dml/00_inserts/changelog.yaml	2026-06-23 22:56:12.633488	45	EXECUTED	9:a5729dae1599266116de93d46b4230e1	sqlFile path=002_insert_permissions.sql	Inserta los permisos iniciales del sistema	\N	5.0.2	\N	\N	2255361807
dml-insert-003-roles-permissions	smarthome-team	02_dml/00_inserts/changelog.yaml	2026-06-23 22:56:12.692499	46	EXECUTED	9:f876ed430b679f7e353b4931aa172b3b	sqlFile path=003_insert_roles_permissions.sql	Asocia roles con permisos	\N	5.0.2	\N	\N	2255361807
dml-insert-004-device-types	smarthome-team	02_dml/00_inserts/changelog.yaml	2026-06-23 22:56:12.764732	47	EXECUTED	9:e6569b730262bb0bd31ce391479ea1d1	sqlFile path=004_insert_tipos_dispositivos.sql	Inserta los tipos de dispositivos disponibles	\N	5.0.2	\N	\N	2255361807
dml-insert-005-admin-user	smarthome-team	02_dml/00_inserts/changelog.yaml	2026-06-23 22:56:13.078807	48	EXECUTED	9:e2acc9065299c0a7788c61fb6b49e51f	sqlFile path=005_insert_admin_user.sql	Crea el usuario administrador inicial	\N	5.0.2	\N	\N	2255361807
dml-insert-006-audit-seed	smarthome-team	02_dml/00_inserts/changelog.yaml	2026-06-23 22:56:13.126444	49	EXECUTED	9:eafbe0135d1a4df620c9bed22ba87d9f	sqlFile path=006_insert_auditoria_seed.sql	Registra evento de auditor├¡a del seed inicial	\N	5.0.2	\N	\N	2255361807
dcl-roles-001-create-roles	smarthome-team	03_dcl/00_roles/changelog.yaml	2026-06-23 22:56:13.178905	50	EXECUTED	9:fb630a303f14fb5db4145a61d443c358	sqlFile path=001_create_roles.sql	Crea los roles smarthome_admin, smarthome_app y smarthome_readonly	\N	5.0.2	\N	\N	2255361807
dcl-grants-001-auth	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.228586	51	EXECUTED	9:6f9c7418b6cb3dcd9f2058fa945acb28	sqlFile path=001_grants_auth.sql	Grants sobre el esquema auth	\N	5.0.2	\N	\N	2255361807
dcl-grants-002-homes	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.277806	52	EXECUTED	9:63544dc6d9b1df55f9c16fd1bc29c1e6	sqlFile path=002_grants_homes.sql	Grants sobre el esquema homes	\N	5.0.2	\N	\N	2255361807
dcl-grants-003-devices	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.324895	53	EXECUTED	9:01a752dcd2d91a249f7334d36dde1086	sqlFile path=003_grants_devices.sql	Grants sobre el esquema devices	\N	5.0.2	\N	\N	2255361807
dcl-grants-004-consumption	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.374939	54	EXECUTED	9:89d2aa22304c87b4c4bf43a48569dbb0	sqlFile path=004_grants_consumption.sql	Grants sobre el esquema consumption	\N	5.0.2	\N	\N	2255361807
dcl-grants-005-notifications	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.42471	55	EXECUTED	9:52f814780bc5973b29221839aceaee67	sqlFile path=005_grants_notifications.sql	Grants sobre el esquema notifications	\N	5.0.2	\N	\N	2255361807
dcl-grants-006-sync	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.475766	56	EXECUTED	9:4df229414cf0ba8f90d4963821fb1fa1	sqlFile path=006_grants_sync.sql	Grants sobre el esquema sync	\N	5.0.2	\N	\N	2255361807
dcl-grants-007-config	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.5223	57	EXECUTED	9:3f43b8e67484e9acdcd8b99253aeea87	sqlFile path=007_grants_config.sql	Grants sobre el esquema config	\N	5.0.2	\N	\N	2255361807
dcl-grants-008-audit	smarthome-team	03_dcl/01_grants/changelog.yaml	2026-06-23 22:56:13.570447	58	EXECUTED	9:18c633e7e006a97e9692bc8c86a616d7	sqlFile path=008_grants_audit.sql	Grants sobre el esquema audit (sin UPDATE/DELETE para smarthome_app)	\N	5.0.2	\N	\N	2255361807
dcl-rls-001-homes	smarthome-team	03_dcl/02_policies/changelog.yaml	2026-06-23 22:56:13.621001	59	EXECUTED	9:a737d82eeb11deb0d4c57eb4ff5c6186	sqlFile path=001_rls_homes.sql	Pol├¡ticas RLS sobre homes.home y homes.area	\N	5.0.2	\N	\N	2255361807
dcl-rls-002-devices	smarthome-team	03_dcl/02_policies/changelog.yaml	2026-06-23 22:56:13.679919	60	EXECUTED	9:9d06b220df07254e165d696568600337	sqlFile path=002_rls_devices.sql	Pol├¡ticas RLS sobre devices.device	\N	5.0.2	\N	\N	2255361807
dcl-rls-003-consumption	smarthome-team	03_dcl/02_policies/changelog.yaml	2026-06-23 22:56:13.729273	61	EXECUTED	9:f3d5485d2e01cfcd47aeb32f1a17e79a	sqlFile path=003_rls_consumption.sql	Pol├¡ticas RLS sobre consumption.consumption, consumption_metric y recommendation	\N	5.0.2	\N	\N	2255361807
dcl-rls-004-notifications	smarthome-team	03_dcl/02_policies/changelog.yaml	2026-06-23 22:56:13.776514	62	EXECUTED	9:51b27e84a594b78a675f4fd7c1915966	sqlFile path=004_rls_notifications.sql	Pol├¡ticas RLS sobre notifications.notification	\N	5.0.2	\N	\N	2255361807
dcl-rls-005-config	smarthome-team	03_dcl/02_policies/changelog.yaml	2026-06-23 22:56:13.841693	63	EXECUTED	9:9743109ccb3e9d9cd934f8d3f564eb29	sqlFile path=005_rls_config.sql	Pol├¡ticas RLS sobre config.configuration_user	\N	5.0.2	\N	\N	2255361807
tcl-tag-001-v1.0.0-initial	smarthome-team	04_tcl/02_release_tags/changelog.yaml	2026-06-23 22:56:13.896457	64	EXECUTED	9:7a8ce98e046879ce21b59714416a840f	sqlFile path=001_tag_v1_0_0_initial.sql	Registro informativo en auditor├¡a del contenido de la versi├│n v1.0.0 (estructura DDL completa)	\N	5.0.2	\N	\N	2255361807
tcl-tag-002-v1.0.1-seed	smarthome-team	04_tcl/02_release_tags/changelog.yaml	2026-06-23 22:56:13.951761	65	EXECUTED	9:5bca6fbd2186b269255814d5095e1347	sqlFile path=002_tag_v1_0_1_seed.sql	Registro informativo en auditor├¡a del contenido de la versi├│n v1.0.1 (datos semilla)	\N	5.0.2	\N	\N	2255361807
dml-test-data-001-usuarios	smarthome-team	02_dml/05_test_data/changelog.yaml	2026-06-23 22:56:46.222711	66	EXECUTED	9:cf978964c6dc257e1fd321a7997b01f3	sqlFile path=001_test_users.sql	[TEST-DATA] Inserta usuarios de prueba	\N	5.0.2	test-data	\N	2255400266
dml-test-data-002-homes	smarthome-team	02_dml/05_test_data/changelog.yaml	2026-06-23 22:56:46.302858	67	EXECUTED	9:4049cb0448e645a69cfb4938dc9edacc	sqlFile path=002_test_homes.sql	[TEST-DATA] Inserta hogares de prueba	\N	5.0.2	test-data	\N	2255400266
dml-test-data-003-dispositivos	smarthome-team	02_dml/05_test_data/changelog.yaml	2026-06-23 22:56:46.378828	68	EXECUTED	9:61c6ef7a7e2244e42f8c8bb6e09f4666	sqlFile path=003_test_devices.sql	[TEST-DATA] Inserta dispositivos de prueba	\N	5.0.2	test-data	\N	2255400266
dml-test-data-004-consumption	smarthome-team	02_dml/05_test_data/changelog.yaml	2026-06-23 22:56:46.443011	69	EXECUTED	9:34b41ec1cf86acb2dc7add3cf78ca422	sqlFile path=004_test_consumption.sql	[TEST-DATA] Inserta consumos de prueba	\N	5.0.2	test-data	\N	2255400266
dml-test-data-005-notifications	smarthome-team	02_dml/05_test_data/changelog.yaml	2026-06-23 22:56:46.504891	70	EXECUTED	9:aa1c3cfc934144a307608001fd434950	sqlFile path=005_test_notifications.sql	[TEST-DATA] Inserta notificaciones de prueba	\N	5.0.2	test-data	\N	2255400266
dml-test-data-006-config	smarthome-team	02_dml/05_test_data/changelog.yaml	2026-06-23 22:56:46.561328	71	EXECUTED	9:c9eb20ba716f2238b4ddd9f2a475895e	sqlFile path=006_test_config.sql	[TEST-DATA] Inserta configuraciones de usuario de prueba	\N	5.0.2	test-data	\N	2255400266
\.


--
-- Data for Name: databasechangeloglock; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.databasechangeloglock (id, locked, lockgranted, lockedby) FROM stdin;
1	f	\N	\N
\.


--
-- Data for Name: backup; Type: TABLE DATA; Schema: sync; Owner: -
--

COPY sync.backup (id_backup, id_user, tipo, alcance, ubicacion, tamanio_bytes, estado, descripcion, created_at) FROM stdin;
\.


--
-- Data for Name: offline_queue; Type: TABLE DATA; Schema: sync; Owner: -
--

COPY sync.offline_queue (id_offline_queue, id_user, tipo_accion, payload, estado, intentos, created_at, procesada_at) FROM stdin;
\.


--
-- Data for Name: synchronization; Type: TABLE DATA; Schema: sync; Owner: -
--

COPY sync.synchronization (id_synchronization, id_user, tipo, estado, dispositivos_sincronizados, errores, created_at) FROM stdin;
\.


--
-- Name: audit_log pk_audit_log; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT pk_audit_log PRIMARY KEY (id_audit_log);


--
-- Name: mfa pk_mfa; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa
    ADD CONSTRAINT pk_mfa PRIMARY KEY (id_mfa);


--
-- Name: permission pk_permission; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.permission
    ADD CONSTRAINT pk_permission PRIMARY KEY (id_permission);


--
-- Name: recovery_token pk_recovery_token; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.recovery_token
    ADD CONSTRAINT pk_recovery_token PRIMARY KEY (id_recovery_token);


--
-- Name: role pk_role; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.role
    ADD CONSTRAINT pk_role PRIMARY KEY (id_role);


--
-- Name: role_permission pk_role_permission; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.role_permission
    ADD CONSTRAINT pk_role_permission PRIMARY KEY (id_role_permission);


--
-- Name: session pk_session; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.session
    ADD CONSTRAINT pk_session PRIMARY KEY (id_session);


--
-- Name: token_blacklist pk_token_blacklist; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.token_blacklist
    ADD CONSTRAINT pk_token_blacklist PRIMARY KEY (id_token_blacklist);


--
-- Name: user pk_user; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth."user"
    ADD CONSTRAINT pk_user PRIMARY KEY (id_user);


--
-- Name: user_role pk_user_role; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role
    ADD CONSTRAINT pk_user_role PRIMARY KEY (id_user_role);


--
-- Name: mfa uq_mfa_user; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa
    ADD CONSTRAINT uq_mfa_user UNIQUE (id_user);


--
-- Name: permission uq_permission_nombre; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.permission
    ADD CONSTRAINT uq_permission_nombre UNIQUE (nombre);


--
-- Name: recovery_token uq_recovery_token; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.recovery_token
    ADD CONSTRAINT uq_recovery_token UNIQUE (token);


--
-- Name: role uq_role_nombre; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.role
    ADD CONSTRAINT uq_role_nombre UNIQUE (nombre);


--
-- Name: role_permission uq_role_permission; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.role_permission
    ADD CONSTRAINT uq_role_permission UNIQUE (id_role, id_permission);


--
-- Name: session uq_session_refresh; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.session
    ADD CONSTRAINT uq_session_refresh UNIQUE (refresh_token);


--
-- Name: session uq_session_token; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.session
    ADD CONSTRAINT uq_session_token UNIQUE (token);


--
-- Name: token_blacklist uq_token_blacklist; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.token_blacklist
    ADD CONSTRAINT uq_token_blacklist UNIQUE (token);


--
-- Name: user uq_user_documento; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth."user"
    ADD CONSTRAINT uq_user_documento UNIQUE (numero_documento);


--
-- Name: user uq_user_email; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth."user"
    ADD CONSTRAINT uq_user_email UNIQUE (email);


--
-- Name: user_role uq_user_role; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role
    ADD CONSTRAINT uq_user_role UNIQUE (id_user, id_role);


--
-- Name: user uq_user_username; Type: CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth."user"
    ADD CONSTRAINT uq_user_username UNIQUE (username);


--
-- Name: configuration_user pk_configuration_user; Type: CONSTRAINT; Schema: config; Owner: -
--

ALTER TABLE ONLY config.configuration_user
    ADD CONSTRAINT pk_configuration_user PRIMARY KEY (id_configuration_user);


--
-- Name: configuration_user uq_configuration_user_id_user; Type: CONSTRAINT; Schema: config; Owner: -
--

ALTER TABLE ONLY config.configuration_user
    ADD CONSTRAINT uq_configuration_user_id_user UNIQUE (id_user);


--
-- Name: consumption pk_consumption; Type: CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption
    ADD CONSTRAINT pk_consumption PRIMARY KEY (id_consumption);


--
-- Name: consumption_metric pk_consumption_metric; Type: CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption_metric
    ADD CONSTRAINT pk_consumption_metric PRIMARY KEY (id_consumption_metric);


--
-- Name: recommendation pk_recommendation; Type: CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.recommendation
    ADD CONSTRAINT pk_recommendation PRIMARY KEY (id_recommendation);


--
-- Name: consumption_metric uq_consumption_metric; Type: CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption_metric
    ADD CONSTRAINT uq_consumption_metric UNIQUE (id_device, periodo, fecha_inicio);


--
-- Name: device pk_device; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device
    ADD CONSTRAINT pk_device PRIMARY KEY (id_device);


--
-- Name: device_status_history pk_device_status_history; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device_status_history
    ADD CONSTRAINT pk_device_status_history PRIMARY KEY (id_device_status_history);


--
-- Name: manual_device pk_manual_device; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.manual_device
    ADD CONSTRAINT pk_manual_device PRIMARY KEY (id_manual_device);


--
-- Name: schedule pk_schedule; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.schedule
    ADD CONSTRAINT pk_schedule PRIMARY KEY (id_schedule);


--
-- Name: smart_device pk_smart_device; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.smart_device
    ADD CONSTRAINT pk_smart_device PRIMARY KEY (id_smart_device);


--
-- Name: threshold_rule pk_threshold_rule; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.threshold_rule
    ADD CONSTRAINT pk_threshold_rule PRIMARY KEY (id_threshold_rule);


--
-- Name: type_device pk_type_device; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.type_device
    ADD CONSTRAINT pk_type_device PRIMARY KEY (id_type_device);


--
-- Name: voice_assistant_token pk_voice_assistant_token; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.voice_assistant_token
    ADD CONSTRAINT pk_voice_assistant_token PRIMARY KEY (id_voice_assistant_token);


--
-- Name: device uq_device_mac; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device
    ADD CONSTRAINT uq_device_mac UNIQUE (mac_address);


--
-- Name: device uq_device_nombre; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device
    ADD CONSTRAINT uq_device_nombre UNIQUE (id_home, nombre);


--
-- Name: manual_device uq_manual_device_device; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.manual_device
    ADD CONSTRAINT uq_manual_device_device UNIQUE (id_device);


--
-- Name: smart_device uq_smart_device_device; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.smart_device
    ADD CONSTRAINT uq_smart_device_device UNIQUE (id_device);


--
-- Name: type_device uq_type_device_nombre; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.type_device
    ADD CONSTRAINT uq_type_device_nombre UNIQUE (nombre);


--
-- Name: voice_assistant_token uq_voice_assistant_token; Type: CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.voice_assistant_token
    ADD CONSTRAINT uq_voice_assistant_token UNIQUE (id_user, asistente);


--
-- Name: area pk_area; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.area
    ADD CONSTRAINT pk_area PRIMARY KEY (id_area);


--
-- Name: home pk_home; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home
    ADD CONSTRAINT pk_home PRIMARY KEY (id_home);


--
-- Name: home_member pk_home_member; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home_member
    ADD CONSTRAINT pk_home_member PRIMARY KEY (id_home_member);


--
-- Name: tariff pk_tariff; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.tariff
    ADD CONSTRAINT pk_tariff PRIMARY KEY (id_tariff);


--
-- Name: area uq_area_nombre; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.area
    ADD CONSTRAINT uq_area_nombre UNIQUE (id_home, nombre);


--
-- Name: home_member uq_home_member; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home_member
    ADD CONSTRAINT uq_home_member UNIQUE (id_home, id_user);


--
-- Name: home uq_home_nombre; Type: CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home
    ADD CONSTRAINT uq_home_nombre UNIQUE (id_user, nombre);


--
-- Name: alert pk_alert; Type: CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.alert
    ADD CONSTRAINT pk_alert PRIMARY KEY (id_alert);


--
-- Name: notification pk_notification; Type: CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.notification
    ADD CONSTRAINT pk_notification PRIMARY KEY (id_notification);


--
-- Name: reminder_notification pk_reminder_notification; Type: CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.reminder_notification
    ADD CONSTRAINT pk_reminder_notification PRIMARY KEY (id_reminder_notification);


--
-- Name: databasechangeloglock databasechangeloglock_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.databasechangeloglock
    ADD CONSTRAINT databasechangeloglock_pkey PRIMARY KEY (id);


--
-- Name: backup pk_backup; Type: CONSTRAINT; Schema: sync; Owner: -
--

ALTER TABLE ONLY sync.backup
    ADD CONSTRAINT pk_backup PRIMARY KEY (id_backup);


--
-- Name: offline_queue pk_offline_queue; Type: CONSTRAINT; Schema: sync; Owner: -
--

ALTER TABLE ONLY sync.offline_queue
    ADD CONSTRAINT pk_offline_queue PRIMARY KEY (id_offline_queue);


--
-- Name: synchronization pk_synchronization; Type: CONSTRAINT; Schema: sync; Owner: -
--

ALTER TABLE ONLY sync.synchronization
    ADD CONSTRAINT pk_synchronization PRIMARY KEY (id_synchronization);


--
-- Name: idx_audit_log_accion; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_accion ON audit.audit_log USING btree (accion);


--
-- Name: idx_audit_log_accion_created_at; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_accion_created_at ON audit.audit_log USING btree (accion, created_at DESC);


--
-- Name: idx_audit_log_created_at; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_created_at ON audit.audit_log USING btree (created_at DESC);


--
-- Name: idx_audit_log_entidad; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_entidad ON audit.audit_log USING btree (entidad);


--
-- Name: idx_audit_log_id_user; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_id_user ON audit.audit_log USING btree (id_user);


--
-- Name: idx_audit_log_modulo; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_modulo ON audit.audit_log USING btree (modulo);


--
-- Name: idx_audit_log_modulo_accion; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_modulo_accion ON audit.audit_log USING btree (modulo, accion);


--
-- Name: idx_audit_log_modulo_created_at; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_modulo_created_at ON audit.audit_log USING btree (modulo, created_at DESC);


--
-- Name: idx_audit_log_resultado; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_resultado ON audit.audit_log USING btree (resultado);


--
-- Name: idx_audit_log_resultado_created_at; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_resultado_created_at ON audit.audit_log USING btree (resultado, created_at DESC) WHERE ((resultado)::text = 'fallido'::text);


--
-- Name: idx_audit_log_user_created_at; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_user_created_at ON audit.audit_log USING btree (id_user, created_at DESC);


--
-- Name: idx_audit_log_user_modulo_fecha; Type: INDEX; Schema: audit; Owner: -
--

CREATE INDEX idx_audit_log_user_modulo_fecha ON audit.audit_log USING btree (id_user, modulo, created_at DESC);


--
-- Name: uq_mv_estadisticas_mensuales; Type: INDEX; Schema: audit; Owner: -
--

CREATE UNIQUE INDEX uq_mv_estadisticas_mensuales ON audit.mv_estadisticas_mensuales USING btree (mes, modulo, accion, resultado);


--
-- Name: idx_mfa_habilitado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_mfa_habilitado ON auth.mfa USING btree (habilitado) WHERE (habilitado = true);


--
-- Name: idx_mfa_id_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_mfa_id_user ON auth.mfa USING btree (id_user);


--
-- Name: idx_permission_accion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_permission_accion ON auth.permission USING btree (accion) WHERE (deleted_at IS NULL);


--
-- Name: idx_permission_modulo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_permission_modulo ON auth.permission USING btree (modulo) WHERE (deleted_at IS NULL);


--
-- Name: idx_permission_modulo_accion; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_permission_modulo_accion ON auth.permission USING btree (modulo, accion) WHERE (deleted_at IS NULL);


--
-- Name: idx_recovery_token_expira_en; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_recovery_token_expira_en ON auth.recovery_token USING btree (expira_en) WHERE (usado = false);


--
-- Name: idx_recovery_token_id_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_recovery_token_id_user ON auth.recovery_token USING btree (id_user);


--
-- Name: idx_recovery_token_token; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_recovery_token_token ON auth.recovery_token USING btree (token) WHERE (usado = false);


--
-- Name: idx_recovery_token_user_tipo; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_recovery_token_user_tipo ON auth.recovery_token USING btree (id_user, tipo) WHERE (usado = false);


--
-- Name: idx_role_nombre; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_role_nombre ON auth.role USING btree (nombre) WHERE (deleted_at IS NULL);


--
-- Name: idx_role_permission_id_role; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_role_permission_id_role ON auth.role_permission USING btree (id_role) WHERE (deleted_at IS NULL);


--
-- Name: idx_session_activa; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_session_activa ON auth.session USING btree (activa) WHERE (deleted_at IS NULL);


--
-- Name: idx_session_expira_en; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_session_expira_en ON auth.session USING btree (expira_en) WHERE (activa = true);


--
-- Name: idx_session_id_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_session_id_user ON auth.session USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_session_id_user_activa; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_session_id_user_activa ON auth.session USING btree (id_user, activa) WHERE (deleted_at IS NULL);


--
-- Name: idx_session_token; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_session_token ON auth.session USING btree (token) WHERE ((activa = true) AND (deleted_at IS NULL));


--
-- Name: idx_token_blacklist_expira_en; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_token_blacklist_expira_en ON auth.token_blacklist USING btree (expira_en);


--
-- Name: idx_token_blacklist_token; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_token_blacklist_token ON auth.token_blacklist USING btree (token);


--
-- Name: idx_user_bloqueado_hasta; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_bloqueado_hasta ON auth."user" USING btree (bloqueado_hasta) WHERE (((estado)::text = 'bloqueado'::text) AND (deleted_at IS NULL));


--
-- Name: idx_user_email; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_email ON auth."user" USING btree (email) WHERE (deleted_at IS NULL);


--
-- Name: idx_user_email_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_email_estado ON auth."user" USING btree (email, estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_user_estado; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_estado ON auth."user" USING btree (estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_user_numero_documento; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_numero_documento ON auth."user" USING btree (numero_documento) WHERE (deleted_at IS NULL);


--
-- Name: idx_user_role_id_role; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_role_id_role ON auth.user_role USING btree (id_role) WHERE (deleted_at IS NULL);


--
-- Name: idx_user_role_id_user; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_role_id_user ON auth.user_role USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_user_username; Type: INDEX; Schema: auth; Owner: -
--

CREATE INDEX idx_user_username ON auth."user" USING btree (username) WHERE (deleted_at IS NULL);


--
-- Name: idx_configuration_user_id_user; Type: INDEX; Schema: config; Owner: -
--

CREATE INDEX idx_configuration_user_id_user ON config.configuration_user USING btree (id_user);


--
-- Name: idx_configuration_user_idioma; Type: INDEX; Schema: config; Owner: -
--

CREATE INDEX idx_configuration_user_idioma ON config.configuration_user USING btree (idioma);


--
-- Name: idx_configuration_user_recomendaciones; Type: INDEX; Schema: config; Owner: -
--

CREATE INDEX idx_configuration_user_recomendaciones ON config.configuration_user USING btree (recomendaciones_activas, frecuencia_recomendaciones) WHERE (recomendaciones_activas = true);


--
-- Name: idx_configuration_user_tema; Type: INDEX; Schema: config; Owner: -
--

CREATE INDEX idx_configuration_user_tema ON config.configuration_user USING btree (tema);


--
-- Name: idx_consumption_device_fecha; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_device_fecha ON consumption.consumption USING btree (id_device, fecha_lectura DESC);


--
-- Name: idx_consumption_fecha_lectura; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_fecha_lectura ON consumption.consumption USING btree (fecha_lectura DESC);


--
-- Name: idx_consumption_home_fecha; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_home_fecha ON consumption.consumption USING btree (id_home, fecha_lectura DESC);


--
-- Name: idx_consumption_id_device; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_id_device ON consumption.consumption USING btree (id_device);


--
-- Name: idx_consumption_id_home; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_id_home ON consumption.consumption USING btree (id_home);


--
-- Name: idx_consumption_metric_device_periodo_fecha; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_metric_device_periodo_fecha ON consumption.consumption_metric USING btree (id_device, periodo, fecha_inicio DESC);


--
-- Name: idx_consumption_metric_fecha_inicio; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_metric_fecha_inicio ON consumption.consumption_metric USING btree (fecha_inicio DESC);


--
-- Name: idx_consumption_metric_home_periodo_fecha; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_metric_home_periodo_fecha ON consumption.consumption_metric USING btree (id_home, periodo, fecha_inicio DESC);


--
-- Name: idx_consumption_metric_id_device; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_metric_id_device ON consumption.consumption_metric USING btree (id_device);


--
-- Name: idx_consumption_metric_id_home; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_metric_id_home ON consumption.consumption_metric USING btree (id_home);


--
-- Name: idx_consumption_metric_periodo; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_consumption_metric_periodo ON consumption.consumption_metric USING btree (periodo);


--
-- Name: idx_recommendation_estado; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_recommendation_estado ON consumption.recommendation USING btree (estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_recommendation_home_estado; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_recommendation_home_estado ON consumption.recommendation USING btree (id_home, estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_recommendation_home_prioridad; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_recommendation_home_prioridad ON consumption.recommendation USING btree (id_home, prioridad) WHERE (deleted_at IS NULL);


--
-- Name: idx_recommendation_id_home; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_recommendation_id_home ON consumption.recommendation USING btree (id_home) WHERE (deleted_at IS NULL);


--
-- Name: idx_recommendation_prioridad; Type: INDEX; Schema: consumption; Owner: -
--

CREATE INDEX idx_recommendation_prioridad ON consumption.recommendation USING btree (prioridad) WHERE (deleted_at IS NULL);


--
-- Name: uq_mv_ranking_dispositivos; Type: INDEX; Schema: consumption; Owner: -
--

CREATE UNIQUE INDEX uq_mv_ranking_dispositivos ON consumption.mv_ranking_dispositivos USING btree (id_device);


--
-- Name: uq_mv_resumen_diario_hogar; Type: INDEX; Schema: consumption; Owner: -
--

CREATE UNIQUE INDEX uq_mv_resumen_diario_hogar ON consumption.mv_resumen_diario_hogar USING btree (id_home, fecha);


--
-- Name: uq_mv_resumen_mensual_hogar; Type: INDEX; Schema: consumption; Owner: -
--

CREATE UNIQUE INDEX uq_mv_resumen_mensual_hogar ON consumption.mv_resumen_mensual_hogar USING btree (id_home, mes);


--
-- Name: idx_device_estado; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_estado ON devices.device USING btree (estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_id_area; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_id_area ON devices.device USING btree (id_area) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_id_home; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_id_home ON devices.device USING btree (id_home) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_id_home_encendido; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_id_home_encendido ON devices.device USING btree (id_home, encendido) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_id_home_estado; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_id_home_estado ON devices.device USING btree (id_home, estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_id_home_nombre; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_id_home_nombre ON devices.device USING btree (id_home, nombre) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_id_type_device; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_id_type_device ON devices.device USING btree (id_type_device) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_mac_address; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_mac_address ON devices.device USING btree (mac_address) WHERE (deleted_at IS NULL);


--
-- Name: idx_device_status_history_created_at; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_status_history_created_at ON devices.device_status_history USING btree (created_at DESC);


--
-- Name: idx_device_status_history_device_created_at; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_status_history_device_created_at ON devices.device_status_history USING btree (id_device, created_at DESC);


--
-- Name: idx_device_status_history_id_device; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_status_history_id_device ON devices.device_status_history USING btree (id_device);


--
-- Name: idx_device_status_history_origen; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_device_status_history_origen ON devices.device_status_history USING btree (origen);


--
-- Name: idx_manual_device_id_device; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_manual_device_id_device ON devices.manual_device USING btree (id_device);


--
-- Name: idx_schedule_activo; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_schedule_activo ON devices.schedule USING btree (activo) WHERE ((activo = true) AND (deleted_at IS NULL));


--
-- Name: idx_schedule_id_device; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_schedule_id_device ON devices.schedule USING btree (id_device) WHERE (deleted_at IS NULL);


--
-- Name: idx_schedule_id_device_activo; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_schedule_id_device_activo ON devices.schedule USING btree (id_device, activo) WHERE (deleted_at IS NULL);


--
-- Name: idx_smart_device_id_device; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_smart_device_id_device ON devices.smart_device USING btree (id_device);


--
-- Name: idx_threshold_rule_activa; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_threshold_rule_activa ON devices.threshold_rule USING btree (activa) WHERE ((activa = true) AND (deleted_at IS NULL));


--
-- Name: idx_threshold_rule_id_device; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_threshold_rule_id_device ON devices.threshold_rule USING btree (id_device) WHERE (deleted_at IS NULL);


--
-- Name: idx_threshold_rule_id_device_tipo; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_threshold_rule_id_device_tipo ON devices.threshold_rule USING btree (id_device, tipo) WHERE ((activa = true) AND (deleted_at IS NULL));


--
-- Name: idx_type_device_nombre; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_type_device_nombre ON devices.type_device USING btree (nombre) WHERE (deleted_at IS NULL);


--
-- Name: idx_voice_assistant_token_activo; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_voice_assistant_token_activo ON devices.voice_assistant_token USING btree (id_user, activo) WHERE ((activo = true) AND (deleted_at IS NULL));


--
-- Name: idx_voice_assistant_token_id_user; Type: INDEX; Schema: devices; Owner: -
--

CREATE INDEX idx_voice_assistant_token_id_user ON devices.voice_assistant_token USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_area_id_home; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_area_id_home ON homes.area USING btree (id_home) WHERE (deleted_at IS NULL);


--
-- Name: idx_area_id_home_nombre; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_area_id_home_nombre ON homes.area USING btree (id_home, nombre) WHERE (deleted_at IS NULL);


--
-- Name: idx_area_tipo; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_area_tipo ON homes.area USING btree (tipo) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_estado; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_estado ON homes.home USING btree (estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_id_user; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_id_user ON homes.home USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_id_user_estado; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_id_user_estado ON homes.home USING btree (id_user, estado) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_id_user_nombre; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_id_user_nombre ON homes.home USING btree (id_user, nombre) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_member_id_home; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_member_id_home ON homes.home_member USING btree (id_home) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_member_id_home_rol; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_member_id_home_rol ON homes.home_member USING btree (id_home, rol_en_hogar) WHERE (deleted_at IS NULL);


--
-- Name: idx_home_member_id_user; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_home_member_id_user ON homes.home_member USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_tariff_id_home; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_tariff_id_home ON homes.tariff USING btree (id_home) WHERE (deleted_at IS NULL);


--
-- Name: idx_tariff_vigente_actual; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_tariff_vigente_actual ON homes.tariff USING btree (id_home, vigente_desde) WHERE ((vigente_hasta IS NULL) AND (deleted_at IS NULL));


--
-- Name: idx_tariff_vigente_desde; Type: INDEX; Schema: homes; Owner: -
--

CREATE INDEX idx_tariff_vigente_desde ON homes.tariff USING btree (id_home, vigente_desde DESC) WHERE (deleted_at IS NULL);


--
-- Name: idx_alert_created_at; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_alert_created_at ON notifications.alert USING btree (created_at DESC);


--
-- Name: idx_alert_device_created_at; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_alert_device_created_at ON notifications.alert USING btree (id_device, created_at DESC);


--
-- Name: idx_alert_home_created_at; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_alert_home_created_at ON notifications.alert USING btree (id_home, created_at DESC);


--
-- Name: idx_alert_id_device; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_alert_id_device ON notifications.alert USING btree (id_device);


--
-- Name: idx_alert_id_home; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_alert_id_home ON notifications.alert USING btree (id_home);


--
-- Name: idx_alert_id_threshold_rule; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_alert_id_threshold_rule ON notifications.alert USING btree (id_threshold_rule);


--
-- Name: idx_notification_created_at; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_created_at ON notifications.notification USING btree (created_at DESC) WHERE (deleted_at IS NULL);


--
-- Name: idx_notification_id_user; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_id_user ON notifications.notification USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_notification_leida; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_leida ON notifications.notification USING btree (id_user, leida) WHERE ((leida = false) AND (deleted_at IS NULL));


--
-- Name: idx_notification_prioridad; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_prioridad ON notifications.notification USING btree (prioridad) WHERE (deleted_at IS NULL);


--
-- Name: idx_notification_tipo; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_tipo ON notifications.notification USING btree (tipo) WHERE (deleted_at IS NULL);


--
-- Name: idx_notification_user_created_at; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_user_created_at ON notifications.notification USING btree (id_user, created_at DESC) WHERE (deleted_at IS NULL);


--
-- Name: idx_notification_user_leida_fecha; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_user_leida_fecha ON notifications.notification USING btree (id_user, leida, created_at DESC) WHERE (deleted_at IS NULL);


--
-- Name: idx_notification_user_tipo; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_notification_user_tipo ON notifications.notification USING btree (id_user, tipo) WHERE (deleted_at IS NULL);


--
-- Name: idx_reminder_notification_id_user; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_reminder_notification_id_user ON notifications.reminder_notification USING btree (id_user) WHERE (deleted_at IS NULL);


--
-- Name: idx_reminder_notification_programado_para; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_reminder_notification_programado_para ON notifications.reminder_notification USING btree (programado_para) WHERE ((enviado = false) AND (deleted_at IS NULL));


--
-- Name: idx_reminder_notification_user_enviado; Type: INDEX; Schema: notifications; Owner: -
--

CREATE INDEX idx_reminder_notification_user_enviado ON notifications.reminder_notification USING btree (id_user, enviado) WHERE (deleted_at IS NULL);


--
-- Name: idx_backup_automatico_completado; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_backup_automatico_completado ON sync.backup USING btree (created_at DESC) WHERE (((tipo)::text = 'automatico'::text) AND ((estado)::text = 'completado'::text));


--
-- Name: idx_backup_created_at; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_backup_created_at ON sync.backup USING btree (created_at DESC);


--
-- Name: idx_backup_estado; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_backup_estado ON sync.backup USING btree (estado);


--
-- Name: idx_backup_id_user; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_backup_id_user ON sync.backup USING btree (id_user);


--
-- Name: idx_backup_tipo; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_backup_tipo ON sync.backup USING btree (tipo);


--
-- Name: idx_backup_user_estado_fecha; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_backup_user_estado_fecha ON sync.backup USING btree (id_user, estado, created_at DESC);


--
-- Name: idx_offline_queue_estado; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_offline_queue_estado ON sync.offline_queue USING btree (estado);


--
-- Name: idx_offline_queue_id_user; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_offline_queue_id_user ON sync.offline_queue USING btree (id_user);


--
-- Name: idx_offline_queue_pendiente_created_at; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_offline_queue_pendiente_created_at ON sync.offline_queue USING btree (created_at) WHERE ((estado)::text = 'pendiente'::text);


--
-- Name: idx_offline_queue_user_estado; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_offline_queue_user_estado ON sync.offline_queue USING btree (id_user, estado);


--
-- Name: idx_offline_queue_user_pendiente_fecha; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_offline_queue_user_pendiente_fecha ON sync.offline_queue USING btree (id_user, created_at) WHERE ((estado)::text = 'pendiente'::text);


--
-- Name: idx_synchronization_created_at; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_synchronization_created_at ON sync.synchronization USING btree (created_at DESC);


--
-- Name: idx_synchronization_estado; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_synchronization_estado ON sync.synchronization USING btree (estado);


--
-- Name: idx_synchronization_id_user; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_synchronization_id_user ON sync.synchronization USING btree (id_user);


--
-- Name: idx_synchronization_tipo; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_synchronization_tipo ON sync.synchronization USING btree (tipo);


--
-- Name: idx_synchronization_user_created_at; Type: INDEX; Schema: sync; Owner: -
--

CREATE INDEX idx_synchronization_user_created_at ON sync.synchronization USING btree (id_user, created_at DESC);


--
-- Name: permission trg_audit_permission; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_audit_permission AFTER INSERT OR UPDATE ON auth.permission FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: role trg_audit_role; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_audit_role AFTER INSERT OR UPDATE ON auth.role FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: role_permission trg_audit_role_permission; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_audit_role_permission AFTER INSERT OR UPDATE ON auth.role_permission FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: user trg_audit_user; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_audit_user AFTER INSERT OR UPDATE ON auth."user" FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: user_role trg_audit_user_role; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_audit_user_role AFTER INSERT OR UPDATE ON auth.user_role FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: user trg_auth_cambio_password; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_auth_cambio_password BEFORE UPDATE ON auth."user" FOR EACH ROW EXECUTE FUNCTION public.fn_auth_cambio_password();


--
-- Name: TRIGGER trg_auth_cambio_password ON "user"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TRIGGER trg_auth_cambio_password ON auth."user" IS 'Revoca todas las sesiones activas y registra tokens en blacklist al cambiar la contrase├▒a.';


--
-- Name: user trg_auth_intentos_fallidos; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_auth_intentos_fallidos BEFORE UPDATE ON auth."user" FOR EACH ROW EXECUTE FUNCTION public.fn_auth_intentos_fallidos();


--
-- Name: TRIGGER trg_auth_intentos_fallidos ON "user"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TRIGGER trg_auth_intentos_fallidos ON auth."user" IS 'Bloquea autom├íticamente la cuenta tras 5 intentos fallidos y cierra sesiones al desactivar o bloquear.';


--
-- Name: recovery_token trg_auth_mfa_reset; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_auth_mfa_reset AFTER UPDATE ON auth.recovery_token FOR EACH ROW EXECUTE FUNCTION public.fn_auth_mfa_reset();


--
-- Name: TRIGGER trg_auth_mfa_reset ON recovery_token; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TRIGGER trg_auth_mfa_reset ON auth.recovery_token IS 'Resetea el contador de intentos fallidos de MFA tras verificaci├│n exitosa del segundo factor.';


--
-- Name: user trg_config_user; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_config_user AFTER INSERT ON auth."user" FOR EACH ROW EXECUTE FUNCTION public.fn_config_user();


--
-- Name: TRIGGER trg_config_user ON "user"; Type: COMMENT; Schema: auth; Owner: -
--

COMMENT ON TRIGGER trg_config_user ON auth."user" IS 'Crea autom├íticamente la configuraci├│n personal del usuario al registrarse en el sistema.';


--
-- Name: mfa trg_updated_at_mfa; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_mfa BEFORE UPDATE ON auth.mfa FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: permission trg_updated_at_permission; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_permission BEFORE UPDATE ON auth.permission FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: role trg_updated_at_role; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_role BEFORE UPDATE ON auth.role FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: session trg_updated_at_session; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_session BEFORE UPDATE ON auth.session FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: user trg_updated_at_user; Type: TRIGGER; Schema: auth; Owner: -
--

CREATE TRIGGER trg_updated_at_user BEFORE UPDATE ON auth."user" FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: configuration_user trg_audit_configuration_user; Type: TRIGGER; Schema: config; Owner: -
--

CREATE TRIGGER trg_audit_configuration_user AFTER INSERT OR UPDATE ON config.configuration_user FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: configuration_user trg_updated_at_configuration_user; Type: TRIGGER; Schema: config; Owner: -
--

CREATE TRIGGER trg_updated_at_configuration_user BEFORE UPDATE ON config.configuration_user FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: consumption_metric trg_updated_at_consumption_metric; Type: TRIGGER; Schema: consumption; Owner: -
--

CREATE TRIGGER trg_updated_at_consumption_metric BEFORE UPDATE ON consumption.consumption_metric FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: recommendation trg_updated_at_recommendation; Type: TRIGGER; Schema: consumption; Owner: -
--

CREATE TRIGGER trg_updated_at_recommendation BEFORE UPDATE ON consumption.recommendation FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: device trg_audit_device; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_audit_device AFTER INSERT OR UPDATE ON devices.device FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: schedule trg_audit_schedule; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_audit_schedule AFTER INSERT OR UPDATE ON devices.schedule FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: threshold_rule trg_audit_threshold_rule; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_audit_threshold_rule AFTER INSERT OR UPDATE ON devices.threshold_rule FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: voice_assistant_token trg_audit_voice_assistant_token; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_audit_voice_assistant_token AFTER INSERT OR UPDATE ON devices.voice_assistant_token FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: device trg_updated_at_device; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_device BEFORE UPDATE ON devices.device FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: manual_device trg_updated_at_manual_device; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_manual_device BEFORE UPDATE ON devices.manual_device FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: schedule trg_updated_at_schedule; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_schedule BEFORE UPDATE ON devices.schedule FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: smart_device trg_updated_at_smart_device; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_smart_device BEFORE UPDATE ON devices.smart_device FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: threshold_rule trg_updated_at_threshold_rule; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_threshold_rule BEFORE UPDATE ON devices.threshold_rule FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: type_device trg_updated_at_type_device; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_type_device BEFORE UPDATE ON devices.type_device FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: voice_assistant_token trg_updated_at_voice_assistant_token; Type: TRIGGER; Schema: devices; Owner: -
--

CREATE TRIGGER trg_updated_at_voice_assistant_token BEFORE UPDATE ON devices.voice_assistant_token FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: area trg_audit_area; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_audit_area AFTER INSERT OR UPDATE ON homes.area FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: home trg_audit_home; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_audit_home AFTER INSERT OR UPDATE ON homes.home FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: home_member trg_audit_home_member; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_audit_home_member AFTER INSERT OR UPDATE ON homes.home_member FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: tariff trg_audit_tariff; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_audit_tariff AFTER INSERT OR UPDATE ON homes.tariff FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: area trg_updated_at_area; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_updated_at_area BEFORE UPDATE ON homes.area FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: home trg_updated_at_home; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_updated_at_home BEFORE UPDATE ON homes.home FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: tariff trg_updated_at_tariff; Type: TRIGGER; Schema: homes; Owner: -
--

CREATE TRIGGER trg_updated_at_tariff BEFORE UPDATE ON homes.tariff FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: notification trg_updated_at_notification; Type: TRIGGER; Schema: notifications; Owner: -
--

CREATE TRIGGER trg_updated_at_notification BEFORE UPDATE ON notifications.notification FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: reminder_notification trg_updated_at_reminder_notification; Type: TRIGGER; Schema: notifications; Owner: -
--

CREATE TRIGGER trg_updated_at_reminder_notification BEFORE UPDATE ON notifications.reminder_notification FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: backup trg_audit_backup; Type: TRIGGER; Schema: sync; Owner: -
--

CREATE TRIGGER trg_audit_backup AFTER INSERT ON sync.backup FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log();


--
-- Name: offline_queue trg_updated_at_offline_queue; Type: TRIGGER; Schema: sync; Owner: -
--

CREATE TRIGGER trg_updated_at_offline_queue BEFORE UPDATE ON sync.offline_queue FOR EACH ROW EXECUTE FUNCTION public.fn_updated_at();


--
-- Name: audit_log fk_audit_log_user; Type: FK CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.audit_log
    ADD CONSTRAINT fk_audit_log_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: mfa fk_mfa_user; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.mfa
    ADD CONSTRAINT fk_mfa_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: recovery_token fk_recovery_token_user; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.recovery_token
    ADD CONSTRAINT fk_recovery_token_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: role_permission fk_role_permission_perm; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.role_permission
    ADD CONSTRAINT fk_role_permission_perm FOREIGN KEY (id_permission) REFERENCES auth.permission(id_permission);


--
-- Name: role_permission fk_role_permission_role; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.role_permission
    ADD CONSTRAINT fk_role_permission_role FOREIGN KEY (id_role) REFERENCES auth.role(id_role);


--
-- Name: session fk_session_user; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.session
    ADD CONSTRAINT fk_session_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: token_blacklist fk_token_blacklist_user; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.token_blacklist
    ADD CONSTRAINT fk_token_blacklist_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: user_role fk_user_role_asignado; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role
    ADD CONSTRAINT fk_user_role_asignado FOREIGN KEY (asignado_por) REFERENCES auth."user"(id_user);


--
-- Name: user_role fk_user_role_role; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role
    ADD CONSTRAINT fk_user_role_role FOREIGN KEY (id_role) REFERENCES auth.role(id_role);


--
-- Name: user_role fk_user_role_user; Type: FK CONSTRAINT; Schema: auth; Owner: -
--

ALTER TABLE ONLY auth.user_role
    ADD CONSTRAINT fk_user_role_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: configuration_user fk_configuration_user_user; Type: FK CONSTRAINT; Schema: config; Owner: -
--

ALTER TABLE ONLY config.configuration_user
    ADD CONSTRAINT fk_configuration_user_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: consumption fk_consumption_device; Type: FK CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption
    ADD CONSTRAINT fk_consumption_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: consumption fk_consumption_home; Type: FK CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption
    ADD CONSTRAINT fk_consumption_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: consumption_metric fk_consumption_metric_device; Type: FK CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption_metric
    ADD CONSTRAINT fk_consumption_metric_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: consumption_metric fk_consumption_metric_home; Type: FK CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.consumption_metric
    ADD CONSTRAINT fk_consumption_metric_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: recommendation fk_recommendation_device; Type: FK CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.recommendation
    ADD CONSTRAINT fk_recommendation_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: recommendation fk_recommendation_home; Type: FK CONSTRAINT; Schema: consumption; Owner: -
--

ALTER TABLE ONLY consumption.recommendation
    ADD CONSTRAINT fk_recommendation_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: device fk_device_area; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device
    ADD CONSTRAINT fk_device_area FOREIGN KEY (id_area) REFERENCES homes.area(id_area);


--
-- Name: device fk_device_home; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device
    ADD CONSTRAINT fk_device_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: device_status_history fk_device_status_history_dev; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device_status_history
    ADD CONSTRAINT fk_device_status_history_dev FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: device_status_history fk_device_status_history_user; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device_status_history
    ADD CONSTRAINT fk_device_status_history_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: device fk_device_type; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.device
    ADD CONSTRAINT fk_device_type FOREIGN KEY (id_type_device) REFERENCES devices.type_device(id_type_device);


--
-- Name: manual_device fk_manual_device_device; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.manual_device
    ADD CONSTRAINT fk_manual_device_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: schedule fk_schedule_device; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.schedule
    ADD CONSTRAINT fk_schedule_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: smart_device fk_smart_device_device; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.smart_device
    ADD CONSTRAINT fk_smart_device_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: threshold_rule fk_threshold_rule_device; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.threshold_rule
    ADD CONSTRAINT fk_threshold_rule_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: voice_assistant_token fk_voice_assistant_token_user; Type: FK CONSTRAINT; Schema: devices; Owner: -
--

ALTER TABLE ONLY devices.voice_assistant_token
    ADD CONSTRAINT fk_voice_assistant_token_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: area fk_area_home; Type: FK CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.area
    ADD CONSTRAINT fk_area_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: home_member fk_home_member_home; Type: FK CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home_member
    ADD CONSTRAINT fk_home_member_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: home_member fk_home_member_user; Type: FK CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home_member
    ADD CONSTRAINT fk_home_member_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: home fk_home_user; Type: FK CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.home
    ADD CONSTRAINT fk_home_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: tariff fk_tariff_home; Type: FK CONSTRAINT; Schema: homes; Owner: -
--

ALTER TABLE ONLY homes.tariff
    ADD CONSTRAINT fk_tariff_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: alert fk_alert_device; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.alert
    ADD CONSTRAINT fk_alert_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: alert fk_alert_home; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.alert
    ADD CONSTRAINT fk_alert_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: alert fk_alert_threshold_rule; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.alert
    ADD CONSTRAINT fk_alert_threshold_rule FOREIGN KEY (id_threshold_rule) REFERENCES devices.threshold_rule(id_threshold_rule);


--
-- Name: notification fk_notification_device; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.notification
    ADD CONSTRAINT fk_notification_device FOREIGN KEY (id_device) REFERENCES devices.device(id_device);


--
-- Name: notification fk_notification_home; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.notification
    ADD CONSTRAINT fk_notification_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: notification fk_notification_user; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.notification
    ADD CONSTRAINT fk_notification_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: reminder_notification fk_reminder_notification_home; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.reminder_notification
    ADD CONSTRAINT fk_reminder_notification_home FOREIGN KEY (id_home) REFERENCES homes.home(id_home);


--
-- Name: reminder_notification fk_reminder_notification_user; Type: FK CONSTRAINT; Schema: notifications; Owner: -
--

ALTER TABLE ONLY notifications.reminder_notification
    ADD CONSTRAINT fk_reminder_notification_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: backup fk_backup_user; Type: FK CONSTRAINT; Schema: sync; Owner: -
--

ALTER TABLE ONLY sync.backup
    ADD CONSTRAINT fk_backup_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: offline_queue fk_offline_queue_user; Type: FK CONSTRAINT; Schema: sync; Owner: -
--

ALTER TABLE ONLY sync.offline_queue
    ADD CONSTRAINT fk_offline_queue_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: synchronization fk_synchronization_user; Type: FK CONSTRAINT; Schema: sync; Owner: -
--

ALTER TABLE ONLY sync.synchronization
    ADD CONSTRAINT fk_synchronization_user FOREIGN KEY (id_user) REFERENCES auth."user"(id_user);


--
-- Name: configuration_user; Type: ROW SECURITY; Schema: config; Owner: -
--

ALTER TABLE config.configuration_user ENABLE ROW LEVEL SECURITY;

--
-- Name: configuration_user configuration_user_insert_policy; Type: POLICY; Schema: config; Owner: -
--

CREATE POLICY configuration_user_insert_policy ON config.configuration_user FOR INSERT TO smarthome_app WITH CHECK ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: configuration_user configuration_user_select_policy; Type: POLICY; Schema: config; Owner: -
--

CREATE POLICY configuration_user_select_policy ON config.configuration_user FOR SELECT TO smarthome_app USING ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: configuration_user configuration_user_update_policy; Type: POLICY; Schema: config; Owner: -
--

CREATE POLICY configuration_user_update_policy ON config.configuration_user FOR UPDATE TO smarthome_app USING ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: consumption; Type: ROW SECURITY; Schema: consumption; Owner: -
--

ALTER TABLE consumption.consumption ENABLE ROW LEVEL SECURITY;

--
-- Name: consumption consumption_insert_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY consumption_insert_policy ON consumption.consumption FOR INSERT TO smarthome_app WITH CHECK ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: consumption_metric; Type: ROW SECURITY; Schema: consumption; Owner: -
--

ALTER TABLE consumption.consumption_metric ENABLE ROW LEVEL SECURITY;

--
-- Name: consumption_metric consumption_metric_insert_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY consumption_metric_insert_policy ON consumption.consumption_metric FOR INSERT TO smarthome_app WITH CHECK ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: consumption_metric consumption_metric_select_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY consumption_metric_select_policy ON consumption.consumption_metric FOR SELECT TO smarthome_app USING ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: consumption consumption_select_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY consumption_select_policy ON consumption.consumption FOR SELECT TO smarthome_app USING ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: recommendation; Type: ROW SECURITY; Schema: consumption; Owner: -
--

ALTER TABLE consumption.recommendation ENABLE ROW LEVEL SECURITY;

--
-- Name: recommendation recommendation_insert_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY recommendation_insert_policy ON consumption.recommendation FOR INSERT TO smarthome_app WITH CHECK ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: recommendation recommendation_select_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY recommendation_select_policy ON consumption.recommendation FOR SELECT TO smarthome_app USING (((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))) AND (deleted_at IS NULL)));


--
-- Name: recommendation recommendation_update_policy; Type: POLICY; Schema: consumption; Owner: -
--

CREATE POLICY recommendation_update_policy ON consumption.recommendation FOR UPDATE TO smarthome_app USING (((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))) AND (deleted_at IS NULL)));


--
-- Name: device; Type: ROW SECURITY; Schema: devices; Owner: -
--

ALTER TABLE devices.device ENABLE ROW LEVEL SECURITY;

--
-- Name: device device_delete_policy; Type: POLICY; Schema: devices; Owner: -
--

CREATE POLICY device_delete_policy ON devices.device FOR DELETE TO smarthome_app USING ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: device device_insert_policy; Type: POLICY; Schema: devices; Owner: -
--

CREATE POLICY device_insert_policy ON devices.device FOR INSERT TO smarthome_app WITH CHECK ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: device device_select_policy; Type: POLICY; Schema: devices; Owner: -
--

CREATE POLICY device_select_policy ON devices.device FOR SELECT TO smarthome_app USING (((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))) AND (deleted_at IS NULL)));


--
-- Name: device device_update_policy; Type: POLICY; Schema: devices; Owner: -
--

CREATE POLICY device_update_policy ON devices.device FOR UPDATE TO smarthome_app USING (((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))) AND (deleted_at IS NULL)));


--
-- Name: area; Type: ROW SECURITY; Schema: homes; Owner: -
--

ALTER TABLE homes.area ENABLE ROW LEVEL SECURITY;

--
-- Name: area area_delete_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY area_delete_policy ON homes.area FOR DELETE TO smarthome_app USING ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: area area_insert_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY area_insert_policy ON homes.area FOR INSERT TO smarthome_app WITH CHECK ((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))));


--
-- Name: area area_select_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY area_select_policy ON homes.area FOR SELECT TO smarthome_app USING (((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))) AND (deleted_at IS NULL)));


--
-- Name: area area_update_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY area_update_policy ON homes.area FOR UPDATE TO smarthome_app USING (((id_home IN ( SELECT home.id_home
   FROM homes.home
  WHERE ((home.id_user = (current_setting('app.current_user_id'::text))::uuid) AND (home.deleted_at IS NULL)))) AND (deleted_at IS NULL)));


--
-- Name: home; Type: ROW SECURITY; Schema: homes; Owner: -
--

ALTER TABLE homes.home ENABLE ROW LEVEL SECURITY;

--
-- Name: home home_delete_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY home_delete_policy ON homes.home FOR DELETE TO smarthome_app USING ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: home home_insert_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY home_insert_policy ON homes.home FOR INSERT TO smarthome_app WITH CHECK ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: home home_select_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY home_select_policy ON homes.home FOR SELECT TO smarthome_app USING (((id_user = (current_setting('app.current_user_id'::text))::uuid) AND (deleted_at IS NULL)));


--
-- Name: home home_update_policy; Type: POLICY; Schema: homes; Owner: -
--

CREATE POLICY home_update_policy ON homes.home FOR UPDATE TO smarthome_app USING (((id_user = (current_setting('app.current_user_id'::text))::uuid) AND (deleted_at IS NULL)));


--
-- Name: notification; Type: ROW SECURITY; Schema: notifications; Owner: -
--

ALTER TABLE notifications.notification ENABLE ROW LEVEL SECURITY;

--
-- Name: notification notification_delete_policy; Type: POLICY; Schema: notifications; Owner: -
--

CREATE POLICY notification_delete_policy ON notifications.notification FOR DELETE TO smarthome_app USING ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: notification notification_insert_policy; Type: POLICY; Schema: notifications; Owner: -
--

CREATE POLICY notification_insert_policy ON notifications.notification FOR INSERT TO smarthome_app WITH CHECK ((id_user = (current_setting('app.current_user_id'::text))::uuid));


--
-- Name: notification notification_select_policy; Type: POLICY; Schema: notifications; Owner: -
--

CREATE POLICY notification_select_policy ON notifications.notification FOR SELECT TO smarthome_app USING (((id_user = (current_setting('app.current_user_id'::text))::uuid) AND (deleted_at IS NULL)));


--
-- Name: notification notification_update_policy; Type: POLICY; Schema: notifications; Owner: -
--

CREATE POLICY notification_update_policy ON notifications.notification FOR UPDATE TO smarthome_app USING (((id_user = (current_setting('app.current_user_id'::text))::uuid) AND (deleted_at IS NULL)));


--
-- Name: mv_estadisticas_mensuales; Type: MATERIALIZED VIEW DATA; Schema: audit; Owner: -
--

REFRESH MATERIALIZED VIEW audit.mv_estadisticas_mensuales;


--
-- Name: mv_ranking_dispositivos; Type: MATERIALIZED VIEW DATA; Schema: consumption; Owner: -
--

REFRESH MATERIALIZED VIEW consumption.mv_ranking_dispositivos;


--
-- Name: mv_resumen_diario_hogar; Type: MATERIALIZED VIEW DATA; Schema: consumption; Owner: -
--

REFRESH MATERIALIZED VIEW consumption.mv_resumen_diario_hogar;


--
-- Name: mv_resumen_mensual_hogar; Type: MATERIALIZED VIEW DATA; Schema: consumption; Owner: -
--

REFRESH MATERIALIZED VIEW consumption.mv_resumen_mensual_hogar;


--
-- PostgreSQL database dump complete
--

\unrestrict CgwZtV57OqVnlaUZvR8Q0mzXDzRh0e2C6oTaySGnZawyN9I93CtIbUoWuqxWxAt

