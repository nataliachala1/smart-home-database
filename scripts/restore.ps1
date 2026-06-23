<#
.SYNOPSIS
    Restaura la base de datos Smart Home desde un archivo de backup.

.DESCRIPTION
    Ejecuta psql dentro del contenedor postgres para restaurar
    un archivo .sql generado previamente por backup.ps1.
    Operacion DESTRUCTIVA: los datos actuales pueden mezclarse
    o sobrescribirse con los del backup, segun su contenido.

.PARAMETER BackupFile
    Ruta completa al archivo .sql de backup a restaurar.

.PARAMETER Force
    Omite la confirmacion interactiva.

.EXAMPLE
    .\restore.ps1 -BackupFile ".\backups\smarthome_backup_2025-06-17_10-30-00.sql"

Archivo: scripts/restore.ps1
Proyecto: Smart Home
Autor: Karen Daniela Holguin Cruz, Natalia Chala Chala, Kevin Stiven Lopez Amaya
Institucion: SENA - Analisis y Desarrollo de Software (Ficha 3145555)
Version: 1.0.0
Fecha: 2025
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$BackupFile,

    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Smart Home - Restauracion de Base de Datos" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Validar que el archivo de backup exista
# ------------------------------------------------------------
if (-not (Test-Path $BackupFile)) {
    Write-Error "El archivo de backup no existe: $BackupFile"
    exit 1
}

$resolvedPath = (Resolve-Path $BackupFile).Path

# ------------------------------------------------------------
# 2. Confirmacion explicita antes de una operacion destructiva
# ------------------------------------------------------------
if (-not $Force) {
    Write-Host ""
    Write-Host "[ADVERTENCIA]  Vas a restaurar desde: $resolvedPath" -ForegroundColor Yellow
    Write-Host "    Esta accion puede sobrescribir datos existentes." -ForegroundColor Yellow
    Write-Host "    Se recomienda crear un backup de seguridad del estado" -ForegroundColor Yellow
    Write-Host "    actual antes de continuar (.\scripts\backup.ps1)." -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Deseas continuar? (s/n)"

    if ($confirm -notmatch '^[sS]$') {
        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
        exit 0
    }
}

Push-Location $projectDir
try {
    # --------------------------------------------------------
    # 3. Verificar que el contenedor postgres este corriendo
    # --------------------------------------------------------
    $postgresStatus = docker compose ps --status running --services postgres

    if ([string]::IsNullOrWhiteSpace($postgresStatus)) {
        Write-Error "El contenedor postgres no esta corriendo. Ejecuta primero .\scripts\setup.ps1"
        exit 1
    }

    # --------------------------------------------------------
    # 4. Leer variables de entorno desde .env
    # --------------------------------------------------------
    $envFile = Join-Path $projectDir ".env"
    $dbName  = "smarthome"
    $dbUser  = "smarthome_admin"

    if (Test-Path $envFile) {
        $envContent = Get-Content $envFile
        foreach ($line in $envContent) {
            if ($line -match '^POSTGRES_DB=(.+)$')   { $dbName = $matches[1].Trim() }
            if ($line -match '^POSTGRES_USER=(.+)$') { $dbUser = $matches[1].Trim() }
        }
    }

    # --------------------------------------------------------
    # 5. Ejecutar la restauracion con psql
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Restaurando base de datos desde el backup..." -ForegroundColor Cyan

    Get-Content $resolvedPath -Raw | docker compose exec -T postgres psql -U $dbUser -d $dbName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "La restauracion fallo. Revisa el log de psql arriba."
        exit 1
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Restauracion completada exitosamente." -ForegroundColor Green
    Write-Host " Archivo restaurado: $resolvedPath" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}
finally {
    Pop-Location
}