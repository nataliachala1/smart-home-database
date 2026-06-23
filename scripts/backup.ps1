<#
.SYNOPSIS
    Crea una copia de seguridad de la base de datos Smart Home.

.DESCRIPTION
    Ejecuta pg_dump dentro del contenedor postgres y guarda el
    archivo resultante en la carpeta backups/ con un nombre que
    incluye fecha y hora. Compatible con el flujo que espera el
    procedimiento sp_restaurar_backup (campo sync.backup.ubicacion).

.PARAMETER OutputDir
    Carpeta donde se guardara el archivo de backup.
    Por defecto: backups/ en la raiz del proyecto.

.EXAMPLE
    .\backup.ps1

.EXAMPLE
    .\backup.ps1 -OutputDir "D:\respaldos-smarthome"

Archivo: scripts/backup.ps1
Proyecto: Smart Home
Autor: Karen Daniela Holguin Cruz, Natalia Chala Chala, Kevin Stiven Lopez Amaya
Institucion: SENA - Analisis y Desarrollo de Software (Ficha 3145555)
Version: 1.0.0
Fecha: 2025
#>

[CmdletBinding()]
param(
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectDir = Split-Path -Parent $scriptDir

if ([string]::IsNullOrWhiteSpace($OutputDir)) {
    $OutputDir = Join-Path $projectDir "backups"
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " Smart Home - Backup de Base de Datos" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

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
    # 2. Crear carpeta de destino si no existe
    # --------------------------------------------------------
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    # --------------------------------------------------------
    # 3. Leer variables de entorno desde .env
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
    # 4. Generar nombre de archivo con timestamp
    # --------------------------------------------------------
    $timestamp  = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $fileName   = "smarthome_backup_$timestamp.sql"
    $outputPath = Join-Path $OutputDir $fileName

    # --------------------------------------------------------
    # 5. Ejecutar pg_dump dentro del contenedor
    # --------------------------------------------------------
    Write-Host ""
    Write-Host "Generando backup en: $outputPath" -ForegroundColor Cyan

    docker compose exec -T postgres pg_dump -U $dbUser -d $dbName --format=plain --no-owner --no-privileges |
        Out-File -FilePath $outputPath -Encoding utf8

    if ($LASTEXITCODE -ne 0) {
        Write-Error "El backup fallo. Revisa el log de pg_dump arriba."
        exit 1
    }

    $fileSize = (Get-Item $outputPath).Length / 1KB

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " Backup completado: $fileName ($([math]::Round($fileSize, 2)) KB)" -ForegroundColor Green
    Write-Host " Ubicacion: $outputPath" -ForegroundColor Green
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Recuerda registrar este backup en sync.backup si corresponde" -ForegroundColor Yellow
    Write-Host "(ver sp_restaurar_backup en 01_ddl/07_procedures)." -ForegroundColor Yellow
}
finally {
    Pop-Location
}