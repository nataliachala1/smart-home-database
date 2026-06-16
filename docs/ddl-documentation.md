# Documentación DDL — Smart Home
**Proyecto:** Smart Home — Sistema inteligente de monitoreo y control de consumo de energía eléctrica  
**Versión:** 1.0.0  
**Fecha:** 2025  
**Autores:** Karen Daniela Holguín Cruz, Natalia Chala Chala, Kevin Stiven López Amaya  
**Instructor:** José de Jesús Motta Vargas  
**Institución:** SENA — Análisis y Desarrollo de Software (Ficha 3145555)

---

## Configuración del Motor de Base de Datos

| Característica | Detalle |
|---|---|
| Motor | PostgreSQL |
| Versión mínima | 15.0 |
| Encoding | UTF-8 |
| Zona horaria | America/Bogota |
| Extensiones | `uuid-ossp`, `pgcrypto` |

---

## Convenciones y Decisiones Técnicas

| Decisión | Elección | Justificación |
|---|---|---|
| Tipo de PK | UUID | Soporta modo offline, sincronización multidispositivo y dispositivos IoT sin depender de la BD para generar IDs |
| Eliminación | Soft delete (`deleted_at`) | El Módulo 7 exige auditoría completa y el RF5.3 define restauración de datos |
| Organización | Esquemas por módulo | Alineado con los 7 módulos del SRS, facilita permisos y mantenimiento |
| Nomenclatura tablas | `snake_case` singular | Ejemplo: `user`, `home`, `device` |
| Nomenclatura PKs | `id_` + nombre tabla | Ejemplo: `id_user`, `id_home`, `id_device` |
| Nomenclatura FKs | Mismo nombre que PK referenciada | Ejemplo: `id_user`, `id_home` |
| Nomenclatura índices | `idx_` + tabla + columna | Ejemplo: `idx_user_email` |
| Auditoría | Campos `created_at`, `updated_at`, `deleted_at` en todas las tablas | Trazabilidad completa de operaciones |

---

## Esquemas

| Esquema | Descripción | Módulo SRS |
|---|---|---|
| `auth` | Gestión de usuarios, autenticación y seguridad | Módulo 1 |
| `homes` | Gestión de hogares, zonas y tarifas | Módulo 2 |
| `devices` | Gestión y configuración de dispositivos IoT | Módulo 3 |
| `consumption` | Monitoreo y consumo energético | Módulo 4 |
| `notifications` | Notificaciones y alertas | Módulo 4 |
| `sync` | Sincronización, backups y modo offline | Módulo 5 |
| `config` | Personalización e internacionalización | Módulo 6 |
| `audit` | Auditoría y trazabilidad | Módulo 7 |

---

## Extensiones PostgreSQL

```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp"; -- Generación de UUIDs para PKs
CREATE EXTENSION IF NOT EXISTS "pgcrypto";  -- Cifrado de datos sensibles
```

---

---

# Esquema: `auth`
**Descripción:** Gestiona todo lo relacionado con usuarios, autenticación, sesiones, roles, permisos y seguridad de acceso al sistema. Corresponde al Módulo 1 del SRS.

---

### auth.user
**Descripción:** Almacena los usuarios registrados en el sistema Smart Home. Incluye datos personales, credenciales y estado de la cuenta.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_user | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del usuario |
| nombre | VARCHAR(100) | NOT NULL | Nombre del usuario |
| apellido | VARCHAR(100) | NOT NULL | Apellido del usuario |
| username | VARCHAR(50) | UNIQUE, NOT NULL | Nombre de usuario único en el sistema |
| email | VARCHAR(255) | UNIQUE, NOT NULL | Correo electrónico del usuario |
| password_hash | TEXT | NOT NULL | Contraseña encriptada con pgcrypto |
| estado | VARCHAR(20) | NOT NULL, DEFAULT 'pendiente' | Estado de la cuenta: pendiente, activo, desactivado, bloqueado |
| email_verificado | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si el correo fue verificado |
| intentos_fallidos | SMALLINT | NOT NULL, DEFAULT 0 | Contador de intentos fallidos de inicio de sesión |
| bloqueado_hasta | TIMESTAMPTZ | NULL | Fecha y hora hasta la que la cuenta está bloqueada |
| mfa_habilitado | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si la autenticación multifactor está activa |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación del registro |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica (soft delete) |

**Relaciones:**
- `auth.user_role` → un usuario puede tener múltiples roles
- `auth.session` → un usuario puede tener múltiples sesiones activas
- `auth.mfa` → un usuario puede tener configuración MFA
- `auth.recovery_token` → un usuario puede tener tokens de recuperación
- `homes.home_member` → un usuario puede pertenecer a múltiples hogares

**Índices:**
- `idx_user_email` — Búsqueda rápida por correo electrónico
- `idx_user_username` — Búsqueda rápida por nombre de usuario
- `idx_user_numero_documento` — Búsqueda rápida por documento
- `idx_user_estado` — Filtrado por estado de cuenta

**Notas:**
- La contraseña debe cumplir criterios de seguridad: mínimo 8 caracteres, una mayúscula, un número y un carácter especial.
- Implementa soft delete mediante `deleted_at`.
- El campo `estado` sigue el ciclo: `pendiente` → `activo` → `desactivado` / `bloqueado`.

---

### auth.role
**Descripción:** Define los roles disponibles en el sistema que determinan los niveles de acceso y permisos de los usuarios.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_role | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del rol |
| nombre | VARCHAR(50) | UNIQUE, NOT NULL | Nombre del rol (administrador, estandar, invitado) |
| descripcion | TEXT | NULL | Descripción del propósito del rol |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Relaciones:**
- `auth.user_role` → un rol puede estar asignado a múltiples usuarios
- `auth.role_permission` → un rol puede tener múltiples permisos

**Índices:**
- `idx_role_nombre` — Búsqueda rápida por nombre de rol

**Notas:**
- Los roles base del sistema son: `administrador`, `estandar`, `invitado`.
- No se puede eliminar el único rol de administrador activo en el sistema.

---

### auth.permission
**Descripción:** Catálogo de permisos disponibles en el sistema, asociados a módulos y acciones específicas.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_permission | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del permiso |
| nombre | VARCHAR(100) | UNIQUE, NOT NULL | Nombre del permiso |
| modulo | VARCHAR(50) | NOT NULL | Módulo al que pertenece el permiso |
| accion | VARCHAR(50) | NOT NULL | Acción que habilita el permiso (leer, crear, editar, eliminar) |
| descripcion | TEXT | NULL | Descripción detallada del permiso |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Relaciones:**
- `auth.role_permission` → un permiso puede estar asignado a múltiples roles

**Índices:**
- `idx_permission_modulo` — Filtrado por módulo
- `idx_permission_accion` — Filtrado por acción

---

### auth.user_role
**Descripción:** Tabla de relación muchos a muchos entre usuarios y roles. Permite asignar múltiples roles a un usuario.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_user_role | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la asignación |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario al que se asigna el rol |
| id_role | UUID | FK → auth.role, NOT NULL | Rol asignado al usuario |
| asignado_por | UUID | FK → auth.user, NULL | Usuario administrador que realizó la asignación |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de asignación |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Restricciones:**
- `UNIQUE (id_user, id_role)` — Un usuario no puede tener el mismo rol asignado dos veces.

**Índices:**
- `idx_user_role_id_user` — Búsqueda de roles por usuario
- `idx_user_role_id_role` — Búsqueda de usuarios por rol

---

### auth.role_permission
**Descripción:** Tabla de relación muchos a muchos entre roles y permisos.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_role_permission | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la asignación |
| id_role | UUID | FK → auth.role, NOT NULL | Rol al que se asigna el permiso |
| id_permission | UUID | FK → auth.permission, NOT NULL | Permiso asignado al rol |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de asignación |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Restricciones:**
- `UNIQUE (id_role, id_permission)` — Un rol no puede tener el mismo permiso dos veces.

**Índices:**
- `idx_role_permission_id_role` — Búsqueda de permisos por rol

---

### auth.session
**Descripción:** Registra las sesiones activas de los usuarios en el sistema, incluyendo información del dispositivo y token de acceso.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_session | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la sesión |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario dueño de la sesión |
| token | TEXT | UNIQUE, NOT NULL | Token JWT de la sesión |
| refresh_token | TEXT | UNIQUE, NULL | Token de renovación de sesión |
| ip_address | VARCHAR(45) | NULL | Dirección IP desde donde se inició sesión |
| user_agent | TEXT | NULL | Información del navegador o dispositivo |
| recordar_sesion | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si el usuario seleccionó "recordar sesión" |
| expira_en | TIMESTAMPTZ | NOT NULL | Fecha y hora de expiración del token |
| activa | BOOLEAN | NOT NULL, DEFAULT TRUE | Indica si la sesión está activa |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación de la sesión |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de cierre/eliminación lógica |

**Índices:**
- `idx_session_id_user` — Búsqueda de sesiones por usuario
- `idx_session_token` — Validación rápida del token
- `idx_session_activa` — Filtrado de sesiones activas

**Notas:**
- Los tokens expiran automáticamente tras 30 minutos de inactividad (RF1.4, RNF5.4).
- Al cerrar sesión, `activa` se establece en FALSE y se registra en `auth.token_blacklist`.

---

### auth.mfa
**Descripción:** Almacena la configuración de autenticación multifactor (MFA) por usuario.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_mfa | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la configuración MFA |
| id_user | UUID | FK → auth.user, UNIQUE, NOT NULL | Usuario dueño de la configuración |
| metodo | VARCHAR(20) | NOT NULL | Método MFA: sms, email, app |
| codigo_secreto | TEXT | NULL | Secreto cifrado para apps autenticadoras |
| habilitado | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si MFA está activo |
| ultimo_codigo_hash | TEXT | NULL | Hash del último código generado (para evitar reutilización) |
| expira_en | TIMESTAMPTZ | NULL | Expiración del último código generado |
| intentos_fallidos | SMALLINT | NOT NULL, DEFAULT 0 | Intentos fallidos de verificación MFA |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |

**Índices:**
- `idx_mfa_id_user` — Búsqueda de configuración MFA por usuario

**Notas:**
- Los códigos MFA tienen vigencia de 5 minutos (RF1.3.1).
- Máximo 3 intentos fallidos antes de solicitar nuevo código.

---

### auth.recovery_token
**Descripción:** Almacena los tokens temporales para recuperación de contraseña y activación de cuenta.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_recovery_token | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del token |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario al que pertenece el token |
| token | TEXT | UNIQUE, NOT NULL | Token único de recuperación |
| tipo | VARCHAR(30) | NOT NULL | Tipo: recuperacion_password, activacion_cuenta, reactivacion_cuenta |
| expira_en | TIMESTAMPTZ | NOT NULL | Fecha y hora de expiración |
| usado | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si el token ya fue utilizado |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |

**Índices:**
- `idx_recovery_token_token` — Validación rápida del token
- `idx_recovery_token_id_user` — Búsqueda por usuario

**Notas:**
- Los tokens de recuperación de contraseña expiran en 1 hora (RF1.8).
- Los tokens de activación de cuenta expiran en 24 horas (RF1.6).
- Un token solo puede usarse una vez (`usado = TRUE` después de su uso).

---

### auth.token_blacklist
**Descripción:** Registra los tokens JWT que han sido revocados para impedir su reutilización.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_token_blacklist | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del registro |
| token | TEXT | UNIQUE, NOT NULL | Token JWT revocado |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario al que pertenecía el token |
| motivo | VARCHAR(50) | NULL | Motivo de revocación: logout, cambio_password, desactivacion |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de revocación |
| expira_en | TIMESTAMPTZ | NOT NULL | Fecha de expiración original del token |

**Índices:**
- `idx_token_blacklist_token` — Verificación rápida de tokens revocados

**Notas:**
- Se recomienda purgar periódicamente los tokens cuya `expira_en` ya haya pasado.

---

---

# Esquema: `homes`
**Descripción:** Gestiona los hogares registrados por los usuarios, sus zonas internas y tarifas eléctricas. Corresponde al Módulo 2 del SRS.

---

### homes.home
**Descripción:** Almacena los hogares registrados en el sistema. Un usuario puede registrar múltiples hogares.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_home | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del hogar |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario propietario del hogar |
| nombre | VARCHAR(100) | NOT NULL | Nombre del hogar (ej: "Casa Principal") |
| estrato | SMALLINT | NOT NULL, CHECK (estrato BETWEEN 1 AND 6) | Estrato socioeconómico del hogar |
| estado | VARCHAR(20) | NOT NULL, DEFAULT 'activo' | Estado del hogar: activo, desactivado |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Restricciones:**
- `UNIQUE (id_user, nombre)` — Un usuario no puede tener dos hogares con el mismo nombre.

**Relaciones:**
- `homes.area` → un hogar puede tener múltiples zonas
- `homes.tariff` → un hogar puede tener múltiples tarifas configuradas
- `homes.home_member` → un hogar puede tener múltiples miembros
- `devices.device` → un hogar puede tener múltiples dispositivos

**Índices:**
- `idx_home_id_user` — Búsqueda de hogares por usuario
- `idx_home_estado` — Filtrado por estado

**Notas:**
- Al desactivar un hogar, su estado cambia a `desactivado` pero se conservan todos los datos (RF2.4).
- El hogar puede reactivarse en cualquier momento.

---

### homes.area
**Descripción:** Representa las zonas o habitaciones dentro de un hogar para organizar los dispositivos por ubicación física.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_area | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la zona |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que pertenece la zona |
| nombre | VARCHAR(100) | NOT NULL | Nombre de la zona (ej: "Sala Principal") |
| tipo | VARCHAR(50) | NULL | Tipo de zona: sala, cocina, dormitorio, baño, exterior, otro |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Restricciones:**
- `UNIQUE (id_home, nombre)` — No puede haber dos zonas con el mismo nombre en el mismo hogar.

**Relaciones:**
- `devices.device` → una zona puede tener múltiples dispositivos

**Índices:**
- `idx_area_id_home` — Búsqueda de zonas por hogar

**Notas:**
- No se puede eliminar una zona si tiene dispositivos vinculados activos (validación en capa de aplicación).

---

### homes.tariff
**Descripción:** Almacena las tarifas eléctricas configuradas por el usuario para cada hogar, usadas para calcular costos y proyecciones de facturación.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_tariff | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la tarifa |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que aplica la tarifa |
| costo_kwh | NUMERIC(10,4) | NOT NULL, CHECK (costo_kwh > 0) | Costo por kWh en la moneda configurada |
| moneda | VARCHAR(10) | NOT NULL, DEFAULT 'COP' | Moneda de la tarifa (COP, USD, etc.) |
| vigente_desde | DATE | NOT NULL | Fecha desde la que aplica esta tarifa |
| vigente_hasta | DATE | NULL | Fecha hasta la que aplica (NULL = tarifa actual) |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_tariff_id_home` — Búsqueda de tarifas por hogar
- `idx_tariff_vigente_desde` — Filtrado por vigencia

**Notas:**
- Se permite el historial de tarifas para que los reportes históricos reflejen el costo correcto en cada periodo (RF2.5).

---

### homes.home_member
**Descripción:** Gestiona los miembros adicionales de un hogar. Permite que varios usuarios compartan la gestión de un mismo hogar.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_home_member | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del miembro |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que pertenece el miembro |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario miembro del hogar |
| rol_en_hogar | VARCHAR(30) | NOT NULL, DEFAULT 'miembro' | Rol dentro del hogar: propietario, administrador, miembro |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de vinculación |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Restricciones:**
- `UNIQUE (id_home, id_user)` — Un usuario no puede ser miembro del mismo hogar dos veces.

**Índices:**
- `idx_home_member_id_home` — Búsqueda de miembros por hogar
- `idx_home_member_id_user` — Búsqueda de hogares por usuario

---

---

# Esquema: `devices`
**Descripción:** Gestiona los dispositivos IoT registrados, su configuración, horarios automáticos, reglas de umbral e historial de estados. Corresponde al Módulo 3 del SRS.

---

### devices.type_device
**Descripción:** Catálogo de tipos de dispositivos disponibles en el sistema.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_type_device | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del tipo |
| nombre | VARCHAR(100) | UNIQUE, NOT NULL | Nombre del tipo de dispositivo |
| descripcion | TEXT | NULL | Descripción del tipo de dispositivo |
| icono | VARCHAR(100) | NULL | Nombre del ícono representativo |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

---

### devices.device
**Descripción:** Almacena los dispositivos inteligentes o sensores registrados en el sistema, vinculados a un hogar y zona específica.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_device | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del dispositivo (no modificable) |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que pertenece el dispositivo |
| id_area | UUID | FK → homes.area, NULL | Zona donde está ubicado el dispositivo |
| id_type_device | UUID | FK → devices.type_device, NOT NULL | Tipo de dispositivo |
| nombre | VARCHAR(100) | NOT NULL | Nombre personalizado del dispositivo |
| estado | VARCHAR(20) | NOT NULL, DEFAULT 'desconectado' | Estado: conectado, desconectado, activo, desactivado |
| encendido | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si el dispositivo está encendido |
| consumo_actual_w | NUMERIC(10,2) | NULL | Consumo eléctrico actual en Watts |
| mac_address | VARCHAR(17) | UNIQUE, NULL | Dirección MAC del dispositivo físico |
| protocolo | VARCHAR(20) | NULL | Protocolo de comunicación: wifi, bluetooth, mqtt |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de registro |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica (desactivación) |

**Restricciones:**
- `UNIQUE (id_home, nombre)` — No puede haber dos dispositivos con el mismo nombre en el mismo hogar.

**Relaciones:**
- `devices.schedule` → un dispositivo puede tener múltiples horarios automáticos
- `devices.threshold_rule` → un dispositivo puede tener múltiples reglas de umbral
- `devices.device_status_history` → historial de estados del dispositivo
- `devices.smart_device` → datos extendidos para dispositivos inteligentes
- `consumption.consumption` → lecturas de consumo del dispositivo

**Índices:**
- `idx_device_id_home` — Búsqueda de dispositivos por hogar
- `idx_device_id_area` — Búsqueda de dispositivos por zona
- `idx_device_estado` — Filtrado por estado
- `idx_device_mac_address` — Búsqueda por MAC address

**Notas:**
- El `id_device` es inmutable una vez creado (RF3.3).
- Al desactivar un dispositivo, `deleted_at` se establece pero el historial se conserva (RF3.4).

---

### devices.smart_device
**Descripción:** Almacena datos extendidos específicos para dispositivos inteligentes con capacidades avanzadas de control.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_smart_device | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único |
| id_device | UUID | FK → devices.device, UNIQUE, NOT NULL | Dispositivo al que pertenece |
| firmware_version | VARCHAR(50) | NULL | Versión del firmware del dispositivo |
| modelo | VARCHAR(100) | NULL | Modelo del dispositivo |
| fabricante | VARCHAR(100) | NULL | Fabricante del dispositivo |
| capacidad_maxima_w | NUMERIC(10,2) | NULL | Capacidad máxima de consumo en Watts |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |

**Índices:**
- `idx_smart_device_id_device` — Búsqueda por dispositivo

---

### devices.manual_device
**Descripción:** Almacena datos extendidos para dispositivos manuales cuyo consumo se registra de forma estimada o manual.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_manual_device | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único |
| id_device | UUID | FK → devices.device, UNIQUE, NOT NULL | Dispositivo al que pertenece |
| consumo_estimado_w | NUMERIC(10,2) | NULL | Consumo estimado en Watts |
| horas_uso_diario | NUMERIC(5,2) | NULL | Horas de uso diario estimadas |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |

**Índices:**
- `idx_manual_device_id_device` — Búsqueda por dispositivo

---

### devices.schedule
**Descripción:** Almacena los horarios automáticos configurados para encender o apagar dispositivos en días y horas específicas.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_schedule | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del horario |
| id_device | UUID | FK → devices.device, NOT NULL | Dispositivo al que aplica el horario |
| accion | VARCHAR(10) | NOT NULL | Acción programada: encender, apagar |
| hora | TIME | NOT NULL | Hora de ejecución |
| dias_semana | SMALLINT[] | NOT NULL | Días de la semana (1=lunes ... 7=domingo) |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE | Indica si el horario está activo |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_schedule_id_device` — Búsqueda de horarios por dispositivo
- `idx_schedule_activo` — Filtrado de horarios activos

**Notas:**
- Al desactivar un dispositivo, todos sus horarios se desactivan automáticamente (RF3.4).

---

### devices.threshold_rule
**Descripción:** Define las reglas de umbral de consumo para un dispositivo. Cuando se supera el umbral, el sistema genera una alerta o ejecuta una acción automática.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_threshold_rule | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la regla |
| id_device | UUID | FK → devices.device, NOT NULL | Dispositivo al que aplica la regla |
| tipo | VARCHAR(20) | NOT NULL | Tipo de umbral: diario, mensual |
| limite_kwh | NUMERIC(10,4) | NOT NULL, CHECK (limite_kwh > 0) | Límite de consumo en kWh |
| accion | VARCHAR(20) | NOT NULL, DEFAULT 'alertar' | Acción al superar: alertar, apagar |
| activa | BOOLEAN | NOT NULL, DEFAULT TRUE | Indica si la regla está activa |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_threshold_rule_id_device` — Búsqueda de reglas por dispositivo

---

### devices.device_status_history
**Descripción:** Registra el historial de cambios de estado de cada dispositivo para trazabilidad y análisis.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_device_status_history | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del registro |
| id_device | UUID | FK → devices.device, NOT NULL | Dispositivo al que pertenece el registro |
| estado_anterior | VARCHAR(20) | NULL | Estado previo del dispositivo |
| estado_nuevo | VARCHAR(20) | NOT NULL | Nuevo estado del dispositivo |
| encendido | BOOLEAN | NOT NULL | Estado de encendido en el momento del registro |
| origen | VARCHAR(20) | NOT NULL, DEFAULT 'usuario' | Origen del cambio: usuario, automatico, voz, sistema |
| id_user | UUID | FK → auth.user, NULL | Usuario que realizó el cambio (si aplica) |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha y hora del cambio de estado |

**Índices:**
- `idx_device_status_history_id_device` — Búsqueda de historial por dispositivo
- `idx_device_status_history_created_at` — Filtrado por fecha

**Notas:**
- El historial se conserva por al menos 30 días (RF3.5).
- No implementa soft delete ya que es un registro histórico inmutable.

---

### devices.voice_assistant_token
**Descripción:** Almacena los tokens de integración con asistentes de voz como Alexa.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_voice_assistant_token | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del token |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario dueño de la integración |
| asistente | VARCHAR(30) | NOT NULL | Nombre del asistente: alexa |
| access_token | TEXT | NOT NULL | Token de acceso cifrado |
| refresh_token | TEXT | NULL | Token de renovación cifrado |
| expira_en | TIMESTAMPTZ | NULL | Fecha de expiración del token |
| activo | BOOLEAN | NOT NULL, DEFAULT TRUE | Indica si la integración está activa |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de vinculación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_voice_assistant_token_id_user` — Búsqueda por usuario

---

---

# Esquema: `consumption`
**Descripción:** Gestiona las lecturas de consumo energético en tiempo real, métricas agregadas para reportes y recomendaciones de ahorro. Corresponde al Módulo 4 del SRS.

---

### consumption.consumption
**Descripción:** Almacena las lecturas de consumo eléctrico en tiempo real de cada dispositivo.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_consumption | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la lectura |
| id_device | UUID | FK → devices.device, NOT NULL | Dispositivo que generó la lectura |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que pertenece el dispositivo |
| watts | NUMERIC(10,4) | NOT NULL, CHECK (watts >= 0) | Consumo instantáneo en Watts |
| kwh_acumulado | NUMERIC(12,6) | NOT NULL, DEFAULT 0 | Consumo acumulado en kWh desde el inicio del día |
| costo_estimado | NUMERIC(12,4) | NULL | Costo estimado según tarifa vigente |
| fecha_lectura | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha y hora de la lectura |

**Índices:**
- `idx_consumption_id_device` — Búsqueda de lecturas por dispositivo
- `idx_consumption_id_home` — Búsqueda de lecturas por hogar
- `idx_consumption_fecha_lectura` — Filtrado por fecha (clave para reportes)

**Notas:**
- Las lecturas se actualizan cada 1 a 5 segundos por dispositivo (RF3.5, RNF1.5).
- Esta tabla puede crecer muy rápidamente; se recomienda particionar por fecha (ej: por mes).
- No implementa soft delete; los datos históricos son inmutables.

---

### consumption.consumption_metric
**Descripción:** Almacena métricas agregadas de consumo para optimizar la generación de gráficos y reportes sin consultar lecturas individuales.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_consumption_metric | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la métrica |
| id_device | UUID | FK → devices.device, NOT NULL | Dispositivo al que pertenece la métrica |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que pertenece la métrica |
| periodo | VARCHAR(10) | NOT NULL | Periodo de la métrica: hora, dia, semana, mes |
| fecha_inicio | TIMESTAMPTZ | NOT NULL | Inicio del periodo de la métrica |
| fecha_fin | TIMESTAMPTZ | NOT NULL | Fin del periodo de la métrica |
| kwh_total | NUMERIC(12,6) | NOT NULL, DEFAULT 0 | Total de kWh consumidos en el periodo |
| costo_total | NUMERIC(12,4) | NULL | Costo total del periodo |
| watts_promedio | NUMERIC(10,4) | NULL | Consumo promedio en Watts durante el periodo |
| watts_maximo | NUMERIC(10,4) | NULL | Consumo máximo en Watts durante el periodo |
| watts_minimo | NUMERIC(10,4) | NULL | Consumo mínimo en Watts durante el periodo |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación de la métrica |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |

**Índices:**
- `idx_consumption_metric_id_device` — Búsqueda por dispositivo
- `idx_consumption_metric_id_home` — Búsqueda por hogar
- `idx_consumption_metric_periodo` — Filtrado por tipo de periodo
- `idx_consumption_metric_fecha_inicio` — Filtrado por rango de fechas

**Notas:**
- Estas métricas son calculadas periódicamente por funciones/triggers para optimizar el rendimiento de los gráficos (RF4.2, RF4.3).

---

### consumption.recommendation
**Descripción:** Almacena las recomendaciones de ahorro energético generadas automáticamente por el sistema para cada hogar.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_recommendation | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la recomendación |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar al que aplica la recomendación |
| id_device | UUID | FK → devices.device, NULL | Dispositivo relacionado (si aplica) |
| titulo | VARCHAR(200) | NOT NULL | Título descriptivo de la recomendación |
| descripcion | TEXT | NOT NULL | Descripción detallada de la recomendación |
| ahorro_estimado_kwh | NUMERIC(10,4) | NULL | Ahorro potencial estimado en kWh por mes |
| ahorro_estimado_costo | NUMERIC(12,4) | NULL | Ahorro potencial estimado en costo por mes |
| prioridad | VARCHAR(10) | NOT NULL, DEFAULT 'media' | Prioridad: alta, media, baja |
| estado | VARCHAR(20) | NOT NULL, DEFAULT 'pendiente' | Estado: pendiente, implementada, descartada |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de generación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_recommendation_id_home` — Búsqueda de recomendaciones por hogar
- `idx_recommendation_prioridad` — Filtrado por prioridad
- `idx_recommendation_estado` — Filtrado por estado

**Notas:**
- Se requiere al menos 7 días de historial de consumo para generar recomendaciones confiables (RF4.4).

---

---

# Esquema: `notifications`
**Descripción:** Gestiona las notificaciones y alertas generadas por el sistema hacia los usuarios. Corresponde al Módulo 4 del SRS.

---

### notifications.notification
**Descripción:** Almacena todas las notificaciones generadas por el sistema para los usuarios.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_notification | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la notificación |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario destinatario |
| id_home | UUID | FK → homes.home, NULL | Hogar relacionado con la notificación (si aplica) |
| id_device | UUID | FK → devices.device, NULL | Dispositivo relacionado (si aplica) |
| tipo | VARCHAR(30) | NOT NULL | Tipo: consumo_elevado, dispositivo_desconectado, nueva_recomendacion, umbral_superado, sistema |
| titulo | VARCHAR(200) | NOT NULL | Título de la notificación |
| mensaje | TEXT | NOT NULL | Contenido detallado de la notificación |
| prioridad | VARCHAR(10) | NOT NULL, DEFAULT 'media' | Prioridad: alta, media, baja |
| leida | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si la notificación fue leída |
| canal | VARCHAR(20) | NOT NULL, DEFAULT 'app' | Canal de envío: app, email, push |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_notification_id_user` — Búsqueda de notificaciones por usuario
- `idx_notification_leida` — Filtrado de no leídas
- `idx_notification_tipo` — Filtrado por tipo
- `idx_notification_created_at` — Ordenamiento cronológico

**Notas:**
- Las notificaciones deben enviarse en menos de 5 segundos desde su generación (RNF4.3).
- El delay máximo de visualización en la app es de 2 segundos (RF4.5).

---

### notifications.alert
**Descripción:** Almacena las alertas específicas generadas cuando un dispositivo supera los umbrales de consumo configurados.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_alert | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la alerta |
| id_threshold_rule | UUID | FK → devices.threshold_rule, NOT NULL | Regla de umbral que generó la alerta |
| id_device | UUID | FK → devices.device, NOT NULL | Dispositivo que generó la alerta |
| id_home | UUID | FK → homes.home, NOT NULL | Hogar del dispositivo |
| consumo_detectado_kwh | NUMERIC(12,6) | NOT NULL | Consumo detectado al momento de la alerta |
| limite_kwh | NUMERIC(10,4) | NOT NULL | Límite configurado que fue superado |
| accion_ejecutada | VARCHAR(20) | NULL | Acción ejecutada: alertar, apagar |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha y hora de la alerta |

**Índices:**
- `idx_alert_id_device` — Búsqueda de alertas por dispositivo
- `idx_alert_id_home` — Búsqueda de alertas por hogar
- `idx_alert_created_at` — Filtrado por fecha

---

### notifications.reminder_notification
**Descripción:** Almacena recordatorios programados para enviar a los usuarios en fechas y horas específicas.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_reminder_notification | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del recordatorio |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario destinatario |
| id_home | UUID | FK → homes.home, NULL | Hogar relacionado (si aplica) |
| mensaje | TEXT | NOT NULL | Contenido del recordatorio |
| programado_para | TIMESTAMPTZ | NOT NULL | Fecha y hora de envío programado |
| enviado | BOOLEAN | NOT NULL, DEFAULT FALSE | Indica si el recordatorio fue enviado |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |
| deleted_at | TIMESTAMPTZ | NULL | Fecha de eliminación lógica |

**Índices:**
- `idx_reminder_notification_id_user` — Búsqueda por usuario
- `idx_reminder_notification_programado_para` — Filtrado por fecha programada

---

---

# Esquema: `sync`
**Descripción:** Gestiona la sincronización de datos entre dispositivos, el modo offline y las copias de seguridad. Corresponde al Módulo 5 del SRS.

---

### sync.offline_queue
**Descripción:** Cola de acciones realizadas por el usuario en modo offline que deben sincronizarse cuando se restablezca la conexión.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_offline_queue | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la acción en cola |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario que realizó la acción |
| tipo_accion | VARCHAR(50) | NOT NULL | Tipo de acción: encender_dispositivo, apagar_dispositivo, actualizar_config |
| payload | JSONB | NOT NULL | Datos de la acción en formato JSON |
| estado | VARCHAR(20) | NOT NULL, DEFAULT 'pendiente' | Estado: pendiente, procesada, fallida |
| intentos | SMALLINT | NOT NULL, DEFAULT 0 | Número de intentos de sincronización |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| procesada_at | TIMESTAMPTZ | NULL | Fecha en que fue procesada |

**Índices:**
- `idx_offline_queue_id_user` — Búsqueda por usuario
- `idx_offline_queue_estado` — Filtrado por estado

**Notas:**
- Las acciones se procesan en orden de creación al reconectar (RF5.4).
- El sistema detecta pérdida de conexión en menos de 5 segundos (RF5.4).

---

### sync.synchronization
**Descripción:** Registra el historial de sincronizaciones realizadas entre dispositivos y el servidor.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_synchronization | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la sincronización |
| id_user | UUID | FK → auth.user, NOT NULL | Usuario que realizó la sincronización |
| tipo | VARCHAR(20) | NOT NULL | Tipo: automatica, manual |
| estado | VARCHAR(20) | NOT NULL | Estado: exitosa, fallida, parcial |
| dispositivos_sincronizados | SMALLINT | NULL | Número de dispositivos sincronizados |
| errores | TEXT | NULL | Descripción de errores si los hubo |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha y hora de la sincronización |

**Índices:**
- `idx_synchronization_id_user` — Búsqueda por usuario
- `idx_synchronization_created_at` — Filtrado por fecha

**Notas:**
- La sincronización completa no debe tardar más de 10 segundos (RF5.2).

---

### sync.backup
**Descripción:** Registra las copias de seguridad generadas del sistema, tanto automáticas como manuales.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_backup | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del backup |
| id_user | UUID | FK → auth.user, NULL | Usuario al que pertenecen los datos (NULL = backup global) |
| tipo | VARCHAR(20) | NOT NULL | Tipo: automatico, manual |
| alcance | VARCHAR(20) | NOT NULL, DEFAULT 'completo' | Alcance: completo, parcial |
| ubicacion | TEXT | NOT NULL | Ruta o URL del archivo de backup |
| tamanio_bytes | BIGINT | NULL | Tamaño del archivo de backup en bytes |
| estado | VARCHAR(20) | NOT NULL, DEFAULT 'completado' | Estado: en_proceso, completado, fallido |
| descripcion | TEXT | NULL | Descripción o notas del backup |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación del backup |

**Índices:**
- `idx_backup_id_user` — Búsqueda de backups por usuario
- `idx_backup_tipo` — Filtrado por tipo
- `idx_backup_created_at` — Filtrado por fecha

**Notas:**
- El sistema realiza copias de seguridad automáticas diarias (RNF4.4).
- Solo usuarios con rol administrador pueden ejecutar restauraciones (RF5.3).
- Antes de restaurar, el sistema crea un backup de seguridad del estado actual.

---

---

# Esquema: `config`
**Descripción:** Almacena las preferencias de personalización e internacionalización de cada usuario. Corresponde al Módulo 6 del SRS.

---

### config.configuration_user
**Descripción:** Almacena las preferencias de configuración personal de cada usuario, incluyendo idioma, tema visual y preferencias de notificaciones.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_configuration_user | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único de la configuración |
| id_user | UUID | FK → auth.user, UNIQUE, NOT NULL | Usuario dueño de la configuración |
| idioma | VARCHAR(10) | NOT NULL, DEFAULT 'es' | Idioma de la interfaz: es, en, fr, de |
| tema | VARCHAR(10) | NOT NULL, DEFAULT 'claro' | Tema visual: claro, oscuro, automatico |
| formato_fecha | VARCHAR(20) | NOT NULL, DEFAULT 'DD/MM/YYYY' | Formato de fecha según región |
| formato_hora | VARCHAR(5) | NOT NULL, DEFAULT '24h' | Formato de hora: 12h, 24h |
| moneda | VARCHAR(10) | NOT NULL, DEFAULT 'COP' | Moneda para reportes de costos |
| unidad_temperatura | VARCHAR(5) | NOT NULL, DEFAULT 'C' | Unidad de temperatura: C, F |
| notif_consumo_elevado | BOOLEAN | NOT NULL, DEFAULT TRUE | Activar notificaciones de consumo elevado |
| notif_dispositivos | BOOLEAN | NOT NULL, DEFAULT TRUE | Activar notificaciones de dispositivos |
| notif_recomendaciones | BOOLEAN | NOT NULL, DEFAULT TRUE | Activar notificaciones de recomendaciones |
| notif_seguridad | BOOLEAN | NOT NULL, DEFAULT TRUE | Activar notificaciones de seguridad |
| notif_canal_app | BOOLEAN | NOT NULL, DEFAULT TRUE | Canal de notificación: app |
| notif_canal_email | BOOLEAN | NOT NULL, DEFAULT TRUE | Canal de notificación: email |
| notif_canal_push | BOOLEAN | NOT NULL, DEFAULT TRUE | Canal de notificación: push |
| no_molestar_inicio | TIME | NULL | Hora de inicio del modo No Molestar |
| no_molestar_fin | TIME | NULL | Hora de fin del modo No Molestar |
| recomendaciones_activas | BOOLEAN | NOT NULL, DEFAULT TRUE | Activar generación de recomendaciones automáticas |
| frecuencia_recomendaciones | VARCHAR(10) | NOT NULL, DEFAULT 'semanal' | Frecuencia: diaria, semanal, mensual |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de creación |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha de última actualización |

**Índices:**
- `idx_configuration_user_id_user` — Búsqueda de configuración por usuario

**Notas:**
- Se crea automáticamente con valores por defecto al registrar un nuevo usuario.
- El cambio de idioma se aplica inmediatamente sin reiniciar la app (RF6.1).
- El cambio de tema se aplica sin recargar la aplicación (RF6.2).
- La preferencia de idioma y tema se sincroniza entre todos los dispositivos del usuario.

---

---

# Esquema: `audit`
**Descripción:** Registra todas las operaciones críticas realizadas en el sistema para garantizar trazabilidad, seguridad y cumplimiento normativo. Corresponde al Módulo 7 del SRS.

---

### audit.audit_log
**Descripción:** Registro inmutable de todas las acciones relevantes realizadas en el sistema por usuarios o procesos automáticos.

| Columna | Tipo | Restricciones | Descripción |
|---|---|---|---|
| id_audit_log | UUID | PK, NOT NULL, DEFAULT uuid_generate_v4() | Identificador único del registro |
| id_user | UUID | FK → auth.user, NULL | Usuario que realizó la acción (NULL si es proceso automático) |
| accion | VARCHAR(50) | NOT NULL | Acción realizada: crear, editar, eliminar, login, logout, restaurar, etc. |
| modulo | VARCHAR(50) | NOT NULL | Módulo del sistema donde ocurrió la acción |
| entidad | VARCHAR(50) | NULL | Entidad afectada (ej: user, home, device) |
| id_entidad | UUID | NULL | ID del registro afectado |
| datos_anteriores | JSONB | NULL | Estado anterior del registro (para auditoría de cambios) |
| datos_nuevos | JSONB | NULL | Estado nuevo del registro (para auditoría de cambios) |
| ip_address | VARCHAR(45) | NULL | Dirección IP desde donde se realizó la acción |
| user_agent | TEXT | NULL | Información del navegador o dispositivo |
| resultado | VARCHAR(10) | NOT NULL, DEFAULT 'exitoso' | Resultado: exitoso, fallido |
| detalle | TEXT | NULL | Descripción adicional o mensaje de error |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Fecha y hora exacta de la acción |

**Índices:**
- `idx_audit_log_id_user` — Filtrado por usuario
- `idx_audit_log_accion` — Filtrado por tipo de acción
- `idx_audit_log_modulo` — Filtrado por módulo
- `idx_audit_log_entidad` — Filtrado por entidad
- `idx_audit_log_created_at` — Filtrado por rango de fechas
- `idx_audit_log_resultado` — Filtrado por resultado

**Notas:**
- Los registros son **inmutables**: no se permite UPDATE ni DELETE sobre esta tabla (RNF8.2).
- Los logs se mantienen por al menos **12 meses** (RNF8.2).
- Solo usuarios con rol `administrador` pueden consultar los logs (RF7.1).
- La consulta de logs también queda registrada en esta misma tabla (meta-auditoría).
- La búsqueda de hasta 10.000 registros no debe tardar más de 5 segundos (RF7.1).
- Los datos sensibles (contraseñas, tokens) se almacenan ofuscados: `[DATO PROTEGIDO]`.

---

---

# Resumen de Tablas por Esquema

| Esquema | Tabla | Descripción breve |
|---|---|---|
| `auth` | `user` | Usuarios del sistema |
| `auth` | `role` | Roles disponibles |
| `auth` | `permission` | Permisos del sistema |
| `auth` | `user_role` | Asignación de roles a usuarios |
| `auth` | `role_permission` | Asignación de permisos a roles |
| `auth` | `session` | Sesiones activas |
| `auth` | `mfa` | Autenticación multifactor |
| `auth` | `recovery_token` | Tokens de recuperación |
| `auth` | `token_blacklist` | Tokens revocados |
| `homes` | `home` | Hogares registrados |
| `homes` | `area` | Zonas dentro del hogar |
| `homes` | `tariff` | Tarifas eléctricas |
| `homes` | `home_member` | Miembros del hogar |
| `devices` | `type_device` | Tipos de dispositivos |
| `devices` | `device` | Dispositivos registrados |
| `devices` | `smart_device` | Datos extendidos dispositivos inteligentes |
| `devices` | `manual_device` | Datos extendidos dispositivos manuales |
| `devices` | `schedule` | Horarios automáticos |
| `devices` | `threshold_rule` | Reglas de umbral de consumo |
| `devices` | `device_status_history` | Historial de estados |
| `devices` | `voice_assistant_token` | Tokens asistentes de voz |
| `consumption` | `consumption` | Lecturas de consumo en tiempo real |
| `consumption` | `consumption_metric` | Métricas agregadas para reportes |
| `consumption` | `recommendation` | Recomendaciones de ahorro |
| `notifications` | `notification` | Notificaciones del sistema |
| `notifications` | `alert` | Alertas por umbral superado |
| `notifications` | `reminder_notification` | Recordatorios programados |
| `sync` | `offline_queue` | Cola de acciones offline |
| `sync` | `synchronization` | Historial de sincronizaciones |
| `sync` | `backup` | Copias de seguridad |
| `config` | `configuration_user` | Preferencias de usuario |
| `audit` | `audit_log` | Registros de auditoría |

**Total: 32 tablas distribuidas en 8 esquemas.**

---

# Referencias

| Documento | Descripción |
|---|---|
| SRS_FINAL.docx | Especificación de Requisitos de Software del proyecto Smart Home |
| sql-layer-architecture.md | Arquitectura de la capa de base de datos |
| MER_drawio.xml | Modelo Entidad-Relación del proyecto |
| Standard IEEE 830-1998 | Estándar para especificación de requisitos de software |