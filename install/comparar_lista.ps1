# install\comparar_lista.ps1 — compara um export novo com a lista publicada (03/11/2026)
#
# Uso (na raiz do repo):
#   powershell -ExecutionPolicy Bypass -File install\comparar_lista.ps1 -Json "<export>.json"
# Quem chama de costume é o install\atualizar_lista.bat (arrastar o JSON em cima).
#
# Compara com a lista da origin/main (não com a cópia local, que pode estar
# atrasada) e mostra: produtos novos, removidos e alterados (com os campos que
# mudaram), campos que o plugin nunca viu, cópias de bloco_3d cujo base_codest
# não está na lista e partes com mais de uma matéria-prima ou herdada (#207,
# o plugin liga uma matéria por parte).
# Só lê: não grava nada. Sai com 1 se o JSON for inválido ou se o repo não
# estiver na main; com 2 se a lista é igual à publicada; com 0 no resto.
param([Parameter(Mandatory = $true)][string]$Json)
$ErrorActionPreference = "Stop"
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

function Falhar($msg) { Write-Host "ERRO: $msg" -ForegroundColor Red; exit 1 }
function Titulo($msg) { Write-Host ""; Write-Host $msg -ForegroundColor Cyan }

$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne "main") { Falhar "o repo está na branch '$branch'. Volte para a main (git checkout main)." }

# JSON novo
if (-not (Test-Path -LiteralPath $Json)) { Falhar "arquivo não encontrado: $Json" }
$textoNovo = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Json), [Text.Encoding]::UTF8)
try { $novo = $textoNovo | ConvertFrom-Json } catch { Falhar "o arquivo não é um JSON válido: $_" }
$prodNovos = @($novo.produtos)
if ($prodNovos.Count -eq 0) { Falhar "o JSON não tem lista de produtos (use o export da linha, nomenclatura_...json)." }

# Lista publicada (origin/main). git show devolve bytes UTF-8: lê por arquivo temporário.
git fetch -q origin main
if ($LASTEXITCODE -ne 0) { Falhar "git fetch falhou (sem internet?)." }
$tmp = [IO.Path]::GetTempFileName()
cmd /c "git show origin/main:dados/produtos.json > `"$tmp`""
$textoVelho = [IO.File]::ReadAllText($tmp, [Text.Encoding]::UTF8)
Remove-Item $tmp -Force
$velho = $textoVelho | ConvertFrom-Json
$prodVelhos = @($velho.produtos)

Write-Host "Publicada: $($prodVelhos.Count) produtos · export de $($velho.exportado_em)"
Write-Host "Nova:      $($prodNovos.Count) produtos · export de $($novo.exportado_em)"

function Chave($p) { "$($p.cod_est)" }
function Js($o) { if ($null -eq $o) { "null" } else { ConvertTo-Json $o -Depth 50 -Compress } }

$mapaVelho = @{}; foreach ($p in $prodVelhos) { $mapaVelho[(Chave $p)] = $p }
$mapaNovo = @{}; foreach ($p in $prodNovos) { $mapaNovo[(Chave $p)] = $p }

# Produtos novos / removidos / alterados
$novosCod = @($prodNovos | Where-Object { -not $mapaVelho.ContainsKey((Chave $_)) })
$removidos = @($prodVelhos | Where-Object { -not $mapaNovo.ContainsKey((Chave $_)) })
$alterados = @()
foreach ($p in $prodNovos) {
    $c = Chave $p
    if (-not $mapaVelho.ContainsKey($c)) { continue }
    $a = $mapaVelho[$c]
    $nomes = @($a.PSObject.Properties.Name) + @($p.PSObject.Properties.Name) | Select-Object -Unique
    $campos = @($nomes | Where-Object { (Js $a.$_) -ne (Js $p.$_) })
    if ($campos.Count -gt 0) { $alterados += [pscustomobject]@{ Produto = $p; Campos = $campos } }
}

$atencao = 0
Titulo "Produtos novos: $($novosCod.Count)"
foreach ($p in $novosCod) { Write-Host "  + $($p.cod_est)  $($p.nome)" -ForegroundColor Green }
Titulo "Produtos removidos: $($removidos.Count)"
foreach ($p in $removidos) { Write-Host "  - $($p.cod_est)  $($p.nome)" -ForegroundColor Red; $atencao++ }
Titulo "Produtos alterados: $($alterados.Count)"
foreach ($x in $alterados) { Write-Host "  * $($x.Produto.cod_est)  $($x.Produto.nome)  [$($x.Campos -join ', ')]" -ForegroundColor Yellow }

# Campos que a lista publicada não tinha (o plugin pode não saber ler)
function Caminhos($o, [string]$p, $conj) {
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        foreach ($prop in $o.PSObject.Properties) {
            $q = "$p.$($prop.Name)"
            [void]$conj.Add($q)
            Caminhos $prop.Value $q $conj
        }
    } elseif ($o -is [array]) {
        foreach ($v in $o) { Caminhos $v "$p[]" $conj }
    }
}
$conjVelho = New-Object 'System.Collections.Generic.HashSet[string]'
$conjNovo = New-Object 'System.Collections.Generic.HashSet[string]'
Caminhos $velho "" $conjVelho
Caminhos $novo "" $conjNovo
$camposNovos = @($conjNovo | Where-Object { -not $conjVelho.Contains($_) } | Sort-Object)
Titulo "Campos que a lista publicada não tinha: $($camposNovos.Count)"
foreach ($c in $camposNovos) { Write-Host "  ! $c" -ForegroundColor Magenta; $atencao++ }

# Cópias de bloco_3d apontando para código fora da lista
$copiasOrfas = @($prodNovos | Where-Object {
    $b = $_.bloco_3d
    $b -and "$($b.base_codest)" -ne "" -and -not $mapaNovo.ContainsKey("$($b.base_codest)")
})
Titulo "Cópias com base_codest fora da lista: $($copiasOrfas.Count)"
foreach ($p in $copiasOrfas) { Write-Host "  ! $($p.cod_est)  $($p.nome)  -> base $($p.bloco_3d.base_codest)" -ForegroundColor Magenta; $atencao++ }

# Partes com mais de uma matéria-prima ou herdada (#207)
$multi = @()
foreach ($p in $prodNovos) {
    foreach ($t in @($p.partes)) {
        if (@($t.materias_primas).Count -gt 1 -or $t.materia_prima_herdada -eq $true) { $multi += "$($p.cod_est)  $($t.nome_parte)" }
    }
}
Titulo "Partes com mais de uma matéria-prima ou herdada: $($multi.Count)"
foreach ($m in $multi) { Write-Host "  ! $m" -ForegroundColor Magenta; $atencao++ }

Write-Host ""
if ($novosCod.Count + $removidos.Count + $alterados.Count -eq 0 -and $camposNovos.Count -eq 0) {
    Write-Host "A lista é igual à publicada." -ForegroundColor Yellow
    exit 2
}
if ($atencao -gt 0) {
    Write-Host "Há $atencao ponto(s) de atenção acima (removidos e marcados com !). Confira antes de publicar (ou peça para o Claude olhar)." -ForegroundColor Magenta
} else {
    Write-Host "Nada fora do comum." -ForegroundColor Green
}
exit 0
