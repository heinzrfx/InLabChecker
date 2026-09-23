/*
 tests\test_familia_ativa.ms — teste automático da família ativa (23/09/2026)
 Cobre InLab_Produto_SugerirFamilia (functions\fn_renomear_produto.ms),
 InLab_DefinirFamiliaAtiva / InLab_FamiliaRotulo (core\struct_familia.ms) e
 que InLab_RodarVerificacoes roda de ponta a ponta com a família definida.
 Se o export real Contract/Health estiver na pasta de trabalho, confere também
 que todo produto dele recebe sugestão.
 RODAR NUMA CENA VAZIA (File > New): cria 1 caixa e apaga no final.
 Resultado: <pasta temp do Max>\inlab_test_familia_ativa.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_ParseJSON, InLab_JSON_Obter, InLab_JSON_LerArquivoUTF8, InLab_Log
global InLab_Produto_Lista, InLab_Produto_SugerirFamilia
global InLab_Familias, InLab_FamiliaAtiva, InLab_DefinirFamiliaAtiva, InLab_FamiliaRotulo
global InLab_RodarVerificacoes, InLab_VerifResults
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_familia_ativa.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    local criados = #()

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms", @"familias\familia_pernas_tampo.ms",
                   @"familias\familia_estrutura_estofado.ms", @"familias\familia_estrutura_modular.ms",
                   @"familias\familia_translacao.ms", @"familias\familia_rotacao.ms",
                   @"familias\familia_giro_assento.ms", @"familias\familia_movimento_especial.ms",
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms",
                   @"functions\fn_otim_nucleo.ms",
                   @"functions\fn_realworldscale.ms",
                   @"verifications\verif_peso_poly.ms", @"verifications\verif_pivot.ms",
                   @"verifications\verif_nomenclatura.ms", @"verifications\verif_geometria.ms",
                   @"verifications\verif_animacao.ms", @"report\report_generator.ms",
                   @"verifications\verif_orquestrador.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        -- 1. SUGESTÃO PELO PRODUTO
        fn produto classe nome animacao partes =
        (
            local js = "{\"classe\": \"" + classe + "\", \"nome\": \"" + nome + "\", \"animacao\": " + animacao + ", \"partes\": ["
            for i = 1 to partes.count do
                js += (if i > 1 then ", " else "") + "{\"nome_parte\": \"" + partes[i][1] + "\", \"mesh_final\": \"" + partes[i][2] + "\"}"
            InLab_ParseJSON (js + "]}")
        )
        local casos = #(
            #("MESA DE JANTAR", "MESA X", "false", #(#("Tampo", "0001")), "pernas_tampo"),
            #("MESA DE CHA", "MESA DE CHÁ Y", "false", #(), "pernas_tampo"),
            #("MODULO", "MODULO Z", "false", #(), "estrutura_modular"),
            #("POLTRONA", "POLTRONA W", "false", #(), "estrutura_estofado"),
            #("APARADOR", "APARADOR V", "false", #(), "corpo_unico"),
            #("CADEIRA", "CADEIRA PICASSO - GIRATORIA", "true", #(#("Assento", "07119271")), "giro_assento"),
            #("POLTRONA", "POLTRONA SLUE GIRATÓRIA", "true", #(), "giro_assento"),
            #("APARADOR", "APARADOR C/ GAVETAS", "true", #(#("Gavetas", "ART_C_Gavetas")), "translacao"),
            #("BUFFET", "BUFFET ROSSETTI", "true", #(#("Portas", "ART_P_Portas"), #("Gavetas", "ART_P_Gavetas")), "rotacao"),
            #("BICAMA", "BICAMA ZORN", "true", #(#("Estrutura", "07144006")), "movimento_especial")
        )
        for c in casos do
        (
            local sug = InLab_Produto_SugerirFamilia (produto c[1] c[2] c[3] c[4])
            checar ("Sugestão: " + c[2] + " → " + c[5] + " (veio '" + sug[1] + "': " + sug[2] + ")") (sug[1] == c[5])
        )
        local semTabela = InLab_Produto_SugerirFamilia (produto "LUMINARIA" "LUMINARIA Q" "false" #())
        checar "Classe fora da tabela: sem sugestão" (semTabela[1] == "" and (findString semTabela[2] "fora da tabela") != undefined)
        checar "Produto sem classe: sem sugestão" ((InLab_Produto_SugerirFamilia (produto "" "SEM" "false" #()))[1] == "")
        checar "Toda sugestão existe em InLab_Familias" (
            (for c in casos where (for f in InLab_Familias where f.nome == c[5] collect f).count == 0 collect c).count == 0)

        -- 2. DEFINIR FAMÍLIA ATIVA
        checar "8 famílias registradas" (InLab_Familias.count == 8)
        InLab_DefinirFamiliaAtiva "pernas_tampo"
        checar "Definir: pernas_tampo" (InLab_FamiliaAtiva != undefined and InLab_FamiliaAtiva.nome == "pernas_tampo")
        InLab_DefinirFamiliaAtiva "nao_existe"
        checar "Nome inválido mantém a anterior" (InLab_FamiliaAtiva != undefined and InLab_FamiliaAtiva.nome == "pernas_tampo")
        InLab_DefinirFamiliaAtiva ""
        checar "\"\" limpa" (InLab_FamiliaAtiva == undefined)
        checar "Rótulo legível" ((InLab_FamiliaRotulo "giro_assento") == "Giro de Assento")
        checar "Rótulo de nome desconhecido = o próprio nome" ((InLab_FamiliaRotulo "xyz") == "xyz")
        checar "Todas as famílias têm rótulo próprio" (
            (for f in InLab_Familias where (InLab_FamiliaRotulo f.nome) == f.nome collect f).count == 0)

        -- 3. VERIFICAÇÕES RODAM COM A FAMÍLIA DEFINIDA
        local b = Box length:50 width:50 height:40 mapcoords:true
        append criados b
        InLab_DefinirFamiliaAtiva "corpo_unico"
        local aprovado = InLab_RodarVerificacoes InLab_FamiliaAtiva
        checar "RodarVerificacoes devolve booleano" (isKindOf aprovado BooleanClass)
        checar ("Resultados registrados (" + InLab_VerifResults.count as string + ")") (InLab_VerifResults.count >= 10)
        checar "V-19 (unidade) está entre os resultados" ((for r in InLab_VerifResults where r.id == "V-19" collect r).count == 1)

        -- 4. EXPORT REAL (opcional): todo produto recebe sugestão
        local arqReal = @"G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Pack_Contract_Rafa\nomenclatura_export_linha contract_health.json"
        if doesFileExist arqReal then
        (
            local produtos = InLab_Produto_Lista (InLab_ParseJSON (InLab_JSON_LerArquivoUTF8 arqReal))
            local semSug = for p in produtos where (InLab_Produto_SugerirFamilia p)[1] == "" collect p
            checar ("Export real: " + produtos.count as string + " produtos, " + semSug.count as string + " sem sugestão") (produtos.count > 0 and semSug.count == 0)
        )
        else linha "SKIP  Export real não encontrado"
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    for o in criados where isValidNode o do delete o
    InLab_FamiliaAtiva = undefined
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
