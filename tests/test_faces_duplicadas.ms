/*
 tests\test_faces_duplicadas.ms — teste de functions\fn_faces_duplicadas.ms
 (issue #214: botão Faces duplicadas das Utilidades Rápidas). Mesma regra da
 V-09a; seleciona as faces, abre o polígono com uma peça só e não apaga nada.
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_faces_duplicadas.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_EhGeometria, InLab_Malha_Tolerancia, InLab_Malha_FacesDuplicadasSet
global InLab_FacesDuplicadas, InLab_FacesDup_TriParaPoly, InLab_AbrirGruposAcima, InLab_FecharGrupos
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_LOGS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_faces_duplicadas.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    INLAB_TESTE_LOGS = #()
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )
    -- Algum log do tipo com o trecho no texto.
    fn logou tipo trecho = ((for l in INLAB_TESTE_LOGS where l[1] == tipo and (findString l[2] trecho) != undefined collect l).count > 0)
    -- Box com uma cópia atachada no mesmo lugar: 24 triângulos, todos duplicados.
    fn caixaDupla x:0 =
    (
        local b = convertToPoly (Box length:40 width:40 height:40 pos:[x, 0, 0])
        polyop.attach b (convertToPoly (Box length:40 width:40 height:40 pos:[x, 0, 0]))
        b
    )

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType

    try
    (
        for m in #(@"core\struct_result.ms", @"core\log.ms", @"core\utils.ms", @"functions\fn_autouv.ms",
                   @"verifications\verif_malha.ms", @"functions\fn_faces_duplicadas.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info =
        (
            append INLAB_TESTE_LOGS #(tipo, msg)
            format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA
        )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- TRI → POLY
        -- quad (2 tris) e pentágono (3 tris)
        local pp = convertToPoly (mesh numverts:0 numfaces:0)
        polyop.createVert pp [0,0,0]; polyop.createVert pp [10,0,0]; polyop.createVert pp [10,10,0]; polyop.createVert pp [0,10,0]
        polyop.createVert pp [20,0,0]; polyop.createVert pp [30,0,0]; polyop.createVert pp [35,5,0]; polyop.createVert pp [30,10,0]; polyop.createVert pp [20,10,0]
        polyop.createPolygon pp #(1, 2, 3, 4)
        polyop.createPolygon pp #(5, 6, 7, 8, 9)
        checar "TriParaPoly: graus 4 e 5" ((polyop.getFaceDeg pp 1) == 4 and (polyop.getFaceDeg pp 2) == 5)
        checar "TriParaPoly: tris 1,2 → poly 1" ((InLab_FacesDup_TriParaPoly pp #{1, 2}) as string == #{1} as string)
        checar "TriParaPoly: tri 3 → poly 2" ((InLab_FacesDup_TriParaPoly pp #{3}) as string == #{2} as string)
        checar "TriParaPoly: tris 2,5 → polys 1,2" ((InLab_FacesDup_TriParaPoly pp #{2, 5}) as string == #{1, 2} as string)
        limparCena()

        ---------------------------------------------------------------- POLY
        local b = caixaDupla()
        local nAntes = polyop.getNumFaces b
        INLAB_TESTE_LOGS = #()
        local n = InLab_FacesDuplicadas objs:#(b)
        checar ("Poly: devolve 24 (" + n as string + ")") (n == 24)
        checar "Poly: os 12 polígonos selecionados" ((polyop.getFaceSelection b) as string == #{1..12} as string)
        checar "Poly: só a peça selecionada" (selection.count == 1 and selection[1] == b)
        checar "Poly: Modify no nível de polígono" (getCommandPanelTaskMode() == #modify and subObjectLevel == 4)
        checar "Poly: não apagou nada" ((polyop.getNumFaces b) == nAntes)
        checar "Poly: log #err com a contagem" (logou #err "24 face(s) coincidente(s)")
        max create mode
        limparCena()

        ---------------------------------------------------------------- DUPLICATA PARCIAL
        -- Revisão final: com 100% duplicado qualquer mapeamento acerta. Aqui um
        -- cilindro de 5 lados (tampas pentagonais, laterais quads) com uma face
        -- apagada no meio, mais a cópia de UM polígono: só os dois polígonos
        -- com esse centro podem sair selecionados.
        local cil = convertToPoly (Cylinder radius:20 height:30 sides:5 heightsegs:1 capsegs:1)
        polyop.deleteFaces cil #{3}
        local copia = copy cil
        local nc = polyop.getNumFaces copia
        local manter = nc - 1 -- uma tampa, no fim da lista
        polyop.deleteFaces copia (#{1..nc} - #{manter})
        local cAlvo = polyop.getFaceCenter copia 1
        polyop.attach cil copia
        local esperado = #{}
        for f = 1 to polyop.getNumFaces cil where (distance (polyop.getFaceCenter cil f) cAlvo) < 0.01 do esperado[f] = true
        n = InLab_FacesDuplicadas objs:#(cil)
        checar ("Parcial: dois polígonos esperados (" + esperado as string + ")") (esperado.numberSet == 2)
        checar ("Parcial: seleção exata " + (polyop.getFaceSelection cil) as string) ((polyop.getFaceSelection cil) as string == esperado as string)
        max create mode
        limparCena()

        ---------------------------------------------------------------- NURMS NA BASE
        -- Malha avaliada difere da base: o mapeamento tri → poly não vale.
        local bn = caixaDupla()
        polyop.setFaceSelection bn #{}
        bn.surfSubdivide = true
        bn.iterations = 1
        INLAB_TESTE_LOGS = #()
        n = InLab_FacesDuplicadas objs:#(bn)
        checar "NURMS: conta as duplicatas" (n > 0)
        checar "NURMS: não seleciona faces erradas" ((polyop.getFaceSelection bn).numberSet == 0)
        checar "NURMS: avisa (#warn) que a malha difere da base" (logou #warn "difere da base")
        max create mode
        limparCena()

        ---------------------------------------------------------------- MESH
        local bm = caixaDupla()
        convertToMesh bm
        n = InLab_FacesDuplicadas objs:#(bm)
        checar "Mesh: devolve 24" (n == 24)
        checar "Mesh: as 24 faces selecionadas" ((getFaceSelection bm).numberSet == 24)
        checar "Mesh: Modify no nível de face" (subObjectLevel == 3)
        max create mode
        limparCena()

        ---------------------------------------------------------------- COM MODIFICADOR
        local bb = caixaDupla()
        polyop.setFaceSelection bb #{}
        addModifier bb (Bend angle:0)
        clearSelection()
        INLAB_TESTE_LOGS = #()
        n = InLab_FacesDuplicadas objs:#(bb)
        checar "Com modificador: devolve 24" (n == 24)
        checar "Com modificador: pede para colapsar (#warn)" (logou #warn "colapse")
        checar "Com modificador: seleção da base não muda" ((polyop.getFaceSelection bb.baseobject).numberSet == 0)
        checar "Com modificador: modificador continua" (bb.modifiers.count == 1)
        checar "Com modificador: peça só contada não fica selecionada" (selection.count == 0)
        max create mode
        limparCena()

        ---------------------------------------------------------------- DUAS PEÇAS
        local d1 = caixaDupla()
        local d2 = caixaDupla x:100
        local limpa = convertToPoly (Box length:10 width:10 height:10 pos:[300, 0, 0])
        n = InLab_FacesDuplicadas objs:#(d1, d2, limpa)
        checar "Duas peças: devolve 48" (n == 48)
        checar "Duas peças: as duas com duplicata selecionadas, a limpa não" (selection.count == 2 and (findItem (selection as array) limpa) == 0)
        checar "Duas peças: faces marcadas nas duas" ((polyop.getFaceSelection d1).numberSet == 12 and (polyop.getFaceSelection d2).numberSet == 12)
        max create mode
        limparCena()

        ---------------------------------------------------------------- PEÇA LIMPA
        local ok1 = convertToPoly (Box length:10 width:10 height:10)
        INLAB_TESTE_LOGS = #()
        n = InLab_FacesDuplicadas objs:#(ok1)
        checar "Limpa: devolve 0" (n == 0)
        checar "Limpa: log #ok" (logou #ok "sem faces duplicadas")
        limparCena()

        ---------------------------------------------------------------- INSTÂNCIA
        local i1 = caixaDupla()
        local i2 = instance i1
        i2.pos = [200, 0, 0]
        INLAB_TESTE_LOGS = #()
        local erroInst = undefined
        try ( n = InLab_FacesDuplicadas objs:#(i1, i2) ) catch ( erroInst = getCurrentException() )
        checar "Instância: sem exceção" (erroInst == undefined)
        checar "Instância: uma linha por nó" ((for l in INLAB_TESTE_LOGS where (findString l[2] "coincidente") != undefined and (findString l[2] ":") != undefined and l[1] == #err collect l).count == 2)
        max create mode
        limparCena()

        ---------------------------------------------------------------- SEM SELEÇÃO
        local sc = caixaDupla()
        clearSelection()
        n = InLab_FacesDuplicadas()
        checar "Sem seleção: age na cena (24)" (n == 24)
        max create mode
        limparCena()

        ---------------------------------------------------------------- GRUPO FECHADO
        local g1 = caixaDupla()
        local g2 = convertToPoly (Box length:10 width:10 height:10 pos:[100, 0, 0])
        local grp = group #(g1, g2) name:"grupoTeste"
        n = InLab_FacesDuplicadas objs:#(g1)
        checar "Grupo fechado: devolve 24" (n == 24)
        checar "Grupo fechado: só o membro selecionado" (selection.count == 1 and selection[1] == g1)
        max create mode
        limparCena()
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( max create mode; limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
