<#
.SYNOPSIS
    Utilitário CLI para invocar o agente 'developer' (Qwen2.5-Coder-14B) no Ollama.
.EXAMPLE
    .\ask_developer.ps1 "Escreva um script GDScript 4..."
    .\ask_developer.ps1 -SpecFile "spec.md"
#>
param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$PromptText,
    [Parameter(Mandatory=$false)]
    [string]$SpecFile
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($SpecFile -and (Test-Path $SpecFile)) {
    $PromptText = [System.IO.File]::ReadAllText($SpecFile, [System.Text.Encoding]::UTF8)
}

if (-not $PromptText) {
    Write-Host "Uso: .\ask_developer.ps1 'seu pseudocodigo aqui' OU .\ask_developer.ps1 -SpecFile caminho\para\spec.md" -ForegroundColor Yellow
    exit 1
}

$bodyObj = @{
    model = "developer"
    prompt = $PromptText
    stream = $false
}

$jsonBody = $bodyObj | ConvertTo-Json -Compress

try {
    $response = Invoke-RestMethod -Uri "http://127.0.0.1:11434/api/generate" -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonBody)) -ContentType "application/json; charset=utf-8"
    Write-Output $response.response
} catch {
    Write-Error "Erro ao conectar com Ollama (http://127.0.0.1:11434): $_"
}

