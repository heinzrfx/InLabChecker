/*
================================================================================
 functions\fn_export_gltf.ms — FUNÇÃO 6 (Fase 3.2)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 Exporta a seleção (ou a cena) para glTF/GLB usando o exportador nativo do
 3ds Max 2023+ — o mesmo que consome os glTF Materials gerados pela Função 5.

 RESOLUÇÃO DO EXPORTADOR — mesma estratégia da classe de material:
 varre exporterPlugin.classes procurando "gltf" no nome, em vez de assumir
 o nome exato (que varia entre builds). O nome resolvido fica no log.

 SAÍDA: o log registra o tamanho final do arquivo em MB — insumo direto
 para acompanhar os limites de peso por família antes mesmo da Fase 4.

 PARÂMETROS DE EXPORT (unidades, eixo, embutir texturas): o exportador
 nativo usa as configurações padrão dele; ajustes finos ficam mapeados
 para a Fase 6 conforme o plano ("Confirmar/parametrizar: unidades, eixo
 up, compressão, embutir texturas ou externas").
================================================================================
*/

global InLab_ClasseExportGLTF = undefined   -- cache do exportador resolvido

--------------------------------------------------------------------------------
-- Resolve a classe do exportador glTF varrendo os exportadores registrados.
--------------------------------------------------------------------------------
fn InLab_ResolverExportadorGLTF =
(
    if InLab_ClasseExportGLTF == undefined do
    (
        for cls in exporterPlugin.classes while InLab_ClasseExportGLTF == undefined do
            if (findString (toLower (cls as string)) "gltf") != undefined do
                InLab_ClasseExportGLTF = cls

        if InLab_ClasseExportGLTF != undefined then
            InLab_Log ("Exportador glTF resolvido: " + (InLab_ClasseExportGLTF as string)) tipo:#ok
        else
        (
            InLab_Log "Nenhum exportador glTF registrado nesta instalação do Max." tipo:#err
            InLab_Log "Diagnóstico: rodar no Listener →  for c in exporterPlugin.classes do format \"%\n\" c" tipo:#err
        )
    )
    InLab_ClasseExportGLTF
)

--------------------------------------------------------------------------------
-- Exporta para o caminho informado (.glb ou .gltf).
--   somenteSelecao:true → exporta só a seleção atual
-- Retorna true/false. Loga o tamanho final do arquivo.
--------------------------------------------------------------------------------
fn InLab_ExportGLTF caminho somenteSelecao:true =
(
    local cls = InLab_ResolverExportadorGLTF()
    if cls == undefined then false
    else
    (
        local ok = false
        try
        (
            -- #noPrompt: sem diálogo do exportador — export direto.
            ok = exportFile caminho #noPrompt selectedOnly:somenteSelecao using:cls
        )
        catch
        (
            InLab_Log ("Export FALHOU (exceção do exportador): " + caminho) tipo:#err
        )

        if ok == true then
        (
            local mb = InLab_TamanhoArquivoMB caminho
            InLab_Log ("Export concluído: " + caminho + " · " + (InLab_FormatarMB mb) +
                       (if somenteSelecao then " (seleção)" else " (cena)")) tipo:#ok
            -- Contexto de peso: compara com o teto da família ativa, se houver.
            if InLab_FamiliaAtiva != undefined and mb != undefined do
                InLab_Log ("Referência família '" + InLab_FamiliaAtiva.nome + "': teto .max " +
                           InLab_FamiliaAtiva.maxFileMB as string + " MB (limite de GLB pendente com o Birô).")
            true
        )
        else
        (
            InLab_Log ("Export não concluído: " + caminho) tipo:#err
            false
        )
    )
)
