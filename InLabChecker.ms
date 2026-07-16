/*
================================================================================
 InLabChecker.ms — ENTRY POINT
 InLab · Artefacto · v0.9 (correções 13/Jul)
--------------------------------------------------------------------------------
 O QUE ESTE ARQUIVO FAZ:
 1. Descobre em qual pasta o plugin está instalado (INLAB_ROOT).
 2. VALIDA A INSTALAÇÃO: confere se TODOS os módulos existem antes de
    carregar qualquer um. Instalação incompleta gera um diálogo listando
    exatamente quais arquivos faltam — em vez da exceção críptica do
    fileIn no primeiro arquivo ausente.
 3. Carrega os módulos na ordem de dependência: structs → log → utils →
    famílias → funções → UI.
 4. Abre a janela principal.

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

        -- FORWARD DECLARATION: InLab_AbrirUI é definida em ui\rollout_main.ms,
        -- carregado mais abaixo. Sem esta declaração, o parser compila o nome
        -- como variável LOCAL implícita deste bloco (que nunca recebe valor)
        -- em vez de resolver para a global criada pelo fileIn.
        global InLab_AbrirUI

        ------------------------------------------------------------------
        -- MANIFESTO DE MÓDULOS — ordem de carga = ordem de dependência.
        -- Ao criar um módulo novo nas próximas fases, adicionar AQUI.
        ------------------------------------------------------------------
        local modulos = #(
            -- 1. CORE (structs primeiro; log antes da UI)
            @"core\struct_result.ms",
            @"core\struct_familia.ms",
            @"core\log.ms",
            @"core\utils.ms",
            -- 2. FAMÍLIAS (spec v2.0, seções 2.2/2.3)
            @"familias\familia_corpo_unico.ms",
            @"familias\familia_pernas_tampo.ms",
            @"familias\familia_estrutura_estofado.ms",
            @"familias\familia_estrutura_modular.ms",
            @"familias\familia_translacao.ms",
            @"familias\familia_rotacao.ms",
            @"familias\familia_giro_assento.ms",
            @"familias\familia_movimento_especial.ms",
            -- 3. FUNÇÕES DE PREPARAÇÃO (Fases 1 e 2)
            @"functions\fn_prooptimizer.ms",
            @"functions\fn_realworldscale.ms",
            @"functions\fn_checktexture.ms",
            @"functions\fn_autouv.ms",
            @"functions\fn_material_convert.ms",
            @"functions\fn_export_gltf.ms",
            @"functions\fn_utilidades.ms",
            -- 4. VERIFICAÇÃO (Fase 4 · grupos 1-3) + relatório (Fase 5)
            @"verifications\verif_peso_poly.ms",
            @"verifications\verif_pivot.ms",
            @"verifications\verif_nomenclatura.ms",
            @"verifications\verif_geometria.ms",
            @"verifications\verif_animacao.ms",
            @"report\report_generator.ms",
            @"verifications\verif_orquestrador.ms",
            -- 4. UI
            @"ui\rollout_main.ms"
        )

        ------------------------------------------------------------------
        -- VALIDAÇÃO DA INSTALAÇÃO: checa tudo ANTES de carregar qualquer
        -- coisa, para reportar a lista completa de ausências de uma vez.
        ------------------------------------------------------------------
        local ausentes = for m in modulos where not (doesFileExist (INLAB_ROOT + m)) collect m

        if ausentes.count > 0 then
        (
            local msg = "Instalação incompleta em:\n" + INLAB_ROOT + "\n\nArquivo(s) ausente(s):\n"
            for a in ausentes do msg += "  • " + a + "\n"
            msg += "\nExtraia o pacote completo do InLabChecker mantendo a estrutura de pastas."
            messageBox msg title:"InLabChecker — Instalação Incompleta"
            format "InLabChecker: %/% módulos ausentes. Carga abortada.\n" ausentes.count modulos.count
        )
        else
        (
            for m in modulos do fileIn (INLAB_ROOT + m)

            -- O prefixo :: força a busca no escopo global em runtime
            -- (redundância intencional com a forward declaration).
            ::InLab_AbrirUI()
        )
    )
)
