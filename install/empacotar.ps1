# install\empacotar.ps1 — monta o zip da release a partir de um commit (23/09/2026, issue #11)
#
# Uso (na raiz do repo):
#   powershell -ExecutionPolicy Bypass -File install\empacotar.ps1 [-Ref v0.12] [-Saida <pasta>]
# Gera InLabChecker-v<versao>.zip com a estrutura que o entry point espera, na
# RAIZ do zip (sem pasta InLabChecker\ por cima): InLabChecker.ms, core\,
# familias\, functions\, verifications\, report\, ui\, install\registrar.ms
# (o boot o chama na abertura do Max para registrar o botão da barra) e
# install\instalar_icone.ms (o instalador do ícone acha a raiz subindo de install\).
# NÃO leva tests\, docs\, .claude\, .superpowers\, o boot nem este script.
# Usa git archive: empacota o COMMIT, não a pasta de trabalho — mudança local
# sem commit nunca vaza para a release.
#
# 13/10/2026: gera também InLabChecker-v<versao>.mzp, o instalador de arrastar
# para o viewport. É o zip mais install\inlabchecker_boot.ms, install\instalar.ms
# e um mzp.run na raiz (extrai em $temp e roda o instalar.ms). O zip continua
# sendo o pacote do updater; o mzp é só para a primeira instalação.
#
# 14/10/2026 (#183): leva também dados\ (dados\produtos.json, a lista de
# produtos embutida, trocada toda semana por install\publicar_semana.ps1).
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
    InLabChecker.ms core familias functions verifications report ui dados install/instalar_icone.ms install/registrar.ms
if ($LASTEXITCODE -ne 0) { throw "git archive falhou" }

$mzp = Join-Path (Resolve-Path $Saida) "InLabChecker-v$versao.mzp"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("inlab_mzp_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$run = Join-Path $tmp "mzp.run"
$conteudo = @(
    'name "InLabChecker"',
    "version $versao",
    'extract to "$temp\InLabChecker_instalar"',
    'run "$temp\InLabChecker_instalar\install\instalar.ms"',
    'clear temp on MAX exit'
) -join "`r`n"
[IO.File]::WriteAllText($run, $conteudo + "`r`n", (New-Object Text.UTF8Encoding $false))
git archive --format=zip -o $mzp --add-file=$run $Ref `
    InLabChecker.ms core familias functions verifications report ui dados install/instalar_icone.ms install/registrar.ms `
    install/inlabchecker_boot.ms install/instalar.ms
$codigo = $LASTEXITCODE
Remove-Item -Recurse -Force $tmp
if ($codigo -ne 0) { throw "git archive do mzp falhou" }

Write-Output "Versao: $versao"
Write-Output "Zip:    $zip ($((Get-Item $zip).Length) bytes)"
Write-Output "Mzp:    $mzp ($((Get-Item $mzp).Length) bytes)"
