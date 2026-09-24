/*
 tests\test_renomear_produto.ms — teste automático de functions\fn_renomear_produto.ms
 RODAR NUMA CENA VAZIA (File > New): cria 4 caixas + materiais de teste e
 apaga as caixas no final. Scripting > Run Script... > este arquivo.
 Resultado: <pasta temp do Max>\inlab_test_renomear.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_ParseJSON, InLab_JSON_Obter, InLab_Log
global InLab_Produto_Lista, InLab_Produto_IndicePorCodigo, InLab_Produto_Texto
global InLab_Produto_ParteValida
global InLab_Produto_Rotulo, InLab_Produto_Normalizar, InLab_Produto_Canal
global InLab_Produto_MateriaisDaSelecao, InLab_Produto_SugerirLigacoes
global InLab_Produto_Aplicar, InLab_Produto_Reverter, InLab_Produto_Renomear
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_renomear.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local logsCapturados = #() -- #(tipo, msg) de cada InLab_Log — p/ conferir log por objeto/material (issue #46)
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA
        flush INLAB_TESTE_SAIDA
        append logsCapturados #(tipo, msg)
    )
    fn logTem tipoAlvo trecho =
    (
        local achou = false
        for l in logsCapturados where not achou and l[1] == tipoAlvo and (findString l[2] trecho) != undefined do achou = true
        achou
    )
    local criados = #()

    try
    (
        fileIn (raiz + @"functions\fn_json.ms")
        fileIn (raiz + @"functions\fn_renomear_produto.ms")

        -- 1. DADOS DO JSON
        local js = "{\"versao_export\": \"nomenclatura-3D-v2\", \"produtos\": [{\"cod_est\": \"0001\", \"nome\": \"TESTE\", \"partes\": [" +
            "{\"nome_parte\": \"Tampo\", \"qualificador\": \"\", \"tipo\": \"P\", \"material_id\": \"ART_P_Tampo\", \"mesh_final\": \"0001\"}, " +
            "{\"nome_parte\": \"Encosto\", \"qualificador\": \"Externo\", \"tipo\": \"T\", \"material_id\": \"ART_T_Encosto_Externo\", \"mesh_final\": \"0001\"}, " +
            "{\"nome_parte\": \"Encosto\", \"qualificador\": \"Interno\", \"tipo\": \"T\", \"material_id\": \"ART_T_Encosto_Interno\", \"mesh_final\": \"0001\"}, " +
            "{\"nome_parte\": \"Gavetas\", \"qualificador\": \"\", \"tipo\": \"\", \"material_id\": \"ART_Gavetas\", \"mesh_final\": \"ART_C_Gavetas\"}]}]}"
        local produtos = InLab_Produto_Lista (InLab_ParseJSON js)
        checar "Lista: 1 produto" (produtos.count == 1)
        checar "Lista vazia p/ JSON sem 'produtos'" ((InLab_Produto_Lista (InLab_ParseJSON "{\"linhas\": []}")).count == 0)
        checar "IndicePorCodigo acha 0001" ((InLab_Produto_IndicePorCodigo produtos "0001") == 1)
        checar "IndicePorCodigo devolve 0 se não existe" ((InLab_Produto_IndicePorCodigo produtos "9999") == 0)
        local partes = InLab_JSON_Obter produtos[1] "partes"
        checar "Rotulo com qualificador" ((InLab_Produto_Rotulo partes[2]) == "Encosto (Externo)")
        checar "Rotulo sem qualificador" ((InLab_Produto_Rotulo partes[1]) == "Tampo")
        checar "Texto de chave ausente = \"\"" ((InLab_Produto_Texto partes[1] "nao_existe") == "")
        checar "Normalizar tira acento e caixa" ((InLab_Produto_Normalizar "Pistão ÇÉ") == "pistao ce")
        checar "Canal tira espaço e símbolo" ((InLab_Produto_Canal "Diffuse Color") == "DiffuseColor")
        checar "Canal vazio vira Mapa" ((InLab_Produto_Canal " #") == "Mapa")

        -- 2. CENA DE TESTE
        local bmpDif = Bitmaptexture name:"dif_qualquer"
        local bmpNorm = Bitmaptexture name:"norm_qualquer"
        local nb = Normal_Bump name:"nb_qualquer" normal_map:bmpNorm
        local mTampo = StandardMaterial name:"tampo_madeira" diffuseMap:bmpDif bumpMap:nb
        local mExt = StandardMaterial name:"Encosto Externo couro"
        local mInt = StandardMaterial name:"encosto_interno"
        local mGav = StandardMaterial name:"Material #99"
        local multiEnc = Multimaterial numsubs:2 name:"multi_encosto"
        multiEnc.materialList[1] = mExt
        multiEnc.materialList[2] = mInt
        local multiMisto = Multimaterial numsubs:2 name:"multi_misto"
        multiMisto.materialList[1] = mTampo
        multiMisto.materialList[2] = mGav
        local b1 = Box name:"obj_tampo" material:mTampo
        local b2 = Box name:"obj_encosto" material:multiEnc pos:[40,0,0]
        local b3 = Box name:"obj_gaveta" material:mGav pos:[80,0,0]
        local b4 = Box name:"obj_misto" material:multiMisto pos:[120,0,0]
        criados = #(b1, b2, b3, b4)

        local mtls = InLab_Produto_MateriaisDaSelecao criados
        checar "MateriaisDaSelecao: 4 únicos, sem o Multimaterial" (mtls.count == 4 and (findItem mtls mTampo) > 0 and (findItem mtls mExt) > 0 and (findItem mtls mInt) > 0 and (findItem mtls mGav) > 0)

        -- 3. SUGESTÃO
        local lig = InLab_Produto_SugerirLigacoes partes mtls
        checar "Sugestão Tampo → tampo_madeira" (lig[1] == mTampo)
        checar "Sugestão Encosto (Externo) → Encosto Externo couro" (lig[2] == mExt)
        checar "Sugestão Encosto (Interno) → encosto_interno" (lig[3] == mInt)
        checar "Sugestão Gavetas → nenhuma" (lig[4] == undefined)

        -- 4. CONFLITO: mesmo material em duas partes bloqueia tudo
        local todos = #(mTampo, mExt, mInt, mGav)
        local nomesAntes = (for m in todos collect m.name) as string
        checar "Conflito: Aplicar devolve false" ((InLab_Produto_Aplicar produtos[1] #(mTampo, mExt, mInt, mTampo) criados) == false)
        checar "Conflito: nenhum material renomeado" ((for m in todos collect m.name) as string == nomesAntes)
        checar "Conflito: nenhum objeto renomeado" (b1.name == "obj_tampo")

        -- 5. APLICAR
        lig[4] = mGav
        logsCapturados = #()
        checar "Aplicar devolve true" ((InLab_Produto_Aplicar produtos[1] lig criados) == true)
        checar "Material Tampo" (mTampo.name == "ART_P_Tampo")
        checar "Material Encosto Externo" (mExt.name == "ART_T_Encosto_Externo")
        checar "Material Encosto Interno" (mInt.name == "ART_T_Encosto_Interno")
        checar "Material Gavetas (tipo vazio, nome provisório)" (mGav.name == "ART_Gavetas")
        local canalDif = ""
        local canalBump = ""
        for i = 1 to (getNumSubTexmaps mTampo) do
        (
            local t = getSubTexmap mTampo i
            if t == bmpDif do canalDif = InLab_Produto_Canal (getSubTexmapSlotName mTampo i)
            if t == nb do canalBump = InLab_Produto_Canal (getSubTexmapSlotName mTampo i)
        )
        linha ("      canais lidos: difuso='" + canalDif + "' bump='" + canalBump + "'")
        checar "Mapa difuso = material_id_canal" (bmpDif.name == "ART_P_Tampo_" + canalDif)
        checar "Mapa bump (Normal_Bump)" (nb.name == "ART_P_Tampo_" + canalBump)
        checar "Mapa dentro do Normal_Bump ganha _2" (bmpNorm.name == "ART_P_Tampo_" + canalBump + "_2")
        checar "Objeto tampo → 0001" (b1.name == "0001")
        checar "Objeto encosto (multi) → 0001" (b2.name == "0001")
        checar "Objeto gaveta → ART_C_Gavetas" (b3.name == "ART_C_Gavetas")
        checar "Objeto misto (2 meshes) NÃO renomeado" (b4.name == "obj_misto")
        checar "Log #ok por material renomeado (issue #46)" (logTem #ok "ART_P_Tampo")
        checar "Log #ok por objeto renomeado (issue #46)" (logTem #ok "0001")

        -- 6. REVERTER
        InLab_Produto_Reverter()
        checar "Reverter: material" (mTampo.name == "tampo_madeira" and mGav.name == "Material #99")
        checar "Reverter: mapas" (bmpDif.name == "dif_qualquer" and bmpNorm.name == "norm_qualquer")
        checar "Reverter: objetos" (b1.name == "obj_tampo" and b3.name == "obj_gaveta")

        -- 7. APLICAR DUAS VEZES COM LIGAÇÃO TROCADA E REVERTER (bug 18/Set no
        -- teste da UI: cada Aplicar zerava o histórico, e o Desfazer não achava
        -- nada — ficaram dois materiais ART_P_Base na cena)
        InLab_Produto_Aplicar produtos[1] lig criados
        InLab_Produto_Aplicar produtos[1] #(mGav, mExt, mInt, undefined) criados
        checar "2ª aplicação: Tampo agora é o material da gaveta" (mGav.name == "ART_P_Tampo")
        InLab_Produto_Reverter()
        checar "Reverter após 2 aplicações: materiais originais" (mTampo.name == "tampo_madeira" and mGav.name == "Material #99" and mExt.name == "Encosto Externo couro")
        checar "Reverter após 2 aplicações: mapas originais" (bmpDif.name == "dif_qualquer" and nb.name == "nb_qualquer")
        checar "Reverter após 2 aplicações: objetos originais" (b1.name == "obj_tampo" and b2.name == "obj_encosto" and b3.name == "obj_gaveta")
        InLab_Produto_Reverter()
        checar "Reverter de novo: nada muda" (mTampo.name == "tampo_madeira" and b1.name == "obj_tampo")

        -- 8. PARTE INVÁLIDA: material_id ou mesh_final vazio/null (issue #46)
        -- "Pe": material_id "" (mas mesh_final válido) — material não pode
        -- ser renomeado p/ "", mas o objeto ainda tem mesh_final válido.
        -- "Base": mesh_final null (mas material_id válido) — o material é
        -- renomeado normalmente, mas o objeto não pode ganhar nome "".
        local js2 = "{\"produtos\": [{\"cod_est\": \"0002\", \"partes\": [" +
            "{\"nome_parte\": \"Pe\", \"qualificador\": \"\", \"tipo\": \"P\", \"material_id\": \"\", \"mesh_final\": \"0002\"}, " +
            "{\"nome_parte\": \"Base\", \"qualificador\": \"\", \"tipo\": \"P\", \"material_id\": \"ART_P_Base\", \"mesh_final\": null}]}]}"
        local produtos2 = InLab_Produto_Lista (InLab_ParseJSON js2)
        local partes2 = InLab_JSON_Obter produtos2[1] "partes"
        checar "ParteValida: material_id vazio é inválido" (not (InLab_Produto_ParteValida partes2[1] "material_id"))
        checar "ParteValida: mesh_final null é inválido" (not (InLab_Produto_ParteValida partes2[2] "mesh_final"))
        checar "ParteValida: material_id preenchido é válido" (InLab_Produto_ParteValida partes2[2] "material_id")
        checar "ParteValida: mesh_final preenchido é válido" (InLab_Produto_ParteValida partes2[1] "mesh_final")

        local mPe = StandardMaterial name:"pe_material"
        local mBase = StandardMaterial name:"base_material"
        local bPe = Box name:"obj_pe" material:mPe pos:[160,0,0]
        local bBase = Box name:"obj_base" material:mBase pos:[200,0,0]
        append criados bPe
        append criados bBase

        logsCapturados = #()
        checar "Aplicar (partes inválidas) devolve true" ((InLab_Produto_Aplicar produtos2[1] #(mPe, mBase) #(bPe, bBase)) == true)
        checar "material_id vazio: material NÃO renomeado" (mPe.name == "pe_material")
        checar "material_id vazio: material NÃO fica com nome vazio" (mPe.name != "")
        checar "material_id vazio: mesh_final da parte ainda é válido — objeto renomeado" (bPe.name == "0002")
        checar "mesh_final null: material da parte é renomeado normalmente" (mBase.name == "ART_P_Base")
        checar "mesh_final null: objeto NÃO renomeado" (bBase.name == "obj_base")
        checar "mesh_final null: objeto NÃO fica com nome vazio" (bBase.name != "")
        checar "Log #warn p/ parte com material_id vazio" (logTem #warn "material_id")
        checar "Log #warn p/ parte com mesh_final vazio" (logTem #warn "mesh_final")

        InLab_Produto_Reverter()
        checar "Reverter (partes inválidas): material Pe volta" (mPe.name == "pe_material")
        checar "Reverter (partes inválidas): objeto Pe volta" (bPe.name == "obj_pe")
        checar "Reverter (partes inválidas): material Base volta" (mBase.name == "base_material")

        -- 9. REVERTER com alvo apagado da cena: o catch tem que logar, não
        -- engolir em silêncio (issue #46).
        local bTemp = Box name:"obj_temp" pos:[240,0,0]
        InLab_Produto_Renomear bTemp "NOME_TEMP"
        checar "Renomear direto: nome mudou" (bTemp.name == "NOME_TEMP")
        delete bTemp
        logsCapturados = #()
        InLab_Produto_Reverter()
        checar "Reverter com alvo apagado: catch loga (não engole em silêncio)" (logTem #warn "obj_temp")

        -- Ctrl+Z nativo NÃO é testável daqui: rodado de dentro do script,
        -- `max undo` desfaz o script inteiro (inclusive a criação das caixas),
        -- não só a renomeação — confirmado em 18/Set. Conferir à mão pela UI.
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
