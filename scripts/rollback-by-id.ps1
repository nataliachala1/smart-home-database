<#
.SYNOPSIS
    Revierte la base de datos Smart Home hasta un tag de Liquibase especifico.

.DESCRIPTION
    Ejecuta "liquibase rollback <tag>" dentro del contenedor liquibase
    definido en docker-compose.yml. Requiere que el contenedor postgres
    ya este levantado y saludable.

.PARAMETER Tag
    Nombre del tag de Liquibase al cual revertir (ej: v1.0.0, v1.0.1).
    Si no se especifica, se solicita interactivamente.

.EXAMPLE
    .\rollback-by-id.ps1 -Tag v1.0.0

.EXAMPLE
    .\rollback-by-id.ps1
    (solicitara el tag de forma interactiva)

Archivo: scripts/rollback-by-id.ps1
Proyecto: Smart Home
Autor: Karen Daniela Holguin Cruz, Natalia Chala Chala, Kevin Stiven Lopez Amaya
Institucion: SENA - Analisis y Desarrollo de Software (Ficha 3145555)
Version: 1.0.0
Fecha: 2025
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$Tag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Smart Home - Rollback de Base de Datos" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Solicitar el tag si no se proporciono como parametro
# ------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($Tag)) {
    Write-Host ""
    Write-Host "Tags disponibles conocidos: v1.0.0 (estructura DDL), v1.0.1 (datos semilla)" -ForegroundColor Yellow
    $Tag = Read-Host "Ingresa el tag al cual deseas revertir"
}

if ([string]::IsNullOrWhiteSpace($Tag)) {
    Write-Error "No se proporciono un tag valido. Operacion cancelada."
    exit 1
}

# ------------------------------------------------------------
# 2. Confirmacion explicita antes de una operacion destructiva
# ------------------------------------------------------------
Write-Host ""
Write-Host "[ADVERTENCIA]  Estas a punto de revertir la base de datos al tag: $Tag" -ForegroundColor Yellow
Write-Host "    Esta accion puede eliminar datos y cambios estructurales" -ForegroundColor Yellow
Write-Host "    posteriores a ese punto. Se recomienda hacer un backup" -ForegroundColor Yellow
Write-Host "    antes de continuar (ver scripts\backup.ps1)." -ForegroundColor Yellow
Write-Host ""
$confirm = Read-Host "Deseas continuar? (s/n)"

if ($confirm -notmatch '^[sS]$') {
    Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
    exit 0
}

# ------------------------------------------------------------
# 3. Verificar que el contenedor postgres este corriendo
# ------------------------------------------------------------
Push-Location $projectDir
try {
    Write-Host ""
    Write-Host "Verificando que el contenedor postgres este activo..." -ForegroundColor Cyan
    $postgresStatus = docker compose ps --status running --services postgres

    if ([string]::IsNullOrWhiteSpace($postgresStatus)) {
        Write-Error "El contenedor postgres no esta corriendo. Ejecuta primero .\scripts\setup.ps1"
        exit 1
    }

    # --------------------------------------------------------
    # 4. Ejecutar el rollback con Liquibase
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Ejecutando rollback hacia el tag '$Tag'..." -ForegroundColor Cyan

    docker compose run --rm liquibase rollback $Tag

    if ($LASTEXITCODE -ne 0) {
        Write-Error "El rollback fallo. Revisa el log de Liquibase arriba."
        exit 1
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Rollback completado exitosamente hacia: $Tag" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}
finally {
    Pop-Location
}