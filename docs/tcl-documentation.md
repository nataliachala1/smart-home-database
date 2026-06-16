# Documentación TCL — Control de Transacciones Smart Home
**Proyecto:** Smart Home — Sistema inteligente de monitoreo y control de consumo de energía eléctrica  
**Versión:** 1.0.0  
**Fecha:** 2025  
**Autores:** Karen Daniela Holguín Cruz, Natalia Chala Chala, Kevin Stiven López Amaya  
**Instructor:** José de Jesús Motta Vargas  
**Institución:** SENA — Análisis y Desarrollo de Software (Ficha 3145555)

---

## Descripción General

Este documento describe la capa de control de transacciones del proyecto Smart Home. Define los bloques transaccionales para operaciones críticas de negocio, los procedimientos de recuperación manual ante fallos, y las marcas de versión (release tags) para el control del deployment de la base de datos con Liquibase.

El control de transacciones está organizado en tres secciones:

| Sección | Descripción | Carpeta |
|---|---|---|
| Transaction Blocks | Operaciones atómicas de negocio | `04_tcl/00_transaction_blocks` |
| Manual Recoveries | Procedimientos de recuperación y rollback | `04_tcl/01_manual_recoveries` |
| Release Tags | Marcas de versión y metadata de deployment | `04_tcl/02_release_tags` |

---

## Convenciones

| Convención | Descripción |
|---|---|
| Atomicidad | Toda operación de negocio crítica se ejecuta dentro de un bloque `BEGIN ... COMMIT` |
| Rollback | Ante cualquier error, se ejecuta `ROLLBACK` para revertir la operación completa |
| Savepoints | Se usan `SAVEPOINT` en operaciones largas para permitir recuperación parcial |
| Registro en auditoría | Toda transacción exitosa o fallida se registra en `audit.audit_log` |
| Idempotencia | Los scripts de recuperación pueden ejecutarse múltiples veces sin efectos secundarios |

---

## Estructura de Archivos

```
04_tcl/
├── 00_transaction_blocks/
│   ├── 001_tcl_registro_usuario.sql
│   ├── 002_tcl_registro_hogar.sql
│   ├── 003_tcl_registro_dispositivo.sql
│   ├── 004_tcl_desactivar_hogar.sql
│   ├── 005_tcl_desactivar_dispositivo.sql
│   ├── 006_tcl_restaurar_backup.sql
│   └── 007_tcl_sincronizacion_offline.sql
├── 01_manual_recoveries/
│   ├── 001_recovery_usuario_bloqueado.sql
│   ├── 002_recovery_hogar_desactivado.sql
│   ├── 003_recovery_dispositivo_desactivado.sql
│   └── 004_recovery_restauracion_fallida.sql
├── 02_release_tags/
│   ├── 001_tag_v1_0_0_initial.sql
│   └── 002_tag_v1_0_1_seed.sql
└── changelog.yaml
```

---

---

# 00_transaction_blocks — Bloques de Transacciones

## Descripción

Los bloques de transacciones garantizan que las operaciones de negocio críticas sean **atómicas**: o se ejecutan completamente o no se ejecutan en absoluto. Esto protege la integridad de los datos ante fallos de red, errores de aplicación o interrupciones inesperadas.

Cada bloque sigue esta estructura:

```sql
BEGIN;
  -- Operaciones de negocio
  SAVEPOINT nombre_savepoint;
  -- Más operaciones
COMMIT;

-- En caso de error:
ROLLBACK;
```

---

## 001 — Registro de Usuario
**Archivo:** `04_tcl/00_transaction_blocks/001_tcl_registro_usuario.sql`  
**Módulo SRS:** Módulo 1 — RF1.1  
**Descripción:** Garantiza que el registro de un nuevo usuario sea atómico. Incluye la creación del usuario, asignación del rol estándar, creación de su configuración por defecto y registro en auditoría. Si cualquier paso falla, se revierte todo.

**Operaciones incluidas:**
1. Insertar usuario en `auth.user`
2. Asignar rol `estandar` en `auth.user_role`
3. Crear configuración por defecto en `config.configuration_user`
4. Insertar token de confirmación en `auth.recovery_token`
5. Registrar en `audit.audit_log`

```sql
BEGIN;

  -- 1. Insertar nuevo usuario
  INSERT INTO auth.user (
    id_user, nombre, apellido, username, email, password_hash,
    tipo_documento, numero_documento, estado, email_verificado,
    created_at, updated_at
  )
  VALUES (
    :id_user, :nombre, :apellido, :username, :email,
    crypt(:password, gen_salt('bf', 12)),
    :tipo_documento, :numero_documento,
    'pendiente', FALSE,
    NOW(), NOW()
  );

  SAVEPOINT sp_usuario_creado;

  -- 2. Asignar rol estándar
  INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
  VALUES (
    uuid_generate_v4(), :id_user,
    'a1b2c3d4-0001-0000-0000-000000000002', -- rol estandar
    NOW()
  );

  SAVEPOINT sp_rol_asignado;

  -- 3. Crear configuración por defecto
  INSERT INTO config.configuration_user (
    id_configuration_user, id_user, idioma, tema,
    formato_fecha, formato_hora, moneda, created_at, updated_at
  )
  VALUES (
    uuid_generate_v4(), :id_user,
    'es', 'claro', 'DD/MM/YYYY', '24h', 'COP',
    NOW(), NOW()
  );

  SAVEPOINT sp_config_creada;

  -- 4. Crear token de confirmación de correo
  INSERT INTO auth.recovery_token (
    id_recovery_token, id_user, token, tipo, expira_en, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user,
    :token_confirmacion,
    'activacion_cuenta',
    NOW() + INTERVAL '24 hours',
    NOW()
  );

  SAVEPOINT sp_token_creado;

  -- 5. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'crear', 'usuarios',
    'user', :id_user, 'exitoso',
    'Registro de nuevo usuario en el sistema',
    NOW()
  );

COMMIT;

-- En caso de error en cualquier paso
-- ROLLBACK;
```

---

## 002 — Registro de Hogar
**Archivo:** `04_tcl/00_transaction_blocks/002_tcl_registro_hogar.sql`  
**Módulo SRS:** Módulo 2 — RF2.1  
**Descripción:** Garantiza que el registro de un nuevo hogar sea atómico. Incluye la creación del hogar, asignación del usuario como propietario y registro en auditoría.

**Operaciones incluidas:**
1. Insertar hogar en `homes.home`
2. Insertar propietario en `homes.home_member`
3. Registrar en `audit.audit_log`

```sql
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

-- En caso de error
-- ROLLBACK;
```

---

## 003 — Registro de Dispositivo
**Archivo:** `04_tcl/00_transaction_blocks/003_tcl_registro_dispositivo.sql`  
**Módulo SRS:** Módulo 3 — RF3.1  
**Descripción:** Garantiza que el registro de un nuevo dispositivo sea atómico. Incluye la creación del dispositivo, su vinculación al hogar y zona, creación del registro extendido (smart o manual) y registro en auditoría.

**Operaciones incluidas:**
1. Insertar dispositivo en `devices.device`
2. Insertar registro extendido en `devices.smart_device` o `devices.manual_device`
3. Registrar historial de estado inicial en `devices.device_status_history`
4. Registrar en `audit.audit_log`

```sql
BEGIN;

  -- 1. Insertar dispositivo
  INSERT INTO devices.device (
    id_device, id_home, id_area, id_type_device,
    nombre, estado, encendido, protocolo, created_at, updated_at
  )
  VALUES (
    :id_device, :id_home, :id_area, :id_type_device,
    :nombre, 'desconectado', FALSE, :protocolo,
    NOW(), NOW()
  );

  SAVEPOINT sp_dispositivo_creado;

  -- 2a. Si es dispositivo inteligente
  INSERT INTO devices.smart_device (
    id_smart_device, id_device, modelo, fabricante,
    capacidad_maxima_w, created_at, updated_at
  )
  VALUES (
    uuid_generate_v4(), :id_device, :modelo, :fabricante,
    :capacidad_maxima_w, NOW(), NOW()
  );

  SAVEPOINT sp_smart_device_creado;

  -- 3. Registrar estado inicial en historial
  INSERT INTO devices.device_status_history (
    id_device_status_history, id_device, estado_anterior,
    estado_nuevo, encendido, origen, id_user, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_device, NULL,
    'desconectado', FALSE, 'sistema', :id_user, NOW()
  );

  SAVEPOINT sp_historial_creado;

  -- 4. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'crear', 'dispositivos',
    'device', :id_device, 'exitoso',
    CONCAT('Registro de nuevo dispositivo: ', :nombre),
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 004 — Desactivar Hogar
**Archivo:** `04_tcl/00_transaction_blocks/004_tcl_desactivar_hogar.sql`  
**Módulo SRS:** Módulo 2 — RF2.4  
**Descripción:** Garantiza que la desactivación de un hogar sea atómica. Desactiva el hogar, sus zonas y desvincula los dispositivos asociados en una sola operación.

**Operaciones incluidas:**
1. Soft delete del hogar en `homes.home`
2. Soft delete de zonas en `homes.area`
3. Soft delete de dispositivos vinculados en `devices.device`
4. Desactivar horarios de dispositivos en `devices.schedule`
5. Desactivar reglas de umbral en `devices.threshold_rule`
6. Registrar en `audit.audit_log`

```sql
BEGIN;

  -- 1. Soft delete del hogar
  UPDATE homes.home
  SET
    estado     = 'desactivado',
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home    = :id_home
    AND deleted_at IS NULL;

  SAVEPOINT sp_hogar_desactivado;

  -- 2. Soft delete de zonas del hogar
  UPDATE homes.area
  SET deleted_at = NOW()
  WHERE id_home    = :id_home
    AND deleted_at IS NULL;

  SAVEPOINT sp_zonas_desactivadas;

  -- 3. Soft delete de dispositivos del hogar
  UPDATE devices.device
  SET
    estado     = 'desactivado',
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_home    = :id_home
    AND deleted_at IS NULL;

  SAVEPOINT sp_dispositivos_desactivados;

  -- 4. Desactivar horarios de dispositivos del hogar
  UPDATE devices.schedule
  SET
    activo     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device
    WHERE id_home = :id_home
  )
  AND deleted_at IS NULL;

  SAVEPOINT sp_horarios_desactivados;

  -- 5. Desactivar reglas de umbral del hogar
  UPDATE devices.threshold_rule
  SET
    activa     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device IN (
    SELECT id_device FROM devices.device
    WHERE id_home = :id_home
  )
  AND deleted_at IS NULL;

  SAVEPOINT sp_umbrales_desactivados;

  -- 6. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'eliminar', 'hogares',
    'home', :id_home, 'exitoso',
    'Desactivación lógica de hogar y sus datos asociados',
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 005 — Desactivar Dispositivo
**Archivo:** `04_tcl/00_transaction_blocks/005_tcl_desactivar_dispositivo.sql`  
**Módulo SRS:** Módulo 3 — RF3.4  
**Descripción:** Garantiza que la desactivación de un dispositivo sea atómica. Desactiva el dispositivo, sus horarios, reglas de umbral y registra el cambio de estado en el historial.

**Operaciones incluidas:**
1. Soft delete del dispositivo en `devices.device`
2. Desactivar horarios en `devices.schedule`
3. Desactivar reglas de umbral en `devices.threshold_rule`
4. Registrar cambio de estado en `devices.device_status_history`
5. Registrar en `audit.audit_log`

```sql
BEGIN;

  -- 1. Soft delete del dispositivo
  UPDATE devices.device
  SET
    estado     = 'desactivado',
    encendido  = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device  = :id_device
    AND deleted_at IS NULL;

  SAVEPOINT sp_dispositivo_desactivado;

  -- 2. Desactivar horarios del dispositivo
  UPDATE devices.schedule
  SET
    activo     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device  = :id_device
    AND deleted_at IS NULL;

  SAVEPOINT sp_horarios_desactivados;

  -- 3. Desactivar reglas de umbral del dispositivo
  UPDATE devices.threshold_rule
  SET
    activa     = FALSE,
    deleted_at = NOW(),
    updated_at = NOW()
  WHERE id_device  = :id_device
    AND deleted_at IS NULL;

  SAVEPOINT sp_umbrales_desactivados;

  -- 4. Registrar en historial de estados
  INSERT INTO devices.device_status_history (
    id_device_status_history, id_device, estado_anterior,
    estado_nuevo, encendido, origen, id_user, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_device, :estado_anterior,
    'desactivado', FALSE, 'usuario', :id_user, NOW()
  );

  SAVEPOINT sp_historial_registrado;

  -- 5. Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'eliminar', 'dispositivos',
    'device', :id_device, 'exitoso',
    'Desactivación lógica de dispositivo y sus configuraciones asociadas',
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 006 — Restaurar Backup
**Archivo:** `04_tcl/00_transaction_blocks/006_tcl_restaurar_backup.sql`  
**Módulo SRS:** Módulo 5 — RF5.3  
**Descripción:** Garantiza que el proceso de restauración de un backup sea atómico. Solo puede ser ejecutado por un usuario con rol administrador. Crea un backup de seguridad del estado actual antes de restaurar.

**Operaciones incluidas:**
1. Validar que el usuario tiene rol administrador
2. Registrar inicio de restauración en `audit.audit_log`
3. Crear registro de backup de seguridad en `sync.backup`
4. Registrar finalización en `audit.audit_log`

```sql
BEGIN;

  -- 1. Validar que el usuario es administrador
  DO $$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM auth.user_role ur
      JOIN auth.role r ON ur.id_role = r.id_role
      WHERE ur.id_user    = :'id_admin'::UUID
        AND r.nombre      = 'administrador'
        AND ur.deleted_at IS NULL
    ) THEN
      RAISE EXCEPTION 'El usuario no tiene permisos de administrador para ejecutar restauraciones.';
    END IF;
  END $$;

  SAVEPOINT sp_validacion_admin;

  -- 2. Registrar inicio de restauración en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'restaurar', 'sync',
    'backup', :id_backup, 'exitoso',
    CONCAT('Inicio de restauración de backup. Motivo: ', :motivo),
    NOW()
  );

  SAVEPOINT sp_auditoria_inicio;

  -- 3. Registrar backup de seguridad del estado actual
  INSERT INTO sync.backup (
    id_backup, id_user, tipo, alcance,
    ubicacion, estado, descripcion, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'automatico', 'completo',
    :ubicacion_backup_seguridad, 'completado',
    CONCAT('Backup de seguridad automático previo a restauración del backup: ', :id_backup),
    NOW()
  );

  SAVEPOINT sp_backup_seguridad;

  -- 4. Registrar finalización en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'restaurar', 'sync',
    'backup', :id_backup, 'exitoso',
    'Restauración de backup completada exitosamente',
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 007 — Sincronización de Cola Offline
**Archivo:** `04_tcl/00_transaction_blocks/007_tcl_sincronizacion_offline.sql`  
**Módulo SRS:** Módulo 5 — RF5.4  
**Descripción:** Garantiza que el procesamiento de la cola de acciones offline sea atómico. Procesa cada acción pendiente y actualiza su estado. Si una acción falla, solo se hace rollback de esa acción usando savepoints, sin afectar las demás.

**Operaciones incluidas:**
1. Obtener acciones pendientes de `sync.offline_queue`
2. Procesar cada acción individualmente con savepoints
3. Actualizar estado de cada acción en `sync.offline_queue`
4. Registrar sincronización en `sync.synchronization`

```sql
BEGIN;

  -- 1. Procesar cada acción pendiente con savepoint individual
  -- (El backend itera sobre las acciones pendientes)

  SAVEPOINT sp_antes_accion;

  -- 2. Marcar acción como procesada (si fue exitosa)
  UPDATE sync.offline_queue
  SET
    estado       = 'procesada',
    procesada_at = NOW()
  WHERE id_offline_queue = :id_accion
    AND estado           = 'pendiente';

  -- Si la acción falla, revertir solo esa acción
  -- ROLLBACK TO SAVEPOINT sp_antes_accion;
  -- UPDATE sync.offline_queue SET estado = 'fallida', intentos = intentos + 1
  -- WHERE id_offline_queue = :id_accion;

  SAVEPOINT sp_accion_procesada;

  -- 3. Registrar sincronización completada
  INSERT INTO sync.synchronization (
    id_synchronization, id_user, tipo, estado,
    dispositivos_sincronizados, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_user, 'manual', 'exitosa',
    :total_dispositivos, NOW()
  );

COMMIT;

-- En caso de error total
-- ROLLBACK;
```

---

---

# 01_manual_recoveries — Recuperaciones Manuales

## Descripción

Los scripts de recuperación manual permiten al administrador del sistema corregir estados inconsistentes en la base de datos que no pueden resolverse automáticamente. Deben ejecutarse con precaución y siempre registrar la acción en el log de auditoría.

> ⚠️ **Importante:** Estos scripts solo deben ser ejecutados por el administrador del sistema o el DBA. Siempre verificar el estado actual antes de ejecutar y hacer un backup previo.

---

## 001 — Recuperación de Usuario Bloqueado
**Archivo:** `04_tcl/01_manual_recoveries/001_recovery_usuario_bloqueado.sql`  
**Módulo SRS:** Módulo 1 — RF1.6  
**Descripción:** Desbloquea manualmente una cuenta de usuario que quedó bloqueada y resetea su contador de intentos fallidos.

```sql
BEGIN;

  -- Verificar estado actual del usuario antes de recuperar
  SELECT
    id_user, email, estado, intentos_fallidos, bloqueado_hasta
  FROM auth.user
  WHERE email      = :email_usuario
    AND deleted_at IS NULL;

  SAVEPOINT sp_verificacion;

  -- Desbloquear cuenta y resetear intentos
  UPDATE auth.user
  SET
    estado            = 'activo',
    intentos_fallidos = 0,
    bloqueado_hasta   = NULL,
    updated_at        = NOW()
  WHERE email      = :email_usuario
    AND deleted_at IS NULL;

  SAVEPOINT sp_usuario_desbloqueado;

  -- Invalidar sesiones activas por seguridad
  UPDATE auth.session
  SET
    activa     = FALSE,
    updated_at = NOW()
  WHERE id_user = (
    SELECT id_user FROM auth.user WHERE email = :email_usuario
  )
  AND activa     = TRUE
  AND deleted_at IS NULL;

  SAVEPOINT sp_sesiones_invalidadas;

  -- Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'editar', 'usuarios',
    'user', 'exitoso',
    CONCAT('Recuperación manual de cuenta bloqueada: ', :email_usuario),
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 002 — Recuperación de Hogar Desactivado
**Archivo:** `04_tcl/01_manual_recoveries/002_recovery_hogar_desactivado.sql`  
**Módulo SRS:** Módulo 2 — RF2.4  
**Descripción:** Reactiva manualmente un hogar que fue desactivado, restaurando también sus zonas y dispositivos al estado previo.

```sql
BEGIN;

  -- Verificar estado actual del hogar
  SELECT id_home, nombre, estado, deleted_at
  FROM homes.home
  WHERE id_home = :id_home;

  SAVEPOINT sp_verificacion;

  -- Reactivar hogar
  UPDATE homes.home
  SET
    estado     = 'activo',
    deleted_at = NULL,
    updated_at = NOW()
  WHERE id_home = :id_home;

  SAVEPOINT sp_hogar_reactivado;

  -- Reactivar zonas del hogar
  UPDATE homes.area
  SET deleted_at = NULL
  WHERE id_home = :id_home;

  SAVEPOINT sp_zonas_reactivadas;

  -- Reactivar dispositivos del hogar
  UPDATE devices.device
  SET
    estado     = 'desconectado',
    deleted_at = NULL,
    updated_at = NOW()
  WHERE id_home = :id_home;

  SAVEPOINT sp_dispositivos_reactivados;

  -- Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'editar', 'hogares',
    'home', :id_home, 'exitoso',
    'Recuperación manual de hogar desactivado y sus datos asociados',
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 003 — Recuperación de Dispositivo Desactivado
**Archivo:** `04_tcl/01_manual_recoveries/003_recovery_dispositivo_desactivado.sql`  
**Módulo SRS:** Módulo 3 — RF3.4  
**Descripción:** Reactiva manualmente un dispositivo desactivado, restaurando su estado a `desconectado` para que pueda volver a configurarse.

```sql
BEGIN;

  -- Verificar estado actual del dispositivo
  SELECT id_device, nombre, estado, deleted_at
  FROM devices.device
  WHERE id_device = :id_device;

  SAVEPOINT sp_verificacion;

  -- Reactivar dispositivo
  UPDATE devices.device
  SET
    estado     = 'desconectado',
    deleted_at = NULL,
    updated_at = NOW()
  WHERE id_device = :id_device;

  SAVEPOINT sp_dispositivo_reactivado;

  -- Registrar estado de reactivación en historial
  INSERT INTO devices.device_status_history (
    id_device_status_history, id_device, estado_anterior,
    estado_nuevo, encendido, origen, id_user, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_device, 'desactivado',
    'desconectado', FALSE, 'sistema', :id_admin, NOW()
  );

  SAVEPOINT sp_historial_registrado;

  -- Registrar en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'editar', 'dispositivos',
    'device', :id_device, 'exitoso',
    'Recuperación manual de dispositivo desactivado',
    NOW()
  );

COMMIT;

-- En caso de error
-- ROLLBACK;
```

---

## 004 — Recuperación de Restauración Fallida
**Archivo:** `04_tcl/01_manual_recoveries/004_recovery_restauracion_fallida.sql`  
**Módulo SRS:** Módulo 5 — RF5.3  
**Descripción:** Procedimiento de recuperación ante una restauración de backup que falló a mitad del proceso, dejando datos en estado inconsistente. Revierte los cambios parciales y restaura el backup de seguridad creado antes de la restauración.

```sql
BEGIN;

  -- 1. Verificar estado de la restauración fallida
  SELECT id_backup, estado, descripcion, created_at
  FROM sync.backup
  WHERE id_backup = :id_backup_fallido;

  SAVEPOINT sp_verificacion;

  -- 2. Marcar la restauración fallida como fallida en el registro
  UPDATE sync.backup
  SET estado = 'fallido'
  WHERE id_backup = :id_backup_fallido;

  SAVEPOINT sp_backup_marcado_fallido;

  -- 3. Registrar inicio de recuperación en auditoría
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'restaurar', 'sync',
    'backup', :id_backup_seguridad, 'exitoso',
    CONCAT('Recuperación manual tras restauración fallida. Usando backup de seguridad: ', :id_backup_seguridad),
    NOW()
  );

  SAVEPOINT sp_auditoria_recuperacion;

  -- 4. Registrar finalización de recuperación
  INSERT INTO audit.audit_log (
    id_audit_log, id_user, accion, modulo,
    entidad, id_entidad, resultado, detalle, created_at
  )
  VALUES (
    uuid_generate_v4(), :id_admin, 'restaurar', 'sync',
    'backup', :id_backup_seguridad, 'exitoso',
    'Recuperación manual completada exitosamente',
    NOW()
  );

COMMIT;

-- En caso de error durante la recuperación
-- ROLLBACK;
```

---

---

# 02_release_tags — Marcas de Versión

## Descripción

Los release tags son marcas de versión registradas en Liquibase que identifican el estado de la base de datos en cada deployment. Permiten rastrear qué cambios se han aplicado y en qué orden, facilitando rollbacks y auditorías de cambios estructurales.

### Convención de versiones

```
v{MAJOR}.{MINOR}.{PATCH}_{descripcion}

Ejemplos:
  v1.0.0_initial   → Versión inicial del sistema
  v1.0.1_seed      → Inserción de datos semilla
  v1.1.0_hotfix    → Corrección urgente
```

---

## 001 — Tag v1.0.0 — Estructura Inicial
**Archivo:** `04_tcl/02_release_tags/001_tag_v1_0_0_initial.sql`  
**Descripción:** Marca la versión 1.0.0 del sistema, correspondiente a la creación de toda la estructura DDL (esquemas, tablas, índices, vistas, funciones, triggers).

**Cambios incluidos en esta versión:**

| Componente | Descripción |
|---|---|
| Extensiones | `uuid-ossp`, `pgcrypto` |
| Esquemas | 8 esquemas: auth, homes, devices, consumption, notifications, sync, config, audit |
| Tablas | 32 tablas distribuidas en los 8 esquemas |
| Índices | Índices de búsqueda sobre columnas clave |
| Roles BD | smarthome_admin, smarthome_app, smarthome_readonly |
| Grants | Privilegios sobre todos los esquemas |
| Políticas RLS | 8 tablas con Row Level Security habilitado |

```sql
-- ============================================================
-- RELEASE TAG: v1.0.0 — Estructura Inicial Smart Home
-- Fecha: 2025
-- Autor: Equipo Smart Home — SENA Ficha 3145555
-- Descripción: Creación de la estructura completa de la BD
-- ============================================================

-- Registrar tag en auditoría del sistema
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'crear', 'sistema', 'release_tag', 'exitoso',
  'Release tag v1.0.0: Creación de estructura completa de la base de datos Smart Home. Incluye 8 esquemas, 32 tablas, índices, roles de BD, grants y políticas RLS.',
  NOW()
);

-- Nota Liquibase: Este tag se registra automáticamente
-- mediante el changelog.yaml con el atributo <tagDatabase>
-- Ejemplo en changelog.yaml:
--
-- - changeSet:
--     id: tag-v1.0.0
--     author: smarthome-team
--     changes:
--       - tagDatabase:
--           tag: v1.0.0
```

**Metadata del release:**

| Campo | Valor |
|---|---|
| Versión | v1.0.0 |
| Fecha | 2025 |
| Autor | Equipo Smart Home |
| Ambiente | desarrollo / producción |
| Estado | estable |
| Rollback disponible | Sí — `05_rollbacks/01_ddl/` |

---

## 002 — Tag v1.0.1 — Datos Semilla
**Archivo:** `04_tcl/02_release_tags/002_tag_v1_0_1_seed.sql`  
**Descripción:** Marca la versión 1.0.1 del sistema, correspondiente a la inserción de datos semilla iniciales (roles, permisos, tipos de dispositivos, usuario administrador).

**Cambios incluidos en esta versión:**

| Componente | Descripción |
|---|---|
| Roles | 3 roles: administrador, estandar, invitado |
| Permisos | 36 permisos distribuidos en 7 módulos |
| Role-Permission | Asignación de permisos a roles por principio de mínimo privilegio |
| Tipos de dispositivos | 13 tipos de dispositivos IoT |
| Usuario administrador | Usuario administrador por defecto del sistema |
| Auditoría seed | 5 registros de trazabilidad del seed inicial |

```sql
-- ============================================================
-- RELEASE TAG: v1.0.1 — Datos Semilla Smart Home
-- Fecha: 2025
-- Autor: Equipo Smart Home — SENA Ficha 3145555
-- Descripción: Inserción de datos iniciales del sistema
-- ============================================================

-- Registrar tag en auditoría del sistema
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'crear', 'sistema', 'release_tag', 'exitoso',
  'Release tag v1.0.1: Inserción de datos semilla. Incluye 3 roles, 36 permisos, 13 tipos de dispositivos y usuario administrador por defecto.',
  NOW()
);

-- Nota Liquibase:
-- - changeSet:
--     id: tag-v1.0.1
--     author: smarthome-team
--     changes:
--       - tagDatabase:
--           tag: v1.0.1
```

**Metadata del release:**

| Campo | Valor |
|---|---|
| Versión | v1.0.1 |
| Fecha | 2025 |
| Autor | Equipo Smart Home |
| Ambiente | desarrollo / producción |
| Estado | estable |
| Rollback disponible | Sí — `05_rollbacks/02_dml/` |

---

---

# Resumen de Transacciones por Módulo SRS

| Script | Módulo SRS | Operaciones atómicas | Savepoints |
|---|---|---|---|
| `001_tcl_registro_usuario.sql` | RF1.1 | 5 | 4 |
| `002_tcl_registro_hogar.sql` | RF2.1 | 3 | 2 |
| `003_tcl_registro_dispositivo.sql` | RF3.1 | 4 | 3 |
| `004_tcl_desactivar_hogar.sql` | RF2.4 | 6 | 5 |
| `005_tcl_desactivar_dispositivo.sql` | RF3.4 | 5 | 4 |
| `006_tcl_restaurar_backup.sql` | RF5.3 | 4 | 3 |
| `007_tcl_sincronizacion_offline.sql` | RF5.4 | 3 | 2 |

---

# Resumen de Recuperaciones Manuales

| Script | Caso de uso | Riesgo |
|---|---|---|
| `001_recovery_usuario_bloqueado.sql` | Cuenta bloqueada por intentos fallidos | Bajo |
| `002_recovery_hogar_desactivado.sql` | Hogar desactivado por error | Medio |
| `003_recovery_dispositivo_desactivado.sql` | Dispositivo desactivado por error | Bajo |
| `004_recovery_restauracion_fallida.sql` | Restauración de backup fallida | Alto |

---

# Resumen de Release Tags

| Tag | Versión | Contenido | Rollback |
|---|---|---|---|
| `001_tag_v1_0_0_initial.sql` | v1.0.0 | Estructura completa DDL | `05_rollbacks/01_ddl/` |
| `002_tag_v1_0_1_seed.sql` | v1.0.1 | Datos semilla DML | `05_rollbacks/02_dml/` |

---

# Orden de Ejecución

| Orden | Archivo | Descripción |
|---|---|---|
| 1 | `00_transaction_blocks/001_tcl_registro_usuario.sql` | Bloque transaccional de registro de usuario |
| 2 | `00_transaction_blocks/002_tcl_registro_hogar.sql` | Bloque transaccional de registro de hogar |
| 3 | `00_transaction_blocks/003_tcl_registro_dispositivo.sql` | Bloque transaccional de registro de dispositivo |
| 4 | `00_transaction_blocks/004_tcl_desactivar_hogar.sql` | Bloque transaccional de desactivación de hogar |
| 5 | `00_transaction_blocks/005_tcl_desactivar_dispositivo.sql` | Bloque transaccional de desactivación de dispositivo |
| 6 | `00_transaction_blocks/006_tcl_restaurar_backup.sql` | Bloque transaccional de restauración de backup |
| 7 | `00_transaction_blocks/007_tcl_sincronizacion_offline.sql` | Bloque transaccional de sincronización offline |
| 8 | `02_release_tags/001_tag_v1_0_0_initial.sql` | Tag de versión v1.0.0 |
| 9 | `02_release_tags/002_tag_v1_0_1_seed.sql` | Tag de versión v1.0.1 |

> **Nota:** Los scripts de `01_manual_recoveries` no tienen un orden fijo de ejecución. Se ejecutan únicamente cuando el administrador los necesita para corregir estados inconsistentes.

---

# Referencias

| Documento | Descripción |
|---|---|
| SRS_FINAL.docx | Especificación de Requisitos de Software |
| ddl-documentation.md | Documentación de estructura de tablas |
| dml-documentation.md | Documentación de datos iniciales |
| dcl-access-control.md | Documentación de control de acceso |
| sql-layer-architecture.md | Arquitectura de la capa de base de datos |