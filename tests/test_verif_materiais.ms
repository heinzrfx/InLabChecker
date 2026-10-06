/*
 tests\test_verif_materiais.ms — teste do grupo 7 de verificações (issue #103)
 Spec: docs\superpowers\specs\2026-10-06-verif-materiais-grupo7-design.md
 RODAR NUMA CENA VAZIA (File > New): cria e apaga os objetos de cada caso.
 Resultado: <pasta temp do Max>\inlab_test_verif_materiais.txt (PASS/FAIL por item).
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log, InLab_VerifResults, InLab_ResetarResultados, InLab_ObterFamilia
global InLab_Material_PerfilSlots, InLab_TipoDeMaterial, InLab_ParseJSON, InLab_Produto_Lista
global InLab_Mat_Uso, InLab_Mat_Resolver, InLab_Mat_MapasDoSlot, InLab_Mat_ArquivoDoMapa
global InLab_V23_SlotsPBR, InLab_V24_PNG, InLab_V25_IDsDeMaterial
global InLab_V35_Palha, InLab_V36_Cristal, InLab_V37_ZonasEstofado, InLab_V38_TampoAcessorio
global InLab_TampoAcessorioProduto
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_verif_materiais.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )
    fn statusDe idV =
    (
        local achado = #ausente
        for r in InLab_VerifResults where r.id == idV do achado = r.status
        achado
    )
    fn mensagemDe idV =
    (
        local achado = ""
        for r in InLab_VerifResults where r.id == idV do achado = r.mensagem
        achado
    )
    fn limparCena = ( delete (for o in objects collect o) )
    fn tem txt trecho = (findString txt trecho) != undefined

    local logOriginal = InLab_Log
    local unidadeOriginal = units.SystemType

    try
    (
        for m in #(@"core\versao.ms", @"core\prefs.ms", @"core\struct_result.ms", @"core\struct_familia.ms",
                   @"core\log.ms", @"core\utils.ms",
                   @"familias\familia_corpo_unico.ms", @"familias\familia_pernas_tampo.ms", @"familias\familia_estrutura_estofado.ms",
                   @"functions\fn_json.ms", @"functions\fn_renomear_produto.ms", @"functions\fn_material_convert.ms") do
            fileIn (raiz + m)
        -- Depois dos fileIn: core\log.ms redefine InLab_Log.
        InLab_Log = fn _logTeste msg tipo:#info = ( format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
        units.SystemType = #Centimeters
        limparCena()

        ---------------------------------------------------------------- perfil
        local pl = InLab_Material_PerfilSlots #legacy
        checar "Perfil Legacy: base = texmapDiffuse" (pl.mapaBase[1] == #texmapDiffuse)
        checar "Perfil Legacy: gloss = texmapReflectGlossiness" (pl.mapaGloss[1] == #texmapReflectGlossiness)
        checar "Perfil Legacy: bump = texmapBump, opacidade = texmapOpacity, refração = levelRefract" (pl.bump[1] == #texmapBump and pl.opacMapa[1] == #texmapOpacity and pl.refrVal[1] == #levelRefract)
        local pp = InLab_Material_PerfilSlots #physical
        checar "Perfil Physical: base = baseTexmap, roughness = baseRoughnessTexmap" (pp.mapaBase[1] == #baseTexmap and pp.mapaGloss[1] == #baseRoughnessTexmap)
        local pv = InLab_Material_PerfilSlots #vray
        checar "Perfil VRay: base = texmap_diffuse, opacidade = texmap_opacity" (pv.mapaBase[1] == #texmap_diffuse and pv.opacMapa[1] == #texmap_opacity)
        checar "Perfil #outro = Physical" ((InLab_Material_PerfilSlots #outro).mapaBase[1] == #baseTexmap)
        -- Os nomes do perfil existem de verdade nos materiais da build.
        local mL = CoronaLegacyMtl()
        checar "Perfil Legacy: todos os slots de mapa existem no CoronaLegacyMtl" ((for n in #(pl.mapaBase[1], pl.mapaGloss[1], pl.bump[1], pl.opacMapa[1], pl.refrVal[1]) where not (isProperty mL n) collect n).count == 0)
        local mP = CoronaPhysicalMtl()
        checar "Perfil Physical: todos os slots de mapa existem no CoronaPhysicalMtl" ((for n in #(pp.mapaBase[1], pp.mapaGloss[1], pp.bump[1], pp.opacMapa[1], pp.refrVal[1]) where not (isProperty mP n) collect n).count == 0)

        -- CASOS DAS PRÓXIMAS TASKS ENTRAM AQUI
    )
    catch
    (
        INLAB_TESTE_FALHAS += 1
        linha ("EXCEÇÃO: " + getCurrentException())
    )

    try ( limparCena() ) catch ()
    units.SystemType = unidadeOriginal
    InLab_Log = logOriginal
    linha ("\n" + (if INLAB_TESTE_FALHAS == 0 then "TUDO OK" else (INLAB_TESTE_FALHAS as string + " FALHA(S)")))
    close INLAB_TESTE_SAIDA
    format "Teste concluído — %\n" arqSaida
)
