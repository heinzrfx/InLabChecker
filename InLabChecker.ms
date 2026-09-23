/*
================================================================================
 InLabChecker.ms — ENTRY POINT
 InLab · Artefacto · versão em core\versao.ms (INLAB_VERSAO) — desde a v0.12
 (23/09/2026, issue #9) a versão não é mais escrita neste cabeçalho.
 (Reload 29/Jul)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 1. Descobre em qual pasta o plugin está instalado (INLAB_ROOT).
 2. VALIDA A INSTALAÇÃO: confere se TODOS os módulos existem antes de
    carregar qualquer um.
 3. Carrega os módulos na ordem de dependência: structs → log → utils →
    famílias → funções → UI.
 4. Abre a janela principal.
 5. Expõe InLab_RecarregarPlugin() — refaz o fileIn de TODOS os módulos
    na mesma ordem (INLAB_MODULOS), sem precisar reabrir o Max.

 COMO EXECUTAR NO 3DS MAX:
    Scripting > Run Script... > selecionar este arquivo (InLabChecker.ms)
================================================================================
*/
(
    local caminhoOrigem = getSourceFileName()
    if caminhoOrigem == undefined then
    (
        messageBox "Execute o InLabChecker via Scripting > Run Script (não cole o código no Listener),\npara que o plugin consiga localizar seus módulos." title:"InLabChecker"
        throw "InLabChecker: caminho raiz não identificado (getSourceFileName == undefined)."
    )
    else
    (
        global INLAB_ROOT = getFilenamePath caminhoOrigem

        global InLab_AbrirUI
        global InLab_RecarregarPlugin
        global InLab_Log            
        global InLabChecker_Rollout

        ------------------------------------------------------------------
        -- MANIFESTO DE MÓDULOS — global agora, pra ser reaproveitado pelo
        -- reload sem duplicar a lista. Ordem de carga = ordem de dependência.
        -- Ao criar um módulo novo, adicionar AQUI (só aqui).
        ------------------------------------------------------------------
        global INLAB_MODULOS = #(
            -- 1. CORE
            -- versao.ms primeiro: INLAB_VERSAO tem que valer antes da legenda
            -- de InLabChecker_Rollout ser avaliada (issue #9).
            @"core\versao.ms",
            -- prefs.ms: ini em #plugcfg, fora de INLAB_ROOT (issue #10)
            @"core\prefs.ms",
            @"core\struct_result.ms",
            @"core\struct_familia.ms",
            @"core\log.ms",
            @"core\utils.ms",
            -- 2. FAMÍLIAS
            @"familias\familia_corpo_unico.ms",
            @"familias\familia_pernas_tampo.ms",
            @"familias\familia_estrutura_estofado.ms",
            @"familias\familia_estrutura_modular.ms",
            @"familias\familia_translacao.ms",
            @"familias\familia_rotacao.ms",
            @"familias\familia_giro_assento.ms",
            @"familias\familia_movimento_especial.ms",
            -- 3. FUNÇÕES DE PREPARAÇÃO
            -- fn_json.ms primeiro: parser genérico consumido pela seção de
            -- Produto (ui\rollout_main.ms) — só depende de core\log.ms.
            @"functions\fn_json.ms",
            -- updater (issue #12): usa fn_json, versao.ms e prefs.ms
            @"functions\fn_updater.ms",
            -- renomeação pelo JSON de produto — depende de fn_json.ms.
            @"functions\fn_renomear_produto.ms",
            @"functions\fn_prooptimizer.ms",
            @"functions\fn_realworldscale.ms",
            @"functions\fn_checktexture.ms",
            @"functions\fn_autouv.ms",
            -- Real World Fix: usa InLab_Instancias de fn_autouv.ms
            @"functions\fn_realworldfix.ms",
            @"functions\fn_material_convert.ms",
            @"functions\fn_material_utils.ms",
            @"functions\fn_export_gltf.ms",
            @"functions\fn_utilidades.ms",
            -- 4. VERIFICAÇÃO + relatório
            @"verifications\verif_peso_poly.ms",
            @"verifications\verif_pivot.ms",
            @"verifications\verif_nomenclatura.ms",
            @"verifications\verif_geometria.ms",
            @"verifications\verif_animacao.ms",
            -- medição de UV (issue #1): só leitura, usada pelo Auto UV no log
            @"verifications\verif_uv.ms",
            @"report\report_generator.ms",
            @"verifications\verif_orquestrador.ms",
            -- 5. UI
            -- kit antes de tudo: header e (depois) as seções leem cor dele.
            @"ui\kit.ms",
            @"ui\header.ms",
            @"ui\splash.ms",
            @"ui\rollout_main.ms"
        )

        ------------------------------------------------------------------
        -- RELOAD: refaz o fileIn de tudo, na mesma ordem, sem duplicar
        -- a lista de módulos. Fecha a UI antes (evita redefinir rollout
        -- aberto) e reabre no final.
        ------------------------------------------------------------------
        fn InLab_RecarregarPlugin =
        (
            try ( destroyDialog InLabChecker_Rollout ) catch()

            local ausentes = for m in INLAB_MODULOS where not (doesFileExist (INLAB_ROOT + m)) collect m
            if ausentes.count > 0 then
            (
                local msg = "Reload abortado — arquivo(s) ausente(s):\n"
                for a in ausentes do msg += "  • " + a + "\n"
                messageBox msg title:"InLabChecker — Reload"
                false
            )
            else
            (
                local falhou = false
                for m in INLAB_MODULOS do
                (
                    try ( fileIn (INLAB_ROOT + m) )
                    catch
                    (
                        format "InLabChecker Reload — falha em %\n" m
                        falhou = true
                    )
                )
                if not falhou then
                (
                    ::InLab_AbrirUI()
                    InLab_Log "Plugin recarregado com sucesso." tipo:#ok
                )
                not falhou
            )
        )

        ------------------------------------------------------------------
        -- VALIDAÇÃO + CARGA INICIAL
        ------------------------------------------------------------------
        local ausentes = for m in INLAB_MODULOS where not (doesFileExist (INLAB_ROOT + m)) collect m

        if ausentes.count > 0 then
        (
            local msg = "Instalação incompleta em:\n" + INLAB_ROOT + "\n\nArquivo(s) ausente(s):\n"
            for a in ausentes do msg += "  • " + a + "\n"
            msg += "\nExtraia o pacote completo do InLabChecker mantendo a estrutura de pastas."
            messageBox msg title:"InLabChecker — Instalação Incompleta"
            format "InLabChecker: %/% módulos ausentes. Carga abortada.\n" ausentes.count INLAB_MODULOS.count
        )
        else
        (
            for m in INLAB_MODULOS do fileIn (INLAB_ROOT + m)
            ::InLab_AbrirUI()
        )
    )
)