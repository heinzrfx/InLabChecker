/*
 tests\test_verif_uv.ms — teste automático de verifications\verif_uv.ms
 RODAR NUMA CENA VAZIA (resetMaxFile #noPrompt): cria malhas com UV no canal 3
 montado à mão (valores conhecidos) e apaga tudo no final.
 Resultado: <pasta temp do Max>\inlab_test_verif_uv.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_MedirUV, InLab_AssinaturaCanal, InLab_UVMetricasTexto
global INLAB_UV_GUTTER_BUSCA
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_uv.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn perto a b = ( a != undefined and abs (a - b) <= 0.001 )

    -- 4 UVs de um quadrado (x0,y0) de lado "lado", no sentido anti-horário
    fn quadUV x0 y0 lado = #([x0, y0, 0], [x0 + lado, y0, 0], [x0 + lado, y0 + lado, 0], [x0, y0 + lado, 0])
    -- o mesmo quadrado espelhado em U: inverte o sentido das faces no UV
    fn quadUVEspelhado x0 y0 lado = #([x0 + lado, y0, 0], [x0, y0, 0], [x0, y0 + lado, 0], [x0 + lado, y0 + lado, 0])

    -- Uma malha com um quadrado 10×10 cm (2 triângulos) por item de "quads",
    -- lado a lado em X. Cada item traz os 4 UVs do quadrado no canal 3.
    fn criarMalha quads =
    (
        local verts = #(), fcs = #()
        for i = 1 to quads.count do
        (
            local x = 20.0 * (i - 1)
            join verts #([x, 0, 0], [x + 10, 0, 0], [x + 10, 10, 0], [x, 10, 0])
            local b = 4 * (i - 1)
            join fcs #([b + 1, b + 2, b + 3], [b + 1, b + 3, b + 4])
        )
        local o = mesh vertices:verts faces:fcs
        -- mesh novo só tem os canais -2..1: abre espaço até o 3 antes do setMapSupport
        meshop.setNumMaps o 4 keep:true
        meshop.setMapSupport o 3 true
        meshop.setNumMapVerts o 3 verts.count
        meshop.setNumMapFaces o 3 fcs.count
        for i = 1 to quads.count do
            for k = 1 to 4 do meshop.setMapVert o 3 (4 * (i - 1) + k) quads[i][k]
        for f = 1 to fcs.count do meshop.setMapFace o 3 f fcs[f]
        update o
        o
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    local criados = #()

    try
    (
        fileIn (raiz + @"verifications\verif_uv.ms")

        -- 1. CASO BASE: duas ilhas iguais separadas por 0,1
        local o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.5 0.1 0.3)
        append criados o
        local m = InLab_MedirUV o 3
        linha ("      " + InLab_UVMetricasTexto m)
        checar "Base: 4 faces" (m.nFaces == 4)
        checar "Base: 2 ilhas" (m.nIlhas == 2)
        checar "Base: aproveitamento 18%" (perto m.aproveitamento 0.18)
        checar "Base: densidade 1,00×" (perto m.densidadeRazao 1.0)
        checar "Base: densidade de área 1,00×" (perto m.densidadeRazaoArea 1.0)
        checar "Base: distorção 1,00×" (perto m.distorcaoMax 1.0)
        checar "Base: nada fora do 0–1" (m.foraDe01 == 0)
        checar "Base: 0 sobrepostas" (m.sobrepostas == 0)
        checar "Base: 0 invertidos" (m.invertidos == 0)
        checar "Base: não espelhado" (not m.espelhado)
        checar "Base: gutter no limite de busca" (perto m.gutterMin INLAB_UV_GUTTER_BUSCA)
        checar "Base: borda 0,1" (perto m.bordaMin 0.1)

        -- 2. GUTTER PEQUENO: 0,01 entre as ilhas
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.41 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Gutter 0,01" (perto m.gutterMin 0.01)

        -- 3. DENSIDADE: mesma área 3D, ilha B com metade do lado
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.5 0.1 0.15)
        append criados o
        m = InLab_MedirUV o 3
        checar "Densidade linear 2,00×" (perto m.densidadeRazao 2.0)
        checar "Densidade de área 4,00×" (perto m.densidadeRazaoArea 4.0)

        -- 4. SOBREPOSIÇÃO: ilha B invade 0,1 da ilha A
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.3 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Sobreposição: 4 faces" (m.sobrepostas == 4)
        checar "Sobreposição: gutter 0" (perto m.gutterMin 0.0)

        -- 5. INVERTIDOS: ilha B espelhada no UV
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUVEspelhado 0.5 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Invertidos: 2 faces" (m.invertidos == 2)
        checar "Invertidos: 0 sobrepostas" (m.sobrepostas == 0)

        -- 6. FORA DO 0–1: ilha B vai até u = 1,2
        o = criarMalha #(quadUV 0.1 0.1 0.3, quadUV 0.9 0.1 0.3)
        append criados o
        m = InLab_MedirUV o 3
        checar "Fora do 0–1: 2 vértices" (m.foraDe01 == 2)
        checar "Fora do 0–1: borda -0,2" (perto m.bordaMin (-0.2))

        -- 7. DISTORÇÃO: um quadrado, uma face com o dobro da área UV da outra
        o = criarMalha #(#([0.1, 0.1, 0], [0.4, 0.1, 0], [0.4, 0.4, 0], [0.1, 0.7, 0]))
        append criados o
        m = InLab_MedirUV o 3
        checar "Distorção: 1 ilha" (m.nIlhas == 1)
        checar "Distorção máx 1,50×" (perto m.distorcaoMax 1.5)
        checar "Uma ilha: gutter indefinido" (m.gutterMin == undefined)

        -- 8. ESPELHADO, CANAL INEXISTENTE E ASSINATURA
        o.scale = [-1, 1, 1]
        checar "Espelhado detectado" ((InLab_MedirUV o 3).espelhado)
        checar "Canal inexistente devolve undefined" ((InLab_MedirUV o 5) == undefined)
        local s1 = InLab_AssinaturaCanal o 3
        checar "Assinatura estável" (s1 != undefined and s1 == (InLab_AssinaturaCanal o 3))
        meshop.setMapVert o 3 1 [0.2, 0.1, 0]
        update o
        checar "Assinatura muda com o UV" (s1 != (InLab_AssinaturaCanal o 3))
        checar "Assinatura de canal inexistente = undefined" ((InLab_AssinaturaCanal o 5) == undefined)

        -- 9. DESEMPENHO: ~15 mil faces (tamanho do Box008) no canal 1
        local esf = Sphere segs:124 mapcoords:true
        append criados esf
        local t0 = timeStamp()
        m = InLab_MedirUV esf 1
        local ms = timeStamp() - t0
        linha ("      esfera: " + m.nFaces as string + " faces em " + ms as string + " ms · " + InLab_UVMetricasTexto m)
        checar "Desempenho: 15 mil faces em menos de 30 s" (m.nFaces > 14000 and ms < 30000)
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
