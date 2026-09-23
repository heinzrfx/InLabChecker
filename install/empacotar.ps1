# install\empacotar.ps1 — monta o zip da release a partir de um commit (23/09/2026, issue #11)
#
# Uso (na raiz do repo):
#   powershell -ExecutionPolicy Bypass -File install\empacotar.ps1 [-Ref v0.12] [-Saida <pasta>]
# Gera InLabChecker-v<versao>.zip com a estrutura que o entry point espera, na
# RAIZ do zip (sem pasta InLabChecker\ por cima): InLabChecker.ms, core\,
# familias\, functions\, verifications\, report\, ui\ e install\instalar_icone.ms
# (o instalador do ícone acha a raiz subindo de install\).
# NÃO leva tests\, docs\, .claude\, .superpowers\, o boot nem este script.
# Usa git archive: empacota o COMMIT, não a pasta de trabalho — mudança local
# sem commit nunca vaza para a release.
param(
    [string]$Ref = "HEAD",
    [string]$Saida = "."
)
$ErrorActionPreference = "Stop"

$versaoMs = git show "${Ref}:core/versao.ms"
$m = [regex]::Match(($versaoMs -join "`n"), 'global INLAB_VERSAO\s*=\s*"([^"]+)"')
if (-not $m.Success) { throw "INLAB_VERSAO nao encontrada em core/versao.ms de $Ref" }
$versao = $m.Groups[1].Value

$zip = Join-Path (Resolve-Path $Saida) "InLabChecker-v$versao.zip"
git archive --format=zip -o $zip $Ref `
    InLabChecker.ms core familias functions verifications report ui install/instalar_icone.ms
if ($LASTEXITCODE -ne 0) { throw "git archive falhou" }

Write-Output "Versao: $versao"
Write-Output "Zip:    $zip ($((Get-Item $zip).Length) bytes)"
