/*
 tests\test_mapear_paineis.ms — teste de functions\fn_mapear_paineis.ms (Mapear por
 paineis). RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt).
 Resultado: <pasta temp do Max>\inlab_test_mapear_paineis.txt (PASS/FAIL por item).
 26/10/2026 (Tarefa 1): vivos e geometria em mundo.
 26/10/2026 (Tarefa 2): costuras pelo vivo, molde em caixa, contornos.
*/
global InLab_Log, InLab_EhGeometria, InLab_Mapear_PolyDe
global InLab_Paineis_Vert, InLab_Paineis_Elementos, InLab_Paineis_VolArea
global InLab_Paineis_EhVivo, InLab_Paineis_VivosDoProduto, InLab_Paineis_NosDaCabeca
global InLab_Paineis_Separar, InLab_Paineis_Contornos
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

        ---------------- Tarefa 2: costuras e paineis ----------------
        -- laço de vivo (mundo): quadrado de meia-medida h em volta da almofada, na altura z
        fn lacoVivo h z desloc =
        (
            local pts = #()
            for k = -h to h by 1.0 do
            (
                append pts ([k, h, z] + desloc)
                append pts ([k, -h, z] + desloc)
                append pts ([h, k, z] + desloc)
                append pts ([-h, k, z] + desloc)
            )
            pts
        )
        -- almofada de teste: Box segmentado (o topo do ChamferBox é um n-gono só)
        fn mkAlmofada nome =
        (
            local a = Box length:100 width:100 height:20 lengthsegs:10 widthsegs:10 heightsegs:2 name:nome
            convertToPoly a
            a
        )
        local a2 = mkAlmofada "TESTE_pn_alm2"
        append criados a2
        local pa2 = a2.baseobject
        local corpo2 = #{1..(polyop.getNumFaces pa2)}
        local vv = lacoVivo 50.0 10.0 [0,0,0]
        local r1 = InLab_Paineis_Separar a2 corpo2 vv
        checar "costura: almofada com vivo no meio dá 2 painéis pelo vivo" (r1.paineis.count == 2 and (matchPattern r1.metodo pattern:"vivo*"))
        local soma = 0, inter = false, uniao = #{}
        for p in r1.paineis do ( soma += p.numberSet; if (uniao * p).numberSet > 0 do inter = true; uniao += p )
        checar "costura: os 2 painéis cobrem todas as faces do corpo" (soma == corpo2.numberSet and not inter and uniao.numberSet == corpo2.numberSet)

        local r2 = InLab_Paineis_Separar a2 corpo2 #()
        checar "caixa: sem vivo dá molde em caixa no eixo Z com 3 painéis" (r2.paineis.count == 3 and r2.eixoCaixa == 3 and (matchPattern r2.metodo pattern:"molde em caixa*"))

        local pe = ChamferBox length:20 width:90 height:36 fillet:3 filletsegs:3 lengthsegs:4 widthsegs:8 heightsegs:4 name:"TESTE_pn_empe"
        convertToPoly pe
        append criados pe
        local r3 = InLab_Paineis_Separar pe #{1..(polyop.getNumFaces pe.baseobject)} #()
        checar "caixa: almofada em pé (fina em Y) usa o eixo Y" (r3.eixoCaixa == 2)

        local cb3 = ChamferBox length:100 width:100 height:20 fillet:5 filletsegs:3 name:"TESTE_pn_cb3"
        convertToPoly cb3
        append criados cb3
        local r3b = InLab_Paineis_Separar cb3 #{1..(polyop.getNumFaces cb3.baseobject)} #()
        checar "caixa: ChamferBox 100×100×20 (Fillet 5) sem vivo dá 3 painéis" (r3b.paineis.count == 3 and r3b.eixoCaixa == 3)
        checar "caixa: almofada em pé ChamferBox 90×20×36 dá 3 painéis no eixo Y" (r3.paineis.count == 3 and r3.eixoCaixa == 2)

        local cil = Cylinder radius:20 height:45 heightsegs:3 sides:24 name:"TESTE_pn_cil"
        convertToPoly cil
        append criados cil
        local r4 = InLab_Paineis_Separar cil #{1..(polyop.getNumFaces cil.baseobject)} #()
        checar "caixa: cilindro Ø40 × 45 fica no eixo Z" (r4.eixoCaixa == 3)
        checar "caixa: cilindro Ø40 × 45 (sides 24) dá 3 painéis" (r4.paineis.count == 3)

        local r5 = InLab_Paineis_Separar a2 corpo2 (lacoVivo 55.0 10.0 [0,0,0])
        checar "diag: vivo a 5 cm não separa e o motivo diz isso" ((matchPattern r5.metodo pattern:"molde em caixa*") and (findString r5.diag "3 cm") != undefined)

        local a3 = mkAlmofada "TESTE_pn_alm3"
        append criados a3
        a3.pos = [5000,300,0]
        a3.pivot = [5005,303,0]
        local r6 = InLab_Paineis_Separar a3 #{1..(polyop.getNumFaces a3.baseobject)} (lacoVivo 50.0 10.0 [5000,300,0])
        local c1 = for p in r1.paineis collect p.numberSet
        local c6 = for p in r6.paineis collect p.numberSet
        sort c1; sort c6
        checar "mundo: a mesma almofada com pivô em [5000,300,0] dá os mesmos painéis" (c1.count == c6.count and c1.count == 2 and c1[1] == c6[1] and c1[2] == c6[2])
        local r7 = InLab_Paineis_Separar a3 #{1..(polyop.getNumFaces a3.baseobject)} #()
        checar "mundo: molde em caixa com pivô deslocado dá 3 painéis" (r7.paineis.count == 3 and r7.eixoCaixa == 3)

        checar "contornos: anel 2, disco 1" (r2.paineis.count == 3 and (InLab_Paineis_Contornos pa2 r2.paineis[3]) == 2 and (InLab_Paineis_Contornos pa2 r2.paineis[1]) == 1)
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
