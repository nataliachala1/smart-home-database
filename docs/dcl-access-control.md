# Documentación DCL — Control de Acceso Smart Home
**Proyecto:** Smart Home — Sistema inteligente de monitoreo y control de consumo de energía eléctrica  
**Versión:** 1.0.0  
**Fecha:** 2025  
**Autores:** Karen Daniela Holguín Cruz, Natalia Chala Chala, Kevin Stiven López Amaya  
**Instructor:** José de Jesús Motta Vargas  
**Institución:** SENA — Análisis y Desarrollo de Software (Ficha 3145555)

---

## Descripción General

Este documento describe la capa de control de acceso de la base de datos del proyecto Smart Home. Define los roles de PostgreSQL, los privilegios otorgados sobre esquemas y tablas, y las políticas de seguridad a nivel de fila (Row Level Security — RLS) que garantizan que cada usuario solo pueda acceder a sus propios datos.

El control de acceso está organizado en tres niveles:

| Nivel | Descripción | Carpeta |
|---|---|---|
| Roles de BD | Roles de PostgreSQL con sus privilegios | `03_dcl/00_roles` |
| Grants | Permisos otorgados sobre esquemas y tablas | `03_dcl/01_grants` |
| Políticas RLS | Restricciones de acceso a nivel de fila | `03_dcl/02_policies` |

---

## Estructura de Archivos

```
03_dcl/
├── 00_roles/
│   └── 001_create_roles.sql
├── 01_grants/
│   ├── 001_grants_auth.sql
│   ├── 002_grants_homes.sql
│   ├── 003_grants_devices.sql
│   ├── 004_grants_consumption.sql
│   ├── 005_grants_notifications.sql
│   ├── 006_grants_sync.sql
│   ├── 007_grants_config.sql
│   └── 008_grants_audit.sql
├── 02_policies/
│   ├── 001_rls_homes.sql
│   ├── 002_rls_devices.sql
│   ├── 003_rls_consumption.sql
│   ├── 004_rls_notifications.sql
│   └── 005_rls_config.sql
└── changelog.yaml
```

---

---

# 00_roles — Roles de PostgreSQL

## Descripción

A nivel de base de datos se definen tres roles de PostgreSQL. Estos roles son independientes de los roles del sistema (administrador, estándar, invitado) definidos en `auth.role`. Los roles de BD controlan **qué puede hacer el motor de base de datos** con cada conexión.

| Rol BD | Descripción | Usado por |
|---|---|---|
| `smarthome_admin` | Acceso total a la base de datos. Puede crear, modificar y eliminar objetos. | DBA o administrador del sistema |
| `smarthome_app` | Rol del backend. Tiene permisos de lectura y escritura sobre las tablas necesarias. | API / Servidor de aplicaciones |
| `smarthome_readonly` | Solo lectura. Para reportes externos, auditorías o herramientas de BI. | Herramientas de reportes, auditorías externas |

---

## 001 — Creación de Roles
**Archivo:** `03_dcl/00_roles/001_create_roles.sql`  
**Descripción:** Crea los tres roles de PostgreSQL con sus atributos base.

```sql
-- ============================================================
-- ROL: smarthome_admin
-- Acceso total a la base de datos
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'smarthome_admin') THEN
    CREATE ROLE smarthome_admin
      NOLOGIN          -- No puede conectarse directamente, se asigna a usuarios
      NOSUPERUSER      -- No es superusuario
      NOCREATEDB       -- No puede crear bases de datos
      NOCREATEROLE     -- No puede crear roles
      INHERIT          -- Hereda permisos de roles asignados
      NOREPLICATION;   -- No puede replicar
    COMMENT ON ROLE smarthome_admin IS
      'Rol administrativo con acceso total a los esquemas y tablas del sistema Smart Home.';
  END IF;
END $$;

-- ============================================================
-- ROL: smarthome_app
-- Rol del backend / API
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'smarthome_app') THEN
    CREATE ROLE smarthome_app
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      INHERIT
      NOREPLICATION;
    COMMENT ON ROLE smarthome_app IS
      'Rol utilizado por el servidor de aplicaciones (API). Tiene permisos de lectura y escritura sobre las tablas del sistema Smart Home.';
  END IF;
END $$;

-- ============================================================
-- ROL: smarthome_readonly
-- Solo lectura para reportes y auditorías externas
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'smarthome_readonly') THEN
    CREATE ROLE smarthome_readonly
      NOLOGIN
      NOSUPERUSER
      NOCREATEDB
      NOCREATEROLE
      INHERIT
      NOREPLICATION;
    COMMENT ON ROLE smarthome_readonly IS
      'Rol de solo lectura para herramientas de reportes, BI o auditorías externas del sistema Smart Home.';
  END IF;
END $$;
```

---

---

# 01_grants — Privilegios sobre Esquemas y Tablas

## Descripción General de Privilegios

La siguiente tabla resume los privilegios otorgados a cada rol por esquema:

| Esquema | smarthome_admin | smarthome_app | smarthome_readonly |
|---|---|---|---|
| `auth` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `homes` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `devices` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `consumption` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `notifications` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `sync` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `config` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `audit` | ALL | SELECT, INSERT | SELECT |

> **Nota:** El esquema `audit` es especial. El rol `smarthome_app` solo puede insertar y consultar registros, **nunca actualizarlos ni eliminarlos**, para garantizar la inmutabilidad de los logs (RNF8.2).

---

## 001 — Grants sobre el Esquema auth
**Archivo:** `03_dcl/01_grants/001_grants_auth.sql`

```sql
-- ============================================================
-- GRANTS: Esquema auth
-- ============================================================

-- Uso del esquema
GRANT USAGE ON SCHEMA auth TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA auth TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA auth TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA auth TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA auth TO smarthome_app;

-- smarthome_readonly: solo lectura
-- Excluye tablas sensibles de seguridad
GRANT SELECT ON auth.role TO smarthome_readonly;
GRANT SELECT ON auth.permission TO smarthome_readonly;
GRANT SELECT ON auth.user_role TO smarthome_readonly;
GRANT SELECT ON auth.role_permission TO smarthome_readonly;

-- Aplicar a tablas futuras del esquema
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA auth
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

> **Nota de seguridad:** El rol `smarthome_readonly` **no tiene acceso** a `auth.user`, `auth.session`, `auth.mfa`, `auth.recovery_token` ni `auth.token_blacklist` por contener datos sensibles de autenticación (RNF5.3).

---

## 002 — Grants sobre el Esquema homes
**Archivo:** `03_dcl/01_grants/002_grants_homes.sql`

```sql
-- ============================================================
-- GRANTS: Esquema homes
-- ============================================================

GRANT USAGE ON SCHEMA homes TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA homes TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA homes TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA homes TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA homes TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA homes TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA homes
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA homes
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA homes
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

---

## 003 — Grants sobre el Esquema devices
**Archivo:** `03_dcl/01_grants/003_grants_devices.sql`

```sql
-- ============================================================
-- GRANTS: Esquema devices
-- ============================================================

GRANT USAGE ON SCHEMA devices TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA devices TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA devices TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA devices TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA devices TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA devices TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA devices
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA devices
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA devices
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

---

## 004 — Grants sobre el Esquema consumption
**Archivo:** `03_dcl/01_grants/004_grants_consumption.sql`

```sql
-- ============================================================
-- GRANTS: Esquema consumption
-- ============================================================

GRANT USAGE ON SCHEMA consumption TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA consumption TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA consumption TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA consumption TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA consumption TO smarthome_app;

-- smarthome_readonly: solo lectura (para reportes y BI)
GRANT SELECT ON ALL TABLES IN SCHEMA consumption TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA consumption
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA consumption
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA consumption
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

---

## 005 — Grants sobre el Esquema notifications
**Archivo:** `03_dcl/01_grants/005_grants_notifications.sql`

```sql
-- ============================================================
-- GRANTS: Esquema notifications
-- ============================================================

GRANT USAGE ON SCHEMA notifications TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA notifications TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA notifications TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA notifications TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA notifications TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA notifications TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA notifications
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

---

## 006 — Grants sobre el Esquema sync
**Archivo:** `03_dcl/01_grants/006_grants_sync.sql`

```sql
-- ============================================================
-- GRANTS: Esquema sync
-- ============================================================

GRANT USAGE ON SCHEMA sync TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA sync TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA sync TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA sync TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA sync TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA sync TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA sync
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA sync
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA sync
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

---

## 007 — Grants sobre el Esquema config
**Archivo:** `03_dcl/01_grants/007_grants_config.sql`

```sql
-- ============================================================
-- GRANTS: Esquema config
-- ============================================================

GRANT USAGE ON SCHEMA config TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA config TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA config TO smarthome_admin;

-- smarthome_app: lectura y escritura
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA config TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA config TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA config TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA config
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA config
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA config
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

---

## 008 — Grants sobre el Esquema audit
**Archivo:** `03_dcl/01_grants/008_grants_audit.sql`

```sql
-- ============================================================
-- GRANTS: Esquema audit
-- ESPECIAL: audit_log es inmutable — no se permite UPDATE ni DELETE
-- ============================================================

GRANT USAGE ON SCHEMA audit TO smarthome_admin, smarthome_app, smarthome_readonly;

-- smarthome_admin: acceso total (incluye correcciones administrativas)
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA audit TO smarthome_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA audit TO smarthome_admin;

-- smarthome_app: solo insertar y consultar (NO UPDATE, NO DELETE)
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA audit TO smarthome_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA audit TO smarthome_app;

-- smarthome_readonly: solo lectura
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO smarthome_readonly;

-- Aplicar a tablas futuras
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
  GRANT SELECT, INSERT ON TABLES TO smarthome_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
  GRANT SELECT ON TABLES TO smarthome_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA audit
  GRANT ALL PRIVILEGES ON TABLES TO smarthome_admin;
```

> **Nota de seguridad:** El rol `smarthome_app` **no puede** ejecutar `UPDATE` ni `DELETE` sobre `audit.audit_log`. Esto garantiza la inmutabilidad de los registros de auditoría, cumpliendo con RNF8.2 y la Ley 1581 de 2012.

---

---

# 02_policies — Row Level Security (RLS)

## Descripción General

Row Level Security (RLS) es una funcionalidad de PostgreSQL que permite restringir qué filas puede ver o modificar un usuario dentro de una tabla, independientemente de los privilegios otorgados. Esto garantiza que un usuario estándar **solo pueda acceder a sus propios datos**, incluso si tiene acceso general a la tabla.

### Principio de funcionamiento

Cuando RLS está habilitado en una tabla, PostgreSQL evalúa una política (policy) por cada consulta. Si la fila no cumple la condición de la política, simplemente no aparece en los resultados ni puede ser modificada.

### Variable de sesión utilizada

El backend debe establecer la variable de sesión `app.current_user_id` al inicio de cada conexión con el UUID del usuario autenticado:

```sql
-- El backend ejecuta esto al inicio de cada sesión
SET app.current_user_id = 'uuid-del-usuario-autenticado';
```

Esto permite que las políticas RLS identifiquen al usuario activo sin depender de la autenticación de PostgreSQL.

### Tablas con RLS habilitado

| Tabla | Columna de filtro | Descripción |
|---|---|---|
| `homes.home` | `id_user` | Solo ver hogares propios |
| `homes.area` | Vía `homes.home` | Solo ver zonas de hogares propios |
| `devices.device` | `id_home` | Solo ver dispositivos de hogares propios |
| `consumption.consumption` | `id_home` | Solo ver consumo de hogares propios |
| `notifications.notification` | `id_user` | Solo ver notificaciones propias |
| `config.configuration_user` | `id_user` | Solo ver configuración propia |

---

## 001 — Políticas RLS sobre homes
**Archivo:** `03_dcl/02_policies/001_rls_homes.sql`

```sql
-- ============================================================
-- RLS: homes.home
-- El usuario solo puede ver y modificar sus propios hogares
-- ============================================================

ALTER TABLE homes.home ENABLE ROW LEVEL SECURITY;
ALTER TABLE homes.home FORCE ROW LEVEL SECURITY;

-- Política de lectura: solo hogares propios
CREATE POLICY home_select_policy ON homes.home
  FOR SELECT
  TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

-- Política de inserción: solo puede crear hogares para sí mismo
CREATE POLICY home_insert_policy ON homes.home
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_user = current_setting('app.current_user_id')::UUID
  );

-- Política de actualización: solo puede modificar sus propios hogares
CREATE POLICY home_update_policy ON homes.home
  FOR UPDATE
  TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

-- Política de eliminación lógica: solo puede desactivar sus propios hogares
CREATE POLICY home_delete_policy ON homes.home
  FOR DELETE
  TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );

-- ============================================================
-- RLS: homes.area
-- El usuario solo puede ver zonas de sus propios hogares
-- ============================================================

ALTER TABLE homes.area ENABLE ROW LEVEL SECURITY;
ALTER TABLE homes.area FORCE ROW LEVEL SECURITY;

CREATE POLICY area_select_policy ON homes.area
  FOR SELECT
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY area_insert_policy ON homes.area
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY area_update_policy ON homes.area
  FOR UPDATE
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY area_delete_policy ON homes.area
  FOR DELETE
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );
```

---

## 002 — Políticas RLS sobre devices
**Archivo:** `03_dcl/02_policies/002_rls_devices.sql`

```sql
-- ============================================================
-- RLS: devices.device
-- El usuario solo puede ver dispositivos de sus propios hogares
-- ============================================================

ALTER TABLE devices.device ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices.device FORCE ROW LEVEL SECURITY;

CREATE POLICY device_select_policy ON devices.device
  FOR SELECT
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY device_insert_policy ON devices.device
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY device_update_policy ON devices.device
  FOR UPDATE
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY device_delete_policy ON devices.device
  FOR DELETE
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );
```

---

## 003 — Políticas RLS sobre consumption
**Archivo:** `03_dcl/02_policies/003_rls_consumption.sql`

```sql
-- ============================================================
-- RLS: consumption.consumption
-- El usuario solo puede ver lecturas de sus propios hogares
-- ============================================================

ALTER TABLE consumption.consumption ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption.consumption FORCE ROW LEVEL SECURITY;

CREATE POLICY consumption_select_policy ON consumption.consumption
  FOR SELECT
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY consumption_insert_policy ON consumption.consumption
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

-- ============================================================
-- RLS: consumption.consumption_metric
-- ============================================================

ALTER TABLE consumption.consumption_metric ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption.consumption_metric FORCE ROW LEVEL SECURITY;

CREATE POLICY consumption_metric_select_policy ON consumption.consumption_metric
  FOR SELECT
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY consumption_metric_insert_policy ON consumption.consumption_metric
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

-- ============================================================
-- RLS: consumption.recommendation
-- El usuario solo puede ver sus propias recomendaciones
-- ============================================================

ALTER TABLE consumption.recommendation ENABLE ROW LEVEL SECURITY;
ALTER TABLE consumption.recommendation FORCE ROW LEVEL SECURITY;

CREATE POLICY recommendation_select_policy ON consumption.recommendation
  FOR SELECT
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );

CREATE POLICY recommendation_insert_policy ON consumption.recommendation
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
  );

CREATE POLICY recommendation_update_policy ON consumption.recommendation
  FOR UPDATE
  TO smarthome_app
  USING (
    id_home IN (
      SELECT id_home FROM homes.home
      WHERE id_user    = current_setting('app.current_user_id')::UUID
        AND deleted_at IS NULL
    )
    AND deleted_at IS NULL
  );
```

---

## 004 — Políticas RLS sobre notifications
**Archivo:** `03_dcl/02_policies/004_rls_notifications.sql`

```sql
-- ============================================================
-- RLS: notifications.notification
-- El usuario solo puede ver sus propias notificaciones
-- ============================================================

ALTER TABLE notifications.notification ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications.notification FORCE ROW LEVEL SECURITY;

CREATE POLICY notification_select_policy ON notifications.notification
  FOR SELECT
  TO smarthome_app
  USING (
    id_user    = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

CREATE POLICY notification_insert_policy ON notifications.notification
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY notification_update_policy ON notifications.notification
  FOR UPDATE
  TO smarthome_app
  USING (
    id_user    = current_setting('app.current_user_id')::UUID
    AND deleted_at IS NULL
  );

CREATE POLICY notification_delete_policy ON notifications.notification
  FOR DELETE
  TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );
```

---

## 005 — Políticas RLS sobre config
**Archivo:** `03_dcl/02_policies/005_rls_config.sql`

```sql
-- ============================================================
-- RLS: config.configuration_user
-- El usuario solo puede ver y modificar su propia configuración
-- ============================================================

ALTER TABLE config.configuration_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE config.configuration_user FORCE ROW LEVEL SECURITY;

CREATE POLICY configuration_user_select_policy ON config.configuration_user
  FOR SELECT
  TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY configuration_user_insert_policy ON config.configuration_user
  FOR INSERT
  TO smarthome_app
  WITH CHECK (
    id_user = current_setting('app.current_user_id')::UUID
  );

CREATE POLICY configuration_user_update_policy ON config.configuration_user
  FOR UPDATE
  TO smarthome_app
  USING (
    id_user = current_setting('app.current_user_id')::UUID
  );
```

---

---

# Resumen de Control de Acceso

## Roles de PostgreSQL

| Rol | LOGIN | SUPERUSER | CREATEDB | Propósito |
|---|---|---|---|---|
| `smarthome_admin` | NO | NO | NO | Administración total de la BD |
| `smarthome_app` | NO | NO | NO | Backend / API del sistema |
| `smarthome_readonly` | NO | NO | NO | Reportes y auditorías externas |

## Matriz de Privilegios por Esquema

| Esquema | smarthome_admin | smarthome_app | smarthome_readonly |
|---|---|---|---|
| `auth` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT (solo tablas no sensibles) |
| `homes` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `devices` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `consumption` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `notifications` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `sync` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `config` | ALL | SELECT, INSERT, UPDATE, DELETE | SELECT |
| `audit` | ALL | SELECT, INSERT | SELECT |

## Tablas con RLS Habilitado

| Tabla | Política SELECT | Política INSERT | Política UPDATE | Política DELETE |
|---|---|---|---|---|
| `homes.home` | Solo hogares propios | Solo para sí mismo | Solo hogares propios | Solo hogares propios |
| `homes.area` | Solo zonas de hogares propios | Solo en hogares propios | Solo en hogares propios | Solo en hogares propios |
| `devices.device` | Solo dispositivos de hogares propios | Solo en hogares propios | Solo en hogares propios | Solo en hogares propios |
| `consumption.consumption` | Solo consumo de hogares propios | Solo en hogares propios | — | — |
| `consumption.consumption_metric` | Solo métricas de hogares propios | Solo en hogares propios | — | — |
| `consumption.recommendation` | Solo recomendaciones propias | Solo en hogares propios | Solo propias | — |
| `notifications.notification` | Solo notificaciones propias | Solo para sí mismo | Solo propias | Solo propias |
| `config.configuration_user` | Solo configuración propia | Solo para sí mismo | Solo propia | — |

---

# Cumplimiento Normativo

| Requisito | Mecanismo implementado |
|---|---|
| RNF5.1 — Control de acceso por roles | Roles de PostgreSQL + permisos por esquema |
| RNF5.2 — Autenticación segura | Variable de sesión `app.current_user_id` validada por RLS |
| RNF5.3 — Cifrado de datos | Tablas sensibles de `auth` excluidas de `smarthome_readonly` |
| RNF5.6 — Cumplimiento Ley 1581 de 2012 y GDPR | RLS garantiza aislamiento de datos por usuario |
| RNF8.2 — Auditoría inmutable | `smarthome_app` sin UPDATE ni DELETE en `audit.audit_log` |

---

# Orden de Ejecución

| Orden | Archivo | Descripción |
|---|---|---|
| 1 | `00_roles/001_create_roles.sql` | Crear roles de PostgreSQL |
| 2 | `01_grants/001_grants_auth.sql` | Grants sobre esquema auth |
| 3 | `01_grants/002_grants_homes.sql` | Grants sobre esquema homes |
| 4 | `01_grants/003_grants_devices.sql` | Grants sobre esquema devices |
| 5 | `01_grants/004_grants_consumption.sql` | Grants sobre esquema consumption |
| 6 | `01_grants/005_grants_notifications.sql` | Grants sobre esquema notifications |
| 7 | `01_grants/006_grants_sync.sql` | Grants sobre esquema sync |
| 8 | `01_grants/007_grants_config.sql` | Grants sobre esquema config |
| 9 | `01_grants/008_grants_audit.sql` | Grants sobre esquema audit |
| 10 | `02_policies/001_rls_homes.sql` | Políticas RLS sobre homes |
| 11 | `02_policies/002_rls_devices.sql` | Políticas RLS sobre devices |
| 12 | `02_policies/003_rls_consumption.sql` | Políticas RLS sobre consumption |
| 13 | `02_policies/004_rls_notifications.sql` | Políticas RLS sobre notifications |
| 14 | `02_policies/005_rls_config.sql` | Políticas RLS sobre config |

---

# Referencias

| Documento | Descripción |
|---|---|
| SRS_FINAL.docx | Especificación de Requisitos de Software |
| ddl-documentation.md | Documentación de estructura de tablas |
| dml-documentation.md | Documentación de datos iniciales |
| sql-layer-architecture.md | Arquitectura de la capa de base de datos |
| Ley 1581 de 2012 | Ley de protección de datos personales en Colombia |
| GDPR | Reglamento General de Protección de Datos europeo |