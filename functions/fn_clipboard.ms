/*
================================================================================
 functions\fn_clipboard.ms — BARRA COPY/PASTE (v0.10, 13/Jul)
--------------------------------------------------------------------------------
 Implementa as funções da barra fixa pedida (referência ArchToolz):
   Copy Objs / Paste Objs → clona objetos para uma área de transferência
                             interna do plugin (não é o clipboard do SO).
   Copy Mat / Paste Mat   → guarda o material do objeto ativo/selecionado e
                             aplica na seleção seguinte.
   Pick Mat               → "conta-gotas": clica num objeto da cena e copia
                             o material dele (equivale a Copy Mat + picking).

 PASTE DWG: NÃO IMPLEMENTADO — pendência de escopo. No ArchToolz é import de
 referência CAD; não há equivalente claro definido para o pipeline GLB do
 InLab. Botão fica visível e desabilitado até a equipe definir o
 comportamento esperado.
================================================================================
*/

global InLab_ClipboardObjs = #()
global InLab_ClipboardMat  = undefined

--------------------------------------------------------------------------------
-- COPY OBJS: guarda referência aos objetos selecionados (não clona ainda —
-- a cópia acontece no Paste, para permitir colar múltiplas vezes).
--------------------------------------------------------------------------------
fn InLab_CopyObjs objs =
(
    InLab_ClipboardObjs = objs
    InLab_Log ("Copy Objs: " + objs.count as string + " objeto(s) na área de transferência do plugin.") tipo:#ok
    objs.count
)

--------------------------------------------------------------------------------
-- PASTE OBJS: clona os objetos copiados (cópia completa, não instância) e
-- seleciona os novos.
--------------------------------------------------------------------------------
fn InLab_PasteObjs =
(
    if InLab_ClipboardObjs.count == 0 then
    (
        InLab_Log "Paste Objs: nada copiado ainda (use Copy Objs primeiro)." tipo:#warn
        #()
    )
    else
    (
        local novos = #()
        undo "InLab Paste Objs" on
        (
            for o in InLab_ClipboardObjs where isValidNode o do
            (
                local clone
                maxOps.CloneNodes o cloneType:#copy newNodes:&clone
                join novos clone
            )
            if novos.count > 0 do select novos
        )
        InLab_Log ("Paste Objs: " + novos.count as string + " objeto(s) colado(s).") tipo:#ok
        novos
    )
)

--------------------------------------------------------------------------------
-- COPY MAT: guarda o material do primeiro objeto da seleção.
--------------------------------------------------------------------------------
fn InLab_CopyMat objs =
(
    local origem = for o in objs where o.material != undefined collect o
    if origem.count == 0 then
    (
        InLab_Log "Copy Mat: nenhum objeto selecionado tem material." tipo:#warn
        false
    )
    else
    (
        InLab_ClipboardMat = origem[1].material
        InLab_Log ("Copy Mat: '" + InLab_ClipboardMat.name + "' guardado (de '" + origem[1].name + "').") tipo:#ok
        true
    )
)

--------------------------------------------------------------------------------
-- PASTE MAT: aplica o material guardado a todos os objetos da seleção.
--------------------------------------------------------------------------------
fn InLab_PasteMat objs =
(
    if InLab_ClipboardMat == undefined then
    (
        InLab_Log "Paste Mat: nenhum material copiado ainda (use Copy Mat ou Pick Mat)." tipo:#warn
        0
    )
    else
    (
        local n = 0
        undo "InLab Paste Mat" on
        (
            for o in objs do ( o.material = InLab_ClipboardMat ; n += 1 )
        )
        InLab_Log ("Paste Mat: '" + InLab_ClipboardMat.name + "' aplicado a " + n as string + " objeto(s).") tipo:#ok
        n
    )
)

--------------------------------------------------------------------------------
-- PICK MAT: usuário clica num objeto da cena; copia o material dele.
-- Equivalente a um "conta-gotas" — usa pickObject nativo do Max.
--------------------------------------------------------------------------------
fn InLab_PickMat =
(
    InLab_Log "Pick Mat: clique num objeto na viewport..."
    local alvo = pickObject message:"InLabChecker · clique no objeto para copiar o material"
    if alvo == undefined then
    (
        InLab_Log "Pick Mat: cancelado (nenhum objeto clicado)." tipo:#warn
        false
    )
    else if alvo.material == undefined then
    (
        InLab_Log ("Pick Mat: '" + alvo.name + "' não tem material.") tipo:#warn
        false
    )
    else
    (
        InLab_ClipboardMat = alvo.material
        InLab_Log ("Pick Mat: '" + InLab_ClipboardMat.name + "' copiado de '" + alvo.name + "'.") tipo:#ok
        true
    )
)
