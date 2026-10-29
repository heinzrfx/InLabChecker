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
 REVISÃO FINAL (29/10/2026): o mapeamento só vale se o snapshot tiver
 exatamente Σ(grau − 2) triângulos. Com NURMS ligado na própria base (ou
 outra diferença entre a malha avaliada e a base) a conta não fecha: a peça
 só é contada, com #warn, em vez de ganhar polígonos errados. Peça só
 contada (modificador, primitiva, NURMS) não entra na seleção nem tem o
 grupo aberto; o texto diz "colapse o stack" ou "converta para Editable Poly".
 Seleção de faces, grupo e painel ficam fora do Ctrl+Z (with undo off): não
 mudam a geometria.
================================================================================
*/

-- verifications\verif_malha.ms carrega depois deste módulo no manifesto.
global InLab_Malha_FacesDuplicadasSet, InLab_Malha_Tolerancia

-- Triângulos do snapshot → polígonos da base Editable Poly (grau − 2 cada).
-- Com nTris (triângulos do snapshot), devolve undefined se a conta não fecha.
fn InLab_FacesDup_TriParaPoly o tris nTris:undefined =
(
    local polys = #{}
    local t = 0
    for f = 1 to polyop.getNumFaces o do
        for k = 1 to (polyop.getFaceDeg o f) - 2 do
        (
            t += 1
            if tris[t] do polys[f] = true
        )
    if nTris != undefined and t != nTris then undefined else polys
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
        local nTris = 0
        try
        (
            m = snapshotAsMesh o
            nTris = m.numfaces
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
                local pilhaVazia = o.modifiers.count == 0
                local cls = classof o.baseobject
                local txt = o.name + ": " + n as string + " face(s) coincidente(s)"
                with undo off
                (
                    if pilhaVazia and cls == Editable_Poly then
                    (
                        local polys = InLab_FacesDup_TriParaPoly o tris nTris:nTris
                        if polys == undefined then
                            InLab_Log (txt + ". A malha avaliada difere da base (NURMS ligado?): desligue para selecionar.") tipo:#warn
                        else
                        (
                            polyop.setFaceSelection o polys
                            append comDup o
                            InLab_Log (txt + ", selecionadas.") tipo:#err
                        )
                    )
                    else if pilhaVazia and cls == Editable_Mesh then
                    (
                        setFaceSelection o tris
                        append comDup o
                        InLab_Log (txt + ", selecionadas.") tipo:#err
                    )
                    else if not pilhaVazia then
                        InLab_Log (txt + ". Para selecionar, colapse o stack.") tipo:#warn
                    else
                        InLab_Log (txt + ". Para selecionar, converta para Editable Poly.") tipo:#warn
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
        InLab_Log ("Faces duplicadas: " + total as string + " face(s); " + comDup.count as string + " de " +
                   objs.count as string + " objeto(s) selecionado(s)" + (if comDup.count > 1 then "; edite uma peça por vez." else ".")) tipo:#warn
    total
)
