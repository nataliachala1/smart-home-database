# Smart Home — Base de Datos

Sistema inteligente de monitoreo y control de consumo de energía eléctrica en hogares colombianos.

**Proyecto:** Smart Home
**Institución:** SENA — Análisis y Desarrollo de Software (Ficha 3145555)
**Autores:** Karen Daniela Holguín Cruz, Natalia Chala Chala, Kevin Stiven López Amaya
**Instructor:** José de Jesús Motta Vargas
**Versión:** 1.0.0

---

## Requisitos previos

Antes de empezar, asegúrate de tener instalado:

| Herramienta | Versión mínima | Verificar con |
|---|---|---|
| Docker Desktop | 24.0+ | `docker --version` |
| Docker Compose | v2 (incluido en Docker Desktop) | `docker compose version` |
| PowerShell | 5.1+ (incluido en Windows) | `$PSVersionTable.PSVersion` |

> 💡 No necesitas instalar PostgreSQL ni Liquibase en tu equipo — ambos corren dentro de contenedores Docker.

---

## Estructura del proyecto

```
Base de datos proyecto/
├── 01_ddl/              # Estructura: esquemas, tablas, vistas, funciones, triggers, procedimientos, índices
├── 02_dml/              # Datos: seed real (roles, permisos, admin) y datos de prueba (00_test_data)
├── 03_dcl/              # Control de acceso: roles de BD, grants, políticas RLS
├── 04_tcl/              # Transacciones de negocio, recuperaciones manuales, release tags
├── 05_rollbacks/        # Scripts de reversión (gestión manual)
├── docker/              # Configuración de inicialización de PostgreSQL
├── docs/                # Documentación: ddl, dml, dcl, tcl-documentation.md + sql-layer-architecture.md
├── scripts/             # Scripts PowerShell de operación (este README los explica)
├── backups/             # Carpeta donde se guardan los backups generados (se crea automáticamente)
├── changelog-master.yaml
├── docker-compose.yml
├── .env.example
└── README.md
```

---

## Guía paso a paso

### 1. Clonar y entrar al proyecto

```powershell
git clone <https://github.com/nataliachala1/smart-home-database.git>
cd "smart-home-database"
```

### 2. Configurar las variables de entorno

Copia el archivo de ejemplo y complétalo con tus propios valores:

```powershell
Copy-Item .env.example .env
```

Abre `.env` y define al menos:

```env
POSTGRES_DB=smarthome
POSTGRES_USER=smarthome_admin
POSTGRES_PASSWORD=<elige-una-contraseña-segura>
POSTGRES_PORT=5432
```

> ⚠️ **Nunca subas el archivo `.env` al repositorio.** Ya está incluido en `.gitignore`.

### 3. Levantar el entorno y aplicar las migraciones

Este es el paso principal. Ejecuta:

```powershell
.\scripts\setup.ps1
```

Este script automáticamente:
1. Verifica que exista `.env` (lo crea desde `.env.example` si falta)
2. Levanta el contenedor `postgres`
3. Espera a que PostgreSQL esté saludable (`healthcheck`)
4. Ejecuta `liquibase update` aplicando **todo** el `changelog-master.yaml`:
   - `01_ddl` → extensiones, esquemas, 32 tablas, vistas, vistas materializadas, funciones, procedimientos, triggers e índices
   - `02_dml` → seed real (roles, permisos, tipos de dispositivo, usuario administrador)
   - `03_dcl` → roles de PostgreSQL, grants y políticas de Row Level Security
   - `04_tcl` → registro descriptivo de los release tags

Al finalizar verás:

```
============================================================
 Entorno Smart Home listo.
 Para cargar datos de prueba, ejecuta: .\scripts\seed_test_data.ps1
============================================================
```

### 4. (Opcional) Cargar datos de prueba

Si quieres trabajar con usuarios, hogares, dispositivos y consumo ficticios para hacer pruebas (recomendado en desarrollo):

```powershell
.\scripts\seed_test_data.ps1
```

Esto inserta, entre otros:
- 3 usuarios de prueba: `karen@smarthome.com`, `kevin@smarthome.com`, `natalia@smarthome.com`
- 2 hogares con zonas y tarifas configuradas
- 8 dispositivos con horarios y umbrales de consumo
- 7 días de lecturas de consumo simuladas
- Notificaciones, alertas y recordatorios de ejemplo

> ⚠️ Estos datos son ficticios y **nunca deben ejecutarse en un entorno de producción**.

### 5. Verificar que todo quedó correcto

Conéctate a la base de datos para comprobar:

```powershell
docker compose exec postgres psql -U smarthome_admin -d smarthome -c "\dn"
```

Deberías ver los 8 esquemas: `auth`, `homes`, `devices`, `consumption`, `notifications`, `sync`, `config`, `audit`.

Para ver el estado de las migraciones aplicadas:

```powershell
docker compose run --rm liquibase status
```

---

## Operaciones comunes

| Quiero... | Ejecuto |
|---|---|
| Levantar el entorno por primera vez | `.\scripts\setup.ps1` |
| Cargar datos de prueba | `.\scripts\seed_test_data.ps1` |
| Crear un backup de la base de datos | `.\scripts\backup.ps1` |
| Restaurar desde un backup | `.\scripts\restore.ps1 -BackupFile ".\backups\archivo.sql"` |
| Revertir a una versión anterior (tag) | `.\scripts\rollback.ps1 -Tag v1.0.0` |
| Reiniciar todo desde cero (¡borra los datos!) | `.\scripts\reset.ps1` |
| Ver logs del contenedor de PostgreSQL | `docker compose logs -f postgres` |
| Detener el entorno sin borrar datos | `docker compose stop` |
| Apagar y eliminar contenedores (conserva el volumen) | `docker compose down` |

---

## Acceso a la base de datos

### Desde una herramienta externa (DBeaver, pgAdmin, TablePlus, etc.)

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Puerto | `5432` (o el definido en `POSTGRES_PORT` en `.env`) |
| Base de datos | `smarthome` |
| Usuario | `smarthome_admin` (o el definido en `.env`) |
| Contraseña | la definida en `POSTGRES_PASSWORD` en `.env` |

### Desde la línea de comandos

```powershell
docker compose exec postgres psql -U smarthome_admin -d smarthome
```

---

## Roles de base de datos

El sistema define 3 roles de PostgreSQL, independientes de los roles de negocio (`administrador`, `estandar`, `invitado` en `auth.role`):

| Rol BD | Uso previsto |
|---|---|
| `smarthome_admin` | Administración total. Es el usuario que usa Liquibase para migrar. |
| `smarthome_app` | Rol que debería usar el backend/API en producción (lectura/escritura controlada + RLS). |
| `smarthome_readonly` | Solo lectura, para reportes o auditorías externas. |

> En este proyecto académico, `POSTGRES_USER` (`smarthome_admin`) se usa también para correr las migraciones. En un entorno productivo real, el backend debería conectarse con `smarthome_app`, no con `smarthome_admin`.

---

## Notas importantes

- **Row Level Security (RLS):** las tablas `homes.home`, `homes.area`, `devices.device`, `consumption.*`, `notifications.notification` y `config.configuration_user` tienen RLS habilitado. El backend debe establecer `SET app.current_user_id = '<uuid-del-usuario>';` al inicio de cada conexión para que las políticas funcionen correctamente.
- **Auditoría inmutable:** la tabla `audit.audit_log` no permite `UPDATE` ni `DELETE` para el rol `smarthome_app`, garantizando trazabilidad completa (RNF8.2).
- **Vistas materializadas:** `consumption.mv_resumen_diario_hogar`, `consumption.mv_resumen_mensual_hogar`, `consumption.mv_ranking_dispositivos` y `audit.mv_estadisticas_mensuales` **no se actualizan en tiempo real**. Deben refrescarse periódicamente (ver sección "Opción A / Opción B" dentro de cada script en `01_ddl/05_materialized_views/`).
- **pg_cron (opcional):** si se desea automatizar el refresco de las vistas materializadas directamente desde PostgreSQL, ver la nota correspondiente en `docker-compose.yml` y cambiar la imagen del servicio `postgres` por una que incluya esta extensión.

---

## Documentación adicional

| Documento | Contenido |
|---|---|
| `docs/ddl-documentation.md` | Detalle de los 8 esquemas y 32 tablas: columnas, tipos, restricciones, relaciones |
| `docs/dml-documentation.md` | Datos semilla del sistema (roles, permisos, tipos de dispositivo, usuario admin) |
| `docs/dcl-access-control.md` | Roles de PostgreSQL, grants por esquema y políticas RLS completas |
| `docs/tcl-documentation.md` | Bloques transaccionales, recuperaciones manuales y release tags |
| `docs/sql-layer-architecture.md` | Decisiones técnicas generales de la arquitectura de base de datos |

---

## Solución de problemas

**El contenedor postgres no llega a "healthy"**
```powershell
docker compose logs postgres
```
Revisa que el puerto 5432 no esté ocupado por otra instancia de PostgreSQL en tu equipo. Si lo está, cambia `POSTGRES_PORT` en `.env`.

**Liquibase falla con "relation already exists"**
Probablemente ya se aplicaron las migraciones antes. Verifica el estado con:
```powershell
docker compose run --rm liquibase status
```

**Necesito empezar completamente de cero**
```powershell
.\scripts\reset.ps1
```
⚠️ Esto borra todos los datos. Haz un backup primero si los necesitas (`.\scripts\backup.ps1`).