/*
 === functions\fn_ver_uv.ms ===
 Ver UV (26/10/2026, Mapear por paineis, Tarefa 5): troca temporariamente o material
 dos nos por um de listras + a letra "F", para conferir o mapeamento no viewport
 (esticado, espelhado, emendas). Spec: 2026-10-26-mapear-paineis-design.md, secao 7.

 O que faz:
   - InLab_VerUV_Ligar objs -> n de nos trocados (#warn e 0 sem objetos). Guarda o
     material original de cada no; o material "InLab Ver UV" e um so, com o PNG no
     canal 1 e tiling 3 (a listra de 18 px a cada 64 repete 3 vezes por tile).
   - Ligar recusa (#warn, 0) com o Real-Time Exporter aberto (InLab_VerUV_ExportadorAberto):
     ele exportaria o material das listras.
   - InLab_VerUV_Desligar() -> n de nos devolvidos (no apagado e ignorado).
   - InLab_VerUV_Ligado() -> bool.
   - InLab_VerUV_MaterialDe o -> o material original se o esta no Ver UV, senao
     o.material. Mapear e Paineis leem o material por aqui (o Ver UV nao pode
     enganar a parte do JSON nem os bitmaps).
   - InLab_VerUV_Textura() -> ui\img\uv_listras.png; se faltar, gera no temp
     (mesmo desenho do PNG do repo: 512x512, fundo (240,235,220), 8 listras de 18 px
     (180,60,30) a cada 64 px, "F" Arial Bold 150 (30,60,200) em (170,120)).
   - Callbacks #InLabVerUV (filePreSave, preExport, systemPreReset, systemPreNew, filePreOpen)
     desligam antes de salvar/limpar a cena: o .max nunca guarda o material do Ver UV.
     O export glTF tambem desliga antes (fn_export_gltf.ms).
 Decisoes:
   - Sem undo: a troca roda em `with undo off` (nao entra no Ctrl+Z; o Desligar e o
     caminho de volta).
   - Os registros nao tem inicializador no `global`: recarregar o arquivo com o Ver
     UV ligado nao perde os originais.
 26/10/2026 (revisao final da feature):
   - InLab_VerUV_Garantir() -> n de nos que continuam com as listras (0 = cena limpa).
     Varre `objects` atras de no com o material das listras fora do registro (clone
     com Shift+arrastar, apagar -> salvar -> Ctrl+Z, Hold/Fetch): instancia de um no
     registrado (InLab_Instancias) recebe o original dele (#info); o resto da #err
     "aplique o material de novo". Depois desliga (InLab_VerUV_Desligar).
     Quem troca o.material ou exporta chama o Garantir antes: Converter Material
     (InLab_ConverterObjetos/InLab_ReverterConversao), RWF (InLab_RealWorldFix),
     Renomear pelo JSON (InLab_Produto_MateriaisDaSelecao/InLab_Produto_Aplicar),
     InLab_ExportGLTF, InLab_AbrirExportadorRealTime e InLab_RodarVerificacoes; os
     tres ultimos recusam (#err, false) se ainda sobrar no com as listras. Os callbacks
     e o botao Ver UV desligado tambem usam o Garantir.
   - Desligar so devolve o original quando o no ainda esta com as listras
     (o.material == InLab_VerUV_Mat); material trocado com o Ver UV ligado fica, com #warn.
   - Ligar nao registra no que ja esta com as listras sem registro (guardaria as
     listras como original): #warn e pula.
   - InLab_VerUV_NosQueUsam b -> nos registrados cujo material original usa o
     texmap b. Com o Ver UV ligado, refs.dependentNodes b nao ve esses nos: a guarda
     "bitmap usado fora desta rodada" do Mapear e do Paineis soma esses nos.
   - O autobackup pode disparar #filePreSave e desligar o Ver UV: aceito.
*/
global InLab_Log, INLAB_ROOT
global InLab_Instancias   -- fn_autouv.ms (carrega antes; guarda != undefined nos testes)
global InLab_VerUV_Nos, InLab_VerUV_Origs, InLab_VerUV_Mat
if InLab_VerUV_Nos == undefined do InLab_VerUV_Nos = #()
if InLab_VerUV_Origs == undefined do InLab_VerUV_Origs = #()

global InLab_VerUV_Desligar, InLab_VerUV_ComListras, InLab_VerUV_Garantir, InLab_VerUV_MatUsa, InLab_VerUV_NosQueUsam
-- 26/10/2026: gancho da UI (definido em ui\rollout_main.ms, que carrega depois):
-- Ligar e Desligar avisam o botao Ver UV para ele acompanhar o estado real, inclusive
-- nos desligamentos automaticos (salvar, resetar, exportar, verificar).
global InLab_VerUV_SincronizarUI

-- Gera o PNG de listras (512x512). Retorna true se gravou.
fn InLab_VerUV_GerarPNG caminho =
(
    local ok = false
    local bmp, g, bPincel, bListra, bLetra, fonte
    try
    (
        bmp = dotNetObject "System.Drawing.Bitmap" 512 512
        g = (dotNetClass "System.Drawing.Graphics").FromImage bmp
        local cor = dotNetClass "System.Drawing.Color"
        g.Clear (cor.FromArgb 240 235 220)
        bListra = dotNetObject "System.Drawing.SolidBrush" (cor.FromArgb 180 60 30)
        for i = 0 to 7 do g.FillRectangle bListra (i * 64) 0 18 512
        bLetra = dotNetObject "System.Drawing.SolidBrush" (cor.FromArgb 30 60 200)
        fonte = dotNetObject "System.Drawing.Font" "Arial" 150.0 (dotNetClass "System.Drawing.FontStyle").Bold (dotNetClass "System.Drawing.GraphicsUnit").Pixel
        g.DrawString "F" fonte bLetra 170.0 120.0
        bmp.Save caminho (dotNetClass "System.Drawing.Imaging.ImageFormat").Png
        ok = true
    )
    catch ( InLab_Log ("Ver UV: não gerei a textura de listras (" + getCurrentException() + ").") tipo:#err )
    try ( if bListra != undefined do bListra.Dispose() ) catch ()
    try ( if bLetra != undefined do bLetra.Dispose() ) catch ()
    try ( if fonte != undefined do fonte.Dispose() ) catch ()
    try ( if g != undefined do g.Dispose() ) catch ()
    try ( if bmp != undefined do bmp.Dispose() ) catch ()
    ok
)

fn InLab_VerUV_Textura =
(
    local doRepo = INLAB_ROOT + "ui\img\uv_listras.png"
    if doesFileExist doRepo then doRepo
    else
    (
        local gerado = (getDir #temp) + "\inlab_uv_listras.png"
        if not (doesFileExist gerado) do InLab_VerUV_GerarPNG gerado
        gerado
    )
)

fn InLab_VerUV_Ligado = ( (for o in InLab_VerUV_Nos where isValidNode o collect o).count > 0 )

fn InLab_VerUV_MaterialDe o =
(
    local k = findItem InLab_VerUV_Nos o
    if k > 0 then InLab_VerUV_Origs[k] else o.material
)

-- o no esta com o material das listras (o registrado ou um de mesmo nome, de antes de recarregar)
fn InLab_VerUV_ComListras o =
(
    isValidNode o and o.material != undefined and \
        ((InLab_VerUV_Mat != undefined and o.material == InLab_VerUV_Mat) or o.material.name == "InLab Ver UV")
)

-- o material (ou texmap) mtl usa o texmap alvo em algum ponto da arvore (submateriais e submapas)
fn InLab_VerUV_MatUsa mtl alvo =
(
    local r = false
    if mtl != undefined do
    (
        if mtl == alvo then r = true
        else
        (
            if superclassof mtl == material do
                for i = 1 to (getNumSubMtls mtl) while not r do r = InLab_VerUV_MatUsa (getSubMtl mtl i) alvo
            for i = 1 to (getNumSubTexmaps mtl) while not r do r = InLab_VerUV_MatUsa (getSubTexmap mtl i) alvo
        )
    )
    r
)

-- nos registrados no Ver UV cujo material original usa o texmap b
fn InLab_VerUV_NosQueUsam b =
(
    local res = #()
    for k = 1 to InLab_VerUV_Nos.count do
        if isValidNode InLab_VerUV_Nos[k] and (InLab_VerUV_MatUsa InLab_VerUV_Origs[k] b) do append res InLab_VerUV_Nos[k]
    res
)

fn InLab_VerUV_CriarMaterial =
(
    local m = StandardMaterial name:"InLab Ver UV"
    local t = BitmapTexture fileName:(InLab_VerUV_Textura())
    t.coords.mapChannel = 1
    t.coords.U_Tiling = 3
    t.coords.V_Tiling = 3
    m.diffuseMap = t
    m.showInViewport = true
    m
)

-- true com o Real-Time Exporter aberto (ele exportaria o material das listras).
fn InLab_VerUV_ExportadorAberto =
(
    (try ( GameExporterShown() ) catch ( false )) == true
)

fn InLab_VerUV_Ligar objs =
(
    local n = 0
    if InLab_VerUV_ExportadorAberto() then InLab_Log "Ver UV: feche o Real-Time Exporter antes de ligar o Ver UV" tipo:#warn
    else
    (
        local alvos = if objs == undefined then #() else (for o in objs where isValidNode o and superclassof o == GeometryClass collect o)
        if alvos.count == 0 then InLab_Log "Ver UV: nenhum objeto de geometria selecionado." tipo:#warn
        else
        (
            with undo off
            (
                if InLab_VerUV_Mat == undefined do InLab_VerUV_Mat = InLab_VerUV_CriarMaterial()
                for o in alvos where (findItem InLab_VerUV_Nos o) == 0 do
                (
                    if InLab_VerUV_ComListras o then
                        InLab_Log (o.name + ": já está com o material de listras do Ver UV, sem o original registrado; aplique o material de novo.") tipo:#warn
                    else
                    (
                    append InLab_VerUV_Nos o
                    append InLab_VerUV_Origs o.material
                    o.material = InLab_VerUV_Mat
                    n += 1
                    )
                )
            )
            InLab_Log ("Ver UV: ligado em " + n as string + " peça(s).") tipo:#ok
        )
    )
    if InLab_VerUV_SincronizarUI != undefined do try ( InLab_VerUV_SincronizarUI() ) catch ()
    n
)

fn InLab_VerUV_Desligar =
(
    local n = 0
    local nosFicam = #(), origsFicam = #()
    local tinha = InLab_VerUV_Nos.count
    with undo off
    (
        for k = 1 to InLab_VerUV_Nos.count do
        (
            local o = InLab_VerUV_Nos[k]
            if isValidNode o do
            (
                -- material trocado com o Ver UV ligado: o atual é o que vale
                if not (InLab_VerUV_ComListras o) then
                    InLab_Log (o.name + ": material trocado com o Ver UV ligado; mantido.") tipo:#warn
                else try ( o.material = InLab_VerUV_Origs[k]; n += 1 )
                catch
                (
                    -- não perde o original: o nó fica registrado para uma nova tentativa
                    append nosFicam o; append origsFicam InLab_VerUV_Origs[k]
                    InLab_Log ("Ver UV: não devolvi o material de um nó (" + getCurrentException() + ").") tipo:#err
                )
            )
        )
    )
    InLab_VerUV_Nos = nosFicam
    InLab_VerUV_Origs = origsFicam
    if nosFicam.count == 0 do InLab_VerUV_Mat = undefined
    if tinha > 0 do InLab_Log ("Ver UV: desligado, " + n as string + " peça(s) com o material original.") tipo:#ok
    if InLab_VerUV_SincronizarUI != undefined do try ( InLab_VerUV_SincronizarUI() ) catch ()
    n
)

-- Desliga e confere a cena inteira: no com as listras fora do registro (clone, Ctrl+Z
-- depois de salvar, Hold/Fetch) recebe o original da instancia registrada ou da #err.
-- Devolve o n de nos que continuam com as listras.
fn InLab_VerUV_Garantir =
(
    local orfaos = for o in objects where (InLab_VerUV_ComListras o) and (findItem InLab_VerUV_Nos o) == 0 collect o
    if orfaos.count > 0 do
        with undo off
        (
            for o in orfaos do
            (
                local k = 0
                if InLab_Instancias != undefined do
                (
                    local inst = InLab_Instancias o
                    for i = 1 to InLab_VerUV_Nos.count while k == 0 do
                        if isValidNode InLab_VerUV_Nos[i] and (findItem inst InLab_VerUV_Nos[i]) > 0 do k = i
                )
                if k > 0 then
                (
                    o.material = InLab_VerUV_Origs[k]
                    InLab_Log (o.name + ": instância de " + InLab_VerUV_Nos[k].name + " com as listras do Ver UV; recebe o material original dela.") tipo:#info
                )
                else
                    InLab_Log (o.name + ": está com o material de listras do Ver UV e não sei o original; aplique o material de novo.") tipo:#err
            )
        )
    InLab_VerUV_Desligar()
    (for o in objects where InLab_VerUV_ComListras o collect o).count
)

-- Antes de salvar, limpar a cena ou abrir outra: o material do Ver UV nao pode ir
-- para o arquivo nem ficar orfao.
callbacks.removeScripts id:#InLabVerUV
for ev in #(#filePreSave, #preExport, #systemPreReset, #systemPreNew, #filePreOpen) do
    callbacks.addScript ev "try ( InLab_VerUV_Garantir() ) catch ( try ( InLab_Log (\"Ver UV: não desliguei antes de salvar/limpar (\" + getCurrentException() + \")\") tipo:#err ) catch () )" id:#InLabVerUV
