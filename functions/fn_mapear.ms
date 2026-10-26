/*
 === functions\fn_mapear.ms ===
 Mapear (23/10/2026, Tarefa 5): orquestrador do botão Mapear, registro e Desfazer.
 Spec: docs\superpowers\specs\2026-10-23-mapear-design.md, seções 4 a 8 e 12.

 O que faz:
   - InLab_Mapear objs produto unwrapGrande:false -> nº de peças refeitas.
     1. Peça com Real-World ou Triplanar que não passou pelo Real World Fix
        (InLab_RWF_Feitos, ela ou uma instância): #err e pulada, como no Auto UV.
     2. Uma vez por grupo de instâncias (o UV vai no objeto base, compartilhado);
        as outras instâncias saem no log. Grupos fechados acima do nó são abertos
        durante a peça e fechados no fim (with undo off).
     3. Stack: UVW Map / Unwrap / UVW Xform no canal 1 que não é "InLab RWF*" ->
        #warn e peça pulada. Outros modificadores -> #warn "UV calculado na base,
        abaixo de <nome>"; Symmetry/Mirror -> #warn "pode espelhar o UV" (só
        quando a peça é refeita).
     4. Por ID de material (Multi/Sub) ou a peça inteira: regra da parte
        (fn_mapear_classe.ms), alvo de escala (densidade atual se ficar entre 10
        e 300 cm por tile, contando o tiling U do difuso; senão
        INLAB_MAPEAR_CM_POR_TILE, com #warn), InLab_Mapear_Motivo. "" -> mantido;
        senão gera pela regra: #madeira GerarMadeira com o veio do difuso;
        #tecido GerarTubo por elemento e GerarGrande (ou Unfold3D no canal 1 com
        unwrapGrande:true) nos outros; #pintada GerarGrande; #liso GerarBox só com
        bitmap no material; #semFamilia GerarBox + #warn.
     5. Antes de gravar: base que não é Editable_Poly vira Editable_Poly
        (Edit_Poly no fundo do stack + CollapseNodeTo, preservando a instância);
        registro (MapearRecord); tira os "InLab RWF*"; religa ao canal 1 os
        bitmaps que liam o canal do Triplanar do RWF (#169), com o tiling
        multiplicado pela razão entre as densidades.
     6. Depois de gravar: mede de novo e loga "<motivo> → refeito (<regra>)";
        corte à vista acima do limite -> #warn "corte à vista: considere o Unwrap"
        (é assim que as peças grandes de tecido saem marcadas: GerarGrande hoje é
        o Box simples).
     7. Resumo "Mapear: N refeita(s), M mantida(s), K pulada(s)."
     - (fix round 1) peça sem nenhuma face a medir: #info "nada a mapear", fora
       das contagens.
   - InLab_ReverterMapear() -> nº de peças restauradas (canal 1 exato da base,
     modificadores "InLab RWF*" de volta na mesma posição, canal e tiling dos
     bitmaps). A classe da base não volta (só logada). Zera InLab_UltimoMapear.

 Decisões (23/10/2026):
   - Tudo é gerado ANTES de mexer na cena (os geradores só leem a base); a
     gravação é uma só por peça. Falha num ID: #err, aquele ID fica como estava e
     os outros seguem. Falha na gravação: a peça volta pelo registro.
   - Medição que falhou -> ID pulado (#err); ID com 0 faces medidas -> nada a
     fazer (#info), não conta como mantido. UV com faces mas sem nenhuma face
     medível (tudo degenerado) -> "UV degenerado".
   - Tirar um "InLab RWF*" do canal 1 muda o UV dos IDs que NÃO são refeitos: o
     UV avaliado deles (com o RWF) é copiado para a base antes. Se a topologia do
     stack não bate com a base, a peça não é tocada (#err).
   - Bitmap que lia o canal do Triplanar do RWF força refazer o ID (o GLB passa a
     ter um UV só, spec 12.3). A densidade desse canal é 1/length do UVW Map
     "InLab RWF*" (Box do tamanho do Triplanar).
   - Unwrap_UVW.getMapChannel devolve 0 para o canal 1 (padrão de fábrica):
     0 e 1 contam como canal 1.
   - polyop no NÓ falha com modificador acima da base: tudo lê e grava em
     o.baseobject (ver InLab_Mapear_PolyDe em fn_mapear_gerar.ms).

 Fix round 1 (23/10/2026, revisão da Tarefa 5):
   - Base que não é Editable_Poly com Unwrap_UVW acima (inclusive o "InLab
     AutoUV"): peça pulada (#warn). O Unwrap guarda o UV por índice de face e a
     conversão mesh -> poly muda as faces. A conversão vem depois do registro; se
     os triângulos de render mudam (Cylinder primitiva: 96 -> 92), a base antiga
     volta (cópia) e a peça não é tocada (#err). Peça abandonada depois da
     conversão: #warn de que a base ficou Editable_Poly.
   - "InLab RWF*" de um canal fora do 1 só sai se todos os IDs que leem esse
     canal foram refeitos; senão o canal fica (modificador e bitmaps) e #warn.
   - Caso A do RWF (spec 12.1): UVW Map com o Xform "InLab RWF" logo acima é do
     RWF e sai junto (entra no registro). Sem o Xform acima, é do usuário.
   - Restaurar não repõe modificador que já está no stack (Desfazer depois de
     Ctrl+Z duplicava).
   - Densidade do canal do RWF implausível -> alvo da tabela SEM compensar o
     tiling (o #warn "a textura passa a X cm" é verdade).
   - Falha na remedição do passo 6 só avisa: a peça já refeita conta como refeita.
   - InLab_Mapear_ForcarFalha (só teste): rótulo do ID cujo gerador falha.

 Revisão final (23/10/2026):
   - Escala do nó: os geradores trabalham no espaço do objeto da base; a escala
     pedida a eles é multiplicada pela escala do objectTransform (média, com #warn
     "escala não uniforme"). No passo 6, densidade medida a mais de 10% do alvo
     -> #warn.
   - Bitmap usado por peça fora da rodada não é religado ao canal 1 (#warn com os
     nomes); o canal do RWF dele continua, como no item C.
   - Desfazer confere a topologia da base (nº de faces e grau) contra o registro;
     se mudou, #warn "a malha mudou desde o Mapear; use o Ctrl+Z" e a peça fica.
   - Log: uma linha "N tubo(s)" por ID e uma de progresso por peça.
*/

global InLab_Log, InLab_EhGeometria, InLab_Instancias, InLab_DeduplicarInstancias
global InLab_AbrirGruposAcima, InLab_FecharGrupos, InLab_UnfoldComGuarda, InLab_RWF_Feitos
global InLab_RWF_UVWsRW, InLab_RWF_BitmapsRW, InLab_RWF_Triplanares, InLab_RWF_CanalBitmap
global INLAB_RWF_SLOTS_DIFUSO, INLAB_CANAL_UV_MATERIAL, InLab_ListaResumida
global InLab_Mapear_ParteDoMaterial, InLab_Mapear_RegraDaParte, InLab_Mapear_DifusoDe
global InLab_Mapear_VeioDaImagem, InLab_Mapear_ZerarCache, InLab_Mapear_BitmapDoMapa
global InLab_Mapear_Medir, InLab_Mapear_Motivo, InLab_Mapear_Limite, InLab_Mapear_Num
global InLab_Mapear_GerarMadeira, InLab_Mapear_GerarTubo, InLab_Mapear_GerarBox
global InLab_Mapear_GerarGrande, InLab_Mapear_Gravar, InLab_Mapear_PolyDe, InLab_Mapear_NoEspelhado

-- Tabela de escala (spec 6, provisória): cm por tile da textura, todas as famílias.
global INLAB_MAPEAR_CM_POR_TILE = 60.0
-- Faixa plausível da densidade atual (spec 12.2), em cm por tile.
global INLAB_MAPEAR_CM_MIN = 10.0
global INLAB_MAPEAR_CM_MAX = 300.0

-- Registro de uma peça refeita, para o Desfazer.
struct MapearRecord
(
    no,                 -- nó processado (o UV vai na base, compartilhada pelas instâncias)
    baseAntes,          -- classe da base antes (só para o log: a classe não volta)
    canal1Antes,        -- #(numMapVerts, #(point3...), #(#(face, #(idx...))...)) ou undefined (sem canal 1)
    modsTirados = #(),  -- #(#(modificador, índice)) em ordem crescente de índice
    bitmapsAntes = #(), -- #(#(bitmap, canal, uTiling, vTiling))
    graus               -- grau de cada face da base no registro (confere a topologia no Desfazer)
)

-- Decisão de um ID de material (uso interno).
struct MapearDecisao
(
    id, mtl, rotulo, regra, med, motivo = "", escala = 0.0, alvo = 0.0,
    veio = #horizontal, rebind = #(), trocouEscala = false, cmAntes = undefined,
    acao = #manter
)

-- Acumulam entre rodadas; só o Desfazer zera.
global InLab_UltimoMapear = #()

global InLab_Mapear_CanalModUV, InLab_Mapear_EhRWF, InLab_Mapear_TemRealWorld
global InLab_Mapear_SemRWF, InLab_Mapear_MaterialDoID, InLab_Mapear_Grupos
global InLab_Mapear_BitmapDifuso, InLab_Mapear_Bitmaps, InLab_Mapear_Tiling
global InLab_Mapear_SetTiling, InLab_Mapear_SetCanal, InLab_Mapear_NomeRegra
global InLab_Mapear_Decidir, InLab_Mapear_FacesDoID, InLab_Mapear_Juntar
global InLab_Mapear_UVAvaliado, InLab_Mapear_UnwrapElemento, InLab_Mapear_GerarRegra
global InLab_Mapear_LerCanal1, InLab_Mapear_Restaurar, InLab_Mapear_ConverterBase
global InLab_Mapear_Peca, InLab_Mapear, InLab_ReverterMapear, InLab_Mapear_FatorNo
-- SÓ TESTE: rótulo ("<nó>" ou "<nó> (ID n)") do ID cujo gerador deve falhar
global InLab_Mapear_ForcarFalha = undefined

--------------------------------------------------------------------------------
-- Stack
--------------------------------------------------------------------------------
fn InLab_Mapear_EhRWF m = matchPattern m.name pattern:"InLab RWF*"

-- Canal em que um modificador de UV escreve; undefined se não é modificador
-- de UV conhecido; -1 se escreve em vertex color.
fn InLab_Mapear_CanalModUV m =
(
    local c = classof m
    if c == Uvwmap then
        (if m.channel == 1 then -1 else m.mapChannel)
    else if c == Unwrap_UVW then
    (
        local k = 1
        try ( k = m.getMapChannel() )
        catch ( InLab_Log (m.name + ": não li o canal do Unwrap (" + getCurrentException() + "); considerado canal 1.") tipo:#warn )
        if k == 0 then 1 else k  -- 0 = padrão de fábrica = canal 1
    )
    else if c == UVW_Xform then
    (
        local k = 1
        try ( k = m.Map_Channel )
        catch ( InLab_Log (m.name + ": não li o canal do UVW Xform (" + getCurrentException() + "); considerado canal 1.") tipo:#warn )
        k
    )
    else undefined
)

--------------------------------------------------------------------------------
-- Pré-requisito do Real World Fix (spec 12.6)
--------------------------------------------------------------------------------
fn InLab_Mapear_TemRealWorld o =
(
    (InLab_RWF_UVWsRW o).count > 0 or (InLab_RWF_BitmapsRW o.material).count > 0 or \
        (InLab_RWF_Triplanares o.material).count > 0
)

fn InLab_Mapear_SemRWF o =
(
    local feitos = if InLab_RWF_Feitos == undefined then #() else InLab_RWF_Feitos
    (InLab_Mapear_TemRealWorld o) and \
        (for i in (InLab_Instancias o) where (findItem feitos i) > 0 collect i).count == 0
)

--------------------------------------------------------------------------------
-- Materiais e bitmaps
--------------------------------------------------------------------------------
fn InLab_Mapear_MaterialDoID mtl id =
(
    if id == undefined or classof mtl != Multimaterial then mtl
    else
    (
        local k = findItem mtl.materialIDList id
        if k > 0 then mtl.materialList[k] else undefined
    )
)

-- #(#(id, material)...): um por ID presente (Multi/Sub) ou #(#(undefined, material)).
fn InLab_Mapear_Grupos o =
(
    if classof o.material != Multimaterial then #(#(undefined, o.material))
    else
    (
        local ids = #()
        local m = snapshotAsMesh o
        for f = 1 to m.numfaces do appendIfUnique ids (getFaceMatID m f)
        delete m
        sort ids
        for id in ids collect #(id, InLab_Mapear_MaterialDoID o.material id)
    )
)

fn InLab_Mapear_BitmapDifuso mtl =
(
    local b = undefined
    if mtl != undefined do
        for p in INLAB_RWF_SLOTS_DIFUSO while b == undefined do
            if hasProperty mtl p do b = InLab_Mapear_BitmapDoMapa (getProperty mtl p)
    b
)

fn InLab_Mapear_Bitmaps mtl =
(
    local r = #()
    if mtl != undefined do
    (
        r = getClassInstances Bitmaptexture target:mtl
        if CoronaBitmap != undefined do join r (getClassInstances CoronaBitmap target:mtl)
    )
    r
)

fn InLab_Mapear_Tiling b =
(
    if classof b == Bitmaptexture then point2 b.coords.U_Tiling b.coords.V_Tiling
    else point2 b.uvwScale.x b.uvwScale.y
)

fn InLab_Mapear_SetTiling b t =
(
    if classof b == Bitmaptexture then ( b.coords.U_Tiling = t.x; b.coords.V_Tiling = t.y )
    else ( local s = b.uvwScale; b.uvwScale = point3 t.x t.y s.z )
)

fn InLab_Mapear_SetCanal b c =
(
    if classof b == Bitmaptexture then b.coords.mapChannel = c else b.uvwChannel = c
)

fn InLab_Mapear_NomeRegra r =
(
    case r of
    (
        #madeira: "madeira"
        #pintada: "pintada"
        #tecido: "tecido"
        #liso: "liso"
        default: "sem família"
    )
)

--------------------------------------------------------------------------------
-- Decisão por ID. rwfCanais = #(#(canal, densidade UV/cm ou undefined)...) dos
-- "InLab RWF*" fora do canal 1.
--------------------------------------------------------------------------------
fn InLab_Mapear_Decidir o produto id mtl rwfCanais =
(
    local d = MapearDecisao id:id mtl:mtl rebind:#()
    d.rotulo = o.name + (if id != undefined then " (ID " + id as string + ")" else "")
    local nome = if mtl == undefined then "" else mtl.name
    local parte = if produto == undefined then undefined else InLab_Mapear_ParteDoMaterial produto nome
    d.regra = if parte == undefined then #semFamilia else InLab_Mapear_RegraDaParte produto parte
    d.med = InLab_Mapear_Medir o matID:id
    local med = d.med
    if med.falhou then
    (
        d.acao = #pular
        InLab_Log (d.rotulo + ": medição falhou, não remapeado.") tipo:#err
    )
    else if med.temCanal and med.faces == 0 then
    (
        d.acao = #nada
        InLab_Log (d.rotulo + ": nenhuma face a medir, nada a fazer.") tipo:#info
    )
    else
    (
        local bmpDif = InLab_Mapear_BitmapDifuso mtl
        local uTil = if bmpDif != undefined then abs (InLab_Mapear_Tiling bmpDif).x else 1.0
        if uTil < 1e-6 do uTil = 1.0
        local canalDif = if bmpDif != undefined then InLab_RWF_CanalBitmap bmpDif else 1
        -- bitmaps que leem o canal do Triplanar do RWF (#169)
        local canaisRWF = for rc in rwfCanais collect rc[1]
        for b in (InLab_Mapear_Bitmaps mtl) where (findItem canaisRWF (InLab_RWF_CanalBitmap b)) > 0 do append d.rebind b
        -- densidade atual (UV/cm) do canal que o difuso lê
        local dens = if med.temCanal and med.amostra > 0 then med.escala else 0.0
        local k = findItem canaisRWF canalDif
        if k > 0 and rwfCanais[k][2] != undefined do dens = rwfCanais[k][2]
        if dens > 1e-9 do d.cmAntes = 1.0 / (dens * uTil)
        if d.cmAntes != undefined and d.cmAntes >= INLAB_MAPEAR_CM_MIN and d.cmAntes <= INLAB_MAPEAR_CM_MAX then
            d.alvo = d.cmAntes
        else
        (
            d.alvo = INLAB_MAPEAR_CM_POR_TILE
            d.trocouEscala = d.cmAntes != undefined
        )
        d.escala = 1.0 / (d.alvo * uTil)
        -- veio da madeira pela imagem do difuso
        if d.regra == #madeira do
        (
            local dd = InLab_Mapear_DifusoDe mtl
            if dd == undefined then
            (
                d.veio = #semDirecao
                InLab_Log (d.rotulo + ": madeira sem bitmap no difuso; veio sem direção, U horizontal.") tipo:#warn
            )
            else
            (
                d.veio = InLab_Mapear_VeioDaImagem dd[1] dd[2]
                if d.veio == #semDirecao do
                    InLab_Log (d.rotulo + ": textura sem direção de veio; U horizontal.") tipo:#warn
            )
        )
        d.motivo = InLab_Mapear_Motivo med d.regra (d.alvo * uTil) veio:d.veio
        if d.motivo == "" and med.temCanal and med.amostra == 0 do d.motivo = "UV degenerado (sem área)"
        if d.motivo == "" and d.rebind.count > 0 do
            d.motivo = "textura lida no canal " + (InLab_RWF_CanalBitmap d.rebind[1]) as string + " do Real World Fix"
        if d.motivo == "" then
        (
            d.acao = #manter
            InLab_Log (d.rotulo + ": mapeamento mantido.") tipo:#ok
        )
        else if d.regra == #liso and (InLab_Mapear_Bitmaps mtl).count == 0 then
        (
            d.acao = #manter
            InLab_Log (d.rotulo + ": material liso sem bitmap, canal 1 mantido (" + d.motivo + ").") tipo:#info
        )
        else d.acao = #refazer
    )
    d
)

--------------------------------------------------------------------------------
-- Geração
--------------------------------------------------------------------------------
fn InLab_Mapear_FacesDoID o id =
(
    local po = InLab_Mapear_PolyDe o
    local nf = polyop.getNumFaces po
    if id == undefined then #{1..nf}
    else ( local r = #{}; for f = 1 to nf where (polyop.getFaceMatID po f) == id do r[f] = true; r )
)

-- junta #(uvs, mapa) de r em acc (índices deslocados)
fn InLab_Mapear_Juntar acc r =
(
    local base = acc[1].count
    join acc[1] r[1]
    for e in r[2] do append acc[2] #(e[1], for i in e[2] collect i + base)
    acc
)

-- UV avaliado (com o stack) das faces da base, para preservar o que não é
-- refeito quando um "InLab RWF*" do canal 1 sai. undefined se a topologia do
-- snapshot não bate com a base.
fn InLab_Mapear_UVAvaliado o faces =
(
    local po = InLab_Mapear_PolyDe o
    local m = snapshotAsMesh o
    local res = undefined
    try
    (
        local nf = polyop.getNumFaces po
        local nTri = 0
        for f = 1 to nf do nTri += (polyop.getFaceDeg po f) - 2
        local ok = m.numverts == (polyop.getNumVerts po) and m.numfaces == nTri and \
            (meshop.getNumMaps m) > 1 and (meshop.getMapSupport m 1)
        if ok do
        (
            local uvs = #(); local mapa = #()
            local dic = #(); dic.count = meshop.getNumMapVerts m 1
            local tri = 0
            for f = 1 to nf while ok do
            (
                local deg = polyop.getFaceDeg po f
                if faces[f] do
                (
                    local vs = polyop.getFaceVerts po f
                    local cantos = #(); cantos.count = vs.count
                    for t = tri + 1 to tri + deg - 2 do
                    (
                        local fv = getFace m t
                        local tv = meshop.getMapFace m 1 t
                        for k = 1 to 3 do
                        (
                            local p = findItem vs (fv[k] as integer)
                            if p > 0 and cantos[p] == undefined do cantos[p] = tv[k] as integer
                        )
                    )
                    if (findItem cantos undefined) > 0 then ok = false
                    else
                    (
                        local idx = for mv in cantos collect
                        (
                            if dic[mv] == undefined do ( append uvs (meshop.getMapVert m 1 mv); dic[mv] = uvs.count )
                            dic[mv]
                        )
                        append mapa #(f, idx)
                    )
                )
                tri += deg - 2
            )
            if ok do res = #(uvs, mapa)
        )
    )
    catch ( InLab_Log (o.name + ": não li o UV avaliado (" + getCurrentException() + ").") tipo:#err; res = undefined )
    delete m
    res
)

-- Unwrap opcional (spec 5.4): Unfold3D no canal 1 num nó temporário com as
-- faces do elemento, densidade normalizada para `escala` e cada ilha girada
-- para a aresta mais horizontal ficar em U. #(uvs, mapa) ou undefined.
fn InLab_Mapear_UnwrapElemento o el escala =
(
    local po = InLab_Mapear_PolyDe o
    local lista = el as array
    local nome = uniqueName "InLab_Mapear_tmp"
    local tmp = undefined
    local res = undefined
    try
    (
        polyop.detachFaces po el delete:false asNode:true name:nome node:o
        tmp = getNodeByName nome
        if tmp == undefined do throw "o nó temporário não foi criado"
        local pt = tmp.baseobject
        if (polyop.getNumFaces pt) != lista.count do throw "o nó temporário não tem as mesmas faces"
        -- confere a ordem dos cantos: posição de cada vértice
        for k = 1 to lista.count do
        (
            local a = polyop.getFaceVerts po lista[k]; local b = polyop.getFaceVerts pt k
            if a.count != b.count do throw "face com grau diferente no nó temporário"
            for j = 1 to a.count do
                if (distance (polyop.getVert po a[j]) (polyop.getVert pt b[j])) > 1e-3 do throw "cantos fora de ordem no nó temporário"
        )
        with undo off ( max modify mode; select tmp )
        local uvw = Unwrap_UVW()
        addModifier tmp uvw
        with undo off ( modPanel.setCurrentObject uvw )
        uvw.setMapChannel 1
        local np = uvw.numberPolygons()
        uvw.selectFaces #{1..np}
        local normais = #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1])
        uvw.flattenMap 55.0 normais 0.01 true 0 true true
        local rev = InLab_UnfoldComGuarda uvw np angulo:55.0 espacamento:0.01
        if rev < 0 do InLab_Log (o.name + ": Unfold3DSolve indisponível, fica o flatten.") tipo:#warn
        convertToPoly tmp
        pt = tmp.baseobject
        -- UV por canto, densidade total e ilhas (vértices de mapa compartilhados)
        local nmv = polyop.getNumMapVerts pt 1
        local uv = for i = 1 to nmv collect (polyop.getMapVert pt 1 i)
        local mfs = for k = 1 to lista.count collect (polyop.getMapFace pt 1 k)
        local a3 = 0.0; local aUV = 0.0
        for k = 1 to lista.count do
        (
            a3 += polyop.getFaceArea pt k
            local mf = mfs[k]; local s = 0.0
            for j = 1 to mf.count do
            (
                local p = uv[mf[j]]; local q = uv[mf[if j == mf.count then 1 else j + 1]]
                s += p.x * q.y - q.x * p.y
            )
            aUV += abs s / 2.0
        )
        if a3 < 1e-9 or aUV < 1e-12 do throw "UV sem área depois do Unfold"
        local fator = escala / (sqrt (aUV / a3))
        -- ilhas por união dos vértices de mapa
        local pai = for i = 1 to nmv collect i
        fn raiz pai i = ( while pai[i] != i do ( pai[i] = pai[pai[i]]; i = pai[i] ); i )
        for mf in mfs do for j = 2 to mf.count do
        (
            local ra = raiz pai mf[1]; local rb = raiz pai mf[j]
            if ra != rb do pai[rb] = ra
        )
        -- por ilha: aresta mais horizontal (peso: comprimento x horizontalidade^4)
        local melhor = #(); melhor.count = nmv   -- por raiz: #(pontuação, ângulo UV)
        for k = 1 to lista.count do
        (
            local mf = mfs[k]; local vs = polyop.getFaceVerts pt k
            local r = raiz pai mf[1]
            for j = 1 to vs.count do
            (
                local j2 = if j == vs.count then 1 else j + 1
                local e = (polyop.getVert pt vs[j2]) - (polyop.getVert pt vs[j])
                local l = length e
                if l > 1e-6 do
                (
                    local hz = 1.0 - (abs (e.z / l))
                    local sc = l * hz * hz * hz * hz
                    local du = uv[mf[j2]] - uv[mf[j]]
                    if (melhor[r] == undefined or sc > melhor[r][1]) and (length du) > 1e-9 do
                        melhor[r] = #(sc, atan2 du.y du.x)
                )
            )
        )
        local espelhado = InLab_Mapear_NoEspelhado o
        local novos = for i = 1 to nmv collect
        (
            local r = raiz pai i
            local ang = if melhor[r] == undefined then 0.0 else -(melhor[r][2])
            local p = uv[i] * fator
            local q = [p.x * (cos ang) - p.y * (sin ang), p.x * (sin ang) + p.y * (cos ang), 0]
            if espelhado do q.y = -q.y
            q
        )
        local mapa = for k = 1 to lista.count collect #(lista[k], for mv in mfs[k] collect (mv as integer))
        res = #(novos, mapa)
    )
    catch ( InLab_Log (o.name + ": Unwrap da peça grande falhou (" + getCurrentException() + "); fica a projeção em caixa.") tipo:#warn; res = undefined )
    if tmp != undefined and isValidNode tmp do
        try ( delete tmp ) catch ( InLab_Log (o.name + ": não apaguei o nó temporário " + nome + " (" + getCurrentException() + ").") tipo:#err )
    res
)

-- gera o UV das faces de um ID pela regra; #(uvs, mapa)
-- #(fator, uniforme, escalas): cm de mundo por unidade do objeto pela escala do
-- objectTransform; não uniforme (diferença > 1%) usa a média.
fn InLab_Mapear_FatorNo o =
(
    local sp = o.objectTransform.scalepart
    local a = #(abs sp.x, abs sp.y, abs sp.z)
    local mx = amax a; local mn = amin a
    local media = (a[1] + a[2] + a[3]) / 3.0
    #(media, (mn > 1e-9 and mx / mn <= 1.01), sp)
)

-- fatorNo: cm de mundo por unidade do objeto (escala do nó); os geradores trabalham
-- no espaço de objeto da base, então a escala pedida a eles é d.escala x fatorNo.
fn InLab_Mapear_GerarRegra o faces d unwrapGrande fatorNo:1.0 =
(
    local acc = #(#(), #())
    local e = d.escala * fatorNo
    case d.regra of
    (
        #madeira: InLab_Mapear_Juntar acc (InLab_Mapear_GerarMadeira o faces e d.veio)
        #pintada: InLab_Mapear_Juntar acc (InLab_Mapear_GerarGrande o faces e)
        #tecido:
        (
            local nTubos = 0; local nGrandes = 0
            local po = InLab_Mapear_PolyDe o
            local resto = copy faces
            while not resto.isEmpty do
            (
                local f1 = undefined
                for f in resto while f1 == undefined do f1 = f
                local el = (polyop.getElementsUsingFace po #{f1}) * faces
                resto -= el
                resto[f1] = false
                local t = InLab_Mapear_GerarTubo o el e silencioso:true
                if t != undefined then
                (
                    nTubos += 1
                    InLab_Mapear_Juntar acc t
                    local cobertas = #{}
                    for x in t[2] do cobertas[x[1]] = true
                    local tampas = el - cobertas
                    if not tampas.isEmpty do InLab_Mapear_Juntar acc (InLab_Mapear_GerarBox o tampas e)
                )
                else
                (
                    nGrandes += 1
                    local u = if unwrapGrande then InLab_Mapear_UnwrapElemento o el e else undefined
                    if u != undefined then InLab_Mapear_Juntar acc u
                    else InLab_Mapear_Juntar acc (InLab_Mapear_GerarGrande o el e)
                )
            )
            -- uma linha por ID (antes era uma por elemento)
            InLab_Log (d.rotulo + ": " + nTubos as string + " tubo(s) reconhecido(s), " + nGrandes as string + " elemento(s) como peça grande.") tipo:#info
        )
        default: InLab_Mapear_Juntar acc (InLab_Mapear_GerarBox o faces e)
    )
    acc
)

--------------------------------------------------------------------------------
-- Registro e Desfazer
--------------------------------------------------------------------------------
fn InLab_Mapear_LerCanal1 o =
(
    local po = InLab_Mapear_PolyDe o
    if not (polyop.getMapSupport po 1) then undefined
    else
    (
        local n = polyop.getNumMapVerts po 1
        local vs = for i = 1 to n collect (polyop.getMapVert po 1 i)
        local fs = for f = 1 to (polyop.getNumFaces po) collect #(f, polyop.getMapFace po 1 f)
        #(n, vs, fs)
    )
)

-- Devolve a peça ao estado do registro. Quem chama abre o undo. false (sem
-- tocar em nada) se a malha da base mudou desde o Mapear: o canal 1 é regravado
-- por índice de face e numa topologia diferente sairia lixo.
fn InLab_Mapear_Restaurar rec =
(
    local o = rec.no
    local po = InLab_Mapear_PolyDe o
    local mesma = (classof po) == Editable_Poly
    if mesma and rec.graus != undefined do
    (
        local nf = polyop.getNumFaces po
        if nf != rec.graus.count then mesma = false
        else for f = 1 to nf while mesma do if (polyop.getFaceDeg po f) != rec.graus[f] do mesma = false
    )
    if not mesma do
    (
        InLab_Log (o.name + ": a malha mudou desde o Mapear; use o Ctrl+Z.") tipo:#warn
        return false
    )
    local c = rec.canal1Antes
    if c == undefined then polyop.setMapSupport po 1 false
    else
    (
        polyop.setMapSupport po 1 true
        polyop.setNumMapVerts po 1 c[1] keep:false
        for k = 1 to c[1] do polyop.setMapVert po 1 k c[2][k]
        for e in c[3] do polyop.setMapFace po 1 e[1] e[2]
    )
    -- modificador que já voltou (Ctrl+Z depois do Mapear) não entra de novo
    for mt in rec.modsTirados where (findItem (for m in o.modifiers collect m) mt[1]) == 0 do
    (
        local idx = mt[2]
        if idx <= 1 then addModifier o mt[1]
        else if (idx - 1) <= o.modifiers.count then addModifier o mt[1] before:(idx - 1)
        else addModifier o mt[1] before:o.modifiers.count
    )
    for b in rec.bitmapsAntes do
    (
        InLab_Mapear_SetCanal b[1] b[2]
        InLab_Mapear_SetTiling b[1] (point2 b[3] b[4])
    )
    true
)

-- Base que não é Editable_Poly vira Editable_Poly, preservando o stack e a
-- instância. true se a base ficou Editable_Poly.
fn InLab_Mapear_ConverterBase o =
(
    local antes = classof o.baseobject
    if antes == Editable_Poly then true
    else
    (
        local nInst = (InLab_Instancias o).count
        addModifier o (Edit_Poly()) before:o.modifiers.count
        maxOps.CollapseNodeTo o o.modifiers.count true
        local depois = classof o.baseobject
        if nInst > 1 and (InLab_Instancias o).count != nInst do
            InLab_Log (o.name + ": a conversão da base quebrou a instância (" + nInst as string + " -> " + (InLab_Instancias o).count as string + " nós).") tipo:#warn
        -- o aviso da conversão sai em InLab_Mapear_Peca, depois de conferir os triângulos
        if depois == Editable_Poly then true
        else
        (
            InLab_Log (o.name + ": a base não virou Editable_Poly (" + depois as string + ").") tipo:#err
            false
        )
    )
)

--------------------------------------------------------------------------------
-- Uma peça (o primeiro nó de um grupo de instâncias): #refeita, #mantida,
-- #pulada ou #nada (nenhuma face a medir em nenhum ID).
--------------------------------------------------------------------------------
fn InLab_Mapear_Peca o produto unwrapGrande rodada:undefined =
(
    if rodada == undefined do rodada = InLab_Instancias o
    InLab_Log (o.name + ": mapeando (" + ((getPolygonCount o)[1]) as string + " faces)...") tipo:#info
    -- 1. stack
    local rwfMods = #()       -- #(modificador, índice, canal)
    local bloqueio = undefined
    local temUnwrap = false
    local avisos = #()
    for i = 1 to o.modifiers.count do
    (
        local m = o.modifiers[i]
        local canal = InLab_Mapear_CanalModUV m
        if classof m == Unwrap_UVW do temUnwrap = true
        -- caso A do RWF (spec 12.1): UVW Map com o Xform "InLab RWF" logo acima é
        -- mapeamento do Real World Fix e sai junto com o Xform
        local acima = if i > 1 then o.modifiers[i - 1] else undefined
        local xformRWFAcima = acima != undefined and classof acima == UVW_Xform and (InLab_Mapear_EhRWF acima)
        if InLab_Mapear_EhRWF m then append rwfMods #(m, i, canal)
        else if m.name == "InLab AutoUV" then ok
        else if classof m == Uvwmap and xformRWFAcima then append rwfMods #(m, i, canal)
        else if canal != undefined then
        (
            if canal == 1 and bloqueio == undefined do bloqueio = m.name
        )
        else if (classof m) == Symmetry or (matchPattern ((classof m) as string) pattern:"*Mirror*") then
            append avisos (m.name + " acima da base pode espelhar o UV")
        else if not (matchPattern ((classof m) as string) pattern:"*UVW*") do
            append avisos ("UV calculado na base, abaixo de " + m.name)
    )
    if bloqueio != undefined then
    (
        InLab_Log (o.name + ": modificador de mapeamento \"" + bloqueio + "\" no canal 1 acima da base; peça não tocada.") tipo:#warn
        #pulada
    )
    else
    (
        -- densidade (UV/cm) de cada canal do RWF fora do canal 1: U_Tile do Xform
        -- "InLab RWF" (UV em cm dividido) ou 1/length do UVW Map "InLab RWF*"
        local rwfCanais = #()
        for r in rwfMods do
        (
            if r[3] != undefined and r[3] != 1 do
            (
                local dens = undefined
                if classof r[1] == UVW_Xform then
                    dens = try ( r[1].U_Tile ) catch ( InLab_Log (o.name + ": não li o U_Tile de " + r[1].name + " (" + getCurrentException() + ").") tipo:#warn; undefined )
                else if classof r[1] == Uvwmap and (InLab_Mapear_EhRWF r[1]) and r[1].length > 1e-6 do dens = 1.0 / r[1].length
                local k = findItem (for rc in rwfCanais collect rc[1]) r[3]
                if k == 0 then append rwfCanais #(r[3], dens)
                else if rwfCanais[k][2] == undefined do rwfCanais[k][2] = dens
            )
        )
        for rc in rwfCanais where rc[2] == undefined do
            InLab_Log (o.name + ": canal " + rc[1] as string + " do Real World Fix sem tamanho conhecido; o tiling dos bitmaps religados não é ajustado.") tipo:#warn

        -- 2. decisão por ID
        local decs = for g in (InLab_Mapear_Grupos o) collect (InLab_Mapear_Decidir o produto g[1] g[2] rwfCanais)
        local refazer = for d in decs where d.acao == #refazer collect d
        if (for d in decs where d.acao != #nada collect d).count == 0 then
        (
            InLab_Log (o.name + ": nada a mapear.") tipo:#info
            #nada
        )
        else if refazer.count == 0 then
            (if (for d in decs where d.acao == #pular collect d).count > 0 then #pulada else #mantida)
        else if (classof o.baseobject) != Editable_Poly and temUnwrap then
        (
            -- o Unwrap guarda o UV por índice de face: converter a base muda as faces
            InLab_Log (o.name + ": Unwrap acima da base " + ((classof o.baseobject) as string) +
                       "; converter a base para Editable_Poly mudaria as faces que ele guarda. Peça não tocada.") tipo:#warn
            #pulada
        )
        else
        (
            for a in avisos do InLab_Log (o.name + ": " + a + ".") tipo:#warn
            for d in refazer where d.trocouEscala do
                InLab_Log (d.rotulo + ": densidade atual de " + (InLab_Mapear_Num d.cmAntes) + " cm por tile fora da faixa (" +
                           (InLab_Mapear_Num INLAB_MAPEAR_CM_MIN) + " a " + (InLab_Mapear_Num INLAB_MAPEAR_CM_MAX) + "); a textura passa a " +
                           (InLab_Mapear_Num d.alvo) + " cm por tile.") tipo:#warn
            local resultado = #pulada
            -- 3. registro (classe antiga) e base Editable_Poly
            local baseAntes = classof o.baseobject
            local rec = MapearRecord no:o baseAntes:baseAntes modsTirados:#() bitmapsAntes:#()
            local convertida = false
            local baseOk = true
            if baseAntes != Editable_Poly do
            (
                local trisAntes = (GetTriMeshFaceCount o)[1]
                local copia = copy o.baseobject
                baseOk = InLab_Mapear_ConverterBase o
                local trisDepois = (GetTriMeshFaceCount o)[1]
                if baseOk and trisDepois != trisAntes do
                (
                    InLab_Log (o.name + ": a conversão para Editable_Poly mudou os triângulos de render (" + trisAntes as string + " -> " +
                               trisDepois as string + "); base " + baseAntes as string + " devolvida, peça não tocada.") tipo:#err
                    baseOk = false
                )
                if baseOk then
                (
                    convertida = true
                    InLab_Log (o.name + ": base " + baseAntes as string + " convertida para Editable_Poly (o Desfazer devolve o UV, não a classe).") tipo:#warn
                )
                else
                    try ( o.baseobject = copia )
                    catch ( InLab_Log (o.name + ": não devolvi a base " + baseAntes as string + " (" + getCurrentException() + "); use o Ctrl+Z.") tipo:#err )
            )
            if baseOk do
            (
                -- escala do nó (objectTransform): os geradores trabalham no espaço do objeto
                local fatorNo = InLab_Mapear_FatorNo o
                if not fatorNo[2] do
                    InLab_Log (o.name + ": escala não uniforme no nó " + fatorNo[3] as string + "; o UV usa a média (" +
                               (formattedPrint fatorNo[1] format:".3g") + "). Conferir a textura, ou Reset XForm.") tipo:#warn
                -- 4. gera tudo antes de mexer no UV
                local acc = #(#(), #())
                local feitos = #()
                for d in refazer do
                (
                    try
                    (
                        -- SÓ TESTE: InLab_Mapear_ForcarFalha = rótulo do ID que deve falhar
                        if InLab_Mapear_ForcarFalha == d.rotulo do throw ("falha forçada para teste (" + d.rotulo + ")")
                        local fs = InLab_Mapear_FacesDoID o d.id
                        local r = InLab_Mapear_GerarRegra o fs d unwrapGrande fatorNo:fatorNo[1]
                        if r == undefined or r[2].count == 0 then
                            InLab_Log (d.rotulo + ": o gerador não devolveu UV (" + (InLab_Mapear_NomeRegra d.regra) + "); ID como estava.") tipo:#err
                        else ( InLab_Mapear_Juntar acc r; append feitos d )
                    )
                    catch ( InLab_Log (d.rotulo + ": falha ao gerar o UV (" + getCurrentException() + "); ID como estava.") tipo:#err )
                )
                -- canais do RWF fora do canal 1 que ficam: algum ID não refeito lê o canal
                local canaisPresos = #()
                for rc in rwfCanais do
                    for d in decs where (findItem feitos d) == 0 do
                        if (for b in d.rebind where (InLab_RWF_CanalBitmap b) == rc[1] collect b).count > 0 do
                        (
                            if (findItem canaisPresos rc[1]) == 0 do
                                InLab_Log (o.name + ": o canal " + rc[1] as string + " do Real World Fix continua (" + d.rotulo +
                                           " não foi refeito e lê esse canal).") tipo:#warn
                            appendIfUnique canaisPresos rc[1]
                        )
                -- bitmap usado por peça fora desta rodada: religar ao canal 1 mudaria essa peça
                for rc in rwfCanais where (findItem canaisPresos rc[1]) == 0 do
                    for d in feitos do
                        for b in d.rebind where (InLab_RWF_CanalBitmap b) == rc[1] and (findItem canaisPresos rc[1]) == 0 do
                        (
                            local fora = for n in (refs.dependentNodes b) where isValidNode n and (InLab_EhGeometria n) and (findItem rodada n) == 0 collect n.name
                            if fora.count > 0 do
                            (
                                InLab_Log (o.name + ": " + b.name + " (canal " + rc[1] as string + ") também é usado fora desta rodada (" +
                                           (InLab_ListaResumida fora) + "); o bitmap não é religado e o canal do Real World Fix continua.") tipo:#warn
                                append canaisPresos rc[1]
                            )
                        )
                local tirar = for r in rwfMods where (findItem canaisPresos r[3]) == 0 collect r
                local tiraCanal1 = (for r in tirar where r[3] == undefined or r[3] == 1 collect r).count > 0
                -- faces que não são refeitas precisam do UV avaliado se um RWF do canal 1 sai
                local ok = feitos.count > 0
                if ok and tiraCanal1 do
                (
                    local refeitas = #{}
                    for e in acc[2] do refeitas[e[1]] = true
                    local resto = #{1..(polyop.getNumFaces o.baseobject)} - refeitas
                    if not resto.isEmpty do
                    (
                        local av = InLab_Mapear_UVAvaliado o resto
                        if av == undefined then
                        (
                            InLab_Log (o.name + ": o UV das partes mantidas depende do Real World Fix e não deu para copiá-lo (topologia do stack diferente da base); peça não tocada.") tipo:#err
                            ok = false
                        )
                        else InLab_Mapear_Juntar acc av
                    )
                )
                if ok do
                (
                    -- 5. canal 1 de antes, RWF fora, bitmaps religados, gravação
                    rec.canal1Antes = InLab_Mapear_LerCanal1 o
                    rec.graus = for f = 1 to (polyop.getNumFaces o.baseobject) collect (polyop.getFaceDeg o.baseobject f)
                    try
                    (
                        for k = tirar.count to 1 by -1 do
                        (
                            deleteModifier o tirar[k][2]
                            insertItem #(tirar[k][1], tirar[k][2]) rec.modsTirados 1
                        )
                        for d in feitos do
                            for b in d.rebind where (findItem canaisPresos (InLab_RWF_CanalBitmap b)) == 0 and \
                                (for x in rec.bitmapsAntes where x[1] == b collect x).count == 0 do
                            (
                                local c = InLab_RWF_CanalBitmap b
                                local t = InLab_Mapear_Tiling b
                                append rec.bitmapsAntes #(b, c, t.x, t.y)
                                local k = findItem (for rc in rwfCanais collect rc[1]) c
                                local dc = if k > 0 then rwfCanais[k][2] else undefined
                                -- densidade trocada (implausível -> tabela): sem compensar, a
                                -- textura passa mesmo ao tamanho novo (o #warn acima diz isso)
                                local razao = if dc == undefined or d.trocouEscala then 1.0 else dc / d.escala
                                InLab_Mapear_SetCanal b 1
                                InLab_Mapear_SetTiling b (t * razao)
                                InLab_Log (b.name + ": passa a ler o canal 1 (era o " + c as string + ")" +
                                           (if abs (razao - 1.0) > 1e-4 then ", tiling × " + (formattedPrint razao format:".3g") else "") + ".") tipo:#info
                            )
                        if not (InLab_Mapear_Gravar o acc[1] acc[2]) do throw "gravação do canal 1 falhou"
                        append InLab_UltimoMapear rec
                        resultado = #refeita
                    )
                    catch
                    (
                        InLab_Log (o.name + ": Mapear falhou (" + getCurrentException() + "); peça restaurada.") tipo:#err
                        try ( InLab_Mapear_Restaurar rec )
                        catch ( InLab_Log (o.name + ": não restaurei a peça (" + getCurrentException() + "); use o Ctrl+Z.") tipo:#err )
                    )
                    -- 6. medir de novo (a peça já está refeita: falha aqui só avisa)
                    if resultado == #refeita do
                        try
                        (
                            for d in feitos do
                            (
                                local m2 = InLab_Mapear_Medir o matID:d.id
                                InLab_Log (d.rotulo + ": " + d.motivo + " → refeito (" + (InLab_Mapear_NomeRegra d.regra) + ", 1 tile a cada " +
                                           (InLab_Mapear_Num d.alvo) + " cm).") tipo:#ok
                                if d.regra == #semFamilia do
                                    InLab_Log (d.rotulo + ": parte sem matéria-prima no JSON (Box simples).") tipo:#warn
                                if m2.amostra > 0 and m2.escala > 0 and (abs (m2.escala / d.escala - 1.0)) > 0.1 do
                                    InLab_Log (d.rotulo + ": densidade medida de " + (InLab_Mapear_Num (d.alvo * d.escala / m2.escala)) +
                                               " cm por tile, alvo " + (InLab_Mapear_Num d.alvo) + " cm (mais de 10% de diferença).") tipo:#warn
                                if m2.emendaVistaQuebra > (InLab_Mapear_Limite #emendaVistaQuebra) do
                                    InLab_Log (d.rotulo + ": corte à vista (" + (InLab_Mapear_Num (m2.emendaVistaQuebra * 100.0)) +
                                               "% das arestas): considere o Unwrap.") tipo:#warn
                            )
                        )
                        catch ( InLab_Log (o.name + ": refeita, mas a medição de conferência falhou (" + getCurrentException() + ").") tipo:#warn )
                )
                if resultado != #refeita and convertida do
                    InLab_Log (o.name + ": peça não refeita, mas a base ficou Editable_Poly (era " + baseAntes as string + "); o Ctrl+Z devolve.") tipo:#warn
            )
            resultado
        )
    )
)

--------------------------------------------------------------------------------
-- Entrada do botão
--------------------------------------------------------------------------------
fn InLab_Mapear objs produto unwrapGrande:false =
(
    local refeitas = 0; local mantidas = 0; local puladas = 0
    local geo = for o in objs where isValidNode o and InLab_EhGeometria o collect o
    if produto == undefined do
        InLab_Log "Mapear: nenhum produto carregado; todas as partes ficam sem família." tipo:#warn
    -- 1. pré-requisito do Real World Fix
    local alvos = #()
    for o in geo do
    (
        if InLab_Mapear_SemRWF o then
        (
            InLab_Log (o.name + ": tem Real-World ou Triplanar e não passou pelo Real World Fix; rode o Real World Fix antes. Peça pulada.") tipo:#err
            puladas += 1
        )
        else append alvos o
    )
    InLab_Mapear_ZerarCache()
    local selAntes = selection as array
    -- nós desta rodada (com as instâncias): bitmap compartilhado só é religado se
    -- todos os que o usam estão aqui
    local rodada = #()
    for o in alvos do for i in (InLab_Instancias o) do appendIfUnique rodada i
    undo "InLab Mapear" on
    (
        for g in (InLab_DeduplicarInstancias alvos) do
        (
            local o = g.no
            for n in g.instancias where n != o do
                InLab_Log (n.name + ": instância de " + o.name + ", recebe o mesmo mapeamento" +
                           (if (findItem alvos n) > 0 then "." else " (fora da seleção).")) tipo:#info
            local abertos = #()
            with undo off ( abertos = InLab_AbrirGruposAcima o )
            local r = #pulada
            try
            (
                if (getPolygonCount o)[1] == 0 then
                (
                    InLab_Log (o.name + ": sem faces, nada a mapear.") tipo:#info
                    r = #nada
                )
                else r = InLab_Mapear_Peca o produto unwrapGrande rodada:rodada
            )
            catch ( InLab_Log (o.name + ": erro inesperado no Mapear (" + getCurrentException() + ").") tipo:#err; r = #pulada )
            with undo off ( InLab_FecharGrupos abertos )
            case r of
            (
                #refeita: refeitas += 1
                #mantida: mantidas += 1
                #nada: ok
                default: puladas += 1
            )
        )
    )
    if unwrapGrande do
        with undo off ( try ( select (for s in selAntes where isValidNode s collect s) ) catch ( InLab_Log ("Mapear: não restaurei a seleção (" + getCurrentException() + ").") tipo:#warn ) )
    InLab_Log ("Mapear: " + refeitas as string + " refeita(s), " + mantidas as string + " mantida(s), " + puladas as string + " pulada(s).") \
        tipo:(if puladas > 0 then #warn else #ok)
    refeitas
)

fn InLab_ReverterMapear =
(
    local n = 0
    if InLab_UltimoMapear.count == 0 then
        InLab_Log "Mapear: nada a desfazer nesta sessão." tipo:#warn
    else
    (
        undo "InLab Desfazer Mapear" on
        (
            for i = InLab_UltimoMapear.count to 1 by -1 do
            (
                local rec = InLab_UltimoMapear[i]
                if not (isValidNode rec.no) then
                    InLab_Log "Mapear: uma peça registrada não existe mais; pulada no Desfazer." tipo:#warn
                else
                (
                    try
                    (
                        if InLab_Mapear_Restaurar rec do
                        (
                            n += 1
                            local agora = classof rec.no.baseobject
                            InLab_Log (rec.no.name + ": mapeamento desfeito" +
                                       (if agora != rec.baseAntes then " (a base continua " + agora as string + "; era " + rec.baseAntes as string + ")." else ".")) tipo:#ok
                        )
                    )
                    catch ( InLab_Log (rec.no.name + ": não desfiz o Mapear (" + getCurrentException() + ").") tipo:#err )
                )
            )
        )
        InLab_UltimoMapear = #()
        InLab_Log ("Mapear desfeito em " + n as string + " peça(s).")
    )
    n
)
