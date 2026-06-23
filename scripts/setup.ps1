<#
.SYNOPSIS
    Levanta el entorno completo de la base de datos Smart Home.

.DESCRIPTION
    Inicia el contenedor postgres, espera a que este saludable
    (healthcheck) y luego ejecuta "liquibase update" para aplicar
    todas las migraciones definidas en changelog-master.yaml.
    No incluye los datos de prueba (00_test_data) - para eso usar
    seed_test_data.ps1 por separado.

.EXAMPLE
    .\setup.ps1

Archivo: scripts/setup.ps1
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
Write-Host " Smart Home - Levantando entorno de base de datos" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

Push-Location $projectDir
try {
    # --------------------------------------------------------
    # 1. Verificar que exista el archivo .env
    # --------------------------------------------------------
    if (-not (Test-Path ".env")) {
        Write-Warning "No se encontro el archivo .env"
        if (Test-Path ".env.example") {
            Write-Host "Copiando .env.example a .env..." -ForegroundColor Yellow
            Copy-Item ".env.example" ".env"
            Write-Host "[ADVERTENCIA]  Revisa y completa las variables en .env antes de continuar." -ForegroundColor Yellow
        }
        else {
            Write-Error "No se encontro .env ni .env.example. Operacion cancelada."
            exit 1
        }
    }

    # --------------------------------------------------------
    # 2. Levantar el contenedor postgres
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Levantando contenedor postgres..." -ForegroundColor Cyan
    docker compose up -d postgres

    if ($LASTEXITCODE -ne 0) {
        Write-Error "No se pudo levantar el contenedor postgres."
        exit 1
    }

    # --------------------------------------------------------
    # 3. Esperar a que postgres este saludable
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Esperando a que postgres este listo..." -ForegroundColor Cyan

    $maxRetries = 30
    $retryCount = 0
    $isHealthy  = $false

    while ($retryCount -lt $maxRetries -and -not $isHealthy) {
        Start-Sleep -Seconds 2
        $status = docker inspect --format='{{.State.Health.Status}}' smarthome_postgres 2>$null

        if ($status -eq "healthy") {
            $isHealthy = $true
        }
        else {
            $retryCount++
            Write-Host "  Esperando... ($retryCount/$maxRetries)" -ForegroundColor Gray
        }
    }

    if (-not $isHealthy) {
        Write-Error "El contenedor postgres no alcanzo estado 'healthy' a tiempo."
        exit 1
    }

    Write-Host "postgres esta listo [OK]" -ForegroundColor Green

    # --------------------------------------------------------
    # 4. Ejecutar migraciones de Liquibase
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Ejecutando migraciones de Liquibase (changelog-master.yaml) excluyendo scripts de referencia..." -ForegroundColor Cyan
    docker compose run --rm liquibase update --contexts='!reference'

    if ($LASTEXITCODE -ne 0) {
        Write-Error "La ejecucion de Liquibase fallo. Revisa el log arriba."
        exit 1
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Entorno Smart Home listo." -ForegroundColor Green
    Write-Host " Para cargar datos de prueba, ejecuta: .\scripts\seed_test_data.ps1" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
}
finally {
    Pop-Location
}