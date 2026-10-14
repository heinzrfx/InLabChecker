# install\publicar_semana.ps1 — release semanal: lista de produtos + correções (14/10/2026, issue #183)
#
# Uso (na raiz do repo, na main, sem mudança local):
#   powershell -ExecutionPolicy Bypass -File install\publicar_semana.ps1 -Json "<export da plataforma>.json" [-Versao 1.2.0] [-Teste]
#
# O que faz, nesta ordem:
#   1. confere que está na main, sem mudança local, e puxa a origin;
#   2. lê o JSON e confere que tem "produtos" (mostra quantos e a data do export);
#   3. copia para dados\produtos.json;
#   4. sobe INLAB_VERSAO em core\versao.ms (último número + 1, ou -Versao);
#   5. commit e push na main;
#   6. empacota (empacotar.ps1) e cria a release v<versão> com zip, mzp e boot.
# A release nova acende a pastilha de versão nos painéis do time (busca a cada
# 4 h ao abrir o painel, ou na hora pelo clique na pastilha).
# Correções de código da semana entram antes, por PR na main: a release leva
# o que a main tiver. As notas listam os commits desde a última tag.
# -Teste: faz os passos 1 a 4 e para (desfaz a cópia e a versão), sem commit,
# push nem release.
param(
    [Parameter(Mandatory = $true)][string]$Json,
    [string]$Versao = "",
    [switch]$Teste
)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

function Falhar($msg) { Write-Host "ERRO: $msg" -ForegroundColor Red; exit 1 }

# 1. main limpa e em dia
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "main") { Falhar "está na branch '$branch'. Rode na main." }
if (git status --porcelain --untracked-files=no) { Falhar "há mudança local sem commit. Faça o commit (ou descarte) antes." }
git pull --ff-only --tags origin main
if ($LASTEXITCODE -ne 0) { Falhar "git pull falhou." }

# 2. JSON válido
if (-not (Test-Path -LiteralPath $Json)) { Falhar "arquivo não encontrado: $Json" }
$texto = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Json), [Text.Encoding]::UTF8)
try { $dados = $texto | ConvertFrom-Json } catch { Falhar "o arquivo não é um JSON válido: $_" }
$n = @($dados.produtos).Count
if ($n -eq 0) { Falhar "o JSON não tem lista de produtos (use o export da linha, nomenclatura_export_...json)." }
$exportado = "$($dados.exportado_em)"
Write-Host "Lista: $n produtos · exportada em $exportado"

# 3. cópia
$destino = Join-Path $raiz "dados\produtos.json"
New-Item -ItemType Directory -Force -Path (Split-Path $destino) | Out-Null
Copy-Item -LiteralPath (Resolve-Path -LiteralPath $Json) -Destination $destino -Force
# git diff normaliza o fim de linha (o export vem em LF, o checkout em CRLF).
git diff --quiet -- dados/produtos.json
$listaMudou = ($LASTEXITCODE -ne 0)

# 4. versão
$arqVersao = Join-Path $raiz "core\versao.ms"
$conteudo = [IO.File]::ReadAllText($arqVersao, [Text.Encoding]::UTF8)
$m = [regex]::Match($conteudo, 'global INLAB_VERSAO\s*=\s*"([^"]+)"')
if (-not $m.Success) { Falhar "INLAB_VERSAO não encontrada em core\versao.ms." }
$atual = $m.Groups[1].Value
if ($Versao -eq "") {
    $partes = $atual.Split(".")
    if ($partes.Count -lt 3) { $partes += "0" }
    $partes[-1] = [string]([int]$partes[-1] + 1)
    $Versao = $partes -join "."
}
$ultimaTag = (git describe --tags --abbrev=0 2>$null)
$commits = if ($ultimaTag) { @(git log "$ultimaTag..HEAD" --no-merges --format="- %s") } else { @() }
if (-not $listaMudou -and $commits.Count -eq 0) {
    Falhar "nada novo: a lista é igual à da v$atual e não há commit desde $ultimaTag."
}
$novo = $conteudo.Substring(0, $m.Groups[1].Index) + $Versao + $conteudo.Substring($m.Groups[1].Index + $m.Groups[1].Length)
[IO.File]::WriteAllText($arqVersao, $novo, (New-Object Text.UTF8Encoding $false))
$qual = if ($listaMudou) { "lista nova" } else { "mesma lista" }
Write-Host "Versão: $atual -> $Versao ($qual)"

if ($Teste) {
    git checkout -- dados/produtos.json core/versao.ms 2>$null
    Write-Host "Teste: parei antes do commit. Nada foi gravado." -ForegroundColor Yellow
    exit 0
}

# 5. commit e push
$hoje = Get-Date -Format "dd/MM/yyyy"
git add dados/produtos.json core/versao.ms
git commit -m "chore(release): versao $Versao, lista de produtos de $hoje"
if ($LASTEXITCODE -ne 0) { Falhar "git commit falhou." }
git push origin main
if ($LASTEXITCODE -ne 0) { Falhar "git push falhou." }

# 6. pacote e release
$saida = Join-Path ([IO.Path]::GetTempPath()) ("inlab_release_" + $Versao)
New-Item -ItemType Directory -Force -Path $saida | Out-Null
& (Join-Path $PSScriptRoot "empacotar.ps1") -Ref HEAD -Saida $saida
$linhaLista = "$n produtos · export de $exportado"
if (-not $listaMudou) { $linhaLista += " (sem mudança)" }
$notas = @("Versão da semana ($hoje).", "", "## Lista de produtos", "", $linhaLista)
if ($commits.Count -gt 0) { $notas += @("", "## Mudanças desde $ultimaTag", "") + $commits }
$notas += @("", "## Atualizar", "", "Clique na pastilha de versão, no topo do painel. Máquina nova: arraste o InLabChecker-v$Versao.mzp para o viewport.")
$arqNotas = Join-Path $saida "notas.md"
[IO.File]::WriteAllText($arqNotas, ($notas -join "`n"), (New-Object Text.UTF8Encoding $false))
gh release create "v$Versao" (Join-Path $saida "InLabChecker-v$Versao.zip") (Join-Path $saida "InLabChecker-v$Versao.mzp") "install/inlabchecker_boot.ms" --title "InLabChecker v$Versao" --notes-file $arqNotas
if ($LASTEXITCODE -ne 0) { Falhar "gh release create falhou (o commit já está na main; rode só o passo 6 de novo)." }
$tag = (gh api repos/heinzrfx/InLabChecker/releases/latest --jq .tag_name)
Write-Host "Publicada: $tag. A pastilha acende nos painéis do time." -ForegroundColor Green
