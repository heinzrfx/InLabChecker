/*
 tests\test_mapear_medir.ms — teste de functions\fn_mapear_medir.ms
 (medição do UV do canal 1 e critério de "ruim"). RODAR NUMA CENA VAZIA.
 Resultado: <pasta temp do Max>\inlab_test_mapear_medir.txt (PASS/FAIL por item).
*/
global InLab_Log
global InLab_Mapear_Medir, InLab_Mapear_Motivo, InLab_Mapear_Limite, MapearMedida
global INLAB_MAPEAR_LIMITES, INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_mapear_medir.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn contem s trecho = ( (findString s trecho) != undefined )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
    )
    local criados = #()

    try
    (
        fileIn (raiz + @"functions\fn_mapear_medir.ms")

        -- 1. BOX COM UVW BOX DE 60 CM
        local b1 = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_mm_box"
        append criados b1
        local u1 = Uvwmap maptype:4 length:60 width:60 height:60
        addModifier b1 u1
        local med1 = InLab_Mapear_Medir b1
        linha ("      medida: escala=" + med1.escala as string + " p10=" + med1.p10 as string + " p90=" + med1.p90 as string + \
            " emenda=" + med1.emendaVistaQuebra as string + " esp=" + med1.espelhado as string + " faces=" + med1.faces as string)
        checar "Box tem canal 1" med1.temCanal
        checar "escala ≈ 1/60" (abs (med1.escala - 1.0/60) < (1.0/60) * 0.05)
        checar "Box com UVW Box: 0% espelhado" (med1.espelhado == 0.0)
        checar "Box com UVW Box: 12 triângulos" (med1.faces == 12)
        checar "Motivo de Box bem mapeado = ''" ((InLab_Mapear_Motivo med1 #madeira 60.0) == "")
        checar "Motivo sem alvo também = ''" ((InLab_Mapear_Motivo med1 #tecido undefined) == "")

        -- 2. FILTROS faces: E matID:
        local so = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_mm_box_filtro"
        append criados so
        addModifier so (Uvwmap maptype:4 length:60 width:60 height:60)
        local medId = InLab_Mapear_Medir so matID:1
        checar "matID:1 mede só as 2 faces daquele ID" (medId.faces == 2)
        checar "matID:1 mantém a escala" (abs (medId.escala - 1.0/60) < (1.0/60) * 0.05)
        local medSem = InLab_Mapear_Medir so matID:99
        checar "matID inexistente: 0 faces, sem exceção" (medSem.faces == 0 and medSem.temCanal)
        local medF = InLab_Mapear_Medir so faces:#{1..4}
        checar "faces:#{1..4} mede 4 triângulos" (medF.faces == 4)
        local medFm = InLab_Mapear_Medir so faces:#{1..4} matID:1
        checar "faces e matID juntos (interseção)" (medFm.faces <= 2)
        local medVazio = undefined
        local excecao = false
        try ( medVazio = InLab_Mapear_Medir so faces:#{} ) catch ( excecao = true )
        checar "Medir em nó com faces:#{} não dá exceção" (not excecao and medVazio != undefined and medVazio.faces == 0)

        -- 3. NÓ ESPELHADO
        -- O snapshot de um nó com escala negativa vem com as faces do avesso e o
        -- render vira a face: um UV "normal" num nó espelhado fica espelhado à vista
        -- (100%); só um UV já invertido no local (utile -1) fica certo (0%).
        local b2 = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_mm_box_espelhado"
        append criados b2
        local u2 = Uvwmap maptype:4 length:60 width:60 height:60
        addModifier b2 u2
        u2.utile = -1
        b2.scale = [-1, 1, 1]
        local med2 = InLab_Mapear_Medir b2
        linha ("      nó espelhado + UV invertido: espelhado=" + med2.espelhado as string)
        checar "espelhado da medida considera o transform" (med2.espelhado == 0.0)
        b2.scale = [1, 1, 1]
        local med2b = InLab_Mapear_Medir b2
        checar "mesmo UV invertido em nó normal: 100% espelhado" (med2b.espelhado == 1.0)
        u2.utile = 1
        b2.scale = [-1, 1, 1]
        local med2c = InLab_Mapear_Medir b2
        checar "nó espelhado com UV normal: 100% espelhado à vista" (med2c.espelhado == 1.0)

        -- 4. UV NA ESCALA DO REAL-WORLD (1 UV/cm)
        local b3 = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_mm_box_rw"
        append criados b3
        b3.realWorldMapSize = true
        addModifier b3 (Uvwmap maptype:4 length:1 width:1 height:1)
        local med3 = InLab_Mapear_Medir b3
        local mot3 = InLab_Mapear_Motivo med3 #madeira 60.0
        linha ("      escala RW=" + med3.escala as string + " motivo: " + mot3)
        checar "Motivo cita Real-World" (contem mot3 "Real-World")

        -- 5. CILINDRO COM UVW PLANAR
        local c1 = Cylinder radius:20 height:60 heightsegs:6 sides:24 mapcoords:true name:"TESTE_mm_cil_planar"
        append criados c1
        addModifier c1 (Uvwmap maptype:0 length:60 width:60)
        local med4 = InLab_Mapear_Medir c1
        local mot4 = InLab_Mapear_Motivo med4 #tecido 60.0
        linha ("      cilindro planar: p10=" + med4.p10 as string + " p90=" + med4.p90 as string + " emenda=" + med4.emendaVistaQuebra as string + " motivo: " + mot4)
        -- as laterais ficam com UV colapsado (planar) e não entram na escala; o que
        -- sobra acusa pelo menos um critério (aqui, o espelhamento da tampa de trás)
        checar "Cilindro com UVW planar: Motivo não vazio" (mot4 != "")

        -- 6. SEM CANAL 1
        local m1 = Box length:50 width:50 height:50 mapcoords:true name:"TESTE_mm_sem_canal"
        append criados m1
        convertToMesh m1
        meshop.setMapSupport m1 1 false
        local med5 = InLab_Mapear_Medir m1
        checar "peça sem canal 1: temCanal = false" (not med5.temCanal)
        checar "Motivo = 'sem canal 1'" ((InLab_Mapear_Motivo med5 #madeira 60.0) == "sem canal 1")

        -- 7. CILINDRO ALTO COM UVW BOX: VEIO ATRAVESSADO
        local c2 = Cylinder radius:2.5 height:80 heightsegs:5 sides:16 mapcoords:true name:"TESTE_mm_cil_alto"
        append criados c2
        addModifier c2 (Uvwmap maptype:4 length:60 width:60 height:60)
        local med6 = InLab_Mapear_Medir c2
        linha ("      cilindro alto: veioOk=" + med6.veioOk as string + " emenda=" + med6.emendaVistaQuebra as string + " motivo madeira: " + (InLab_Mapear_Motivo med6 #madeira 60.0))
        checar "Cilindro alto com UVW Box: veio atravessado (veioOk < 60%)" (med6.veioOk < 0.6)
        checar "veio só conta em #madeira: tecido não cita veio" (not (contem (InLab_Mapear_Motivo med6 #tecido 60.0) "veio"))

        -- 7b. FALHA NO MEIO DA MEDIÇÃO NÃO VIRA "BOM"
        local medOk = InLab_Mapear_Medir b1
        checar "peça normal: falhou = false" (not medOk.falhou)
        local medFalha = InLab_Mapear_Medir b1 faces:42 -- bitarray * inteiro dá exceção dentro da medição
        checar "exceção na medição: falhou = true" medFalha.falhou
        checar "Motivo = 'medição falhou'" ((InLab_Mapear_Motivo medFalha #madeira 60.0) == "medição falhou")

        -- 7c. TETO DA AMOSTRA (20 mil < triângulos < 40 mil)
        local pl = Plane length:100 width:100 lengthsegs:130 widthsegs:130 mapcoords:true name:"TESTE_mm_plano_grande"
        append criados pl
        addModifier pl (Uvwmap maptype:0 length:60 width:60)
        local medPl = InLab_Mapear_Medir pl
        linha ("      plano grande: faces=" + medPl.faces as string + " amostra=" + medPl.amostra as string)
        checar "malha entre 20 e 40 mil triângulos" (medPl.faces > 20000 and medPl.faces < 40000)
        checar "amostra não passa de 20 mil" (medPl.amostra > 0 and medPl.amostra <= 20000)
        checar "malha grande ainda mede a escala" (abs (medPl.escala - 1.0/60) < (1.0/60) * 0.05)

        -- 8. MOTIVO SOBRE MEDIDAS SINTÉTICAS (ordem da tabela da spec 7)
        local ok0 = MapearMedida temCanal:true escala:(1.0/60) p10:(1.0/60) p90:(1.0/60) veioOk:1.0 faces:100
        checar "sintética boa = ''" ((InLab_Mapear_Motivo ok0 #madeira 60.0) == "")
        local s1 = copy ok0; s1.escala = 0.5
        checar "escala > 0,2 UV/cm cita Real-World" (contem (InLab_Mapear_Motivo s1 #tecido 60.0) "Real-World")
        local s2 = copy ok0
        checar "escala longe do alvo só com alvo" ((InLab_Mapear_Motivo s2 #tecido 10.0) != "" and (InLab_Mapear_Motivo s2 #tecido undefined) == "")
        local s3 = copy ok0; s3.p90 = (1.0/60) * 1.8
        checar "densidade desigual cita p90/p10" (contem (InLab_Mapear_Motivo s3 #tecido 60.0) "p90/p10 = 1,8")
        local s4 = copy ok0; s4.emendaVistaQuebra = 0.12
        checar "emendas à vista: 12%" (contem (InLab_Mapear_Motivo s4 #tecido 60.0) "(12%)")
        local s5 = copy ok0; s5.espelhado = 0.76
        checar "UV espelhado: 76%" (contem (InLab_Mapear_Motivo s5 #tecido 60.0) "76% das faces")
        local s6 = copy ok0; s6.veioOk = 0.35
        checar "veio atravessado: 35% (madeira)" (contem (InLab_Mapear_Motivo s6 #madeira 60.0) "veio atravessado (35% das faces no sentido certo)")
        checar "veio ignorado fora de madeira" ((InLab_Mapear_Motivo s6 #pintada 60.0) == "")
        local s7 = copy s1; s7.emendaVistaQuebra = 0.5
        checar "ordem: Real-World vem antes de emendas" (contem (InLab_Mapear_Motivo s7 #madeira 60.0) "Real-World")
    )
    catch ( linha ("FAIL  exceção no teste: " + (getCurrentException())); INLAB_TESTE_FALHAS += 1 )

    -- limpeza
    for o in criados where isValidNode o do try ( delete o ) catch ()
    InLab_Log = logOriginal
    linha (if INLAB_TESTE_FALHAS == 0 then "== TUDO PASSOU ==" else ("== " + INLAB_TESTE_FALHAS as string + " FALHA(S) =="))
    close INLAB_TESTE_SAIDA
)
