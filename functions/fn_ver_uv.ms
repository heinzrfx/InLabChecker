/*
 === functions\fn_ver_uv.ms ===
 Ver UV (26/10/2026, Mapear por paineis, Tarefa 5): troca temporariamente o material
 dos nos por um de listras + a letra "F", para conferir o mapeamento no viewport
 (esticado, espelhado, emendas). Spec: 2026-10-26-mapear-paineis-design.md, secao 7.

 O que faz:
   - InLab_VerUV_Ligar objs -> n de nos trocados (#warn e 0 sem objetos). Guarda o
     material original de cada no; o material "InLab Ver UV" e um so, com o PNG no
     canal 1 e tiling 3 (a listra de 18 px a cada 64 repete 3 vezes por tile).
   - InLab_VerUV_Desligar() -> n de nos devolvidos (no apagado e ignorado).
   - InLab_VerUV_Ligado() -> bool.
   - InLab_VerUV_MaterialDe o -> o material original se o esta no Ver UV, senao
     o.material. Mapear e Paineis leem o material por aqui (o Ver UV nao pode
     enganar a parte do JSON nem os bitmaps).
   - InLab_VerUV_Textura() -> ui\img\uv_listras.png; se faltar, gera no temp
     (mesmo desenho do PNG do repo: 512x512, fundo (240,235,220), 8 listras de 18 px
     (180,60,30) a cada 64 px, "F" Arial Bold 150 (30,60,200) em (170,120)).
   - Callbacks #InLabVerUV (filePreSave, systemPreReset, systemPreNew, filePreOpen)
     desligam antes de salvar/limpar a cena: o .max nunca guarda o material do Ver UV.
     O export glTF tambem desliga antes (fn_export_gltf.ms).
 Decisoes:
   - Sem undo: a troca roda em `with undo off` (nao entra no Ctrl+Z; o Desligar e o
     caminho de volta).
   - Os registros nao tem inicializador no `global`: recarregar o arquivo com o Ver
     UV ligado nao perde os originais.
*/
global InLab_Log, INLAB_ROOT
global InLab_VerUV_Nos, InLab_VerUV_Origs, InLab_VerUV_Mat
if InLab_VerUV_Nos == undefined do InLab_VerUV_Nos = #()
if InLab_VerUV_Origs == undefined do InLab_VerUV_Origs = #()

global InLab_VerUV_Desligar

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

fn InLab_VerUV_Ligado = ( InLab_VerUV_Nos.count > 0 )

fn InLab_VerUV_MaterialDe o =
(
    local k = findItem InLab_VerUV_Nos o
    if k > 0 then InLab_VerUV_Origs[k] else o.material
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

fn InLab_VerUV_Ligar objs =
(
    local n = 0
    local alvos = if objs == undefined then #() else (for o in objs where isValidNode o and superclassof o == GeometryClass collect o)
    if alvos.count == 0 then InLab_Log "Ver UV: nenhum objeto de geometria selecionado." tipo:#warn
    else
    (
        with undo off
        (
            if InLab_VerUV_Mat == undefined do InLab_VerUV_Mat = InLab_VerUV_CriarMaterial()
            for o in alvos where (findItem InLab_VerUV_Nos o) == 0 do
            (
                append InLab_VerUV_Nos o
                append InLab_VerUV_Origs o.material
                o.material = InLab_VerUV_Mat
                n += 1
            )
        )
        InLab_Log ("Ver UV: ligado em " + n as string + " peça(s).") tipo:#ok
    )
    n
)

fn InLab_VerUV_Desligar =
(
    local n = 0
    with undo off
    (
        for k = 1 to InLab_VerUV_Nos.count do
        (
            local o = InLab_VerUV_Nos[k]
            if isValidNode o do
            (
                try ( o.material = InLab_VerUV_Origs[k]; n += 1 )
                catch ( InLab_Log ("Ver UV: não devolvi o material de um nó (" + getCurrentException() + ").") tipo:#err )
            )
        )
    )
    local tinha = InLab_VerUV_Nos.count
    InLab_VerUV_Nos = #()
    InLab_VerUV_Origs = #()
    InLab_VerUV_Mat = undefined
    if tinha > 0 do InLab_Log ("Ver UV: desligado, " + n as string + " peça(s) com o material original.") tipo:#ok
    n
)

-- Antes de salvar, limpar a cena ou abrir outra: o material do Ver UV nao pode ir
-- para o arquivo nem ficar orfao.
callbacks.removeScripts id:#InLabVerUV
for ev in #(#filePreSave, #systemPreReset, #systemPreNew, #filePreOpen) do
    callbacks.addScript ev "try ( InLab_VerUV_Desligar() ) catch ( try ( InLab_Log (\"Ver UV: não desliguei antes de salvar/limpar (\" + getCurrentException() + \")\") tipo:#err ) catch () )" id:#InLabVerUV
