<#
.SYNOPSIS
    Wrapper de entrada para revertir la base de datos Smart Home.

.DESCRIPTION
    Punto de entrada simple que delega toda la logica real a
    rollback-by-id.ps1, ubicado en la misma carpeta. Permite
    invocar el rollback con un nombre de comando corto y generico
    mientras la implementacion detallada vive en un archivo
    separado y mas descriptivo.

.PARAMETER Tag
    Nombre del tag de Liquibase al cual revertir. Se reenvia
    sin modificar a rollback-by-id.ps1.

.EXAMPLE
    .\rollback.ps1 -Tag v1.0.0

.EXAMPLE
    .\rollback.ps1
    (rollback-by-id.ps1 solicitara el tag de forma interactiva)

Archivo: scripts/rollback.ps1
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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$mainScript = Join-Path $scriptDir "rollback-by-id.ps1"

# Reenvia todos los parametros recibidos (incluyendo -Tag) al
# script real. El splat @PSBoundParameters preserva nombres de
# parametro y valores exactamente como fueron pasados.
& $mainScript @PSBoundParameters