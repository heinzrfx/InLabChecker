/*
 tests\test_familia_ativa.ms — teste automático da família ativa (23/09/2026)
 Cobre InLab_Produto_Familia (functions\fn_renomear_produto.ms: família pela
 "natureza" do produto, issue #138), InLab_DefinirFamiliaAtiva /
 InLab_FamiliaRotulo (core\struct_familia.ms) e que InLab_RodarVerificacoes
 roda de ponta a ponta com a família definida. Se o export v7 estiver na
 pasta de trabalho, confere também que todo produto dele tem natureza válida.
 RODAR NUMA CENA VAZIA (File > New): cria 1 caixa e apaga no final.
 Resultado: <pasta temp do Max>\inlab_test_familia_ativa.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_ParseJSON, InLab_JSON_Obter, InLab_JSON_LerArquivoUTF8, InLab_Log
global InLab_Produto_Lista, InLab_Produto_Familia
global InLab_Familias, InLab_FamiliaAtiva, InLab_DefinirFamiliaAtiva, InLab_FamiliaRotulo, InLab_FamiliasEsperadas
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
                   @"familias\familia_corpo_portas_gavetas.ms", @"familias\familia_base_cabeceira.ms",
                   @"familias\familia_translacao.ms", @"familias\familia_rotacao.ms",
                   @"familias\familia_giro_assento.ms", @"familias\familia_movimento_especial.ms",
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms", @"functions\fn_export_gltf.ms",
                   @"functions\fn_material_convert.ms",
                   @"functions\fn_otim_nucleo.ms",
                   @"functions\fn_realworldscale.ms",
                   @"verifications\verif_peso_poly.ms", @"verifications\verif_pivot.ms",
                   @"verifications\verif_nomenclatura.ms", @"verifications\verif_geometria.ms",
                   @"verifications\verif_malha.ms", @"verifications\verif_animacao.ms",
                   @"verifications\verif_uv.ms", @"functions\fn_autouv.ms", @"functions\fn_checktexture.ms",
                   @"verifications\verif_mapeamento.ms", @"verifications\verif_materiais.ms", @"report\report_generator.ms",
                   @"verifications\verif_orquestrador.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )

        -- 1. FAMÍLIA PELA NATUREZA DO PRODUTO (08/10/2026, issue #138)
        fn produto natureza =
        (
            local campo = if natureza == undefined then "" else ("\"natureza\": \"" + natureza + "\", ")
            InLab_ParseJSON ("{\"cod_est\": \"0001\", " + campo + "\"classe\": \"MESA LATERAL\", \"partes\": []}")
        )
        for nat in #("corpo_unico", "pernas_tampo", "estrutura_estofado", "estrutura_modular", "rotacao", "translacao") do
        (
            local fam = InLab_Produto_Familia (produto nat)
            checar ("Natureza '" + nat + "' vira a família (veio '" + fam[1] + "')") (fam[1] == nat)
        )
        -- A classe não decide mais nada: MESA LATERAL com natureza corpo_unico
        -- (a sugestão antiga dava pernas_tampo).
        checar "Classe não interfere: MESA LATERAL + corpo_unico = corpo_unico" ((InLab_Produto_Familia (produto "corpo_unico"))[1] == "corpo_unico")
        checar "Maiúsculas e espaços são tolerados (' Corpo_Unico ')" ((InLab_Produto_Familia (produto " Corpo_Unico "))[1] == "corpo_unico")
        local semNat = InLab_Produto_Familia (produto undefined)
        checar ("Produto sem natureza: sem família, motivo pede novo export ('" + semNat[2] + "')") (semNat[1] == "" and (findString semNat[2] "natureza") != undefined)
        local vazia = InLab_Produto_Familia (produto "")
        checar "Natureza vazia: sem família" (vazia[1] == "")
        local estranha = InLab_Produto_Familia (produto "mesa_magica")
        checar ("Natureza desconhecida: sem família ('" + estranha[2] + "')") (estranha[1] == "" and (findString estranha[2] "mesa_magica") != undefined)
        checar "Nenhum produto: sem família" ((InLab_Produto_Familia undefined)[1] == "")

        -- 2. DEFINIR FAMÍLIA ATIVA
        checar "10 famílias registradas" (InLab_Familias.count == 10)
        -- 08/10/2026 (issue #147): o esperado sai do manifesto, não de 8 fixo.
        local manif = #(@"core\log.ms", @"familias\familia_corpo_unico.ms", @"familias\familia_rotacao.ms", @"functions\fn_json.ms")
        checar "Esperadas: conta os arquivos familias\ do manifesto (2)" ((InLab_FamiliasEsperadas modulos:manif) == 2)
        checar "Esperadas: sem manifesto devolve undefined" ((InLab_FamiliasEsperadas modulos:#none) == undefined)
        local manifReal = undefined
        try
        (
            local txtManif = (dotNetClass "System.IO.File").ReadAllText (raiz + "InLabChecker.ms")
            -- Entradas @"familias\... do INLAB_MODULOS no arquivo do entry point.
            manifReal = ((dotNetClass "System.Text.RegularExpressions.Regex").Matches txtManif "@\"familias\\\\").Count
        )
        catch ()
        checar ("Esperadas pelo manifesto real = famílias registradas (" + manifReal as string + ")") (manifReal == InLab_Familias.count)
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

        -- 4. EXPORT REAL (opcional): export v7, todo produto tem natureza válida
        local arqReal = @"G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\produtos_teste_plugin_rafa_v7.json"
        if doesFileExist arqReal then
        (
            local produtos = InLab_Produto_Lista (InLab_ParseJSON (InLab_JSON_LerArquivoUTF8 arqReal))
            local semFam = for p in produtos where (InLab_Produto_Familia p)[1] == "" collect p
            checar ("Export v7: " + produtos.count as string + " produtos, " + semFam.count as string + " sem família " +
                    (for p in semFam collect (InLab_Produto_Familia p)[2]) as string) (produtos.count > 0 and semFam.count == 0)
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
