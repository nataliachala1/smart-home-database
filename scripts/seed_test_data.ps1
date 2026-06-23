<#
.SYNOPSIS
    Carga los datos de prueba del proyecto Smart Home.

.DESCRIPTION
    Ejecuta "liquibase update" pasando el contexto "test-data",
    que activa los changeSets protegidos en 02_dml/00_test_data
    (usuarios, hogares, dispositivos, consumo, notificaciones y
    configuraciones ficticias). Estos changeSets estan protegidos
    con context: test-data y NUNCA se ejecutan en un
    "liquibase update" normal sin este contexto explicito.

.EXAMPLE
    .\seed_test_data.ps1

Archivo: scripts/seed_test_data.ps1
Proyecto: Smart Home
Autor: Karen Daniela Holguin Cruz, Natalia Chala Chala, Kevin Stiven Lopez Amaya
Institucion: SENA - Analisis y Desarrollo de Software (Ficha 3145555)
Version: 1.0.0
Fecha: 2025
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Smart Home - Cargando datos de prueba" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "[ADVERTENCIA]  Esto insertara usuarios, hogares, dispositivos, lecturas" -ForegroundColor Yellow
Write-Host "    de consumo y notificaciones FICTICIAS. No usar en" -ForegroundColor Yellow
Write-Host "    produccion." -ForegroundColor Yellow
Write-Host ""

Push-Location $projectDir
try {
    # --------------------------------------------------------
    # 1. Verificar que el contenedor postgres este corriendo
    # --------------------------------------------------------
    $postgresStatus = docker compose ps --status running --services postgres

    if ([string]::IsNullOrWhiteSpace($postgresStatus)) {
        Write-Error "El contenedor postgres no esta corriendo. Ejecuta primero .\scripts\setup.ps1"
        exit 1
    }

    # --------------------------------------------------------
    # 2. Ejecutar Liquibase con el contexto test-data
    # --------------------------------------------------------
    Write-Host "Ejecutando migraciones con contexto 'test-data'..." -ForegroundColor Cyan

    docker compose run --rm liquibase update --contexts=test-data

    if ($LASTEXITCODE -ne 0) {
        Write-Error "La carga de datos de prueba fallo. Revisa el log de Liquibase arriba."
        exit 1
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Datos de prueba cargados exitosamente." -ForegroundColor Green
    Write-Host " Usuarios de prueba: karen@smarthome.com, kevin@smarthome.com," -ForegroundColor Green
    Write-Host "                     natalia@smarthome.com" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}
finally {
    Pop-Location
}