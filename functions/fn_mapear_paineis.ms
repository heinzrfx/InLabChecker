/*
 functions\fn_mapear_paineis.ms — Mapear por paineis (feature de 26/10/2026).
 Parte 1 (Tarefa 1): vivos (cordao/viés/debrum) e geometria em MUNDO.
 Parte 2 (Tarefa 2): costuras pelo vivo e molde em caixa (InLab_Paineis_Separar),
 contornos (InLab_Paineis_Contornos). Logica do spike (SPK_MontarGrade/Dist/Regioes/
 Juntar/Contornos e o bloco molde em caixa de SPK_Peca), em MUNDO via objectTransform.
 Vivo amostrado a no maximo 8000 pontos por passo fixo num while (collect com
 parametro da "Bad free thunk").
 Parte 3 (Tarefa 3): UV de cada painel (InLab_Paineis_UV, sem gravar: devolve #(uvs, mapa,
 resumo) do InLab_Mapear_Gravar) e trama torta (InLab_Paineis_Torta). Port de SPK_UVDisco,
 SPK_UVAnel (volta e perfil varrido, sem escalar U por r/rOut), SPK_Unfold, SPK_AngDir,
 SPK_Girar, SPK_FlipU, SPK_Espelho e SPK_DesalinhoRef, em MUNDO. Unfold3D num nó temporário
 (polyop.detachFaces asNode de uma CÓPIA da base em mundo, InLab_Paineis_CopiaBase, uma por
 peça, apagada no fim: o detach com delete:false acrescenta vértices de mapa no canal 1 da
 origem, achado em 26/10/2026; select/modPanel em with undo off, painel Modify uma vez por
 chamada; seleção devolvida), lido por canto de face.
 Fix 26/10/2026 (desempenho): tabelas da volta/perfil com acesso direto por faixa de 2 graus
 e por grau (antes busca linear por vértice), raio de fora por faixa calculado uma vez,
 ângulo/raio por vértice uma vez; Unfold3D do anel só se a melhor de volta/perfil passa de 0,02;
 cópia da base com setVert em array (5 s -> 0); UV do Unfold3D lido no poly colapsado (2,9 s ->
 0,4 s em 7.400 faces). Peça de 19.744 faces: ~25 s -> ~11 s. Pegadinha: local aMin/aMax engole
 as funções amin/amax (nomes sem maiúsculas). Nó espelhado: normal e espelho pelo sinal do transform.
 27/10/2026 (Mapear assistido, Tarefa 7): SAIU o Painéis automático. Apagados InLab_Paineis (botão),
 InLab_Paineis_Peca, InLab_Paineis_UV, a separação (Separar, Juntar, MontarGrade, Dist, VivosDoProduto,
 NosDaCabeca, CopiaMundo, struct InLab_PaineisSeparacao), TortaP/Torta, SPerfil, RDe, Girar, FlipU, o
 perfil: do UVAnel e as constantes INLAB_PAINEIS_DISTANCIAS/LIMIAR_CAIXA/VIVO_MAX_PONTOS/GRADE/GMIN/GN/
 VIVOP. Este arquivo ficou como infraestrutura do Cortar e do Sentido (fn_mapear_cortar.ms): geometria
 em mundo, Elementos/EhVivo/Regioes/Contornos, UVDisco/UVAnel/Unfold, Preparar/Aplicar/DevolverBase,
 a pilha e o Desfazer Painéis. As partes 1 a 4 acima descrevem o histórico do automático.
 Spec/plano: docs\superpowers\specs e docs\superpowers\plans (Mapear por paineis);
 logica de referencia no spike docs\superpowers\specs\2026-10-26-spike-paineis.ms.

 Regras:
 - Toda a logica usa coordenadas de MUNDO. polyop.getVert na base devolve espaço
   de OBJETO: InLab_Paineis_Vert multiplica por o.objectTransform.
 - Vivo = elemento fechado, fino (2V/A < 1.5 cm, o raio do tubo) e comprido
   (maior medida > 12 x raio).
 - Nunca polyop.getFacesUsingEdge por aresta (travou o Max 30 min): usa getEdgeFaces.
 - InLab_Paineis_VivosDoProduto: com nos: indefinido varre a geometria sob a mesma
   cabeça de hierarquia de o (a Tarefa 4 restringe as pecas de tecido).
 - Pre-condicao: Vert, VolArea, EhVivo e Elementos exigem no cuja base seja
   Editable_Poly. Sem isso logam #err ("<nome>: base não é Editable_Poly (<classe>)")
   e devolvem valor neutro (Vert undefined, VolArea #(0,0), EhVivo #(false,0,0)).
 - VivosDoProduto avalia nos de base nao-poly (Editable_Mesh, spline renderizavel)
   ou com modificadores por uma copia temporaria em mundo (snapshotAsMesh ->
   Editable_Mesh com transform identidade -> convertToPoly), apagada no fim; malha
   avaliada sem faces: #warn e pula (fix 26/10/2026).
 Parte 4 (Tarefa 4, 26/10/2026): botao Paineis (InLab_Paineis objs produto), pilha de rodadas
 (InLab_PilhaPaineis, cada uma #(MapearRecord...)), Desfazer Paineis (InLab_DesfazerPaineis
 tudo:false), InLab_Paineis_EsquecerPeca (o Desfazer Mapear tira da pilha as rodadas da peca),
 InLab_Paineis_EhTecido e InLab_Paineis_Escala (cmPorID do Mapear > "InLab RWF*" do canal do
 difuso > INLAB_MAPEAR_CM_POR_TILE). Guardas, gravacao e registro como no Mapear (stack, base
 Editable_Poly com triangulos conferidos, RWF do canal 1 fora com o UV avaliado das faces que
 nao sao de tecido, bitmaps do canal do Triplanar religados ao canal 1, grupos abertos e
 fechados, uma vez por base com #warn de instancia girada). Vivos lidos uma vez por cabeca na
 rodada, so das pecas de tecido (nos:). Os ChamferBox dos testes da Tarefa 2 passaram a usar
 Length_Segments etc. (densos): passaram sem mudar a separacao.
 Fix 1 (26/10/2026, revisao da Tarefa 4): escala = cmPorID da rodada de Paineis mais nova da
 peca > do Mapear > "InLab RWF*" > densidade medida do ID (faixa do Mapear) > tamanho do RWF
 do mesmo bitmap na rodada > 60 cm (RWF -> Paineis -> Paineis caia para 60). Varredura do
 stack em InLab_Mapear_VarrerStack (a mesma do Mapear). InLab_Paineis_RestaurarPeca (o
 Desfazer Mapear volta antes as rodadas de Paineis da peca, mais novas que ele) e
 EsquecerPeca motivo: (o Mapear que refaz a peca tira da pilha as rodadas dela). A rodada so
 conta pecas de tecido (bitmap compartilhado com uma madeira selecionada nao e religado).
 try/catch externo em InLab_Paineis zera o estado da rodada.
 Pegadinhas: nomes sao case-insensitive (local "a" esconde o parametro "A"); o
 parametro de fn usado dentro de collect em bloco aninhado da "Bad free thunk".
 Revisao final (26/10/2026):
 - O Mapear nao refaz peca com rodada de Paineis na pilha (InLab_Paineis_TemPeca, chamada no
   inicio de InLab_Mapear_Peca): pula com #info "use Desfazer Paineis antes". O caminho do
   EsquecerPeca motivo:"o Mapear refez a peca" nao acontece mais (a funcao fica).
 - Escala por ID: cada ID de tecido usa InLab_Paineis_Escala o id, o cmPorID grava o cm de
   cada ID e o tiling de cada bitmap religado usa a escala do ID dele. Painel que mistura IDs
   usa a escala do ID com mais faces nele (InLab_Paineis_UV aceita uma escala por painel).
 - Faces sem painel (vivos) dos IDs cujo bitmap e religado ao canal 1 recebem no canal 1 o UV
   avaliado do canal do RWF que o bitmap lia (x escala/densidade do RWF): o vivo nao muda.
 - Bitmap preso no canal do RWF: #warn "o material continua lendo o canal N" no fim da peca.
 - Ver UV ligado: a guarda "bitmap usado fora desta rodada" soma InLab_VerUV_NosQueUsam
   (refs.dependentNodes nao ve os nos com as listras).
 - Temporarios (InLab_Paineis_Temp: camada 0, visiveis, nao congelados): CopiaMundo,
   CopiaBase e VivosDoProduto apagam o temporario numa excecao e relancam; o fim de
   InLab_Paineis apaga sempre os InLab_tmp_* que sobraram, com #warn.
   InLab_Paineis_ForcarFalha (so teste) forca a excecao.
 - Dist limita o indice de cada celula vizinha (antes recusava ponto perto da borda da
   grade). Separar recorta os pontos de vivo pela caixa do corpo + 3 cm antes da grade (nenhum
   ponto: "vivo a mais de 3 cm") e monta a adjacencia de faces uma vez para as 7 distancias
   (InLab_Paineis_Regioes adj:).
 Hotfix 1.3.2 (27/10/2026): face morta na base (polyop.getFaceDeg undefined) travava o Max
 (CPU 100%, RAM até 23 GB): polyop.getElementsUsingFace nela devolve vazio, e
 InLab_Paineis_Elementos nunca a tirava do conjunto. Agora a face de partida sai sempre e
 elemento vazio é descartado. O detachFaces do Unfold3D também compacta a cópia e renumera as
 faces depois da morta: InLab_Paineis_Peca chama InLab_Paineis_TirarMortas
 (polyop.collapseDeadStructs na base, dentro do undo do Painéis) antes de ler índices.
 Refator 27/10/2026 (Mapear assistido, Tarefa 1; sem mudanca de comportamento): InLab_Paineis_Peca
 dividida em InLab_Paineis_Preparar (guardas, stack, base poly, face morta; devolve a struct
 InLab_PaineisPrep), InLab_Paineis_Aplicar (RWF fora, bitmaps religados, UV das faces sem painel,
 registro e gravacao; o log do resumo ficou em Peca, e o aviso dos canais do RWF mantidos agora
 sai antes dele) e InLab_Paineis_DevolverBase, para o Cortar reaproveitar. A escala por ID do
 Aplicar sai do cm por tile recebido.
 - Peca nao refeita com a base convertida: a base de antes volta (o.baseobject = copia).
 - Vivo como spline renderizavel: #info com o nome (fica fora da separacao).
 27/10/2026 (Mapear assistido, Tarefa 5): o Desfazer Painéis e o InLab_Paineis_RestaurarPeca
 devolvem as marcas do Cortar de antes (InLab_Paineis_VoltarMarcas: rec.marcas definido;
 #nenhuma apaga as marcas). Registro do Painéis automático (marcas undefined) não mexe nelas.
*/
global InLab_Log, InLab_EhGeometria
global InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea, InLab_Paineis_TirarMortas
global InLab_Paineis_BaseOk
global InLab_Paineis_EhVivo
global InLab_Paineis_Contornos, InLab_Paineis_Regioes
global InLab_Mapear_NoEspelhado
global InLab_Paineis_Sinal, InLab_Paineis_PosMundo, InLab_Paineis_NormalArea, InLab_Paineis_EixoAnel
global InLab_Paineis_UVDisco, InLab_Paineis_AngP, InLab_Paineis_LDe
global InLab_Paineis_UVAnel, InLab_Paineis_DirUV
global InLab_Paineis_AngDir, InLab_Paineis_EspelhoUV
global InLab_Paineis_Unfold, InLab_Paineis_Bin, InLab_Paineis_CopiaBase
-- Tarefa 4
global InLab_Mapear_ParteDoMaterial, InLab_Mapear_RegraDaParte, InLab_Mapear_MaterialDoID, InLab_Mapear_Grupos
global InLab_Mapear_BitmapDifuso, InLab_Mapear_Bitmaps, InLab_Mapear_Tiling, InLab_Mapear_SetTiling, InLab_Mapear_SetCanal
global InLab_Mapear_CanalOriginal, InLab_Mapear_DensRWF, InLab_Mapear_TamDoBitmap, InLab_Mapear_EhRWF, InLab_Mapear_CanalModUV
global InLab_Mapear_SemRWF, InLab_Mapear_ConverterBase, InLab_Mapear_Gravar, InLab_Mapear_UVAvaliado, InLab_Mapear_Juntar
global InLab_Mapear_LerCanal1, InLab_Mapear_Restaurar, InLab_Mapear_FacesDoID, InLab_Mapear_Num, InLab_Mapear_ZerarCache
global InLab_Mapear_CanaisIni, InLab_Mapear_TamIni, InLab_UltimoMapear, InLab_RWF_CanalBitmap, InLab_ListaResumida
global InLab_Instancias, InLab_DeduplicarInstancias, InLab_AbrirGruposAcima, InLab_FecharGrupos
global INLAB_MAPEAR_CM_POR_TILE, INLAB_MAPEAR_CM_MIN, INLAB_MAPEAR_CM_MAX
global InLab_Paineis_EhTecido, InLab_Paineis_UTil, InLab_Paineis_CmOk, InLab_Paineis_Escala, InLab_Paineis_Girada
global InLab_Paineis_Preparar, InLab_Paineis_Aplicar, InLab_Paineis_DevolverBase
global InLab_Paineis_EsquecerPeca, InLab_DesfazerPaineis
global InLab_Paineis_RestaurarPeca, InLab_Mapear_VarrerStack, InLab_Mapear_Medir
-- revisão final (26/10/2026)
global InLab_Paineis_Temp, InLab_Paineis_TemPeca, InLab_VerUV_NosQueUsam
-- 27/10/2026 (Mapear assistido, Tarefa 5): fn_mapear_cortar.ms (carregado depois)
global InLab_Cortar_GravarMarcas, InLab_Cortar_ApagarMarcas, InLab_Paineis_VoltarMarcas
-- pilha de rodadas do Painéis: cada item é #(MapearRecord...) de um clique; só o Desfazer tira
global InLab_PilhaPaineis = #()
-- SÓ TESTE (revisão final, 26/10/2026): "CopiaBase" força uma exceção
-- logo depois de criar o nó temporário (conferir que nenhum InLab_tmp_* sobra)
global InLab_Paineis_ForcarFalha = undefined

-- base é Editable_Poly? Senão loga #err e devolve false
fn InLab_Paineis_BaseOk o =
(
    local ok = isValidNode o and (classof o.baseobject == Editable_Poly)
    if not ok do
        InLab_Log ((if isValidNode o then o.name else "<nó inválido>") + ": base não é Editable_Poly (" + (if isValidNode o then (classof o.baseobject) as string else "undefined") + ")") tipo:#err
    ok
)

-- nó temporário na camada 0, visível e não congelado (camada atual escondida ou congelada
-- não pode atrapalhar o select/Unfold3D). Devolve o nó.
fn InLab_Paineis_Temp n =
(
    try ( (LayerManager.getLayer 0).addNode n )
    catch ( InLab_Log ("painéis: não pus o nó temporário na camada 0 (" + getCurrentException() + ")") tipo:#warn )
    n.isHidden = false
    n.isFrozen = false
    n
)

-- vértice v da base de o em coordenadas de mundo
fn InLab_Paineis_Vert o v =
(
    if not (InLab_Paineis_BaseOk o) then undefined
    else (polyop.getVert (InLab_Mapear_PolyDe o) v) * o.objectTransform
)

-- elementos conexos (bitarrays de faces) dentro de faces
fn InLab_Paineis_Elementos po faces =
(
    -- hotfix 1.3.2: face morta fora (getElementsUsingFace de uma face viva a inclui)
    local vivas = copy faces
    for f in faces do ( local d = polyop.getFaceDeg po f; if d == undefined or d < 3 do vivas[f] = false )
    faces = vivas
    local resta = copy faces
    local els = #()
    while not resta.isEmpty do
    (
        local f0 = 0
        for f in resta while f0 == 0 do f0 = f
        -- face morta dá elemento vazio: tirar f0 sempre (sem isso o laço não termina, hotfix 1.3.2)
        resta[f0] = false
        local el = (polyop.getElementsUsingFace po #{f0}) * faces
        if not el.isEmpty do
        (
            append els el
            resta -= el
        )
    )
    els
)

-- tira as faces e arestas mortas da base Editable_Poly de o (polyop.collapseDeadStructs).
-- Devolve quantas faces mortas havia (0 = nada mudou). Hotfix 1.3.2.
fn InLab_Paineis_TirarMortas o =
(
    local po = o.baseobject
    local n = 0
    for f = 1 to polyop.getNumFaces po do
    (
        local d = polyop.getFaceDeg po f
        if d == undefined or d < 3 do n += 1
    )
    if n > 0 do polyop.collapseDeadStructs po
    n
)

-- #(volume, area) em MUNDO de um conjunto de faces (fan dos poligonos)
fn InLab_Paineis_VolArea o fs =
(
    if not (InLab_Paineis_BaseOk o) then return #(0.0, 0.0)
    local po = InLab_Mapear_PolyDe o
    local tm = o.objectTransform
    local cache = #()
    local v = 0.0, a = 0.0
    for f in fs do
    (
        local vs = polyop.getFaceVerts po f
        local pts = #()
        for k = 1 to vs.count do
        (
            if cache[vs[k]] == undefined do cache[vs[k]] = (polyop.getVert po vs[k]) * tm
            append pts cache[vs[k]]
        )
        local p0 = pts[1]
        for k = 2 to pts.count - 1 do
        (
            local p1 = pts[k], p2 = pts[k+1]
            v += (dot p0 (cross p1 p2)) / 6.0
            a += (length (cross (p1 - p0) (p2 - p0))) / 2.0
        )
    )
    #(abs v, a)
)

-- #(ehVivo, raio, maiorMedida): fechado, 2V/A < 1.5 cm e maior medida > 12 x raio
fn InLab_Paineis_EhVivo o el =
(
    if not (InLab_Paineis_BaseOk o) then return #(false, 0.0, 0.0)
    local po = InLab_Mapear_PolyDe o
    local va = InLab_Paineis_VolArea o el
    local abertas = ((polyop.getOpenEdges po) * (polyop.getEdgesUsingFace po el)).numberSet
    local mn = [1e9,1e9,1e9], mx = [-1e9,-1e9,-1e9]
    for v in (polyop.getVertsUsingFace po el) do
    (
        local p = InLab_Paineis_Vert o v
        mn = [amin mn.x p.x, amin mn.y p.y, amin mn.z p.z]
        mx = [amax mx.x p.x, amax mx.y p.y, amax mx.z p.z]
    )
    local tam = amax #(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    local r = if va[2] > 1e-6 then 2.0 * va[1] / va[2] else 0.0
    #(abertas == 0 and va[2] > 1e-6 and r < 1.5 and tam > 12.0 * r, r, tam)
)

-- regiões de faces conectadas sem atravessar arestas de costura. adj: #(arestas por face,
-- faces por aresta) montado uma vez pela peça (revisão final); indefinido = lê do poly
fn InLab_Paineis_Regioes po faces costura adj:undefined =
(
    local resta = copy faces
    local regs = #()
    while not resta.isEmpty do
    (
        local f0 = 0
        for f in resta while f0 == 0 do f0 = f
        local reg = #{f0}, fila = #(f0)
        resta[f0] = false
        while fila.count > 0 do
        (
            local f = fila[fila.count]
            fila.count = fila.count - 1
            local fes = if adj != undefined then adj[1][f] else polyop.getFaceEdges po f
            for e in fes where not costura[e] do
                for g in (if adj != undefined then adj[2][e] else polyop.getEdgeFaces po e) where resta[g] do
                (
                    resta[g] = false
                    reg[g] = true
                    append fila g
                )
        )
        append regs reg
    )
    regs
)

-- número de contornos (bordas fechadas) de um conjunto de faces: 1 = disco, >=2 = anel, 0 = fechado
fn InLab_Paineis_Contornos po fs =
(
    local borda = #{}
    for f in fs do for e in (polyop.getFaceEdges po f) do
    (
        local dentro = 0
        for g in (polyop.getEdgeFaces po e) where fs[g] do dentro += 1
        if dentro == 1 do borda[e] = true
    )
    local resta = copy borda, n = 0
    while not resta.isEmpty do
    (
        local e0 = 0
        for e in resta while e0 == 0 do e0 = e
        local fila = #(e0)
        resta[e0] = false
        n += 1
        while fila.count > 0 do
        (
            local e = fila[fila.count]
            fila.count = fila.count - 1
            for v in (polyop.getEdgeVerts po e) do
                for e2 in (polyop.getEdgesUsingVert po v) where resta[e2] do ( resta[e2] = false; append fila e2 )
        )
    )
    n
)

---------------- Tarefa 3: UV de cada painel (spec 5.5 e 5.6) ----------------
-- Tudo em MUNDO. Nada é gravado no nó: cada painel gera #(uvs, mapa) próprios, e o
-- Unfold3D roda num nó temporário (detachFaces asNode, apagado no fim).

-- -1 se o nó é espelhado (a normal que aparece é a oposta do sentido dos vértices em mundo)
fn InLab_Paineis_Sinal o = ( if InLab_Mapear_NoEspelhado o then -1.0 else 1.0 )

-- posição (mundo) dos vértices das faces fs, indexada pelo vértice da base
fn InLab_Paineis_PosMundo o fs =
(
    local po = InLab_Mapear_PolyDe o
    local tm = o.objectTransform
    local posM = #()
    for v in (polyop.getVertsUsingFace po fs) do posM[v] = (polyop.getVert po v) * tm
    posM
)

-- normal (mundo) de uma face com comprimento = área; sinal -1 no nó espelhado
fn InLab_Paineis_NormalArea posM vs sinal =
(
    local n = [0,0,0]
    local p0 = posM[vs[1]]
    for j = 2 to vs.count - 1 do n += cross (posM[vs[j]] - p0) (posM[vs[j+1]] - p0)
    n * (0.5 * sinal)
)

-- eixo do anel pelo vivo: o eixo do mundo com menor soma de área x |n·eixo|
fn InLab_Paineis_EixoAnel po posM fs sinal =
(
    local s = #(0.0, 0.0, 0.0)
    for f in fs do
    (
        local n = InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
        s[1] += abs n.x; s[2] += abs n.y; s[3] += abs n.z
    )
    local k = 1
    for i = 2 to 3 where s[i] < s[k] do k = i
    k
)

-- disco: projeção plana na normal média (T horizontal, X do mundo se a normal é quase vertical)
fn InLab_Paineis_UVDisco po posM fs escala sinal =
(
    local n = [0,0,0]
    for f in fs do n += InLab_Paineis_NormalArea posM (polyop.getFaceVerts po f) sinal
    n = normalize n
    local eT = if abs n.z > 0.9 then [1,0,0] else normalize [-n.y, n.x, 0]
    local eB = cross n eT
    local uvs = #(), mapa = #(), tab = #()
    for f in fs do
    (
        local ids = #()
        for v in (polyop.getFaceVerts po f) do
        (
            if tab[v] == undefined do
            (
                local q = posM[v]
                append uvs [(dot q eT) * escala, (dot q eB) * escala, 0]
                tab[v] = uvs.count
            )
            append ids tab[v]
        )
        append mapa #(f, ids)
    )
    #(uvs, mapa, n)
)

-- ângulo (0..360) de p em volta do centro (c1, c2) no plano (e1, e2), já deslocado para o corte ficar em 0
fn InLab_Paineis_AngP p e1 e2 c1 c2 corte =
(
    local s = (atan2 ((dot p e2) - c2) ((dot p e1) - c1)) - corte
    while s < 0 do s += 360.0
    while s >= 360 do s -= 360.0
    s
)
-- faixa de 2 graus (1..180) de um ângulo 0..360
fn InLab_Paineis_Bin ang =
(
    local b = (floor (ang / 2.0)) as integer + 1
    if b < 1 do b = 1
    if b > 180 do b = 180
    b
)
-- comprimento ao longo do contorno de fora no ângulo ang (tabela ângulo -> comprimento).
-- idxBin[b] = índice em tabA do último ponto de faixa <= b (0 = antes do primeiro): acesso
-- direto, sem busca linear (fix de desempenho 26/10/2026)
fn InLab_Paineis_LDe ang tabA tabL idxBin =
(
    local i = 0
    if ang >= tabA[1] do
    (
        i = idxBin[InLab_Paineis_Bin ang]
        -- o ponto da mesma faixa pode estar depois de ang
        if i > 0 and tabA[i] > ang do i -= 1
    )
    if i == 0 do ( ang += 360.0; i = tabA.count - 1 )
    if i >= tabA.count then tabL[tabL.count]
    else tabL[i] + (ang - tabA[i]) / (amax 1e-6 (tabA[i+1] - tabA[i])) * (tabL[i+1] - tabL[i])
)
-- anel em volta do eixo k (1=X 2=Y 3=Z). Volta pelo contorno de fora (maior raio a cada
-- 2 graus); corte numa quina de trás (entre -X e +Y) se o eixo é Z, embaixo (-Z) se é
-- horizontal (corte: em graus substitui esse padrão). O U NÃO é escalado por r/rOut (abre a trama em leque).
-- Ângulo e raio por vértice calculados uma vez; tabelas por faixa/grau com acesso direto.
fn InLab_Paineis_UVAnel po posM fs k escala corte:undefined =
(
    local ax = #([1,0,0], [0,1,0], [0,0,1])[k]
    local e1 = if k == 3 then [1,0,0] else if k == 1 then [0,1,0] else [1,0,0]
    local e2 = if k == 3 then [0,1,0] else [0,0,1]
    local vs = (polyop.getVertsUsingFace po fs) as array
    local c1 = 0.0, c2 = 0.0
    for v in vs do ( local q = posM[v]; c1 += dot q e1; c2 += dot q e2 )
    c1 /= vs.count; c2 /= vs.count
    -- corte: (graus, Tarefa 3 do Mapear assistido, 27/10/2026) substitui o padrão quando dado
    local angCorte = if corte != undefined then (corte as float) else (if k == 3 then 135.0 else -90.0)
    -- ângulo e raio de cada vértice (indexados pelo vértice da base)
    local angV = #(), raioV = #()
    for v in vs do
    (
        local q = posM[v]
        angV[v] = InLab_Paineis_AngP q e1 e2 c1 c2 angCorte
        raioV[v] = distance [(dot q e1), (dot q e2), 0] [c1, c2, 0]
    )
    -- contorno de fora: maior raio a cada 2 graus
    local bins = #()
    bins.count = 180
    for v in vs do
    (
        local q = posM[v]
        local b = InLab_Paineis_Bin angV[v]
        if bins[b] == undefined or raioV[v] > bins[b][1] do bins[b] = #(raioV[v], [(dot q e1), (dot q e2), 0], angV[v])
    )
    local pts = #(), idxBin = #()
    idxBin.count = 180
    for b = 1 to 180 do
    (
        if bins[b] != undefined do append pts bins[b]
        idxBin[b] = pts.count
    )
    local tabA = #(), tabL = #()
    local acc = 0.0
    for i = 1 to pts.count do
    (
        if i > 1 do acc += distance pts[i][2] pts[i-1][2]
        append tabA pts[i][3]
        append tabL acc
    )
    local perim = acc + (distance pts[1][2] pts[pts.count][2])
    append tabA (pts[1][3] + 360.0)
    append tabL perim
    -- comprimento na volta por vértice (o "alto" soma perim depois)
    local sV = #()
    for v in vs do sV[v] = InLab_Paineis_LDe angV[v] tabA tabL idxBin
    local tV = #()
    for v in vs do tV[v] = dot posM[v] ax
    local uvs = #(), mapa = #(), tabBaixo = #(), tabAlto = #()
    for f in fs do
    (
        local fv = polyop.getFaceVerts po f
        -- (não chamar de aMin/aMax: nomes sem maiúsculas engolem as funções amin/amax)
        local angMin = 1e9, angMax = -1e9
        for v in fv do ( angMin = amin angMin angV[v]; angMax = amax angMax angV[v] )
        local atravessa = (angMax - angMin) > 180.0
        local ids = #()
        for j = 1 to fv.count do
        (
            local v = fv[j]
            local alto = atravessa and angV[v] < 180.0
            local tt = if alto then tabAlto else tabBaixo
            if tt[v] == undefined do
            (
                local s = sV[v] + (if alto then perim else 0.0)
                local tEixo = tV[v]
                -- eixo vertical: U = volta, V = altura; horizontal: U = eixo, V = volta
                append uvs (if k == 3 then [s * escala, tEixo * escala, 0] else [tEixo * escala, s * escala, 0])
                tt[v] = uvs.count
            )
            append ids tt[v]
        )
        append mapa #(f, ids)
    )
    #(uvs, mapa)
)

-- direção (2D, no UV) da direção dir do mundo projetada na face f (pela combinação exata
-- das arestas); undefined se dir fica quase na normal (projeção < lim) ou a face é degenerada
fn InLab_Paineis_DirUV po posM f ids uvs dir lim =
(
    local vs = polyop.getFaceVerts po f
    local p0 = posM[vs[1]], p1 = posM[vs[2]], p2 = posM[vs[3]]
    local t0 = uvs[ids[1]], t1 = uvs[ids[2]], t2 = uvs[ids[3]]
    local a1 = p1 - p0, a2 = p2 - p0
    local cr = cross a1 a2
    local res = undefined
    if (length cr) > 1e-12 do
    (
        local nn = normalize cr
        local xp = dir - nn * (dot nn dir)
        if (length xp) > lim do
        (
            local g11 = dot a1 a1, g12 = dot a1 a2, g22 = dot a2 a2
            local b1 = dot xp a1, b2 = dot xp a2
            local det = g11*g22 - g12*g12
            if abs det > 1e-12 do
            (
                local x1 = (b1*g22 - b2*g12) / det, x2 = (b2*g11 - b1*g12) / det
                local d = (t1 - t0) * x1 + (t2 - t0) * x2
                if (length d) > 1e-12 do res = d
            )
        )
    )
    res
)

-- ângulo médio (graus, no UV) de dir do mundo projetada nas faces
fn InLab_Paineis_AngDir po posM uvs mapa dir =
(
    local g = [0,0,0]
    for e in mapa do
    (
        local d = InLab_Paineis_DirUV po posM e[1] e[2] uvs dir 0.2
        if d != undefined do g += (normalize d) * (length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) 1.0))
    )
    atan2 g.y g.x
)

-- fração da área com UV espelhado (produto vetorial 2D contra o sentido da face que aparece)
fn InLab_Paineis_EspelhoUV po posM uvs mapa sinal =
(
    local ruim = 0.0, tot = 0.0
    for e in mapa do
    (
        local ids = e[2]
        local t0 = uvs[ids[1]], t1 = uvs[ids[2]], t2 = uvs[ids[3]]
        local cuv = (t1 - t0).x * (t2 - t0).y - (t1 - t0).y * (t2 - t0).x
        local ar = length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts po e[1]) 1.0)
        tot += ar
        if cuv * sinal < 0 do ruim += ar
    )
    if tot > 0 then ruim / tot else 0.0
)

-- cópia temporária da BASE de o num nó novo, com os vértices em MUNDO e transform identidade
-- (mesmos índices de face; sem a pilha nem o grupo de o). Quem chama apaga. O detach do
-- Unfold3D sai daqui: o detach (mesmo com delete:false) mexe no canal 1 da origem
-- (acrescenta vértices de mapa), achado em 26/10/2026.
fn InLab_Paineis_CopiaBase o =
(
    local src = undefined
    with undo off
    (
        try
        (
            src = Box name:(uniqueName "InLab_tmp_unfold_src")
            InLab_Paineis_Temp src
            src.baseobject = copy o.baseobject
            if InLab_Paineis_ForcarFalha == "CopiaBase" do throw "falha forçada para teste (CopiaBase)"
            local sp = src.baseobject
            local tm = o.objectTransform
            -- uma chamada com array (setVert vértice a vértice levou 5 s em 20 mil vértices)
            local nv = polyop.getNumVerts sp
            local pos = #()
            pos.count = nv
            for v = 1 to nv do pos[v] = (polyop.getVert sp v) * tm
            if nv > 0 do polyop.setVert sp #{1..nv} pos
        )
        catch
        (
            -- revisão final: o temporário não fica na cena
            if isValidNode src do delete src
            throw()   -- relança a mesma exceção (dentro do catch só vale throw sem argumento)
        )
    )
    src
)

-- Unfold3D a partir de uvs/mapa (o UV inicial, com os cortes) num nó temporário com as faces fs
-- destacadas de src (InLab_Paineis_CopiaBase; apagado no fim). Escala pela área (3D em mundo /
-- UV) e posição pelo centro do UV inicial; o giro fica para quem chama. A face k do nó destacado
-- é a k-ésima de fs; o resultado é lido por canto de face (o solve renumera os vértices de UV).
-- Quem chama já pôs o painel Modify e devolve a seleção. undefined se falhou.
fn InLab_Paineis_Unfold src fs uvs mapa posM escala nomePeca =
(
    local lista = fs as array
    local idsDe = #()
    for e in mapa do idsDe[e[1]] = e[2]
    local nome = uniqueName "InLab_tmp_unfold"
    local tmp = undefined, novos = undefined
    try
    (
        with undo off
        (
            polyop.detachFaces src.baseobject fs delete:false asNode:true name:nome node:src
            tmp = getNodeByName nome
            InLab_Paineis_Temp tmp
            local tp = tmp.baseobject
            if (polyop.getNumFaces tp) != lista.count do throw "nó temporário com outro número de faces"
            for k = 1 to lista.count do
                if (polyop.getFaceDeg tp k) != idsDe[lista[k]].count do throw "nó temporário com faces em outra ordem"
            polyop.setMapSupport tp 1 true
            polyop.setNumMapVerts tp 1 uvs.count keep:false
            for i = 1 to uvs.count do polyop.setMapVert tp 1 i uvs[i]
            for k = 1 to lista.count do polyop.setMapFace tp 1 k idsDe[lista[k]]
            select tmp
            local uvw = Unwrap_UVW()
            addModifier tmp uvw
            modPanel.setCurrentObject uvw
            uvw.setMapChannel 1
            uvw.selectFaces #{1..(uvw.numberPolygons())}
            uvw.Unfold3DSolve()
            -- lê por canto de face no poly colapsado: getVertexIndexFromFace/getVertexPosition
            -- do Unwrap levou 2,9 s em 7.400 faces, o colapso + polyop 0,4 s (mesmos valores)
            maxOps.CollapseNodeTo tmp 1 true
            local tc = tmp.baseobject
            if (classof tc) != Editable_Poly or (polyop.getNumFaces tc) != lista.count do throw "colapso do Unwrap mudou a malha"
            novos = #()
            for k = 1 to lista.count do
            (
                local q = #()
                for i in (polyop.getMapFace tc 1 k) do append q (polyop.getMapVert tc 1 i)
                if q.count != idsDe[lista[k]].count do throw "face com outro número de cantos depois do Unfold3D"
                append novos q
            )
        )
    )
    catch
    (
        InLab_Log (nomePeca + ": painéis: Unfold3D falhou (" + (getCurrentException()) + ")") tipo:#warn
        novos = undefined
    )
    with undo off ( if isValidNode tmp do delete tmp )
    if novos == undefined then undefined
    else
    (
        local a3 = 0.0, auv = 0.0, cN = [0,0,0], cV = [0,0,0], nc = 0
        for k = 1 to lista.count do
        (
            a3 += length (InLab_Paineis_NormalArea posM (polyop.getFaceVerts src.baseobject lista[k]) 1.0)
            local q = novos[k]
            for j = 2 to q.count - 1 do auv += abs (((q[j] - q[1]).x * (q[j+1] - q[1]).y - (q[j] - q[1]).y * (q[j+1] - q[1]).x) / 2.0)
            local ids = idsDe[lista[k]]
            for j = 1 to ids.count do ( cN += q[j]; cV += uvs[ids[j]]; nc += 1 )
        )
        cN /= nc; cV /= nc
        local s = (sqrt (a3 / (amax 1e-12 auv))) * escala
        local novoDe = #(), uvs2 = #(), mapa2 = #()
        for k = 1 to lista.count do
        (
            local ids = idsDe[lista[k]]
            local ids2 = #()
            for j = 1 to ids.count do
            (
                if novoDe[ids[j]] == undefined do
                (
                    local q = (novos[k][j] - cN) * s + cV
                    append uvs2 [q.x, q.y, 0]
                    novoDe[ids[j]] = uvs2.count
                )
                append ids2 novoDe[ids[j]]
            )
            append mapa2 #(lista[k], ids2)
        )
        #(uvs2, mapa2)
    )
)

---------------- Tarefa 4: botão Painéis, pilha e Desfazer Painéis (spec 4, 5.7 a 5.9, 6 e 8) ----------------
-- A gravação, o registro e o Desfazer usam a infraestrutura do Mapear (fn_mapear.ms): base
-- Editable_Poly, "InLab RWF*" do canal 1 tirados (o UV avaliado das faces que não são de tecido é
-- copiado antes), bitmaps que liam o canal do Triplanar do RWF religados ao canal 1, MapearRecord.

-- tecido pela parte do JSON do material do ID (id indefinido: o material da peça; num Multi/Sub,
-- algum submaterial de tecido)
fn InLab_Paineis_EhTecido o produto id:undefined =
(
    local r = false
    if produto != undefined and isValidNode o and (InLab_Mapear_Mat o) != undefined do
    (
        local mats = #()
        if id != undefined then mats = #(InLab_Mapear_MaterialDoID (InLab_Mapear_Mat o) id)
        else if classof (InLab_Mapear_Mat o) == Multimaterial then ( for m in (InLab_Mapear_Mat o).materialList do append mats m )
        else mats = #((InLab_Mapear_Mat o))
        for m in mats where m != undefined while not r do
        (
            local parte = InLab_Mapear_ParteDoMaterial produto m.name
            if parte != undefined and (InLab_Mapear_RegraDaParte produto parte) == #tecido do r = true
        )
    )
    r
)

-- tiling U do difuso do ID (1 sem bitmap)
fn InLab_Paineis_UTil o id =
(
    local b = InLab_Mapear_BitmapDifuso (InLab_Mapear_MaterialDoID (InLab_Mapear_Mat o) id)
    local u = if b != undefined then abs (InLab_Mapear_Tiling b).x else 1.0
    if u < 1e-6 then 1.0 else u
)

-- cm por tile plausível (faixa do Mapear, com 1% de folga)
fn InLab_Paineis_CmOk cm = ( cm != undefined and cm >= INLAB_MAPEAR_CM_MIN * 0.99 and cm <= INLAB_MAPEAR_CM_MAX * 1.01 )

-- UV por cm do ID (spec 5.7), pela ordem: cmPorID da rodada de Painéis mais nova da peça (ou de uma
-- instância) em InLab_PilhaPaineis; cmPorID do Mapear mais novo em InLab_UltimoMapear; o "InLab
-- RWF*" do canal que o difuso lê; a densidade medida do ID, se plausível; o tamanho que o RWF deu
-- ao mesmo bitmap em outra peça da rodada; INLAB_MAPEAR_CM_POR_TILE.
fn InLab_Paineis_Escala o id =
(
    local uTil = InLab_Paineis_UTil o id
    local inst = InLab_Instancias o
    local cm = undefined
    -- 1º a rodada de Painéis mais nova da peça (fix 1: RWF -> Painéis -> Painéis caía para 60)
    for i = InLab_PilhaPaineis.count to 1 by -1 while cm == undefined do
        for r in InLab_PilhaPaineis[i] while cm == undefined do
            if isValidNode r.no and (findItem inst r.no) > 0 do
                for x in r.cmPorID while cm == undefined do if x[1] == id do cm = x[2]
    -- 2º o Mapear
    local mapeados = if InLab_UltimoMapear == undefined then #() else InLab_UltimoMapear
    for i = mapeados.count to 1 by -1 while cm == undefined do
    (
        local r = mapeados[i]
        if isValidNode r.no and (findItem inst r.no) > 0 do
            for x in r.cmPorID while cm == undefined do if x[1] == id do cm = x[2]
    )
    if cm != undefined then 1.0 / (cm * uTil)
    else
    (
        local dens = undefined
        local bmp = InLab_Mapear_BitmapDifuso (InLab_Mapear_MaterialDoID (InLab_Mapear_Mat o) id)
        local canal = if bmp != undefined then InLab_Mapear_CanalOriginal bmp else 1
        for m in o.modifiers where (InLab_Mapear_EhRWF m) while dens == undefined do
        (
            if (InLab_Mapear_CanalModUV m) == canal do
            (
                local d = InLab_Mapear_DensRWF o m
                if d != undefined and d > 1e-9 and (InLab_Paineis_CmOk (1.0 / (d * uTil))) do dens = d
            )
        )
        -- densidade medida do ID, se plausível (como no Mapear)
        if dens == undefined do
        (
            local med = try ( InLab_Mapear_Medir o matID:id )
                        catch ( InLab_Log (o.name + ": não medi a densidade atual (" + getCurrentException() + ").") tipo:#warn; undefined )
            if med != undefined and not med.falhou and med.temCanal and med.amostra > 0 and med.escala > 1e-9 and \
                (InLab_Paineis_CmOk (1.0 / (med.escala * uTil))) do dens = med.escala
        )
        if dens == undefined and bmp != undefined do
        (
            local d = InLab_Mapear_TamDoBitmap bmp
            if d != undefined and d > 1e-9 and (InLab_Paineis_CmOk (1.0 / (d * uTil))) do dens = d
        )
        if dens != undefined then dens else 1.0 / (INLAB_MAPEAR_CM_POR_TILE * uTil)
    )
)

-- instância b girada ou espelhada em relação a a (linhas do objectTransform, tolerância 1°)
fn InLab_Paineis_Girada a b =
(
    local ta = a.objectTransform, tb = b.objectTransform
    local lim = cos 1.0
    local r = false
    for k = 1 to 3 do if (dot (normalize ta[k]) (normalize tb[k])) < lim do r = true
    r
)

-- Resultado de InLab_Paineis_Preparar (27/10/2026): o que Aplicar/DevolverBase precisam da peça.
struct InLab_PaineisPrep ( tec, grupos, rwfMods, baseAntes, convertida, copiaBase )

-- Passos 1 e 2 do Painéis (27/10/2026, dividido de InLab_Paineis_Peca para o Cortar reaproveitar):
-- guardas, varredura do stack, base Editable_Poly e face morta. Devolve InLab_PaineisPrep ou
-- undefined (peça não tocada; o log já disse por quê).
fn InLab_Paineis_Preparar o produto =
(
    local grupos = InLab_Mapear_Grupos o
    local tec = #()
    for g in grupos do if (InLab_Paineis_EhTecido o produto id:g[1]) do append tec g[1]
    if tec.count == 0 do
    (
        InLab_Log (o.name + ": Painéis é só para tecido; peça como estava.") tipo:#warn
        return undefined
    )
    InLab_Log (o.name + ": mapeando por painéis (" + ((getPolygonCount o)[1]) as string + " faces)...") tipo:#info
    -- 1. stack (a mesma varredura do Mapear)
    local st = InLab_Mapear_VarrerStack o
    local rwfMods = st[1]       -- #(modificador, índice, canal)
    local bloqueio = st[2]
    local temUnwrap = st[3]
    local avisos = st[4]
    if bloqueio != undefined do
    (
        InLab_Log (o.name + ": modificador de mapeamento \"" + bloqueio + "\" no canal 1 acima da base; peça não tocada.") tipo:#warn
        return undefined
    )
    if (classof o.baseobject) != Editable_Poly and temUnwrap do
    (
        InLab_Log (o.name + ": Unwrap acima da base " + ((classof o.baseobject) as string) +
                   "; converter a base para Editable_Poly mudaria as faces que ele guarda. Peça não tocada.") tipo:#warn
        return undefined
    )
    for a in avisos do InLab_Log (o.name + ": " + a + ".") tipo:#warn
    -- 2. base Editable_Poly (como no Mapear: triângulos de render conferidos). Cópia da conversão
    -- de InLab_Mapear_Peca (fn_mapear.ms, passo 3): mudança lá vem para cá também.
    local baseAntes = classof o.baseobject
    local convertida = false
    local copiaBase = undefined   -- revisão final: devolvida se a peça não for refeita
    if baseAntes != Editable_Poly do
    (
        local trisAntes = (GetTriMeshFaceCount o)[1]
        local copia = copy o.baseobject
        copiaBase = copia
        local baseOk = InLab_Mapear_ConverterBase o
        if baseOk and (GetTriMeshFaceCount o)[1] != trisAntes do
        (
            InLab_Log (o.name + ": a conversão para Editable_Poly mudou os triângulos de render; base " + baseAntes as string + " devolvida, peça não tocada.") tipo:#err
            baseOk = false
        )
        if not baseOk do
        (
            try ( o.baseobject = copia )
            catch ( InLab_Log (o.name + ": não devolvi a base " + baseAntes as string + " (" + getCurrentException() + "); use o Ctrl+Z.") tipo:#err )
            return undefined
        )
        convertida = true
        InLab_Log (o.name + ": base " + baseAntes as string + " convertida para Editable_Poly (o Desfazer Painéis devolve o UV, não a classe).") tipo:#warn
    )
    -- hotfix 1.3.2: face morta na base travava o Max (InLab_Paineis_Elementos) e o detachFaces
    -- do Unfold3D compacta a cópia e renumera as faces. Tira antes de ler qualquer índice.
    local mortas = InLab_Paineis_TirarMortas o
    if mortas > 0 do InLab_Log (o.name + ": " + mortas as string + " face(s) morta(s) da base tirada(s) (invisíveis; o Ctrl+Z devolve).") tipo:#info
    InLab_PaineisPrep tec:tec grupos:grupos rwfMods:rwfMods baseAntes:baseAntes convertida:convertida copiaBase:copiaBase
)

-- Passos 5 e 6 do Painéis (27/10/2026, dividido de InLab_Paineis_Peca): RWF fora, bitmaps
-- religados, UV avaliado das faces sem painel, registro e gravação do canal 1; o catch restaura.
-- uv = #(uvs, mapa); refeitasCmPorID = #(#(id, cm por tile)...); rodada = nós da rodada.
-- Devolve #(#refeita, MapearRecord) ou #(#pulada, undefined). Não loga o resumo (quem chama loga).
fn InLab_Paineis_Aplicar o prep uv refeitasCmPorID rodada =
(
    local res = #(#pulada, undefined)
    local grupos = prep.grupos, tec = prep.tec, rwfMods = prep.rwfMods, baseAntes = prep.baseAntes
    local po = o.baseobject
    local nf = polyop.getNumFaces po
    local motivo = ""
    -- escala (tiles por unidade) e cm de cada ID de tecido, na ordem de tec
    local cmPorIDp = #(), escPorID = #()
    for k = 1 to tec.count do
    (
        local cmK = 1.0
        for e in refeitasCmPorID where e[1] == tec[k] do cmK = e[2]
        append cmPorIDp cmK
        append escPorID (1.0 / (cmK * (InLab_Paineis_UTil o tec[k])))
    )
    local rwfCanais = #()   -- #(canal, densidade ou undefined)
    for r in rwfMods where r[3] != undefined and r[3] != 1 and r[3] != -1 do
    (
        local k = findItem (for rc in rwfCanais collect rc[1]) r[3]
        local dn = InLab_Mapear_DensRWF o r[1]
        if k == 0 then append rwfCanais #(r[3], dn) else if rwfCanais[k][2] == undefined do rwfCanais[k][2] = dn
    )
    local canaisRWF = for rc in rwfCanais collect rc[1]
    local rebind = #(), rebindEsc = #()   -- bitmap e a escala do ID dele (o 1º ID que o usa)
    for k = 1 to tec.count do
        for b in (InLab_Mapear_Bitmaps (InLab_Mapear_MaterialDoID (InLab_Mapear_Mat o) tec[k])) do
            if (findItem canaisRWF (InLab_Mapear_CanalOriginal b)) > 0 and (findItem rebind b) == 0 do
            ( append rebind b; append rebindEsc escPorID[k] )
    local presos = #()
    for g in grupos where (findItem tec g[1]) == 0 do
        for b in (InLab_Mapear_Bitmaps g[2]) do
        (
            local c = InLab_Mapear_CanalOriginal b
            if (findItem canaisRWF c) > 0 and (findItem presos c) == 0 do
            (
                append presos c
                InLab_Log (o.name + ": o canal " + c as string + " do Real World Fix continua (um ID que não é de tecido lê esse canal).") tipo:#warn
            )
        )
    for b in rebind do
    (
        local c = InLab_Mapear_CanalOriginal b
        if (findItem presos c) == 0 do
        (
            local fora = #()
            for n in (refs.dependentNodes b) do
                if isValidNode n and (InLab_EhGeometria n) and (findItem rodada n) == 0 do append fora n.name
            -- revisão final: com o Ver UV ligado, refs.dependentNodes não vê os nós com as listras
            if InLab_VerUV_NosQueUsam != undefined do
                for n in (InLab_VerUV_NosQueUsam b) do
                    if isValidNode n and (InLab_EhGeometria n) and (findItem rodada n) == 0 and (findItem fora n.name) == 0 do append fora n.name
            if fora.count > 0 do
            (
                InLab_Log (o.name + ": " + b.name + " (canal " + c as string + ") também é usado fora desta rodada (" +
                           (InLab_ListaResumida fora) + "); o bitmap não é religado e o canal do Real World Fix continua.") tipo:#warn
                append presos c
            )
        )
    )
    local tirar = for r in rwfMods where (findItem presos r[3]) == 0 collect r
    local tiraCanal1 = (for r in tirar where r[3] == undefined or r[3] == 1 collect r).count > 0
    -- bitmaps que vão ser religados ao canal 1 (lêem um canal do RWF que sai)
    local religar = #(), religarEsc = #()
    for ib = 1 to rebind.count do
        if (InLab_RWF_CanalBitmap rebind[ib]) != 1 and (findItem presos (InLab_Mapear_CanalOriginal rebind[ib])) == 0 do
        ( append religar rebind[ib]; append religarEsc rebindEsc[ib] )
    local acc = #(uv[1], uv[2])
    local refeitas = #{}
    for e in uv[2] do refeitas[e[1]] = true
    -- revisão final: faces sem painel (vivos) dos IDs cujo bitmap é religado recebem no canal 1
    -- o UV avaliado do canal que o bitmap lia; o tiling vai × (densidade do RWF / escala), então
    -- o UV copiado vai × (escala / densidade do RWF) e a textura do vivo fica do mesmo tamanho
    local copiadas = #{}
    for k = 1 to tec.count while motivo == "" do
    (
        local bk = undefined, ek = undefined
        for b in (InLab_Mapear_Bitmaps (InLab_Mapear_MaterialDoID (InLab_Mapear_Mat o) tec[k])) where bk == undefined do
        (
            local j = findItem religar b
            if j > 0 do ( bk = b; ek = religarEsc[j] )
        )
        if bk != undefined do
        (
            local fs = (InLab_Mapear_FacesDoID o tec[k]) - refeitas - copiadas
            if not fs.isEmpty do
            (
                local cBk = InLab_RWF_CanalBitmap bk
                local av = InLab_Mapear_UVAvaliado o fs canal:cBk
                if av == undefined then
                (
                    InLab_Log (o.name + ": o UV do canal " + cBk as string + " das faces sem painel (vivos) não deu para copiar (topologia do stack diferente da base); peça não tocada.") tipo:#err
                    motivo = "UV avaliado"
                )
                else
                (
                    local kc = findItem canaisRWF cBk
                    local dc = if kc > 0 then rwfCanais[kc][2] else undefined
                    if dc != undefined and dc > 1e-12 do
                    (
                        local fat = ek / dc
                        for i = 1 to av[1].count do av[1][i] = av[1][i] * fat
                    )
                    InLab_Mapear_Juntar acc av
                    copiadas += fs
                )
            )
        )
    )
    if tiraCanal1 and motivo == "" do
    (
        -- faces que não recebem painel (outros IDs, vivos) ficam com o UV avaliado
        local resto = #{1..nf} - refeitas - copiadas
        if not resto.isEmpty do
        (
            local av = InLab_Mapear_UVAvaliado o resto
            if av == undefined then
            (
                InLab_Log (o.name + ": o UV das partes mantidas depende do Real World Fix e não deu para copiá-lo (topologia do stack diferente da base); peça não tocada.") tipo:#err
                motivo = "UV avaliado"
            )
            else InLab_Mapear_Juntar acc av
        )
    )
    if motivo == "" do
    (
        -- 6. registro, RWF fora, bitmaps religados, gravação
        local rec = MapearRecord no:o baseAntes:baseAntes modsTirados:#() bitmapsAntes:#()
        rec.canal1Antes = InLab_Mapear_LerCanal1 o
        rec.graus = for f = 1 to nf collect (polyop.getFaceDeg po f)
        try
        (
            for k = tirar.count to 1 by -1 do
            (
                deleteModifier o tirar[k][2]
                insertItem #(tirar[k][1], tirar[k][2]) rec.modsTirados 1
            )
            for ib = 1 to religar.count do
            (
                local b = religar[ib]
                local c = InLab_RWF_CanalBitmap b
                (
                    local t = InLab_Mapear_Tiling b
                    append rec.bitmapsAntes #(b, c, t.x, t.y)
                    local k = findItem canaisRWF c
                    local dc = if k > 0 then rwfCanais[k][2] else undefined
                    local razao = if dc == undefined then 1.0 else dc / religarEsc[ib]
                    InLab_Mapear_SetCanal b 1
                    InLab_Mapear_SetTiling b (t * razao)
                    InLab_Log (b.name + ": passa a ler o canal 1 (era o " + c as string + ")" +
                               (if abs (razao - 1.0) > 1e-4 then ", tiling × " + (formattedPrint razao format:".3g") else "") + ".") tipo:#info
                )
            )
            if not (InLab_Mapear_Gravar o acc[1] acc[2]) do throw "gravação do canal 1 falhou"
            for k = 1 to tec.count do append rec.cmPorID #(tec[k], cmPorIDp[k])
            res = #(#refeita, rec)
            -- bitmap que ficou no canal do RWF
            for c in presos do
                InLab_Log (o.name + ": o material continua lendo o canal " + c as string + " (Real World Fix mantido nesse canal).") tipo:#warn
        )
        catch
        (
            InLab_Log (o.name + ": Painéis falhou (" + getCurrentException() + "); peça restaurada.") tipo:#err
            try ( InLab_Mapear_Restaurar rec desde:"os Painéis" )
            catch ( InLab_Log (o.name + ": não restaurei a peça (" + getCurrentException() + "); use o Ctrl+Z.") tipo:#err )
        )
    )
    res
)

-- Revisão final (27/10/2026, dividido de InLab_Paineis_Peca): peça não refeita volta à base de antes.
fn InLab_Paineis_DevolverBase o prep =
(
    if prep.convertida do
    (
        local okB = false
        try ( o.baseobject = prep.copiaBase; okB = true )
        catch ( InLab_Log (o.name + ": peça não refeita e não devolvi a base " + prep.baseAntes as string + " (" + getCurrentException() + "); o Ctrl+Z devolve.") tipo:#warn )
        if okB do InLab_Log (o.name + ": peça não refeita; base " + prep.baseAntes as string + " devolvida.") tipo:#info
    )
)

-- revisão final: o nó (ou uma instância dele) tem rodada de Painéis na pilha? O Mapear não
-- refaz peça assim (InLab_Mapear_Peca, fn_mapear.ms).
fn InLab_Paineis_TemPeca no =
(
    local r = false
    if InLab_PilhaPaineis != undefined and isValidNode no do
    (
        local inst = InLab_Instancias no
        for rd in InLab_PilhaPaineis while not r do
            for x in rd while not r do if isValidNode x.no and (findItem inst x.no) > 0 do r = true
    )
    r
)

-- tira da pilha os registros do nó (ou de uma instância dele); rodadas vazias somem. Nº tirado.
-- Revisão final: o Mapear não chama mais (não refaz peça com painéis); fica para uso manual.
fn InLab_Paineis_EsquecerPeca no motivo:"o estado de antes deles foi desfeito com o Mapear" =
(
    local tirados = 0
    if InLab_PilhaPaineis != undefined and isValidNode no do
    (
        local inst = InLab_Instancias no
        for i = InLab_PilhaPaineis.count to 1 by -1 do
        (
            local rd = InLab_PilhaPaineis[i]
            for k = rd.count to 1 by -1 do
                if isValidNode rd[k].no and (findItem inst rd[k].no) > 0 do ( deleteItem rd k; tirados += 1 )
            if rd.count == 0 do deleteItem InLab_PilhaPaineis i
        )
        if tirados > 0 do
            InLab_Log (no.name + ": " + tirados as string + " registro(s) de Painéis descartado(s); " + motivo + ".") tipo:#info
    )
    tirados
)

-- 27/10/2026 (Tarefa 5): registro do Cortar (rec.marcas definido) devolve as marcas de antes;
-- #nenhuma = não havia marca (apaga). Registro do Painéis (marcas undefined) não mexe.
fn InLab_Paineis_VoltarMarcas rec =
(
    if rec.marcas != undefined and isValidNode rec.no and InLab_Cortar_GravarMarcas != undefined do
    (
        if rec.marcas == #nenhuma then InLab_Cortar_ApagarMarcas rec.no
        else InLab_Cortar_GravarMarcas rec.no rec.marcas
    )
)

-- Desfazer Mapear (fix 1): volta os registros de Painéis do nó (ou de uma instância) que ainda
-- estão na pilha, do mais novo para o mais velho, e tira-os da pilha. Quem chama abre o undo.
-- Nº de registros restaurados.
fn InLab_Paineis_RestaurarPeca no =
(
    local n = 0
    if InLab_PilhaPaineis != undefined and isValidNode no do
    (
        local inst = InLab_Instancias no
        local achados = 0
        for i = InLab_PilhaPaineis.count to 1 by -1 do
        (
            local rd = InLab_PilhaPaineis[i]
            for k = rd.count to 1 by -1 do
                if isValidNode rd[k].no and (findItem inst rd[k].no) > 0 do
                (
                    achados += 1
                    try ( if InLab_Mapear_Restaurar rd[k] desde:"os Painéis" do ( n += 1; InLab_Paineis_VoltarMarcas rd[k] ) )
                    catch ( InLab_Log (no.name + ": não desfiz os painéis antes do Mapear (" + getCurrentException() + ").") tipo:#err )
                    deleteItem rd k
                )
            if rd.count == 0 do deleteItem InLab_PilhaPaineis i
        )
        if achados > 0 do
            InLab_Log (no.name + ": " + n as string + " de " + achados as string + " rodada(s) de Painéis desfeita(s) antes do Mapear.") tipo:#info
    )
    n
)

-- Desfazer Painéis: volta a última rodada (tudo:true, todas, da mais nova para a mais velha).
-- Nº de peças restauradas.
fn InLab_DesfazerPaineis tudo:false =
(
    local n = 0
    if InLab_PilhaPaineis.count == 0 then
        InLab_Log "Painéis: nada a desfazer nesta sessão." tipo:#warn
    else
    (
        undo "InLab Desfazer Painéis" on
        (
            local seguir = true
            while seguir and InLab_PilhaPaineis.count > 0 do
            (
                local rd = InLab_PilhaPaineis[InLab_PilhaPaineis.count]
                for i = rd.count to 1 by -1 do
                (
                    local rec = rd[i]
                    if not (isValidNode rec.no) then
                        InLab_Log "Painéis: uma peça registrada não existe mais; pulada no Desfazer." tipo:#warn
                    else
                        try
                        (
                            if InLab_Mapear_Restaurar rec desde:"os Painéis" do
                            (
                                n += 1
                                InLab_Paineis_VoltarMarcas rec
                                InLab_Log (rec.no.name + ": painéis desfeitos.") tipo:#ok
                            )
                        )
                        catch ( InLab_Log (rec.no.name + ": não desfiz os painéis (" + getCurrentException() + ").") tipo:#err )
                )
                deleteItem InLab_PilhaPaineis InLab_PilhaPaineis.count
                seguir = tudo
            )
        )
        InLab_Log ("Painéis desfeitos em " + n as string + " peça(s).")
    )
    n
)
