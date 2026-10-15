/*
 tests\test_export_pasta_materialx.ms — teste de InLab_Export_GarantirPastaMaterialX
 (functions\fn_export_gltf.ms). 15/10/2026: no Max 2025 o exportador glTF
 grava <getDir #export>\TempMaterialX\*.mtlx; com o projeto em Arquivos de
 Programas o GLB saía preto. RODAR NUMA CENA VAZIA (File > New). Mexe na pasta
 de export da sessão e devolve a original no final.
 A pasta sem permissão é simulada com um ARQUIVO chamado TempMaterialX
 (makeDir falha do mesmo jeito, sem precisar de administrador).
 Resultado: <pasta temp do Max>\inlab_test_export_pasta_materialx.txt
*/
-- Declarados ANTES do bloco: o bloco é compilado antes dos fileIn rodarem.
global InLab_Log
global InLab_Export_PastaGravavel, InLab_Export_GarantirPastaMaterialX
global INLAB_TESTE_SAIDA, INLAB_TESTE_FALHAS, INLAB_TESTE_LOGS
(
    local dirTeste = getFilenamePath (getSourceFileName())
    local raiz = substring dirTeste 1 (dirTeste.count - 6) -- tira "tests\"
    local arqSaida = (getDir #temp) + "\\inlab_test_export_pasta_materialx.txt"
    INLAB_TESTE_SAIDA = createFile arqSaida encoding:#utf8
    INLAB_TESTE_FALHAS = 0
    INLAB_TESTE_LOGS = #()
    fn linha s = ( format "%\n" s to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA )
    fn checar nome ok =
    (
        if not ok do INLAB_TESTE_FALHAS += 1
        linha ((if ok then "PASS  " else "FAIL  ") + nome)
    )

    local logOriginal = InLab_Log
    InLab_Log = fn _logTeste msg tipo:#info =
    (
        append INLAB_TESTE_LOGS tipo
        format "      [LOG %] %\n" tipo msg to:INLAB_TESTE_SAIDA; flush INLAB_TESTE_SAIDA
    )
    local exportOriginal = getDir #export
    local base = (getDir #temp) + "\\inlab_teste_materialx"
    local io = dotNetClass "System.IO.File"

    try
    (
        for m in #(@"core\utils.ms", @"functions\fn_material_convert.ms", @"functions\fn_material_utils.ms",
                   @"functions\fn_export_gltf.ms") do
            fileIn (raiz + m)

        -- 1. PASTA GRAVÁVEL: não troca nada e não deixa o arquivo de teste.
        local boa = base + "\\boa"
        makeDir boa all:true
        checar "Gravável: PastaGravavel true" (InLab_Export_PastaGravavel boa)
        checar "Gravável: arquivo de teste apagado" (not (doesFileExist (boa + "\\TempMaterialX\\inlab_teste_escrita.tmp")))
        setDir #export boa
        INLAB_TESTE_LOGS = #()
        checar "Gravável: Garantir devolve true" ((InLab_Export_GarantirPastaMaterialX()) == true)
        checar "Gravável: pasta de export mantida" ((trimRight (getDir #export) "\\") == boa)
        checar "Gravável: nada no log" (INLAB_TESTE_LOGS.count == 0)

        -- 2. PASTA SEM PERMISSÃO (simulada): troca para uma gravável e avisa.
        local ruim = base + "\\ruim"
        makeDir ruim all:true
        io.WriteAllText (ruim + "\\TempMaterialX") "bloqueia o makeDir"
        checar "Bloqueada: PastaGravavel false" (not (InLab_Export_PastaGravavel ruim))
        setDir #export ruim
        INLAB_TESTE_LOGS = #()
        checar "Bloqueada: Garantir devolve true (achou alternativa)" ((InLab_Export_GarantirPastaMaterialX()) == true)
        local nova = trimRight (getDir #export) "\\"
        checar "Bloqueada: pasta de export trocada" (nova != ruim)
        checar "Bloqueada: pasta nova é InLab_export" ((findString nova "InLab_export") != undefined)
        checar "Bloqueada: pasta nova gravável" (InLab_Export_PastaGravavel nova)
        checar "Bloqueada: aviso no log" ((findItem INLAB_TESTE_LOGS #warn) > 0)
    )
    catch
    (
        checar ("Exceção inesperada: " + (getCurrentException())) false
    )

    -- Limpeza (mesmo depois de exceção): pasta de export original e arquivos.
    setDir #export exportOriginal
    try ( (dotNetClass "System.IO.Directory").Delete base true ) catch()
    InLab_Log = logOriginal
    linha ("RESUMO: " + (if INLAB_TESTE_FALHAS == 0 then "TODOS PASSARAM" else INLAB_TESTE_FALHAS as string + " FALHA(S)"))
    close INLAB_TESTE_SAIDA
)
