/*
 tests\test_mapear_paineis.ms — teste de functions\fn_mapear_paineis.ms (Mapear por
 paineis). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis.txt (PASS/FAIL por item).
 26/10/2026 (Tarefa 1): vivos e geometria em mundo.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea
global InLab_Paineis_EhVivo, InLab_Paineis_VivosDoProduto, InLab_Paineis_NosDaCabeca
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_paineis.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()
    try
    (
        fileIn (raiz + @"core\utils.ms")
        fileIn (raiz + @"functions\fn_mapear_gerar.ms")
        fileIn (raiz + @"functions\fn_mapear_paineis.ms")

        -- almofada: Box 100x100x20 arredondado
        local almofada = ChamferBox length:100 width:100 height:20 fillet:5 filletsegs:3 name:"TESTE_pn_almofada"
        convertToPoly almofada
        append criados almofada
        -- vivo: toro fino
        local toro = Torus radius1:50 radius2:0.6 segments:48 sides:8 name:"TESTE_pn_toro" pos:[0,0,10]
        convertToPoly toro
        append criados toro

        local pa = almofada.baseobject, pt = toro.baseobject
        local elA = InLab_Paineis_Elementos pa #{1..(polyop.getNumFaces pa)}
        local elT = InLab_Paineis_Elementos pt #{1..(polyop.getNumFaces pt)}
        checar "elementos: almofada e toro tem 1 elemento cada" (elA.count == 1 and elT.count == 1)
        checar "vivo: toro fino é vivo" ((InLab_Paineis_EhVivo toro elT[1])[1] == true)
        checar "vivo: almofada não é vivo" ((InLab_Paineis_EhVivo almofada elA[1])[1] == false)
        local pts = InLab_Paineis_VivosDoProduto almofada nos:#(almofada, toro)
        checar "vivo: VivosDoProduto acha os vértices do toro" (pts.count == polyop.getNumVerts pt)

        -- sem nos: varre a hierarquia da cabeça (toro filho da almofada)
        toro.parent = almofada
        local pts2 = InLab_Paineis_VivosDoProduto toro
        checar "vivo: sem nos varre a hierarquia a partir da cabeça" (pts2.count == polyop.getNumVerts pt)

        -- plano fino aberto não é vivo
        local plano = Plane length:200 width:2 lengthsegs:4 widthsegs:1 name:"TESTE_pn_plano"
        convertToPoly plano
        append criados plano
        local elP = InLab_Paineis_Elementos plano.baseobject #{1..(polyop.getNumFaces plano.baseobject)}
        checar "vivo: plano fino aberto não é vivo" ((InLab_Paineis_EhVivo plano elP[1])[1] == false)

        -- nó Editable_Mesh com um toro fino
        local toroM = Torus radius1:50 radius2:0.6 segments:48 sides:8 name:"TESTE_pn_toroM" pos:[0,500,10]
        convertToMesh toroM
        append criados toroM
        local ptsM = InLab_Paineis_VivosDoProduto toroM nos:#(toroM)
        checar "vivo: VivosDoProduto acha o vivo de um nó Editable_Mesh" (ptsM.count == 48 * 8)
        local nTemp = (for o in objects where (matchPattern o.name pattern:"InLab_tmp_paineis*") collect o).count
        checar "vivo: cópia temporária apagada" (nTemp == 0)
        local el0 = #{1..(getNumFaces toroM.mesh)}
        local r0 = try ( InLab_Paineis_EhVivo toroM el0 ) catch ( undefined )
        checar "guarda: EhVivo numa base Editable_Mesh devolve false sem exceção" (r0 != undefined and r0[1] == false)

        -- mundo: nó com pivô deslocado
        local m = Box length:30 width:20 height:10 name:"TESTE_pn_mundo"
        convertToPoly m
        append criados m
        m.pos = [5000,0,0]
        m.pivot = [5010,5,3]
        rotate m (eulerAngles 0 0 30)
        local malha = snapshotAsMesh m
        local pm = m.baseobject
        local ok = true
        -- ordem dos vértices do snapshot do poly = ordem da base (Box convertido, sem triangulação extra)
        for v = 1 to (polyop.getNumVerts pm) while ok do
            if (distance (InLab_Paineis_Vert m v) (getVert malha v)) > 1e-3 do ok = false
        checar "mundo: vértice de nó com pivô em [5000,0,0]" ok
        delete malha
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
