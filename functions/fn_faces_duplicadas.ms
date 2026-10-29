/*
================================================================================
 functions\fn_faces_duplicadas.ms — FACES DUPLICADAS (Utilidades Rápidas)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Botão "Faces duplicadas" (issue #214, 29/10/2026). A V-09 reprovava a Nambu
 (00125400) com "660 face(s) coincidente(s)", e o desenhista não tinha como
 achar as faces: a mensagem só traz o nome do objeto. O botão acha as faces
 com a MESMA regra e tolerância da V-09a (InLab_Malha_FacesDuplicadasSet,
 verifications\verif_malha.ms), seleciona-as e não apaga nada.

 - Age nos objetos selecionados; sem seleção, em toda a geometria da cena.
 - Editable Poly de stack vazio: seleciona os polígonos. A V-09 mede no
   snapshotAsMesh (triângulos), e os triângulos de um Editable Poly saem na
   ordem dos polígonos, grau − 2 cada (sondado no Max 2024 em 29/10/2026,
   com face apagada no meio): InLab_FacesDup_TriParaPoly faz essa conta.
 - Editable Mesh de stack vazio: seleciona as faces direto.
 - Outros (modificador no stack, primitiva): só conta e pede para colapsar,
   porque a seleção na base não seria a do topo do stack.
 - Ao fim, seleciona as peças com duplicata. Se for uma só, abre o Modify no
   nível de polígono (ou face). Com várias, o Max não abre o subnível de
   mais de um nó: as faces ficam marcadas em cada peça.
 - Grupo fechado acima da peça é aberto (select num membro de grupo fechado
   seleciona o grupo todo) e fica aberto para o desenhista editar.
 Seleção de faces, grupo e painel ficam fora do Ctrl+Z (with undo off): não
 mudam a geometria.
================================================================================
*/

-- verifications\verif_malha.ms carrega depois deste módulo no manifesto.
global InLab_Malha_FacesDuplicadasSet, InLab_Malha_Tolerancia

-- Triângulos do snapshot → polígonos da base Editable Poly (grau − 2 cada).
fn InLab_FacesDup_TriParaPoly o tris =
(
    local polys = #{}
    local t = 0
    for f = 1 to polyop.getNumFaces o do
        for k = 1 to (polyop.getFaceDeg o f) - 2 do
        (
            t += 1
            if tris[t] do polys[f] = true
        )
    polys
)

-- Devolve o total de faces duplicadas (em triângulos, como a V-09).
fn InLab_FacesDuplicadas objs:undefined =
(
    if objs == undefined do
    (
        objs = for o in selection where InLab_EhGeometria o collect o
        if objs.count == 0 do objs = for o in geometry where InLab_EhGeometria o collect o
    )
    objs = for o in objs where isValidNode o and InLab_EhGeometria o collect o
    local tol = InLab_Malha_Tolerancia()
    local comDup = #()
    local total = 0
    for o in objs do
    (
        local tris = undefined
        local m = undefined
        try
        (
            m = snapshotAsMesh o
            tris = InLab_Malha_FacesDuplicadasSet m tol
        )
        catch ( InLab_Log (o.name + ": falha ao procurar faces duplicadas (" + getCurrentException() + ").") tipo:#err )
        if m != undefined do try ( delete m ) catch ()
        if tris != undefined do
        (
            local n = tris.numberSet
            if n == 0 then
                InLab_Log (o.name + ": sem faces duplicadas.") tipo:#ok
            else
            (
                total += n
                append comDup o
                local pilhaVazia = o.modifiers.count == 0
                local cls = classof o.baseobject
                with undo off
                (
                    if pilhaVazia and cls == Editable_Poly then
                    (
                        polyop.setFaceSelection o (InLab_FacesDup_TriParaPoly o tris)
                        InLab_Log (o.name + ": " + n as string + " face(s) coincidente(s), selecionadas.") tipo:#err
                    )
                    else if pilhaVazia and cls == Editable_Mesh then
                    (
                        setFaceSelection o tris
                        InLab_Log (o.name + ": " + n as string + " face(s) coincidente(s), selecionadas.") tipo:#err
                    )
                    else
                        InLab_Log (o.name + ": " + n as string + " face(s) coincidente(s). Para selecionar, colapse o stack.") tipo:#warn
                )
            )
        )
    )

    if comDup.count > 0 do with undo off
    (
        for o in comDup do InLab_AbrirGruposAcima o
        select comDup
        local o = comDup[1]
        local cls = classof o.baseobject
        if comDup.count == 1 and o.modifiers.count == 0 and (cls == Editable_Poly or cls == Editable_Mesh) do
        (
            max modify mode
            modPanel.setCurrentObject o.baseobject
            subObjectLevel = if cls == Editable_Poly then 4 else 3
        )
    )

    if total == 0 then
        InLab_Log ("Faces duplicadas: nenhuma em " + objs.count as string + " objeto(s).") tipo:#ok
    else
        InLab_Log ("Faces duplicadas: " + total as string + " face(s) em " + comDup.count as string + " de " +
                   objs.count as string + " objeto(s)" + (if comDup.count > 1 then "; selecione uma peça por vez para editar." else ".")) tipo:#warn
    total
)
