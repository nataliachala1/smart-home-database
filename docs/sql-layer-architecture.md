# SQL Layer Architecture - Smart Home

## 1. Descripción general

Este documento define la arquitectura de la capa de base de datos del proyecto Smart Home, un sistema inteligente de monitoreo y control de consumo de energía eléctrica en hogares colombianos.

---

## 2. Motor de base de datos

| Característica | Detalle |
|---|---|
| Motor | PostgreSQL |
| Versión mínima | 15.0 |
| Encoding | UTF-8 |
| Zona horaria | America/Bogota |

---

## 3. Decisiones técnicas

| Decisión | Elección | Justificación |
|---|---|---|
| Tipo de PK | UUID | Soporta modo offline, sincronización multidispositivo y dispositivos IoT sin depender de la BD para generar IDs |
| Eliminación | Soft delete | El Módulo 7 exige auditoría completa y el RF5.3 define restauración de datos |
| Organización | Esquemas por módulo | Alineado con los 7 módulos del SRS, facilita permisos y mantenimiento |
| Nomenclatura tablas | snake_case singular | Ejemplo: `user`, `home`, `device` |
| Nomenclatura PKs | `id_` + nombre tabla | Ejemplo: `id_user`, `id_home`, `id_device` |
| Nomenclatura FKs | Mismo nombre que PK referenciada | Ejemplo: `id_user`, `id_home` |
| Nomenclatura índices | `idx_` + tabla + columna | Ejemplo: `idx_user_email` |

---

## 4. Esquemas

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

## 5. Entidades por esquema

### `auth`
| Entidad | Descripción |
|---|---|
| `user` | Usuarios del sistema |
| `role` | Roles disponibles |
| `permission` | Permisos del sistema |
| `user_role` | Asignación de roles a usuarios |
| `role_permission` | Asignación de permisos a roles |
| `session` | Sesiones activas |
| `mfa` | Autenticación multifactor |
| `recovery_token` | Tokens de recuperación de contraseña |
| `token_blacklist` | Tokens revocados |

### `homes`
| Entidad | Descripción |
|---|---|
| `home` | Hogares registrados |
| `area` | Zonas dentro de un hogar |
| `tariff` | Tarifas eléctricas por hogar |
| `home_member` | Miembros de un hogar |

### `devices`
| Entidad | Descripción |
|---|---|
| `device` | Dispositivos registrados |
| `type_device` | Tipos de dispositivos disponibles |
| `smart_device` | Especialización dispositivos inteligentes |
| `manual_device` | Especialización dispositivos manuales |
| `schedule` | Horarios automáticos de dispositivos |
| `threshold_rule` | Reglas de umbral de consumo |
| `device_status_history` | Historial de estados de dispositivos |
| `voice_assistant_token` | Tokens de integración con asistentes de voz |

### `consumption`
| Entidad | Descripción |
|---|---|
| `consumption` | Lecturas de consumo en tiempo real |
| `consumption_metric` | Métricas para gráficos y reportes |
| `recommendation` | Recomendaciones de ahorro |

### `notifications`
| Entidad | Descripción |
|---|---|
| `notification` | Notificaciones generales del sistema |
| `alert` | Alertas generadas por reglas de umbral |
| `reminder_notification` | Notificaciones de recordatorio |

### `sync`
| Entidad | Descripción |
|---|---|
| `offline_queue` | Cola de acciones en modo offline |
| `synchronization` | Registro de sincronizaciones |
| `backup` | Copias de seguridad |

### `config`
| Entidad | Descripción |
|---|---|
| `configuration_user` | Preferencias de usuario |

### `audit`
| Entidad | Descripción |
|---|---|
| `audit_log` | Registros de auditoría del sistema |

---

## 6. Extensiones PostgreSQL utilizadas

| Extensión | Propósito |
|---|---|
| `uuid-ossp` | Generación de UUIDs para PKs |
| `pgcrypto` | Cifrado de datos sensibles |

---

## 7. Relación con el frontend

| Esquema BD | Módulo frontend | Tecnología |
|---|---|---|
| `auth` | `src/modules/auth` | AuthContext, JWT, SecureStore |
| `homes` | `src/modules/homes` | useHomes hook |
| `devices` | `src/modules/devices` | useDevices hook, WebSocket |
| `consumption` | `src/modules/consumption` | useConsumption, Victory Native |
| `notifications` | `src/modules/notifications` | useNotifications, Expo Notifications |
| `sync` | OfflineContext | AsyncStorage, NetInfo |
| `config` | `src/modules/settings` | ThemeContext, LanguageContext |
| `audit` | Panel administrador | Guard Pattern |