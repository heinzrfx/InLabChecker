/*
================================================================================
 core\utils.ms
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Helpers genéricos usados pelas funções de preparação (Fases 1–3) e pelas
 verificações (Fase 4). Nenhuma função aqui altera a cena — são todas de
 leitura/consulta.

 Conteúdo:
   - seleção segura de objetos
   - filtro de geometria válida
   - deduplicação por instância (stack compartilhado)
   - contagem de polígonos (objeto e conjunto)
   - tamanho de arquivo em MB (base para V-01/V-02)
   - unidade do sistema (base para V-19)
   - formatadores para o log

 24/09/2026 (issue #42): `InLab_InstanciasDoNo`/`InLab_DeduplicarInstancias` —
 helper de deduplicação por instância, para laços que aplicam modificador
 (stack compartilhado: aplicar em cada instância empilha o modificador uma vez
 por nó) ou medem por peça única. Mesma técnica de `InLab_Instancias`
 (functions\fn_autouv.ms: InstanceMgr.GetInstances), mas mora aqui porque
 fn_prooptimizer.ms e fn_otim_fino.ms (issue #62) carregam ANTES de
 fn_autouv.ms no manifesto (INLAB_MODULOS, InLabChecker.ms) — usar
 InLab_Instancias dali exigiria pré-declarar o global e criaria uma
 dependência "carrega antes, mas usa depois". core\utils.ms carrega primeiro
 que tudo isso, então os dois convivem sem se atropelar. Consumido por
 functions\fn_prooptimizer.ms (InLab_ProOptimizer) e functions\fn_otim_fino.ms
 (InLab_OtimFino_Calcular/_Aplicar, issue #62).
================================================================================
*/

--------------------------------------------------------------------------------
-- SELEÇÃO E GEOMETRIA
--------------------------------------------------------------------------------

-- Retorna a seleção atual como array. Se não houver nada selecionado,
-- registra um aviso no log e retorna array vazio (nunca undefined —
-- o chamador pode iterar com segurança sem checar nil).
fn InLab_SelecaoValida =
(
    if selection.count == 0 then
    (
        InLab_Log "Nenhum objeto selecionado." tipo:#warn
        #()
    )
    else selection as array
)

-- true se o nó é geometria renderizável (exclui targets de câmera/luz,
-- helpers, shapes não renderizáveis etc.). Usado como filtro antes de
-- contagens de polígono e das verificações de malha.
fn InLab_EhGeometria obj =
(
    superclassof obj == GeometryClass and not (isKindOf obj TargetObject)
)

-- Conta os polígonos de UM objeto. getPolygonCount retorna #(faces, verts);
-- usamos o índice [1] (faces). Objetos não-geométricos contam 0.
fn InLab_ContarPoligonosObj obj =
(
    if InLab_EhGeometria obj then (getPolygonCount obj)[1]
    else 0
)

-- Soma os polígonos de um array de objetos (ex.: a seleção, ou a cena
-- inteira via "geometry as array"). Base para V-03/V-04.
fn InLab_ContarPoligonos objs =
(
    local total = 0
    for o in objs do total += InLab_ContarPoligonosObj o
    total
)

--------------------------------------------------------------------------------
-- INSTÂNCIAS (issue #42) — ver nota no cabeçalho sobre por que não é
-- InLab_Instancias de fn_autouv.ms.
--------------------------------------------------------------------------------

-- Nós que compartilham o stack com "o" (inclui o próprio "o").
fn InLab_InstanciasDoNo o =
(
    local inst = #()
    InstanceMgr.GetInstances o &inst
    if inst.count == 0 do inst = #(o)
    inst
)

-- Um representante por grupo de instâncias dentro de "objs" (mesmo stack
-- compartilhado), na ordem de entrada. "no" é o 1º nó do grupo que aparece em
-- objs; "instancias" é o array completo (InLab_InstanciasDoNo), pra quem
-- chama logar quantas vieram junto. Structs em vez de 2 arrays paralelos:
-- quem usa só "no" (laço que aplica 1x por stack) ignora "instancias".
struct InLab_GrupoInstancias (no, instancias)
fn InLab_DeduplicarInstancias objs =
(
    local vistos = #()
    local grupos = #()
    for o in objs where findItem vistos o == 0 do
    (
        local inst = InLab_InstanciasDoNo o
        append grupos (InLab_GrupoInstancias no:o instancias:inst)
        join vistos inst
    )
    grupos
)

--------------------------------------------------------------------------------
-- ARQUIVOS E UNIDADES
--------------------------------------------------------------------------------

-- Tamanho de um arquivo em MB (float). Retorna undefined se o arquivo não
-- existir. Base para V-01 (.max) e V-02 (.skp).
fn InLab_TamanhoArquivoMB caminho =
(
    if caminho != undefined and caminho != "" and doesFileExist caminho then
        (getFileSize caminho) / 1048576.0
    else undefined
)

-- Tamanho da cena atual em MB. Retorna undefined se a cena nunca foi salva —
-- caso em que V-01 deverá pedir um save antes de rodar.
fn InLab_TamanhoCenaMB =
(
    InLab_TamanhoArquivoMB (maxFilePath + maxFileName)
)

-- Unidade do sistema (units.SystemType → #Millimeters, #Centimeters, #Meters,
-- #Inches...). Base para V-19. A regra de qual unidade é a correta fica na
-- verificação, não aqui.
fn InLab_UnidadeSistema =
(
    units.SystemType
)

--------------------------------------------------------------------------------
-- FORMATADORES (apenas apresentação no log/relatório)
--------------------------------------------------------------------------------

-- Formata um valor em MB com 2 casas decimais. undefined vira "n/d".
fn InLab_FormatarMB v =
(
    if v == undefined then "n/d"
    else (formattedPrint v format:".2f") + " MB"
)
