/*
 tests\test_otim_escondidas.ms — teste automático de functions\fn_otim_escondidas.ms (issue #63)
 Spec 2026-09-23-otimizacao-design.md, seções 5 e 6: a cena da sondagem com os
 números exatos (32, 50, 224, 84, zeros); peça animada excluída (e a face que
 encosta nela); fundo nunca marcado; instâncias (interseção, 1 modificador);
 modificador aplicado e removido pelo Reverter.
 Revisão (24/09/2026): oclusor aberto (plano inclinado) não marca "dentro";
 peça escondida ou não renderizável não cobre; decalque coplanar virado para
 o mesmo lado não esconde nem é escondido; passos 1 e 2 pulam peça com o
 passo 3 (Calcular, Aplicar e Reverter pelo despachante).
 Revisão 2: peça em camada oculta / não renderizável não cobre; valor do
 passo 1 preso por uma peça com passo 3 sobrevive a um novo Aplicar do passo 1.
 RODAR NUMA CENA VAZIA (File > New).
 Resultado: <pasta temp do Max>\inlab_test_otim_escondidas.txt (PASS/FAIL por item).
*/
global InLab_Log, InLab_Otim_Triangulos, OtimProposta
global InLab_OtimEscondidas_Calcular, InLab_OtimEscondidas_Aplicar, InLab_OtimEscondidas_Reverter
global InLab_UltimasEscondidas, InLab_OtimEscondidas_Destaque, InLab_OtimEscondidas_Mods, InLab_OtimEscondidas_LimparDestaque
global INLAB_ESC_NOME_MOD, INLAB_ESC_NOME_SEL
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_AVISOS
global INLAB_OTIM_META_MANUAL, InLab_FamiliaAtiva, InLab_UltimaOtimOrigem, InLab_UltimoAjusteFino
global InLab_Otim_Calcular, InLab_Otim_Aplicar, InLab_Otim_Reverter
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_otim_escondidas.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn limparCena = ( delete (for o in objects collect o) )
    fn propDe props o = ( local r = undefined; for p in props where p.no == o do r = p; r )
    fn nFaces props o = ( local p = propDe props o; if p == undefined then 0 else p.depois.numberSet )
    local unidadeOriginal = units.SystemType
    fn contarMods objs = ( local n = 0; for o in objs do for m in o.modifiers where m.name == INLAB_ESC_NOME_MOD or m.name == INLAB_ESC_NOME_SEL do n += 1; n )

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms", @"functions\fn_otim_nucleo.ms", @"functions\fn_otim_origem.ms",
                   @"functions\fn_otim_fino.ms", @"functions\fn_otim_escondidas.ms") do
            fileIn (raiz + m)
        INLAB_TESTE_AVISOS = ""
        InLab_Log = fn _logTeste msg tipo:#info =
        (
            if tipo == #warn do INLAB_TESTE_AVISOS += msg + "\n"
            format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA
        )
        limparCena()
        InLab_UltimasEscondidas = #()
        unidadeOriginal = units.SystemType
        units.SystemType = #centimeters

        ---------------------------------------------------------------- CENA DA SONDAGEM (spec seção 5)
        -- Contato: base com topo 10x10 (8x8 segmentos) sob caixa 5x5 (5x5 segmentos).
        local base  = Box name:"esc_base" length:10 width:10 height:2 lengthsegs:8 widthsegs:8 heightsegs:1 pos:[0, 0, 0]
        local caixa = Box name:"esc_caixa" length:5 width:5 height:5 lengthsegs:5 widthsegs:5 heightsegs:1 pos:[0, 0, 2]
        -- Peça interna: esfera (224 triângulos) dentro de caixa.
        local externa = Box name:"esc_externa" length:30 width:30 height:30 pos:[100, 0, 0]
        local esfera  = Sphere name:"esc_esfera" radius:5 segs:16 pos:[100, 0, 15]
        -- Ponta embutida: perna (1 segmento por cm) entrando 3 cm no tampo.
        local tampo = Box name:"esc_tampo" length:60 width:60 height:5 pos:[200, 0, 20]
        local perna = Cylinder name:"esc_perna" radius:2 height:20 heightsegs:20 capsegs:1 sides:12 pos:[200, 0, 3]
        local sondagem = #(base, caixa, externa, esfera, tampo, perna)

        ---------------------------------------------------------------- ANIMADA
        -- Placa 20x20 (células de 5): gaveta animada sobre 4 células, caixa
        -- estática sobre 1 célula (2 triângulos).
        local placa  = Box name:"esc_placa" length:20 width:20 height:2 lengthsegs:4 widthsegs:4 heightsegs:1 pos:[300, 0, 0]
        local gaveta = Box name:"esc_gaveta" length:10 width:10 height:5 pos:[295, 0, 2]
        local cubo   = Box name:"esc_cubo" length:5 width:5 height:5 pos:[307.5, 7.5, 2]
        with animate on ( at time 10 gaveta.pos = [295, -20, 2] )
        sliderTime = 0

        ---------------------------------------------------------------- FUNDO
        -- Ponteira dentro do pé, as duas com o fundo em Z=0 (coplanares).
        local pe = Cylinder name:"esc_pe" radius:2 height:10 heightsegs:1 capsegs:1 sides:12 pos:[400, 0, 0]
        local ponteira = Cylinder name:"esc_ponteira" radius:1.5 height:1 heightsegs:1 capsegs:1 sides:12 pos:[400, 0, 0]

        ---------------------------------------------------------------- INSTÂNCIAS
        local pedestal = Box name:"esc_pedestal" length:10 width:40 height:2 pos:[500, 0, 0]
        local inst1 = Box name:"esc_inst_1" length:4 width:4 height:4 pos:[490, 0, 2]
        local inst2 = instance inst1
        inst2.name = "esc_inst_2"
        inst2.pos = [510, 0, 10] -- solta no ar: a face de baixo não está escondida nela

        ---------------------------------------------------------------- OCLUSORES FORA DA SPEC
        -- Plano (malha aberta) inclinado por cima de uma caixa: as 3 direções
        -- tortas sobem e batem 1 vez no plano (paridade ímpar) — não é "dentro".
        local sobPlano = Box name:"esc_sob_plano" length:4 width:4 height:4 pos:[1200, 0, 0]
        local plano = Plane name:"esc_plano" length:200 width:200 pos:[1200, 0, 8]
        rotate plano (angleaxis 10 [1, 0, 0])
        -- Peça escondida e peça não renderizável envolvendo uma caixa: não cobrem.
        local sobOculta = Box name:"esc_sob_oculta" length:4 width:4 height:4 pos:[700, 0, 0.5]
        local oculta = Box name:"esc_oculta" length:10 width:10 height:10 pos:[700, 0, 0]
        hide oculta
        local sobNaoRender = Box name:"esc_sob_naorender" length:4 width:4 height:4 pos:[800, 0, 0.5]
        local naoRender = Box name:"esc_naorender" length:10 width:10 height:10 pos:[800, 0, 0]
        naoRender.renderable = false
        -- Decalque 0,1 mm acima do topo de uma base, virado para o mesmo lado.
        local baseDecal = Box name:"esc_base_decal" length:10 width:10 height:2 lengthsegs:2 widthsegs:2 pos:[900, 0, 0]
        local decal = Plane name:"esc_decal" length:4 width:4 lengthsegs:1 widthsegs:1 pos:[900, 0, 2.01]
        -- Peça oculta ou não renderizável PELA CAMADA (o nó em si está normal).
        for n in #("esc_camada_oculta", "esc_camada_naorender") do try ( LayerManager.deleteLayerByName n ) catch ()
        local camOculta = LayerManager.newLayerFromName "esc_camada_oculta"
        local camNaoRender = LayerManager.newLayerFromName "esc_camada_naorender"
        local sobCamOculta = Box name:"esc_sob_cam_oculta" length:4 width:4 height:4 pos:[1000, 0, 0.5]
        local cxCamOculta = Box name:"esc_cx_cam_oculta" length:10 width:10 height:10 pos:[1000, 0, 0]
        camOculta.addNode cxCamOculta
        camOculta.ishidden = true
        local sobCamNaoRender = Box name:"esc_sob_cam_naorender" length:4 width:4 height:4 pos:[1050, 0, 0.5]
        local cxCamNaoRender = Box name:"esc_cx_cam_naorender" length:10 width:10 height:10 pos:[1050, 0, 0]
        camNaoRender.addNode cxCamNaoRender
        camNaoRender.renderable = false

        local todos = for o in geometry collect o
        local trisAntes = for o in todos collect (InLab_Otim_Triangulos #(o))
        local nosTxt = for o in todos collect o.name

        ---------------------------------------------------------------- CALCULAR
        local t0 = timeStamp()
        local props = InLab_OtimEscondidas_Calcular todos
        linha ("      Calcular: " + ((timeStamp() - t0) / 1000.0) as string + " s, " + props.count as string + " proposta(s)")
        for p in props do linha ("      " + p.rotulo)
        checar "Calcular não mexe na cena" ((for o in todos collect (InLab_Otim_Triangulos #(o))) as string == trisAntes as string and
                                            (for o in todos where o.modifiers.count > 0 collect o).count == 0)
        checar ("Contato: topo da base sob a caixa = 32 (" + (nFaces props base) as string + ")") ((nFaces props base) == 32)
        checar ("Contato: fundo da caixa apoiada = 50 (" + (nFaces props caixa) as string + ")") ((nFaces props caixa) == 50)
        checar ("Peça interna: esfera dentro da caixa = 224 (" + (nFaces props esfera) as string + ")") ((nFaces props esfera) == 224)
        checar ("Ponta embutida: perna 3 cm no tampo = 84 (" + (nFaces props perna) as string + ")") ((nFaces props perna) == 84)
        checar ("Zeros: caixa externa, tampo (" + (nFaces props externa) as string + ", " + (nFaces props tampo) as string + ")") \
            ((propDe props externa) == undefined and (propDe props tampo) == undefined)
        local pEsf = propDe props esfera
        local pCaixa = propDe props caixa
        checar "Motivo: esfera 'dentro', caixa 'contato'" (pEsf != undefined and pCaixa != undefined and
            (findString pEsf.motivo "dentro 224") != undefined and (findString pCaixa.motivo "contato 50") != undefined)
        checar "Proposta: triângulos antes/depois" (pCaixa != undefined and pCaixa.trisAntes == 140 and pCaixa.trisDepois == 90)

        checar "Peça animada não é proposta" ((propDe props gaveta) == undefined)
        checar ("Face encostada na animada fica: placa só com a célula do cubo = 2 (" + (nFaces props placa) as string + ")") ((nFaces props placa) == 2)
        checar ("Cubo estático sobre a placa: fundo em contato = 2 (" + (nFaces props cubo) as string + ")") ((nFaces props cubo) == 2)

        checar ("Ponteira: tampa e lados dentro do pé = 36, fundo fora (" + (nFaces props ponteira) as string + ")") ((nFaces props ponteira) == 36)
        -- Fundo nunca marcado: nenhuma face marcada virada para baixo em Z=0.
        local noFundo = 0
        for p in props do
        (
            local m = snapshotAsMesh p.no
            for f in p.depois do
            (
                local fv = getFace m f
                local vs = #(getVert m fv.x, getVert m fv.y, getVert m fv.z)
                if (getFaceNormal m f).z < -0.5 and (amax (for v in vs collect v.z)) < 0.01 do noFundo += 1
            )
            delete m
        )
        checar ("Fundo nunca marcado (" + noFundo as string + " face(s) de baixo em Z=0)") (noFundo == 0)

        checar "Instâncias: face escondida só numa instância não entra" ((propDe props inst1) == undefined and (propDe props inst2) == undefined)

        checar ("Plano aberto inclinado não marca a caixa embaixo como 'dentro' (" + (nFaces props sobPlano) as string + ")") \
            ((propDe props sobPlano) == undefined and (propDe props plano) == undefined)
        checar ("Peça escondida não cobre (" + (nFaces props sobOculta) as string + ")") ((propDe props sobOculta) == undefined)
        checar ("Peça não renderizável não cobre (" + (nFaces props sobNaoRender) as string + ")") ((propDe props sobNaoRender) == undefined)
        checar ("Peça em camada oculta não cobre (" + (nFaces props sobCamOculta) as string + ")") ((propDe props sobCamOculta) == undefined)
        checar ("Peça em camada não renderizável não cobre (" + (nFaces props sobCamNaoRender) as string + ")") ((propDe props sobCamNaoRender) == undefined)
        checar ("Decalque coplanar: nem o decalque nem a base (" + (nFaces props decal) as string + ", " + (nFaces props baseDecal) as string + ")") \
            ((propDe props decal) == undefined and (propDe props baseDecal) == undefined)

        local nPts = 0
        for e in InLab_OtimEscondidas_Destaque do nPts += e[2].count
        local somaFaces = 0
        for p in props do somaFaces += p.depois.numberSet
        checar ("Destaque: uma entrada por proposta, 3 pontos por face (" + nPts as string + ")") \
            (InLab_OtimEscondidas_Destaque.count == props.count and nPts == 3 * somaFaces)

        ---------------------------------------------------------------- INSTÂNCIAS APOIADAS
        inst2.pos = [510, 0, 2]
        local pInst = InLab_OtimEscondidas_Calcular #(inst1, inst2)
        checar ("Instâncias apoiadas: uma proposta, 2 faces (" + pInst.count as string + ")") \
            (pInst.count == 1 and pInst[1].depois.numberSet == 2 and (findString pInst[1].rotulo "×2") != undefined)

        ---------------------------------------------------------------- APLICAR
        select base
        -- Desmarcar a linha da base deixa a peça de fora.
        (propDe props base).marcada = false
        local nApl = InLab_OtimEscondidas_Aplicar props
        checar ("Aplicar devolve as marcadas (" + nApl as string + " de " + (props.count - 1) as string + ")") \
            (nApl == props.count - 1 and InLab_UltimasEscondidas.count == nApl)
        checar "Seleção do usuário restaurada" (selection.count == 1 and selection[1] == base)
        checar "Linha desmarcada: base sem modificador" (base.modifiers.count == 0)
        checar "Destaque limpo depois de Aplicar" (InLab_OtimEscondidas_Destaque.count == 0)
        for p in props where p.marcada do
        (
            local ms = InLab_OtimEscondidas_Mods p.no
            local obtido = InLab_Otim_Triangulos #(p.no)
            checar (p.no.name + ": modificadores no topo e " + obtido as string + " = " + p.trisDepois as string + " triângulos") \
                (ms[1] != undefined and ms[2] != undefined and p.no.modifiers[1] == ms[2] and p.no.modifiers[2] == ms[1] and obtido == p.trisDepois)
        )
        -- As faces apagadas são as escondidas: o que sobrou da caixa não tem face em Z=2 virada para baixo.
        local mc = snapshotAsMesh caixa
        local sobrou = 0
        for f = 1 to mc.numfaces where (getFaceNormal mc f).z < -0.5 do sobrou += 1
        delete mc
        checar ("Caixa: nenhuma face de baixo sobrou (" + sobrou as string + ")") (sobrou == 0)

        local nInstApl = InLab_OtimEscondidas_Aplicar pInst
        checar "Instâncias: um modificador só, compartilhado" \
            (nInstApl == 1 and inst1.modifiers.count == 2 and inst2.modifiers.count == 2 and inst1.modifiers[1] == inst2.modifiers[1] and
             (InLab_Otim_Triangulos #(inst2)) == 10)

        ---------------------------------------------------------------- NUNCA EMPILHA
        local pDe = InLab_OtimEscondidas_Calcular #(caixa, esfera)
        checar "Recalcular não propõe peça que já tem o modificador" (pDe.count == 0)
        local forjada = OtimProposta no:caixa alvo:caixa prop:#facesEscondidas antes:90 depois:#{1} trisAntes:90 trisDepois:89
        InLab_OtimEscondidas_Aplicar #(forjada)
        checar "Aplicar não empilha" ((contarMods #(caixa)) == 2)

        ---------------------------------------------------------------- MALHA MUDOU
        local pMud = InLab_OtimEscondidas_Calcular #(base)
        base.lengthsegs = 4
        checar "Malha mudou desde o Calcular: não aplica" (pMud.count == 1 and (InLab_OtimEscondidas_Aplicar pMud) == 0 and base.modifiers.count == 0)
        base.lengthsegs = 8

        ---------------------------------------------------------------- REVERTER
        local nRev = InLab_OtimEscondidas_Reverter()
        checar ("Reverter devolve quantas peças voltaram (" + nRev as string + ")") (nRev == nApl + 1)
        checar "Reverter limpa: nenhum modificador e triângulos de volta" \
            ((contarMods todos) == 0 and (for o in todos collect (InLab_Otim_Triangulos #(o))) as string == trisAntes as string)
        checar "Reverter de novo não faz nada" ((InLab_OtimEscondidas_Reverter()) == 0)

        -- Sem registro (plugin recarregado): Reverter acha os modificadores pelo nome.
        local pR = InLab_OtimEscondidas_Calcular #(esfera)
        InLab_OtimEscondidas_Aplicar pR
        InLab_UltimasEscondidas = #()
        checar "Reverter sem registro remove pelo nome" ((InLab_OtimEscondidas_Reverter()) == 1 and esfera.modifiers.count == 0)

        ---------------------------------------------------------------- PASSOS 1 E 2 PULAM PEÇA COM O PASSO 3
        -- Passo 3 apaga por índice: mexer abaixo dele desloca as faces.
        limparCena()
        InLab_UltimasEscondidas = #()
        InLab_UltimaOtimOrigem = #()
        InLab_UltimoAjusteFino = #()
        InLab_FamiliaAtiva = undefined
        local suporte = Box name:"esc_suporte" length:20 width:20 height:2 pos:[0, 0, 0]
        local vaso = Cylinder name:"esc_vaso" radius:3 height:10 sides:64 heightsegs:1 capsegs:1 pos:[0, 0, 2]
        INLAB_OTIM_META_MANUAL = 150
        local p1 = InLab_Otim_Calcular 1 #(suporte, vaso)
        local p1Vaso = for p in p1 where p.no == vaso collect p
        checar ("Passo 1 propõe baixar os lados do vaso (" + p1.count as string + ")") (p1Vaso.count > 0)
        InLab_Otim_Aplicar 1 p1
        local ladosReduzidos = vaso.sides
        checar ("Passo 1 aplicado: lados " + ladosReduzidos as string + " < 64") (ladosReduzidos < 64)
        local p3 = InLab_Otim_Calcular 3 #(vaso)
        local n3 = InLab_Otim_Aplicar 3 p3
        checar ("Passo 3 aplicado no vaso (" + n3 as string + ")") (n3 == 1)
        local trisVaso = InLab_Otim_Triangulos #(vaso)

        INLAB_TESTE_AVISOS = ""
        InLab_Otim_Reverter 1
        checar ("Reverter do passo 1 não mexe no vaso com passo 3 (lados " + vaso.sides as string + ")") \
            (vaso.sides == ladosReduzidos and (InLab_Otim_Triangulos #(vaso)) == trisVaso)
        checar "Reverter do passo 1 avisa 'tem o passo 3 aplicado'" ((findString INLAB_TESTE_AVISOS "esc_vaso: tem o passo 3 aplicado") != undefined)
        checar "Entrada do vaso continua no registro do passo 1" (InLab_UltimaOtimOrigem.count > 0)

        INLAB_TESTE_AVISOS = ""
        local c1 = InLab_Otim_Calcular 1 #(vaso)
        checar "Calcular do passo 1 pula o vaso e avisa" (c1.count == 0 and (findString INLAB_TESTE_AVISOS "esc_vaso: tem o passo 3 aplicado") != undefined)
        INLAB_TESTE_AVISOS = ""
        InLab_Otim_Aplicar 1 p1Vaso
        checar "Aplicar do passo 1 (linha velha) pula o vaso" (vaso.sides == ladosReduzidos and (findString INLAB_TESTE_AVISOS "tem o passo 3 aplicado") != undefined)

        INLAB_TESTE_AVISOS = ""
        INLAB_OTIM_META_MANUAL = 50
        local c2 = InLab_Otim_Calcular 2 #(suporte, vaso)
        checar "Calcular do passo 2 pula o vaso e avisa" ((for p in c2 where p.no == vaso collect p).count == 0 and
                                                          (findString INLAB_TESTE_AVISOS "esc_vaso: tem o passo 3 aplicado") != undefined)

        -- Depois de reverter o passo 3, o passo 1 volta normalmente.
        InLab_Otim_Reverter 3
        InLab_Otim_Reverter 1
        checar ("Sem o passo 3, Reverter do passo 1 volta os lados (" + vaso.sides as string + ")") (vaso.sides == 64)

        -- Passo 1 em A -> passo 3 em A -> passo 1 em B -> Reverter passo 3 ->
        -- Reverter passo 1 volta A e B (a entrada presa de A não se perde).
        local vasoB = Cylinder name:"esc_vaso_b" radius:3 height:10 sides:64 heightsegs:1 capsegs:1 pos:[50, 0, 0]
        InLab_UltimaOtimOrigem = #()
        INLAB_OTIM_META_MANUAL = 150
        InLab_Otim_Aplicar 1 (InLab_Otim_Calcular 1 #(vaso))
        local ladosA = vaso.sides
        InLab_Otim_Aplicar 3 (InLab_Otim_Calcular 3 #(vaso))
        InLab_Otim_Aplicar 1 (InLab_Otim_Calcular 1 #(vasoB))
        local ladosB = vasoB.sides
        checar ("Passo 1 em A e em B aplicado (A " + ladosA as string + ", B " + ladosB as string + ")") \
            (ladosA < 64 and ladosB < 64 and vaso.sides == ladosA and (InLab_OtimEscondidas_Mods vaso)[2] != undefined)
        InLab_Otim_Reverter 3
        InLab_Otim_Reverter 1
        checar ("Reverter do passo 1 volta A e B (A " + vaso.sides as string + ", B " + vasoB.sides as string + ")") \
            (vaso.sides == 64 and vasoB.sides == 64)
        INLAB_OTIM_META_MANUAL = undefined

        InLab_OtimEscondidas_LimparDestaque()
        limparCena()
        for n in #("esc_camada_oculta", "esc_camada_naorender") do
            try ( LayerManager.deleteLayerByName n ) catch ( linha ("      camada " + n + " não apagada: " + getCurrentException()) )
    )
    catch
    (
        checar ("Exceção no teste: " + getCurrentException()) false
        try ( InLab_OtimEscondidas_LimparDestaque() ) catch()
    )
    units.SystemType = unidadeOriginal
    linha ("FIM: " + (if INLAB_TESTE_FALHAS == 0 then "tudo passou" else (INLAB_TESTE_FALHAS as string + " falha(s)")))
    close INLAB_TESTE_SAIDA
)
