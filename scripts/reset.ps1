<#
.SYNOPSIS
    Reinicia por completo el entorno de base de datos Smart Home.

.DESCRIPTION
    Detiene los contenedores, elimina el volumen de datos de
    PostgreSQL (smarthome_pgdata) y vuelve a levantar el entorno
    desde cero ejecutando setup.ps1. Operacion DESTRUCTIVA:
    borra todos los datos existentes en la base de datos.

.PARAMETER Force
    Omite la confirmacion interactiva. Util para scripts de CI
    o automatizacion.

.EXAMPLE
    .\reset.ps1

.EXAMPLE
    .\reset.ps1 -Force

Archivo: scripts/reset.ps1
Proyecto: Smart Home
Autor: Karen Daniela Holguin Cruz, Natalia Chala Chala, Kevin Stiven Lopez Amaya
Institucion: SENA - Analisis y Desarrollo de Software (Ficha 3145555)
Version: 1.0.0
Fecha: 2025
#>

[CmdletBinding()]
param(
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Red
Write-Host " Smart Home - Reinicio COMPLETO del entorno" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red

if (-not $Force) {
    Write-Host ""
    Write-Host "[ADVERTENCIA]  ADVERTENCIA: esta accion eliminara el volumen de datos" -ForegroundColor Yellow
    Write-Host "    completo (smarthome_pgdata). Se perdera TODA la" -ForegroundColor Yellow
    Write-Host "    informacion almacenada en la base de datos." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    Si necesitas conservar los datos, ejecuta primero:" -ForegroundColor Yellow
    Write-Host "    .\scripts\backup.ps1" -ForegroundColor Yellow
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
    # 1. Detener y eliminar contenedores + volumenes
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Deteniendo contenedores y eliminando volumenes..." -ForegroundColor Cyan
    docker compose down -v

    if ($LASTEXITCODE -ne 0) {
        Write-Error "No se pudo detener/limpiar el entorno actual."
        exit 1
    }

    Write-Host "Entorno anterior eliminado [OK]" -ForegroundColor Green

    # --------------------------------------------------------
    # 2. Volver a levantar desde cero usando setup.ps1
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Levantando entorno limpio..." -ForegroundColor Cyan
    & (Join-Path $scriptDir "setup.ps1")

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Reinicio completado. Entorno Smart Home levantado desde cero." -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}
finally {
    Pop-Location
}