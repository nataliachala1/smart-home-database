# Documentación DML — Smart Home
**Proyecto:** Smart Home — Sistema inteligente de monitoreo y control de co
nsumo de energía eléctrica  
**Versión:** 1.0.0  
**Fecha:** 2025  
**Autores:** Karen Daniela Holguín Cruz, Natalia Chala Chala, Kevin Stiven López Amaya  
**Instructor:** José de Jesús Motta Vargas  
**Institución:** SENA — Análisis y Desarrollo de Software (Ficha 3145555)

---

## Descripción General

Este documento describe los datos iniciales (seed data) necesarios para que el sistema Smart Home funcione correctamente desde el primer arranque. Incluye la inserción de roles, permisos, tipos de dispositivos, usuario administrador por defecto y configuraciones base del sistema.

Los scripts DML están organizados en la siguiente estructura:

```
02_dml/
├── 00_inserts/       → Datos iniciales del sistema (seed data)
├── 01_updates/       → Actualizaciones de datos existentes
├── 02_deletes/       → Eliminaciones controladas
├── 03_upserts/       → Inserción o actualización combinada
├── 04_patches/       → Parches de datos puntuales
└── changelog.yaml    → Control de versiones Liquibase
```

---

## Convenciones

| Convención | Descripción |
|---|---|
| Orden de ejecución | Los scripts deben ejecutarse en el orden numérico definido para respetar las dependencias entre tablas |
| UUIDs | Se usan UUIDs fijos para los datos semilla, facilitando referencias cruzadas y rollbacks |
| Idempotencia | Todos los inserts usan `INSERT ... ON CONFLICT DO NOTHING` para permitir re-ejecución segura |
| Soft delete | Los datos semilla nunca tienen `deleted_at` poblado |
| Fechas | Se usa `NOW()` o fechas fijas según corresponda |

---

---

# 00_inserts — Datos Iniciales del Sistema

## 001 — Roles del Sistema
**Archivo:** `02_dml/00_inserts/001_insert_roles.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.role`  
**Descripción:** Inserta los tres roles base del sistema definidos en el SRS (RF1.3). Estos roles determinan el nivel de acceso de cada usuario.

| id_role | nombre | descripcion |
|---|---|---|
| `a1b2c3d4-0001-0000-0000-000000000001` | administrador | Acceso total al sistema. Puede gestionar usuarios, roles, backups, logs de auditoría y toda la configuración del sistema. |
| `a1b2c3d4-0001-0000-0000-000000000002` | estandar | Acceso a funcionalidades propias del hogar. Puede gestionar hogares, dispositivos, consumo y configuración personal. |
| `a1b2c3d4-0001-0000-0000-000000000003` | invitado | Acceso de solo lectura. Puede visualizar consumo y estado de dispositivos sin realizar cambios. |

```sql
INSERT INTO auth.role (id_role, nombre, descripcion, created_at, updated_at)
VALUES
  ('a1b2c3d4-0001-0000-0000-000000000001', 'administrador',
   'Acceso total al sistema. Puede gestionar usuarios, roles, backups, logs de auditoría y toda la configuración del sistema.',
   NOW(), NOW()),
  ('a1b2c3d4-0001-0000-0000-000000000002', 'estandar',
   'Acceso a funcionalidades propias del hogar. Puede gestionar hogares, dispositivos, consumo y configuración personal.',
   NOW(), NOW()),
  ('a1b2c3d4-0001-0000-0000-000000000003', 'invitado',
   'Acceso de solo lectura. Puede visualizar consumo y estado de dispositivos sin realizar cambios.',
   NOW(), NOW())
ON CONFLICT (id_role) DO NOTHING;
```

---

## 002 — Permisos del Sistema
**Archivo:** `02_dml/00_inserts/002_insert_permisos.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.permission`  
**Descripción:** Inserta todos los permisos del sistema organizados por módulo y acción. Cada permiso habilita una funcionalidad específica del SRS.

### Módulo 1 — Gestión de Usuarios y Autenticación

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| usuarios:leer | usuarios | leer | Ver listado y detalle de usuarios |
| usuarios:crear | usuarios | crear | Registrar nuevos usuarios |
| usuarios:editar | usuarios | editar | Modificar datos de usuarios |
| usuarios:eliminar | usuarios | eliminar | Desactivar cuentas de usuarios |
| roles:asignar | usuarios | editar | Asignar y modificar roles de usuarios |
| usuarios:ver_todos | usuarios | leer | Ver todos los usuarios del sistema |

### Módulo 2 — Gestión de Hogares y Espacios

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| hogares:leer | hogares | leer | Ver hogares propios |
| hogares:crear | hogares | crear | Registrar nuevos hogares |
| hogares:editar | hogares | editar | Modificar datos del hogar |
| hogares:desactivar | hogares | eliminar | Desactivar hogares |
| zonas:crear | hogares | crear | Crear zonas dentro de un hogar |
| zonas:editar | hogares | editar | Editar zonas existentes |
| zonas:eliminar | hogares | eliminar | Eliminar zonas del hogar |
| tarifas:configurar | hogares | editar | Configurar tarifas eléctricas |

### Módulo 3 — Gestión de Dispositivos

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| dispositivos:leer | dispositivos | leer | Ver dispositivos registrados |
| dispositivos:crear | dispositivos | crear | Registrar nuevos dispositivos |
| dispositivos:editar | dispositivos | editar | Modificar configuración de dispositivos |
| dispositivos:desactivar | dispositivos | eliminar | Desactivar dispositivos |
| dispositivos:controlar | dispositivos | editar | Encender/apagar dispositivos remotamente |
| dispositivos:configurar_horarios | dispositivos | editar | Configurar horarios automáticos |
| dispositivos:configurar_umbrales | dispositivos | editar | Configurar umbrales de consumo |
| asistente_voz:vincular | dispositivos | crear | Vincular asistentes de voz |

### Módulo 4 — Monitoreo y Consumo Energético

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| consumo:leer | consumo | leer | Ver consumo en tiempo real |
| consumo:reportes | consumo | leer | Generar y ver reportes de consumo |
| consumo:graficos | consumo | leer | Ver gráficos de consumo |
| recomendaciones:leer | consumo | leer | Ver recomendaciones de ahorro |
| recomendaciones:configurar | consumo | editar | Configurar recomendaciones automáticas |
| notificaciones:leer | consumo | leer | Ver notificaciones |
| notificaciones:configurar | consumo | editar | Configurar preferencias de notificaciones |

### Módulo 5 — Sincronización de Plataforma

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| sync:manual | sync | editar | Forzar sincronización manual |
| backups:restaurar | sync | editar | Restaurar información desde backup |
| backups:leer | sync | leer | Ver backups disponibles |

### Módulo 6 — Personalización e Internacionalización

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| config:leer | config | leer | Ver configuración personal |
| config:editar | config | editar | Modificar configuración personal |

### Módulo 7 — Auditoría y Trazabilidad

| nombre | modulo | accion | descripcion |
|---|---|---|---|
| auditoria:leer | auditoria | leer | Consultar logs de auditoría |
| auditoria:exportar | auditoria | leer | Exportar registros de auditoría |

```sql
INSERT INTO auth.permission (id_permission, nombre, modulo, accion, descripcion, created_at, updated_at)
VALUES
  -- Módulo usuarios
  (uuid_generate_v4(), 'usuarios:leer',       'usuarios', 'leer',    'Ver listado y detalle de usuarios', NOW(), NOW()),
  (uuid_generate_v4(), 'usuarios:crear',      'usuarios', 'crear',   'Registrar nuevos usuarios', NOW(), NOW()),
  (uuid_generate_v4(), 'usuarios:editar',     'usuarios', 'editar',  'Modificar datos de usuarios', NOW(), NOW()),
  (uuid_generate_v4(), 'usuarios:eliminar',   'usuarios', 'eliminar','Desactivar cuentas de usuarios', NOW(), NOW()),
  (uuid_generate_v4(), 'roles:asignar',       'usuarios', 'editar',  'Asignar y modificar roles de usuarios', NOW(), NOW()),
  (uuid_generate_v4(), 'usuarios:ver_todos',  'usuarios', 'leer',    'Ver todos los usuarios del sistema', NOW(), NOW()),
  -- Módulo hogares
  (uuid_generate_v4(), 'hogares:leer',        'hogares',  'leer',    'Ver hogares propios', NOW(), NOW()),
  (uuid_generate_v4(), 'hogares:crear',       'hogares',  'crear',   'Registrar nuevos hogares', NOW(), NOW()),
  (uuid_generate_v4(), 'hogares:editar',      'hogares',  'editar',  'Modificar datos del hogar', NOW(), NOW()),
  (uuid_generate_v4(), 'hogares:desactivar',  'hogares',  'eliminar','Desactivar hogares', NOW(), NOW()),
  (uuid_generate_v4(), 'zonas:crear',         'hogares',  'crear',   'Crear zonas dentro de un hogar', NOW(), NOW()),
  (uuid_generate_v4(), 'zonas:editar',        'hogares',  'editar',  'Editar zonas existentes', NOW(), NOW()),
  (uuid_generate_v4(), 'zonas:eliminar',      'hogares',  'eliminar','Eliminar zonas del hogar', NOW(), NOW()),
  (uuid_generate_v4(), 'tarifas:configurar',  'hogares',  'editar',  'Configurar tarifas eléctricas', NOW(), NOW()),
  -- Módulo dispositivos
  (uuid_generate_v4(), 'dispositivos:leer',              'dispositivos', 'leer',    'Ver dispositivos registrados', NOW(), NOW()),
  (uuid_generate_v4(), 'dispositivos:crear',             'dispositivos', 'crear',   'Registrar nuevos dispositivos', NOW(), NOW()),
  (uuid_generate_v4(), 'dispositivos:editar',            'dispositivos', 'editar',  'Modificar configuración de dispositivos', NOW(), NOW()),
  (uuid_generate_v4(), 'dispositivos:desactivar',        'dispositivos', 'eliminar','Desactivar dispositivos', NOW(), NOW()),
  (uuid_generate_v4(), 'dispositivos:controlar',         'dispositivos', 'editar',  'Encender/apagar dispositivos remotamente', NOW(), NOW()),
  (uuid_generate_v4(), 'dispositivos:configurar_horarios','dispositivos','editar',  'Configurar horarios automáticos', NOW(), NOW()),
  (uuid_generate_v4(), 'dispositivos:configurar_umbrales','dispositivos','editar',  'Configurar umbrales de consumo', NOW(), NOW()),
  (uuid_generate_v4(), 'asistente_voz:vincular',         'dispositivos', 'crear',   'Vincular asistentes de voz', NOW(), NOW()),
  -- Módulo consumo
  (uuid_generate_v4(), 'consumo:leer',                'consumo', 'leer',  'Ver consumo en tiempo real', NOW(), NOW()),
  (uuid_generate_v4(), 'consumo:reportes',            'consumo', 'leer',  'Generar y ver reportes de consumo', NOW(), NOW()),
  (uuid_generate_v4(), 'consumo:graficos',            'consumo', 'leer',  'Ver gráficos de consumo', NOW(), NOW()),
  (uuid_generate_v4(), 'recomendaciones:leer',        'consumo', 'leer',  'Ver recomendaciones de ahorro', NOW(), NOW()),
  (uuid_generate_v4(), 'recomendaciones:configurar',  'consumo', 'editar','Configurar recomendaciones automáticas', NOW(), NOW()),
  (uuid_generate_v4(), 'notificaciones:leer',         'consumo', 'leer',  'Ver notificaciones', NOW(), NOW()),
  (uuid_generate_v4(), 'notificaciones:configurar',   'consumo', 'editar','Configurar preferencias de notificaciones', NOW(), NOW()),
  -- Módulo sync
  (uuid_generate_v4(), 'sync:manual',       'sync', 'editar','Forzar sincronización manual', NOW(), NOW()),
  (uuid_generate_v4(), 'backups:restaurar', 'sync', 'editar','Restaurar información desde backup', NOW(), NOW()),
  (uuid_generate_v4(), 'backups:leer',      'sync', 'leer',  'Ver backups disponibles', NOW(), NOW()),
  -- Módulo config
  (uuid_generate_v4(), 'config:leer',  'config', 'leer',  'Ver configuración personal', NOW(), NOW()),
  (uuid_generate_v4(), 'config:editar','config', 'editar','Modificar configuración personal', NOW(), NOW()),
  -- Módulo auditoría
  (uuid_generate_v4(), 'auditoria:leer',    'auditoria', 'leer','Consultar logs de auditoría', NOW(), NOW()),
  (uuid_generate_v4(), 'auditoria:exportar','auditoria', 'leer','Exportar registros de auditoría', NOW(), NOW())
ON CONFLICT (nombre) DO NOTHING;
```

---

## 003 — Asignación de Permisos a Roles
**Archivo:** `02_dml/00_inserts/003_insert_role_permissions.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.role_permission`  
**Descripción:** Asigna los permisos correspondientes a cada rol del sistema según el principio de mínimo privilegio.

### Permisos del rol: `administrador`
El rol administrador tiene acceso a **todos los permisos** del sistema.

```sql
-- Asignar todos los permisos al rol administrador
INSERT INTO auth.role_permission (id_role_permission, id_role, id_permission, created_at)
SELECT
  uuid_generate_v4(),
  'a1b2c3d4-0001-0000-0000-000000000001',
  id_permission,
  NOW()
FROM auth.permission
ON CONFLICT (id_role, id_permission) DO NOTHING;
```

### Permisos del rol: `estandar`
El rol estándar tiene acceso a la gestión de sus propios hogares, dispositivos y consumo, pero **no** puede acceder a auditoría, gestión de usuarios ni restaurar backups.

| Permisos asignados |
|---|
| hogares:leer, hogares:crear, hogares:editar, hogares:desactivar |
| zonas:crear, zonas:editar, zonas:eliminar |
| tarifas:configurar |
| dispositivos:leer, dispositivos:crear, dispositivos:editar, dispositivos:desactivar |
| dispositivos:controlar, dispositivos:configurar_horarios, dispositivos:configurar_umbrales |
| asistente_voz:vincular |
| consumo:leer, consumo:reportes, consumo:graficos |
| recomendaciones:leer, recomendaciones:configurar |
| notificaciones:leer, notificaciones:configurar |
| sync:manual |
| config:leer, config:editar |

```sql
INSERT INTO auth.role_permission (id_role_permission, id_role, id_permission, created_at)
SELECT
  uuid_generate_v4(),
  'a1b2c3d4-0001-0000-0000-000000000002',
  id_permission,
  NOW()
FROM auth.permission
WHERE nombre IN (
  'hogares:leer', 'hogares:crear', 'hogares:editar', 'hogares:desactivar',
  'zonas:crear', 'zonas:editar', 'zonas:eliminar',
  'tarifas:configurar',
  'dispositivos:leer', 'dispositivos:crear', 'dispositivos:editar', 'dispositivos:desactivar',
  'dispositivos:controlar', 'dispositivos:configurar_horarios', 'dispositivos:configurar_umbrales',
  'asistente_voz:vincular',
  'consumo:leer', 'consumo:reportes', 'consumo:graficos',
  'recomendaciones:leer', 'recomendaciones:configurar',
  'notificaciones:leer', 'notificaciones:configurar',
  'sync:manual',
  'config:leer', 'config:editar'
)
ON CONFLICT (id_role, id_permission) DO NOTHING;
```

### Permisos del rol: `invitado`
El rol invitado tiene acceso de **solo lectura** a consumo, dispositivos y notificaciones.

| Permisos asignados |
|---|
| hogares:leer |
| dispositivos:leer |
| consumo:leer, consumo:graficos |
| notificaciones:leer |
| config:leer, config:editar |

```sql
INSERT INTO auth.role_permission (id_role_permission, id_role, id_permission, created_at)
SELECT
  uuid_generate_v4(),
  'a1b2c3d4-0001-0000-0000-000000000003',
  id_permission,
  NOW()
FROM auth.permission
WHERE nombre IN (
  'hogares:leer',
  'dispositivos:leer',
  'consumo:leer', 'consumo:graficos',
  'notificaciones:leer',
  'config:leer', 'config:editar'
)
ON CONFLICT (id_role, id_permission) DO NOTHING;
```

---

## 004 — Tipos de Dispositivos
**Archivo:** `02_dml/00_inserts/004_insert_tipos_dispositivos.sql`  
**Esquema:** `devices`  
**Tabla:** `devices.type_device`  
**Descripción:** Inserta el catálogo inicial de tipos de dispositivos IoT compatibles con el sistema Smart Home.

| nombre | descripcion | icono |
|---|---|---|
| Lámpara inteligente | Bombilla o lámpara con control remoto de encendido/apagado y consumo medible | lamp |
| Enchufe inteligente | Enchufe con monitoreo de consumo y control remoto | plug |
| Aire acondicionado | Sistema de climatización con control de temperatura y programación | ac |
| Calentador de agua | Calentador eléctrico de agua con control de temperatura | heater |
| Lavadora | Electrodoméstico de lavado con monitoreo de ciclos y consumo | washer |
| Nevera | Refrigerador con monitoreo de consumo energético | fridge |
| Televisor | Televisor con control remoto y monitoreo de consumo | tv |
| Computador | Equipo de cómputo con monitoreo de consumo | computer |
| Horno microondas | Microondas con monitoreo de uso y consumo | microwave |
| Sensor de consumo | Sensor genérico de medición de consumo eléctrico | sensor |
| Ventilador | Ventilador con control remoto y monitoreo de consumo | fan |
| Cargador | Punto de carga para dispositivos móviles o vehículos eléctricos | charger |
| Otro | Dispositivo genérico no clasificado en las categorías anteriores | device |

```sql
INSERT INTO devices.type_device (id_type_device, nombre, descripcion, icono, created_at, updated_at)
VALUES
  (uuid_generate_v4(), 'Lámpara inteligente',  'Bombilla o lámpara con control remoto de encendido/apagado y consumo medible', 'lamp',      NOW(), NOW()),
  (uuid_generate_v4(), 'Enchufe inteligente',  'Enchufe con monitoreo de consumo y control remoto',                           'plug',      NOW(), NOW()),
  (uuid_generate_v4(), 'Aire acondicionado',   'Sistema de climatización con control de temperatura y programación',          'ac',        NOW(), NOW()),
  (uuid_generate_v4(), 'Calentador de agua',   'Calentador eléctrico de agua con control de temperatura',                    'heater',    NOW(), NOW()),
  (uuid_generate_v4(), 'Lavadora',             'Electrodoméstico de lavado con monitoreo de ciclos y consumo',               'washer',    NOW(), NOW()),
  (uuid_generate_v4(), 'Nevera',               'Refrigerador con monitoreo de consumo energético',                           'fridge',    NOW(), NOW()),
  (uuid_generate_v4(), 'Televisor',            'Televisor con control remoto y monitoreo de consumo',                        'tv',        NOW(), NOW()),
  (uuid_generate_v4(), 'Computador',           'Equipo de cómputo con monitoreo de consumo',                                 'computer',  NOW(), NOW()),
  (uuid_generate_v4(), 'Horno microondas',     'Microondas con monitoreo de uso y consumo',                                  'microwave', NOW(), NOW()),
  (uuid_generate_v4(), 'Sensor de consumo',    'Sensor genérico de medición de consumo eléctrico',                           'sensor',    NOW(), NOW()),
  (uuid_generate_v4(), 'Ventilador',           'Ventilador con control remoto y monitoreo de consumo',                       'fan',       NOW(), NOW()),
  (uuid_generate_v4(), 'Cargador',             'Punto de carga para dispositivos móviles o vehículos eléctricos',            'charger',   NOW(), NOW()),
  (uuid_generate_v4(), 'Otro',                 'Dispositivo genérico no clasificado en las categorías anteriores',           'device',    NOW(), NOW())
ON CONFLICT (nombre) DO NOTHING;
```

---

## 005 — Usuario Administrador por Defecto
**Archivo:** `02_dml/00_inserts/005_insert_admin_user.sql`  
**Esquema:** `auth`  
**Tablas:** `auth.user`, `auth.user_role`, `config.configuration_user`  
**Descripción:** Crea el usuario administrador inicial del sistema. Este usuario debe cambiar su contraseña en el primer inicio de sesión.

> ⚠️ **Importante:** La contraseña `Admin@SmartHome2025` es solo para el arranque inicial del sistema. Debe cambiarse obligatoriamente antes de pasar a producción.

| Campo | Valor |
|---|---|
| id_user | `a1b2c3d4-9999-0000-0000-000000000001` |
| nombre | Administrador |
| apellido | Sistema |
| username | admin_smarthome |
| email | admin@smarthome.com |
| tipo_documento | CC |
| numero_documento | 0000000001 |
| estado | activo |
| email_verificado | TRUE |
| rol asignado | administrador |

```sql
-- Insertar usuario administrador
INSERT INTO auth.user (
  id_user, nombre, apellido, username, email, password_hash,
  tipo_documento, numero_documento, estado, email_verificado,
  created_at, updated_at
)
VALUES (
  'a1b2c3d4-9999-0000-0000-000000000001',
  'Administrador',
  'Sistema',
  'admin_smarthome',
  'admin@smarthome.com',
  crypt('Admin@SmartHome2025', gen_salt('bf', 12)),
  'CC',
  '0000000001',
  'activo',
  TRUE,
  NOW(),
  NOW()
)
ON CONFLICT (id_user) DO NOTHING;

-- Asignar rol administrador al usuario
INSERT INTO auth.user_role (id_user_role, id_user, id_role, created_at)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'a1b2c3d4-0001-0000-0000-000000000001',
  NOW()
)
ON CONFLICT (id_user, id_role) DO NOTHING;

-- Crear configuración por defecto para el administrador
INSERT INTO config.configuration_user (
  id_configuration_user, id_user, idioma, tema, formato_fecha,
  formato_hora, moneda, created_at, updated_at
)
VALUES (
  uuid_generate_v4(),
  'a1b2c3d4-9999-0000-0000-000000000001',
  'es', 'claro', 'DD/MM/YYYY', '24h', 'COP',
  NOW(), NOW()
)
ON CONFLICT (id_user) DO NOTHING;
```

---

## 006 — Registro en Auditoría del Seed Inicial
**Archivo:** `02_dml/00_inserts/006_insert_auditoria_seed.sql`  
**Esquema:** `audit`  
**Tabla:** `audit.audit_log`  
**Descripción:** Registra en el log de auditoría la ejecución del seed inicial del sistema para trazabilidad completa desde el primer arranque.

```sql
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo, entidad,
  resultado, detalle, created_at
)
VALUES
  (uuid_generate_v4(), 'a1b2c3d4-9999-0000-0000-000000000001',
   'crear', 'sistema', 'role', 'exitoso',
   'Seed inicial: inserción de roles base del sistema (administrador, estandar, invitado)',
   NOW()),
  (uuid_generate_v4(), 'a1b2c3d4-9999-0000-0000-000000000001',
   'crear', 'sistema', 'permission', 'exitoso',
   'Seed inicial: inserción de permisos del sistema por módulo',
   NOW()),
  (uuid_generate_v4(), 'a1b2c3d4-9999-0000-0000-000000000001',
   'crear', 'sistema', 'role_permission', 'exitoso',
   'Seed inicial: asignación de permisos a roles',
   NOW()),
  (uuid_generate_v4(), 'a1b2c3d4-9999-0000-0000-000000000001',
   'crear', 'sistema', 'type_device', 'exitoso',
   'Seed inicial: inserción de catálogo de tipos de dispositivos',
   NOW()),
  (uuid_generate_v4(), 'a1b2c3d4-9999-0000-0000-000000000001',
   'crear', 'sistema', 'user', 'exitoso',
   'Seed inicial: creación de usuario administrador por defecto',
   NOW());
```

---

---

# 01_updates — Actualizaciones de Datos

## 001 — Actualización de Contraseña del Administrador
**Archivo:** `02_dml/01_updates/001_update_admin_password.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.user`  
**Descripción:** Script de referencia para actualizar la contraseña del administrador por defecto. Debe ejecutarse antes de pasar a producción.

> ⚠️ **Reemplazar** `NUEVA_CONTRASEÑA_SEGURA` con la contraseña real antes de ejecutar.

```sql
UPDATE auth.user
SET
  password_hash = crypt('NUEVA_CONTRASEÑA_SEGURA', gen_salt('bf', 12)),
  updated_at    = NOW()
WHERE id_user = 'a1b2c3d4-9999-0000-0000-000000000001'
  AND deleted_at IS NULL;
```

---

## 002 — Actualización de Estado de Usuario
**Archivo:** `02_dml/01_updates/002_update_estado_usuario.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.user`  
**Descripción:** Script de referencia para actualizar el estado de un usuario (activar, desactivar, bloquear). Se usa en los flujos de RF1.5 y RF1.6.

```sql
-- Activar cuenta de usuario
UPDATE auth.user
SET
  estado     = 'activo',
  updated_at = NOW()
WHERE email      = :email_usuario
  AND deleted_at IS NULL;

-- Desactivar cuenta de usuario
UPDATE auth.user
SET
  estado     = 'desactivado',
  updated_at = NOW()
WHERE email      = :email_usuario
  AND deleted_at IS NULL;

-- Bloquear cuenta tras múltiples intentos fallidos
UPDATE auth.user
SET
  estado           = 'bloqueado',
  bloqueado_hasta  = NOW() + INTERVAL '15 minutes',
  updated_at       = NOW()
WHERE email      = :email_usuario
  AND deleted_at IS NULL;

-- Desbloquear cuenta tras expirar el tiempo
UPDATE auth.user
SET
  estado           = 'activo',
  intentos_fallidos = 0,
  bloqueado_hasta  = NULL,
  updated_at       = NOW()
WHERE bloqueado_hasta < NOW()
  AND estado       = 'bloqueado'
  AND deleted_at   IS NULL;
```

---

## 003 — Actualización de Configuración de Usuario
**Archivo:** `02_dml/01_updates/003_update_config_usuario.sql`  
**Esquema:** `config`  
**Tabla:** `config.configuration_user`  
**Descripción:** Script de referencia para actualizar las preferencias de un usuario (idioma, tema, notificaciones). Se usa en los flujos de RF6.1 y RF6.2.

```sql
-- Cambiar idioma del usuario
UPDATE config.configuration_user
SET
  idioma     = :nuevo_idioma,
  updated_at = NOW()
WHERE id_user = :id_usuario;

-- Cambiar tema visual del usuario
UPDATE config.configuration_user
SET
  tema       = :nuevo_tema,
  updated_at = NOW()
WHERE id_user = :id_usuario;

-- Actualizar preferencias de notificaciones
UPDATE config.configuration_user
SET
  notif_consumo_elevado  = :valor,
  notif_dispositivos     = :valor,
  notif_recomendaciones  = :valor,
  notif_seguridad        = :valor,
  notif_canal_app        = :valor,
  notif_canal_email      = :valor,
  notif_canal_push       = :valor,
  updated_at             = NOW()
WHERE id_user = :id_usuario;
```

---

---

# 02_deletes — Eliminaciones Controladas

## 001 — Soft Delete de Usuario
**Archivo:** `02_dml/02_deletes/001_soft_delete_usuario.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.user`  
**Descripción:** Script de referencia para la eliminación lógica de un usuario. No elimina físicamente el registro (RF1.5).

```sql
-- Soft delete de usuario (desactivación permanente)
UPDATE auth.user
SET
  deleted_at = NOW(),
  estado     = 'desactivado',
  updated_at = NOW()
WHERE id_user    = :id_usuario
  AND deleted_at IS NULL;

-- Registrar en auditoría
INSERT INTO audit.audit_log (
  id_audit_log, id_user, accion, modulo,
  entidad, id_entidad, resultado, detalle, created_at
)
VALUES (
  uuid_generate_v4(), :id_admin, 'eliminar', 'usuarios',
  'user', :id_usuario, 'exitoso',
  'Eliminación lógica de usuario', NOW()
);
```

---

## 002 — Soft Delete de Hogar
**Archivo:** `02_dml/02_deletes/002_soft_delete_hogar.sql`  
**Esquema:** `homes`  
**Tabla:** `homes.home`  
**Descripción:** Eliminación lógica de un hogar. Desvincula dispositivos pero conserva todos los datos (RF2.4).

```sql
-- Soft delete del hogar
UPDATE homes.home
SET
  deleted_at = NOW(),
  estado     = 'desactivado',
  updated_at = NOW()
WHERE id_home    = :id_hogar
  AND deleted_at IS NULL;

-- Soft delete de zonas asociadas al hogar
UPDATE homes.area
SET deleted_at = NOW()
WHERE id_home    = :id_hogar
  AND deleted_at IS NULL;
```

---

## 003 — Soft Delete de Dispositivo
**Archivo:** `02_dml/02_deletes/003_soft_delete_dispositivo.sql`  
**Esquema:** `devices`  
**Tabla:** `devices.device`  
**Descripción:** Eliminación lógica de un dispositivo. Desactiva también sus horarios y reglas de umbral (RF3.4).

```sql
-- Soft delete del dispositivo
UPDATE devices.device
SET
  deleted_at = NOW(),
  estado     = 'desactivado',
  updated_at = NOW()
WHERE id_device  = :id_dispositivo
  AND deleted_at IS NULL;

-- Desactivar horarios asociados
UPDATE devices.schedule
SET
  activo     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device  = :id_dispositivo
  AND deleted_at IS NULL;

-- Desactivar reglas de umbral asociadas
UPDATE devices.threshold_rule
SET
  activa     = FALSE,
  deleted_at = NOW(),
  updated_at = NOW()
WHERE id_device  = :id_dispositivo
  AND deleted_at IS NULL;
```

---

---

# 03_upserts — Inserción o Actualización

## 001 — Upsert de Configuración de Usuario
**Archivo:** `02_dml/03_upserts/001_upsert_config_usuario.sql`  
**Esquema:** `config`  
**Tabla:** `config.configuration_user`  
**Descripción:** Crea la configuración de un usuario si no existe, o la actualiza si ya existe. Se ejecuta automáticamente al registrar un nuevo usuario (RF1.1).

```sql
INSERT INTO config.configuration_user (
  id_configuration_user, id_user, idioma, tema,
  formato_fecha, formato_hora, moneda,
  created_at, updated_at
)
VALUES (
  uuid_generate_v4(), :id_usuario,
  'es', 'claro', 'DD/MM/YYYY', '24h', 'COP',
  NOW(), NOW()
)
ON CONFLICT (id_user) DO UPDATE
SET
  idioma        = EXCLUDED.idioma,
  tema          = EXCLUDED.tema,
  formato_fecha = EXCLUDED.formato_fecha,
  formato_hora  = EXCLUDED.formato_hora,
  moneda        = EXCLUDED.moneda,
  updated_at    = NOW();
```

---

## 002 — Upsert de Métricas de Consumo
**Archivo:** `02_dml/03_upserts/002_upsert_consumption_metric.sql`  
**Esquema:** `consumption`  
**Tabla:** `consumption.consumption_metric`  
**Descripción:** Actualiza las métricas agregadas de consumo por periodo. Se ejecuta periódicamente por triggers o jobs programados (RF4.2, RF4.3).

```sql
INSERT INTO consumption.consumption_metric (
  id_consumption_metric, id_device, id_home, periodo,
  fecha_inicio, fecha_fin, kwh_total, costo_total,
  watts_promedio, watts_maximo, watts_minimo,
  created_at, updated_at
)
VALUES (
  uuid_generate_v4(), :id_device, :id_home, :periodo,
  :fecha_inicio, :fecha_fin, :kwh_total, :costo_total,
  :watts_promedio, :watts_maximo, :watts_minimo,
  NOW(), NOW()
)
ON CONFLICT (id_device, periodo, fecha_inicio) DO UPDATE
SET
  kwh_total      = EXCLUDED.kwh_total,
  costo_total    = EXCLUDED.costo_total,
  watts_promedio = EXCLUDED.watts_promedio,
  watts_maximo   = EXCLUDED.watts_maximo,
  watts_minimo   = EXCLUDED.watts_minimo,
  updated_at     = NOW();
```

---

---

# 04_patches — Parches de Datos

## 001 — Patch: Reseteo de Intentos Fallidos
**Archivo:** `02_dml/04_patches/001_patch_reset_intentos_fallidos.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.user`  
**Descripción:** Resetea el contador de intentos fallidos y desbloquea cuentas cuyo tiempo de bloqueo ya expiró. Puede ejecutarse como job programado.

```sql
UPDATE auth.user
SET
  intentos_fallidos = 0,
  bloqueado_hasta   = NULL,
  estado            = 'activo',
  updated_at        = NOW()
WHERE estado         = 'bloqueado'
  AND bloqueado_hasta < NOW()
  AND deleted_at    IS NULL;
```

---

## 002 — Patch: Invalidar Tokens Expirados
**Archivo:** `02_dml/04_patches/002_patch_invalidar_tokens_expirados.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.session`  
**Descripción:** Marca como inactivas las sesiones cuyo token ya expiró. Puede ejecutarse como job programado diariamente (RNF5.4).

```sql
UPDATE auth.session
SET
  activa     = FALSE,
  updated_at = NOW()
WHERE expira_en  < NOW()
  AND activa     = TRUE
  AND deleted_at IS NULL;
```

---

## 003 — Patch: Purgar Tokens de Blacklist Expirados
**Archivo:** `02_dml/04_patches/003_patch_purgar_blacklist.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.token_blacklist`  
**Descripción:** Elimina físicamente los tokens revocados cuya fecha de expiración original ya pasó, para mantener la tabla liviana.

```sql
DELETE FROM auth.token_blacklist
WHERE expira_en < NOW() - INTERVAL '1 day';
```

---

## 004 — Patch: Marcar Recovery Tokens Expirados
**Archivo:** `02_dml/04_patches/004_patch_recovery_tokens_expirados.sql`  
**Esquema:** `auth`  
**Tabla:** `auth.recovery_token`  
**Descripción:** Marca como usados los tokens de recuperación que ya expiraron sin ser utilizados.

```sql
UPDATE auth.recovery_token
SET usado = TRUE
WHERE expira_en < NOW()
  AND usado     = FALSE;
```

---

---

# Orden de Ejecución del Seed Inicial

La siguiente tabla define el orden correcto de ejecución para respetar las dependencias entre tablas:

| Orden | Archivo | Tabla destino | Depende de |
|---|---|---|---|
| 1 | `001_insert_roles.sql` | `auth.role` | — |
| 2 | `002_insert_permisos.sql` | `auth.permission` | — |
| 3 | `003_insert_role_permissions.sql` | `auth.role_permission` | `auth.role`, `auth.permission` |
| 4 | `004_insert_tipos_dispositivos.sql` | `devices.type_device` | — |
| 5 | `005_insert_admin_user.sql` | `auth.user`, `auth.user_role`, `config.configuration_user` | `auth.role` |
| 6 | `006_insert_auditoria_seed.sql` | `audit.audit_log` | `auth.user` |

---

# Resumen de Datos Iniciales

| Entidad | Cantidad | Descripción |
|---|---|---|
| Roles | 3 | administrador, estandar, invitado |
| Permisos | 36 | Distribuidos en 7 módulos |
| Asignaciones rol-permiso | 36 (admin) + 26 (estandar) + 6 (invitado) | Según principio de mínimo privilegio |
| Tipos de dispositivos | 13 | Catálogo inicial de dispositivos IoT |
| Usuario administrador | 1 | Usuario inicial del sistema |
| Registros de auditoría | 5 | Trazabilidad del seed inicial |

---

# Referencias

| Documento | Descripción |
|---|---|
| SRS_FINAL.docx | Especificación de Requisitos de Software |
| ddl-documentation.md | Documentación de estructura de tablas |
| sql-layer-architecture.md | Arquitectura de la capa de base de datos |