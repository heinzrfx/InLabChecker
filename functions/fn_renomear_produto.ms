/*
================================================================================
 functions\fn_renomear_produto.ms — renomeação pelo JSON de produto (18/Set)
--------------------------------------------------------------------------------
 Aplica os nomes oficiais do export de nomenclatura da plataforma
 (versao_export "nomenclatura-3D-v2") no produto aberto no Max:
   material ligado a cada parte → material_id          (ex.: ART_P_Base)
   mapas dentro desse material  → material_id_<canal>  (ex.: ART_P_Base_Bump)
   objeto                       → mesh_final escolhido para ele (ver #54 abaixo)
 A LIGAÇÃO parte → material (e objeto → mesh_final) é decidida pelo
 modelador na seção Produto (ui\rollout_main.ms); InLab_Produto_SugerirLigacoes
 e InLab_Produto_SugerirMeshes só pré-preenchem. Este arquivo não tem UI.
 Spec: docs\superpowers\specs\2026-09-18-renomear-produto-design.md

 UNDO: Aplicar roda dentro de `undo on` E guarda os nomes antigos em
 InLab_UltimaRenomeacao, restaurados por InLab_Produto_Reverter — mesmo
 padrão de InLab_ReverterOtimizacao / InLab_ReverterConversao (o undo nativo
 pode não cobrir .name de material/texmap alterado por script).
 O histórico ACUMULA entre aplicações e só é zerado pelo Reverter (bug
 18/Set: zerar a cada Aplicar fazia o Desfazer perder a 1ª aplicação quando
 o modelador trocava a ligação e aplicava de novo).

 `global` antes de cada fn usada fora daqui (ou recursiva): este arquivo
 pode ser carregado de dentro de InLab_RecarregarPlugin() — ver fn_json.ms.

 24/09/2026 (issue #46): `material_id`/`mesh_final` vazio ou null (o export
 usa "" e null — ver InLab_Produto_Texto) renomeava material/objeto para ""
 e mapa para "_Canal". InLab_Produto_ParteValida guarda os dois campos —
 parte inválida é pulada com #warn e nada é renomeado para ela. Nome
 reaproveitável: a renomeação de meshes (#54) usa a mesma função para
 `mesh_final`. Aplicar agora loga cada material e objeto renomeado (não só
 o resumo), e o `catch` de Reverter loga o alvo que sumiu da cena em vez de
 engolir a exceção.

 24/09/2026 (issue #54): objeto só era renomeado "por tabela" — pelo
 material ligado a uma parte. Objeto sem material ligado ou que misturava
 meshes ficava com o nome antigo. Agora (decisão do humano) Aplicar renomeia
 SÓ materiais e mapas, e os objetos saem de InLab_Produto_RenomearMeshes:
 o modelador liga cada objeto a um mesh_final (InLab_Produto_MeshesDoProduto)
 com pré-ligação por InLab_Produto_SugerirMeshes (nome já igual → material
 ligado → semelhança de nome). Os dois usam o mesmo histórico acumulado, e
 InLab_Produto_Reverter desfaz os dois.

 02/10/2026 (export v2, respostas da Bianca — docs\superpowers\specs\
 2026-10-02-json-v2-respostas-bianca.md):
   - `so3d:true` (Porta_1, Tampa_1...) vem com `tipo:""` de propósito: o aviso
     "Classificar a parte na plataforma" era falso alarme e não sai mais.
   - "|" no `mesh_final` = a parte está em mais de uma mesh. O nome é dividido
     (InLab_Produto_MeshesDaParte); antes "A|B" entrava como um nome só.
   - parte-mãe de subparte so3d (Porta) vem sem `mesh_final`: a geometria
     está nas subpartes. Sai #info em vez de #warn.
   - `ok_3d:false`: avisa e pula (InLab_Produto_Liberado3D) — Aplicar e
     RenomearMeshes não renomeiam nada. Export sem o campo conta como liberado.
   - sugestão de família: ver o bloco abaixo (substituído no mesmo dia).

 02/10/2026 (respostas v3 da Bianca, mesmo spec): o v1 do plugin trabalha só
 com produto ESTÁTICO; animado entra tratado como estático e os campos de
 animação do JSON ficam, sem uso.
   - família é estrutural e sai da classe (tabela da equipe); saiu o palpite
     de família animada por nome/porta/gaveta, inclusive o "mesa giratória →
     rotacao" que tinha entrado de manhã.
   - o objeto da subparte so3d carrega o material da parte-MÃE: a subparte
     sai da lista de materiais (InLab_Produto_PartesDeMaterial). `ligacoes`
     passa a ser paralelo a essa lista, não a todas as partes.

 02/10/2026 (issue #93, cópias de bloco_3d): ver o bloco "CÓPIAS DE bloco_3d".
 O bloqueio de ok_3d passa por InLab_Produto_MotivoBloqueio, que também pula
 a cópia cuja base não está liberada. Voltar do nome da cópia para o do
 master NÃO é pelo Desfazer (ele desfaz a sessão inteira, inclusive a
 renomeação do master): é escolher o master de novo e "Renomear objetos".
================================================================================
*/

global InLab_UltimaRenomeacao = #() -- pares #(alvo, nomeAntigo) desde o último Reverter

--------------------------------------------------------------------------------
-- DADOS DO JSON
--------------------------------------------------------------------------------

-- Valor de texto de um campo, "" se ausente/null (o export usa "" e null).
global InLab_Produto_Texto
fn InLab_Produto_Texto obj chave =
(
    local v = InLab_JSON_Obter obj chave
    if v == undefined then "" else (v as string)
)

-- Produtos do export. #() se o JSON não tiver "produtos" (ex.: foi importado
-- o nomenclatura_projeto.json, que é o arquivo de trabalho do app).
global InLab_Produto_Lista
fn InLab_Produto_Lista dados =
(
    local produtos = InLab_JSON_Obter dados "produtos"
    if isKindOf produtos Array then produtos else #()
)

-- Parte com `campo` vazio ou null é inválida p/ renomear (o export usa ""
-- e null p/ campo ausente — ver InLab_Produto_Texto acima). Reaproveitada
-- por material_id e mesh_final aqui, e pela renomeação de meshes (#54).
global InLab_Produto_ParteValida
fn InLab_Produto_ParteValida parte campo =
(
    (InLab_Produto_Texto parte campo) != ""
)

-- Campo booleano do export (true/false do JSON; "true" em texto também vale).
global InLab_Produto_Booleano
fn InLab_Produto_Booleano obj chave =
(
    (toLower (InLab_Produto_Texto obj chave)) == "true"
)

-- 02/10/2026: nomes de mesh da parte. "|" no mesh_final = a parte está em
-- mais de um grupo de mesh (ex.: "00124600|00124600_Prato_Giratoria").
-- #() se o campo vier vazio ou null.
global InLab_Produto_MeshesDaParte
fn InLab_Produto_MeshesDaParte parte =
(
    local nomes = #()
    for n in (filterString (InLab_Produto_Texto parte "mesh_final") "|") do
    (
        local limpo = trimLeft (trimRight n)
        if limpo != "" do append nomes limpo
    )
    nomes
)

-- 02/10/2026: a parte é mãe de alguma subparte só de 3D (so3d com
-- subparte_de = nome dela)? A mãe vem sem mesh_final de propósito.
global InLab_Produto_EhMaeDeSubparte
fn InLab_Produto_EhMaeDeSubparte produto parte =
(
    local partes = if produto == undefined then undefined else InLab_JSON_Obter produto "partes"
    local nome = InLab_Produto_Texto parte "nome_parte"
    local ehMae = false
    if nome != "" and isKindOf partes Array do
        for p in partes where not ehMae and (InLab_Produto_Booleano p "so3d") and (InLab_Produto_Texto p "subparte_de") == nome do ehMae = true
    ehMae
)

-- 02/10/2026: false só quando o export traz ok_3d = false (produto ainda não
-- liberado para o 3D na plataforma). Export sem o campo conta como liberado.
global InLab_Produto_Liberado3D
fn InLab_Produto_Liberado3D produto =
(
    produto == undefined or (toLower (InLab_Produto_Texto produto "ok_3d")) != "false"
)

-- 02/10/2026 (v3): partes que recebem material na seção Produto — todas menos
-- as subpartes só de 3D (so3d), cujo objeto usa o material da parte-mãe.
-- `ligacoes` (Aplicar, SugerirMeshes, UI) é paralelo a ESTA lista.
global InLab_Produto_PartesDeMaterial
fn InLab_Produto_PartesDeMaterial produto =
(
    local partes = if produto == undefined then undefined else InLab_JSON_Obter produto "partes"
    if isKindOf partes Array then (for p in partes where not (InLab_Produto_Booleano p "so3d") collect p) else #()
)

-- Índice (1-based) do produto com esse cod_est; 0 se não houver.
global InLab_Produto_IndicePorCodigo
fn InLab_Produto_IndicePorCodigo produtos cod =
(
    local idx = 0
    for i = 1 to produtos.count where idx == 0 and (InLab_Produto_Texto produtos[i] "cod_est") == cod do idx = i
    idx
)

--------------------------------------------------------------------------------
-- CÓPIAS DE bloco_3d (02/10/2026, issue #93)
--------------------------------------------------------------------------------
-- bloco_3d.papel = "copia" + duplicar_renomear: a cópia não tem .max próprio.
-- Ela sai do .max do master (base_codest) com a mesh renomeada para o cod_est
-- da cópia e os MESMOS material_id (Bianca, respostas v3) — copiar o GLB não
-- basta, porque a mesh de dentro muda de nome. O plugin já faz isso com o
-- que existe: cópia escolhida no dropdown → "Renomear objetos" → exportar.
-- Aqui ficam só a leitura do bloco, o bloqueio (a cópia segue a base) e os
-- avisos do log.

-- cod_est do master se o produto é cópia de OUTRO produto; "" se não é.
global InLab_Produto_BaseDaCopia
fn InLab_Produto_BaseDaCopia produto =
(
    local bloco = if produto == undefined then undefined else InLab_JSON_Obter produto "bloco_3d"
    local base = InLab_Produto_Texto bloco "base_codest"
    if (toLower (InLab_Produto_Texto bloco "papel")) == "copia" and base != "" and base != (InLab_Produto_Texto produto "cod_est") then base else ""
)

-- Produtos da lista que são cópia do cod_est dado.
global InLab_Produto_CopiasDe
fn InLab_Produto_CopiasDe produtos cod =
(
    if cod == "" then #() else (for p in produtos where (InLab_Produto_BaseDaCopia p) == cod collect p)
)

-- "" se o produto pode ser renomeado; senão o motivo do bloqueio: o próprio
-- produto com ok_3d = false, ou cópia cuja base está com ok_3d = false (sem
-- master exportado não há o que copiar). Base fora da lista não bloqueia —
-- não dá para saber — e InLab_Produto_AvisosDeBloco avisa.
global InLab_Produto_MotivoBloqueio
fn InLab_Produto_MotivoBloqueio produtos produto =
(
    local motivo = ""
    if produto != undefined do
    (
        local cod = InLab_Produto_Texto produto "cod_est"
        if not (InLab_Produto_Liberado3D produto) then
            motivo = "Produto " + cod + " está com 3D não liberado na plataforma (ok_3d = false)"
        else
        (
            local base = InLab_Produto_BaseDaCopia produto
            local idx = if base == "" then 0 else InLab_Produto_IndicePorCodigo produtos base
            if idx > 0 and not (InLab_Produto_Liberado3D produtos[idx]) do
                motivo = "Produto " + cod + " é cópia do " + base + ", que está com 3D não liberado na plataforma (ok_3d = false): a cópia segue a base"
        )
    )
    motivo
)

-- Log da escolha do produto: bloqueio, de qual master a cópia sai e quais
-- cópias saem deste master.
global InLab_Produto_AvisosDeBloco
fn InLab_Produto_AvisosDeBloco produtos produto =
(
    if produto != undefined do
    (
        local cod = InLab_Produto_Texto produto "cod_est"
        local motivo = InLab_Produto_MotivoBloqueio produtos produto
        if motivo != "" do
            InLab_Log (motivo + " — os botões de renomear vão pular este produto.") tipo:#warn
        local base = InLab_Produto_BaseDaCopia produto
        if base != "" do
        (
            if (InLab_Produto_IndicePorCodigo produtos base) == 0 do
                InLab_Log ("Produto " + cod + " é cópia do " + base + ", que não está neste arquivo de produtos — confira se o master já foi exportado.") tipo:#warn
            if motivo == "" do
                InLab_Log ("Produto " + cod + " é cópia do " + base + ": sai do .max do master, com os mesmos materiais. Use 'Renomear objetos' (o objeto passa a se chamar " + cod +
                           ") e exporte. Para voltar, escolha o " + base + " em Produto e use 'Renomear objetos' de novo.") tipo:#info
        )
        local copias = InLab_Produto_CopiasDe produtos cod
        if copias.count > 0 do
        (
            local lista = ""
            for i = 1 to copias.count do lista += (if i > 1 then ", " else "") + (InLab_Produto_Texto copias[i] "cod_est")
            InLab_Log ("Produto " + cod + " é base de " + copias.count as string + " cópia(s): " + lista +
                       ". Depois de exportar este, escolha cada cópia em Produto, use 'Renomear objetos' e exporte de novo.") tipo:#info
        )
    )
)

-- Rótulo da parte na UI. O qualificador entra porque o nome sozinho repete
-- (ex.: 07112075 tem "Encosto" Externo e Interno).
global InLab_Produto_Rotulo
fn InLab_Produto_Rotulo parte =
(
    local nome = InLab_Produto_Texto parte "nome_parte"
    local qual = InLab_Produto_Texto parte "qualificador"
    if qual == "" then nome else (nome + " (" + qual + ")")
)

--------------------------------------------------------------------------------
-- TEXTO
--------------------------------------------------------------------------------

global INLAB_REN_ACENTOS = #(#("áàâãäÁÀÂÃÄ", "a"), #("éèêëÉÈÊË", "e"), #("íìîïÍÌÎÏ", "i"),
                             #("óòôõöÓÒÔÕÖ", "o"), #("úùûüÚÙÛÜ", "u"), #("çÇ", "c"))

-- Minúsculo e sem acento — só para COMPARAR nomes na sugestão.
global InLab_Produto_Normalizar
fn InLab_Produto_Normalizar s =
(
    local saida = ""
    for i = 1 to s.count do
    (
        local c = s[i]
        for par in INLAB_REN_ACENTOS where (findString par[1] c) != undefined do c = par[2]
        saida += c
    )
    toLower saida
)

-- Nome de slot do Max ("Diffuse Color") → sufixo de mapa ("DiffuseColor").
global InLab_Produto_Canal
fn InLab_Produto_Canal nomeSlot =
(
    local permitidos = "abcdefghijklmnopqrstuvwxyz0123456789" -- findString ignora caixa
    local saida = ""
    for i = 1 to nomeSlot.count where (findString permitidos nomeSlot[i]) != undefined do saida += nomeSlot[i]
    if saida == "" then "Mapa" else saida
)

--------------------------------------------------------------------------------
-- CENA: materiais e mapas
--------------------------------------------------------------------------------

-- Materiais únicos dos objetos. De um Multi/Sub-Object entram os
-- submateriais — o multi em si não é acabamento de nenhuma parte.
global InLab_Produto_MateriaisDaSelecao
fn InLab_Produto_MateriaisDaSelecao objs =
(
    local mtls = #()
    for o in objs where o.material != undefined do
    (
        local m = o.material
        if classOf m == Multimaterial then
            for s in m.materialList where s != undefined do appendIfUnique mtls s
        else appendIfUnique mtls m
    )
    mtls
)

-- O objeto usa o material direto ou como submaterial do seu Multi/Sub.
global InLab_Produto_ObjUsaMaterial
fn InLab_Produto_ObjUsaMaterial o mtl =
(
    local m = o.material
    if m == mtl then true
    else if m != undefined and classOf m == Multimaterial then (findItem m.materialList mtl) > 0
    else false
)

-- O texmap e todos os que estão dentro dele (ex.: bitmap dentro de Normal_Bump).
global InLab_Produto_ColetarMapas
fn InLab_Produto_ColetarMapas tm acum =
(
    append acum tm
    for i = 1 to (getNumSubTexmaps tm) do
    (
        local s = getSubTexmap tm i
        if s != undefined do InLab_Produto_ColetarMapas s acum
    )
    acum
)

-- #(canal, texmap) para cada mapa do material. Mapas aninhados herdam o
-- canal do slot de topo. Genérico: não depende de nomes de propriedade de
-- Corona/glTF, só da interface de sub-texmaps que todo material expõe.
global InLab_Produto_MapasDoMaterial
fn InLab_Produto_MapasDoMaterial mtl =
(
    local itens = #()
    for i = 1 to (getNumSubTexmaps mtl) do
    (
        local tm = getSubTexmap mtl i
        if tm != undefined do
        (
            local canal = InLab_Produto_Canal (getSubTexmapSlotName mtl i)
            for m in (InLab_Produto_ColetarMapas tm #()) do append itens #(canal, m)
        )
    )
    itens
)

--------------------------------------------------------------------------------
-- SUGESTÃO DE LIGAÇÃO
--------------------------------------------------------------------------------

-- Array paralelo a `partes`: material sugerido ou undefined. Um material
-- nunca é sugerido para duas partes.
--   1º material que já se chama exatamente material_id (plugin já rodou);
--   2º nome normalizado contém nome_parte (e o qualificador, se houver) —
--      partes COM qualificador primeiro, pra "Encosto" sem qualificador não
--      pegar o material de "Encosto (Externo)".
global InLab_Produto_SugerirLigacoes
fn InLab_Produto_SugerirLigacoes partes mtls =
(
    local ligacoes = for p in partes collect undefined
    local usados = #()
    for i = 1 to partes.count do
    (
        local mid = InLab_Produto_Texto partes[i] "material_id"
        for m in mtls where ligacoes[i] == undefined and m.name == mid and (findItem usados m) == 0 do
        (
            ligacoes[i] = m
            append usados m
        )
    )
    for passo in #(#comQual, #semQual) do
        for i = 1 to partes.count where ligacoes[i] == undefined do
        (
            local nome = InLab_Produto_Normalizar (InLab_Produto_Texto partes[i] "nome_parte")
            local qual = InLab_Produto_Normalizar (InLab_Produto_Texto partes[i] "qualificador")
            if nome != "" and ((passo == #comQual) == (qual != "")) do
                for m in mtls where ligacoes[i] == undefined and (findItem usados m) == 0 do
                (
                    local nm = InLab_Produto_Normalizar m.name
                    if (findString nm nome) != undefined and (qual == "" or (findString nm qual) != undefined) do
                    (
                        ligacoes[i] = m
                        append usados m
                    )
                )
        )
    ligacoes
)

--------------------------------------------------------------------------------
-- SUGESTÃO DE FAMÍLIA (23/09/2026 · tabela da equipe em 02/10/2026)
--------------------------------------------------------------------------------
-- O export não traz a família do plugin: "familia" no JSON é a LINHA comercial
-- (ex.: "RIZZI"). A sugestão sai da "classe" e é só um PRÉ-PREENCHIMENTO do
-- dropdown Família — o modelador confirma ou troca.
-- 02/10/2026 (Bianca, respostas v3): família é ESTRUTURAL (4 famílias) e não
-- tem nada de animação. O v1 do plugin trata produto animado como estático,
-- então saiu o palpite por movimento (giratória/porta/gaveta → família
-- animada). Os campos de animação do JSON continuam lá, só não são usados.
-- Tabela da equipe:
global INLAB_FAMILIA_POR_CLASSE = #(
    #("corpo_unico",        #("mesa de centro", "mesa de jantar", "mesa lateral", "mesa de jogo",
                              "aparador", "banco", "puff")),
    #("pernas_tampo",       #("escrivaninha", "mesa bar", "mesa de cha", "mesa bistro", "mesa de bistro")),
    #("estrutura_estofado", #("cadeira", "poltrona", "chaise longue")),
    #("estrutura_modular",  #("estante", "carro bar"))
)
-- Classes que a equipe ainda NÃO definiu (Sofá e Buffet "a definir"; as outras
-- não entraram na tabela dela): fica o palpite antigo, com "provisório" no
-- motivo. Vanity Desk segue sem sugestão.
global INLAB_FAMILIA_PROVISORIA = #(
    #("pernas_tampo",       #("mesa componivel", "coluna de jantar")),
    #("estrutura_modular",  #("modulo")),
    #("estrutura_estofado", #("sofa", "cabeceira", "longarina", "cama", "bicama")),
    #("corpo_unico",        #("buffet", "mesa de cabeceira", "banqueta"))
)

-- true se alguma parte do produto tem o campo booleano `campo` ligado e, se
-- `trecho` vier, o nome_parte (sem acento, minúsculo) contém `trecho`.
global InLab_Produto_AlgumaParte
fn InLab_Produto_AlgumaParte produto campo trecho:"" =
(
    local partes = InLab_JSON_Obter produto "partes"
    local achou = false
    if isKindOf partes Array do
        for p in partes where not achou and (InLab_Produto_Booleano p campo) do
            if trecho == "" or (findString (InLab_Produto_Normalizar (InLab_Produto_Texto p "nome_parte")) trecho) != undefined do achou = true
    achou
)

-- #(nomeFamilia, motivo). nomeFamilia = "" quando não dá para sugerir.
-- As duas classes com duas famílias na tabela da equipe saem do dado:
--   Aparador: Pernas + Tampo se o tampo é acessório (parte "Tampo" com
--             acessorio = true); senão Corpo Único.
--   Banco / Puff: Estrutura + Estofado se alguma parte é tecido; senão
--             Corpo Único.
global InLab_Produto_SugerirFamilia
fn InLab_Produto_SugerirFamilia produto =
(
    local classe = InLab_Produto_Normalizar (InLab_Produto_Texto produto "classe")
    local sufixo = if InLab_Produto_Booleano produto "animacao" then " · animado: entra como estático nesta versão" else ""
    if classe == "aparador" and (InLab_Produto_AlgumaParte produto "acessorio" trecho:"tampo") then
        #("pernas_tampo", "aparador com tampo acessório" + sufixo)
    else if (classe == "banco" or classe == "puff") and (InLab_Produto_AlgumaParte produto "tecido") then
        #("estrutura_estofado", classe + " com parte em tecido" + sufixo)
    else
    (
        local fam = ""
        local provisoria = false
        for par in INLAB_FAMILIA_POR_CLASSE where fam == "" and (findItem par[2] classe) > 0 do fam = par[1]
        if fam == "" do
            for par in INLAB_FAMILIA_PROVISORIA where fam == "" and (findItem par[2] classe) > 0 do ( fam = par[1] ; provisoria = true )
        if fam != "" then #(fam, "classe '" + classe + "'" + (if provisoria then ", provisório: a equipe ainda não definiu esta classe" else "") + sufixo)
        else #("", (if classe == "" then "produto sem classe" else "classe '" + classe + "' fora da tabela"))
    )
)

--------------------------------------------------------------------------------
-- APLICAR / REVERTER
--------------------------------------------------------------------------------

-- Renomeia guardando o nome antigo para InLab_Produto_Reverter.
global InLab_Produto_Renomear
fn InLab_Produto_Renomear alvo novoNome =
(
    if alvo.name != novoNome do
    (
        append InLab_UltimaRenomeacao #(alvo, alvo.name)
        alvo.name = novoNome
    )
)

-- ligacoes: paralelo a InLab_Produto_PartesDeMaterial (material ou undefined).
-- Renomeia só materiais e mapas (24/09/2026, #54): objetos são renomeados
-- por InLab_Produto_RenomearMeshes. Devolve false (e não renomeia NADA) se
-- um material estiver ligado a mais de uma parte. produtos: (opcional) a
-- lista do export, para o bloqueio de cópia cuja base não está liberada (#93).
global InLab_Produto_Aplicar
fn InLab_Produto_Aplicar produto ligacoes produtos:#() =
(
    local motivo = InLab_Produto_MotivoBloqueio produtos produto
    local partes = InLab_Produto_PartesDeMaterial produto

    local conflito = false
    for i = 1 to partes.count where ligacoes[i] != undefined do
        for j = (i + 1) to partes.count where ligacoes[j] == ligacoes[i] do
        (
            conflito = true
            InLab_Log ("Material '" + ligacoes[i].name + "' ligado a duas partes: " +
                       (InLab_Produto_Rotulo partes[i]) + " e " + (InLab_Produto_Rotulo partes[j]) + ".") tipo:#err
        )

    if motivo != "" then
    (
        InLab_Log (motivo + " — pulado, nada foi renomeado.") tipo:#warn
        false
    )
    else if conflito then
    (
        InLab_Log "Nada foi renomeado — cada material só pode ter um nome. Corrija as ligações e aplique de novo." tipo:#err
        false
    )
    else
    (
        local nMat = 0, nMap = 0, nAviso = 0
        local mapasFeitos = #()
        undo "InLab: Renomear pelo JSON" on
        (
            for i = 1 to partes.count do
            (
                local rot = InLab_Produto_Rotulo partes[i]
                local mid = InLab_Produto_Texto partes[i] "material_id"
                local mtl = ligacoes[i]
                if mtl == undefined then
                (
                    InLab_Log ("Parte '" + rot + "' sem material ligado — pulada.") tipo:#warn
                    nAviso += 1
                )
                else if not (InLab_Produto_ParteValida partes[i] "material_id") then
                (
                    InLab_Log ("Parte '" + rot + "' sem material_id no JSON — material não renomeado.") tipo:#warn
                    nAviso += 1
                )
                else
                (
                    -- (subparte so3d, que vem sem tipo de propósito, nem chega aqui: PartesDeMaterial)
                    if (InLab_Produto_Texto partes[i] "tipo") == "" do
                    (
                        InLab_Log ("Parte '" + rot + "' sem tipo no JSON — nome provisório '" + mid + "'. Classificar a parte na plataforma.") tipo:#warn
                        nAviso += 1
                    )
                    local nomeAntigoMtl = mtl.name
                    InLab_Produto_Renomear mtl mid
                    InLab_Log (mid + ": material renomeado — era '" + nomeAntigoMtl + "', parte '" + rot + "'.") tipo:#ok
                    nMat += 1
                    local bases = #()
                    local contagens = #()
                    for item in (InLab_Produto_MapasDoMaterial mtl) do
                    (
                        local tm = item[2]
                        if (findItem mapasFeitos tm) > 0 then
                        (
                            InLab_Log ("Mapa '" + tm.name + "' é usado em mais de um lugar — mantido o primeiro nome.") tipo:#warn
                            nAviso += 1
                        )
                        else
                        (
                            local base = mid + "_" + item[1]
                            local k = findItem bases base
                            if k == 0 then
                            (
                                append bases base
                                append contagens 1
                                k = bases.count
                            )
                            else contagens[k] += 1
                            InLab_Produto_Renomear tm (if contagens[k] == 1 then base else (base + "_" + contagens[k] as string))
                            append mapasFeitos tm
                            nMap += 1
                        )
                    )
                )
            )
        )
        InLab_Log ("Renomeação: " + nMat as string + " material(is), " + nMap as string + " mapa(s) · " +
                   nAviso as string + " aviso(s). Objetos: use 'Renomear objetos'.") tipo:#ok
        true
    )
)

--------------------------------------------------------------------------------
-- MESHES (24/09/2026, issue #54)
--------------------------------------------------------------------------------
-- Função separada do Aplicar: o modelador liga cada objeto a um mesh_final
-- do produto, sem depender dos materiais. Mesmo histórico acumulado
-- (InLab_UltimaRenomeacao) — o Desfazer volta os dois.

-- mesh_final distintos e válidos do produto, na ordem das partes. Parte com
-- mesh_final vazio/null fica de fora (InLab_Produto_ParteValida, #46) —
-- avisar:true loga cada uma (#info se for parte-mãe de subparte so3d, que
-- vem sem mesh de propósito; #warn nas demais). 02/10/2026: "|" divide.
global InLab_Produto_MeshesDoProduto
fn InLab_Produto_MeshesDoProduto produto avisar:false =
(
    local partes = if produto == undefined then undefined else InLab_JSON_Obter produto "partes"
    local meshes = #()
    if isKindOf partes Array do
        for p in partes do
        (
            local daParte = InLab_Produto_MeshesDaParte p
            if daParte.count > 0 then
                for n in daParte do appendIfUnique meshes n
            else if avisar and (InLab_Produto_EhMaeDeSubparte produto p) then
                InLab_Log ("Parte '" + (InLab_Produto_Rotulo p) + "' não tem mesh própria — a geometria está nas subpartes.") tipo:#info
            else if avisar do
                InLab_Log ("Parte '" + (InLab_Produto_Rotulo p) + "' sem mesh_final no JSON — não entra na lista de nomes de objeto.") tipo:#warn
        )
    meshes
)

-- true se o nome (normalizado) do objeto lembra o mesh_final: algum trecho
-- do mesh_final (separado por _ - espaço ponto) com 4+ caracteres, fora o
-- prefixo "art", aparece no nome do objeto — também sem o "s" final
-- ("obj_gaveta_01" ↔ "ART_C_Gavetas", "05111083_corpo" ↔ "05111083").
global InLab_Produto_NomeLembraMesh
fn InLab_Produto_NomeLembraMesh nomeObj mesh =
(
    local nObj = InLab_Produto_Normalizar nomeObj
    local achou = false
    for t in (filterString (InLab_Produto_Normalizar mesh) "_- .") where not achou and t.count >= 4 and t != "art" do
    (
        if (findString nObj t) != undefined then achou = true
        else if t[t.count] == "s" and (findString nObj (substring t 1 (t.count - 1))) != undefined do achou = true
    )
    achou
)

-- Array paralelo a `objs`: mesh_final sugerido ou "" (sem sugestão).
--   1º o objeto já se chama exatamente um mesh_final (plugin já rodou);
--   2º pelo material ligado: o objeto usa materiais de partes com UM só
--      mesh_final (a lógica que o Aplicar usava até 24/09/2026);
--   3º por semelhança de nome (InLab_Produto_NomeLembraMesh);
--   4º (02/10/2026) o produto tem UM nome de objeto só: é esse. Nos assets
--      reais do piloto os nomes são genéricos (Cylinder002, Shape019) e os
--      três passos acima não ligavam nada; 5 de 6 produtos tinham um nome só.
-- ligacoes pode ser #() (materiais não lidos): aí só 1º e 3º.
global InLab_Produto_SugerirMeshes
fn InLab_Produto_SugerirMeshes produto ligacoes objs =
(
    local meshes = InLab_Produto_MeshesDoProduto produto
    local partes = InLab_Produto_PartesDeMaterial produto -- paralelo a ligacoes
    for o in objs collect
    (
        local sug = ""
        if isValidNode o do
        (
            if (findItem meshes o.name) > 0 then sug = o.name
            else
            (
                local porMat = #()
                for i = 1 to partes.count where i <= ligacoes.count and ligacoes[i] != undefined and
                    (InLab_Produto_ObjUsaMaterial o ligacoes[i]) do
                    for n in (InLab_Produto_MeshesDaParte partes[i]) do appendIfUnique porMat n
                if porMat.count == 1 then sug = porMat[1]
                else
                    for m in meshes where sug == "" and (InLab_Produto_NomeLembraMesh o.name m) do sug = m
                if sug == "" and meshes.count == 1 do sug = meshes[1]
            )
        )
        sug
    )
)

-- nomes: paralelo a `objs` (mesh_final escolhido, ou "" / undefined = não
-- renomear). Renomeia guardando no histórico do Desfazer. Devolve o número
-- de objetos renomeados. produto: / produtos: (opcionais) produto bloqueado
-- (ok_3d = false, ou cópia de base não liberada — InLab_Produto_MotivoBloqueio)
-- → avisa e não renomeia nada (02/10/2026).
global InLab_Produto_RenomearMeshes
fn InLab_Produto_RenomearMeshes objs nomes produto:undefined produtos:#() =
(
    local nObj = 0, nAviso = 0
    local motivo = InLab_Produto_MotivoBloqueio produtos produto
    if motivo != "" then InLab_Log (motivo + " — pulado, nada foi renomeado.") tipo:#warn
    else
    (
    undo "InLab: Renomear meshes" on
    (
        for i = 1 to objs.count do
        (
            local o = objs[i]
            local nome = if i <= nomes.count and nomes[i] != undefined then nomes[i] as string else ""
            if not (isValidNode o) then
            (
                InLab_Log "Objeto lido não existe mais na cena — pulado." tipo:#warn
                nAviso += 1
            )
            else if nome == "" then
            (
                InLab_Log ("Objeto '" + o.name + "' sem nome escolhido — não renomeado.") tipo:#warn
                nAviso += 1
            )
            else if o.name == nome then
                InLab_Log (nome + ": objeto já tem esse nome.") tipo:#info
            else
            (
                local nomeAntigo = o.name
                InLab_Produto_Renomear o nome
                InLab_Log (nome + ": objeto renomeado — era '" + nomeAntigo + "'.") tipo:#ok
                nObj += 1
            )
        )
    )
    InLab_Log ("Renomear objetos: " + nObj as string + " objeto(s) renomeado(s) · " + nAviso as string + " aviso(s).") tipo:#ok
    )
    nObj
)

global InLab_Produto_Reverter
fn InLab_Produto_Reverter =
(
    if InLab_UltimaRenomeacao.count == 0 then
        InLab_Log "Nenhuma renomeação para desfazer." tipo:#warn
    else
    (
        local n = 0
        -- ordem inversa: se o mesmo alvo mudou duas vezes, volta ao nome original
        for i = InLab_UltimaRenomeacao.count to 1 by -1 do
        (
            local par = InLab_UltimaRenomeacao[i]
            try ( par[1].name = par[2]; n += 1 )
            catch ( InLab_Log ("Reverter: alvo de '" + par[2] + "' não existe mais na cena — pulado.") tipo:#warn )
        )
        InLab_UltimaRenomeacao = #()
        InLab_Log ("Nomes revertidos: " + n as string + ".") tipo:#ok
    )
)
