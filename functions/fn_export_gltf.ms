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

 BUG 10/Set — FALTAVA CHAMAR A JANELA DO REAL-TIME EXPORTER:
 até aqui o botão Exportar só fazia export HEADLESS (#noPrompt, sem
 diálogo nenhum) via InLab_ExportGLTF — o usuário nunca via a janela
 nativa do Real-Time Exporter (a mesma de File > Real-Time Exporter,
 renomeada de "Game Exporter" a partir do Max 2023) pra ajustar formato/
 compressão/caminho na hora. Essa janela NÃO é o exportador clássico
 (exporterPlugin.classes / exportFile) — é um utility plugin à parte, com
 sua própria API global:
     GameExporterOpenDialog()  -> abre a janela (true/false)
     GameExporterHideDialog()  -> fecha (Max 2023+)
     GameExporterShown()       -> true se já está aberta
 Ela não aceita parâmetros via script (formato/caminho são escolhidos pelo
 usuário DENTRO da janela) — por isso InLab_AbrirExportadorRealTime só
 seleciona os objetos certos na viewport antes de abrir (a janela nativa
 exporta a partir da seleção atual do Max) e loga o resultado.
 InLab_ExportGLTF (headless) fica mantida abaixo pra uso futuro (ex.: export
 em lote sem interação), mas o botão da UI agora chama a função nova.

 FIX 24/Set (issue #49) — MODO "CENA INTEIRA" E FOCO DA JANELA:
 sondagem no Max (2024) confirmou os dois pontos da issue:
   1. FOCO FALSO: com a janela já aberta (GameExporterShown() == true), o
      código só logava "trazida ao foco" sem chamar nada. Reproduzido: abri
      a janela, forcei o foco de volta pro Max (windows.setForegroundWindow
      no HWND do Max) e chamei de novo o ramo "já aberta" — o foco
      continuava no Max (windows.getFocus() não mudava). Corrigido com
      InLab_FocarJanelaExportador, que localiza o HWND da janela varrendo o
      desktop (windows.getChildrenHWND (windows.getDesktopHWND()), texto
      "Real-Time Exporter" ou "Game Exporter" — nome varia por build) e usa
      windows.setForegroundWindow nesse HWND. O retorno de
      setForegroundWindow não é confiável (voltou false na sondagem mesmo
      quando o foco mudou de fato) — a confirmação real é comparar
      windows.getFocus() com o HWND depois da chamada. Só loga "trazida ao
      foco" quando essa comparação bate; senão loga aviso.
      DUAS PEGADINHAS achadas na varredura do desktop (tests\test_export_gltf.ms
      pegou as duas por acaso, num teste rodado com o Editor de Script aberto
      numa aba com este arquivo): (a) o campo de texto que
      windows.getChildrenHWND devolve para um controle MXS_Scintilla é o
      CONTEÚDO inteiro dele, não uma legenda — um findString "contém" pelo
      título "Real-Time Exporter" achava esse editor (que tinha a frase no
      código) em vez da janela; a comparação virou EXATA (trim + ==). (b)
      GameExporterHideDialog() só ESCONDE a janela — o HWND sobrevive e
      continua aparecendo na varredura do desktop mesmo depois de "fechada";
      sem filtrar por windows.isWindowVisible, a função continuava achando
      (e "focando") uma janela escondida.
   2. "CENA INTEIRA" NÃO MEXIA NA SELEÇÃO: confirmado que o modo cena
      inteira não limpava nem tocava a seleção do Max antes de abrir a
      janela — só o modo "Somente seleção" fazia `select objs`. A janela do
      Real-Time Exporter é um app Qt à parte (classe "Qt5151QWindowIcon" no
      Max 2024) sem controles filhos expostos como HWND — não dá pra ler
      nem setar por Win32 a opção de escopo dela (dropdown "Export All" /
      outra, visto por captura de tela com windows.snapshot). Também não
      existe API de script pra isso: GameExporter (UtilityPlugin) não expõe
      properties (getPropNames vazio) e não há GameExporterSetOptions nem
      GameExporterGetOptions nesta build; sem arquivo .ini em plugcfg pra
      essa opção (não persiste aí). Sondagem com 1 objeto selecionado e com
      seleção vazia mostrou o dropdown sempre em "Export All" nos dois
      casos — ou seja, ele NÃO reflete a seleção do Max no momento em que a
      janela abre; pode ser um valor lembrado da sessão anterior (mudado
      manualmente pelo usuário) que só é lido de fato quando o Export é
      clicado. Não deu pra confirmar isso sem clicar dentro da janela
      (arriscado via script: só dava pra mirar coordenada de tela, sem
      controle Win32 dedicado, podendo acertar Export/Help por engano) —
      pendente de teste humano (comparar o .glb exportado com o dropdown em
      cada opção). Como não existe alavanca de script pra "opção
      equivalente no exportador" (aceite, opção B), a correção usa a opção
      A do aceite: limpar a seleção do Max antes de abrir em modo "Cena
      inteira", pra pelo menos eliminar o cenário claro do bug (seleção
      antiga sobrando "vazar" pro export). A seleção limpa NÃO é restaurada
      automaticamente: a janela é modeless (o usuário clica Export quando
      quiser, não durante esta chamada), e restaurar a seleção de imediato
      reintroduziria o mesmo risco caso a leitura seja feita no clique do
      Export, não na abertura. O log avisa que a seleção foi limpa e que o
      usuário precisa reselecionar depois de fechar o exportador, se for
      usar outra função do plugin.
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

--------------------------------------------------------------------------------
-- Localiza o HWND da janela nativa do Real-Time Exporter varrendo os filhos
-- do desktop (padrão de sondagem do MCP — ver CLAUDE.md, pegadinhas de
-- dotNetControl/sondagem). O texto do título varia por build ("Real-Time
-- Exporter" a partir do Max 2023, "Game Exporter" em builds antigas).
-- Retorna o HWND (integer) ou undefined se não achar.
--------------------------------------------------------------------------------
fn InLab_LocalizarJanelaExportadorRealTime =
(
    local hwnd = undefined
    try
    (
        -- COMPARAÇÃO EXATA (não findString/contém): o campo de texto que
        -- windows.getChildrenHWND devolve para alguns controles (ex.: um
        -- MXS_Scintilla — o Editor de Script aberto em paralelo) é o
        -- CONTEÚDO inteiro do controle, não uma legenda curta. Sondagem da
        -- issue #49: com o Editor de Script aberto numa aba que tinha o
        -- comentário "Real-Time Exporter" no código-fonte, um findString
        -- (contém) casava com esse editor em vez da janela do exportador —
        -- falso positivo. O título real da janela do exportador é EXATO:
        -- "Real-Time Exporter" (Max 2023+) ou "Game Exporter" (mais antigo).
        -- GameExporterHideDialog() só ESCONDE a janela (windows.isWindowVisible
        -- vira false) — o HWND continua existindo e aparece na varredura do
        -- desktop mesmo depois de "fechada". Sem o filtro de visibilidade, a
        -- função continuaria achando a janela escondida e reportando foco
        -- confirmado numa janela que o usuário não vê. Confirmado na sondagem
        -- da issue #49.
        local filhos = windows.getChildrenHWND (windows.getDesktopHWND())
        for h in filhos while hwnd == undefined do
        (
            local txt = toLower (trimRight (trimLeft (h[5] as string)))
            if (txt == "real-time exporter" or txt == "game exporter") and (windows.isWindowVisible h[1]) do
                hwnd = h[1]
        )
    )
    catch ( InLab_Log ("Falha ao varrer o desktop procurando a janela do exportador: " + (getCurrentException())) tipo:#err )
    hwnd
)

--------------------------------------------------------------------------------
-- Traz a janela do exportador (HWND já localizado) para o foco de verdade,
-- via windows.setForegroundWindow. O retorno dessa chamada NÃO é confiável
-- (sondagem no Max 2024: voltou false mesmo quando o foco mudou de fato) —
-- a confirmação é comparar windows.getFocus() com o HWND alvo depois da
-- chamada. Retorna true só quando essa comparação confirma o foco.
--------------------------------------------------------------------------------
fn InLab_FocarJanelaExportadorRealTime hwnd =
(
    local focado = false
    if hwnd != undefined do
    (
        try
        (
            windows.setForegroundWindow hwnd
            focado = (windows.getFocus() == hwnd)
        )
        catch ( InLab_Log ("Falha ao tentar focar a janela do exportador: " + (getCurrentException())) tipo:#err )
    )
    focado
)

--------------------------------------------------------------------------------
-- Abre a janela NATIVA do Real-Time Exporter (GameExporter) em vez de
-- exportar direto por script. somenteSelecao:true seleciona objs na
-- viewport ANTES de abrir — a janela nativa exporta a partir da seleção
-- atual do Max, então isso garante que ela já abre com o escopo certo.
--
-- somenteSelecao:false ("Cena inteira") LIMPA a seleção do Max antes de
-- abrir (issue #49): não existe API de script pra marcar direto a opção de
-- escopo dentro da janela (GameExporter não expõe properties nesta build,
-- sem GameExporterSetOptions) — limpar a seleção evita o cenário confirmado
-- na sondagem em que uma seleção antiga, deixada de uma ação anterior,
-- "vaza" pro export mesmo em modo cena inteira. A seleção limpa NÃO é
-- restaurada automaticamente — a janela é modeless e fica aberta esperando
-- o usuário clicar Export quando quiser, então restaurar aqui reintroduziria
-- o mesmo risco. Ver cabeçalho do arquivo (FIX 24/Set) pro detalhe da
-- sondagem.
--
-- Retorna true se a janela abriu (ou já estava aberta), false se a API
-- global não existir nesta build (Max < 2017 — sem Real-Time Exporter).
--------------------------------------------------------------------------------
fn InLab_AbrirExportadorRealTime objs somenteSelecao:true =
(
    if somenteSelecao then
    (
        if objs != undefined and objs.count > 0 do select objs
    )
    else
    (
        local qtdAntes = selection.count
        if qtdAntes > 0 do
        (
            clearSelection()
            InLab_Log ("Cena inteira: seleção anterior (" + qtdAntes as string +
                       " objeto(s)) limpa antes de abrir o exportador — evita que a janela " +
                       "exporte só essa seleção. Não é restaurada automaticamente; reselecione " +
                       "depois de fechar o exportador, se precisar.") tipo:#warn
        )
    )

    local jaAberta = try ( GameExporterShown() ) catch ( undefined )
    if jaAberta == true then
    (
        local hwnd = InLab_LocalizarJanelaExportadorRealTime()
        if InLab_FocarJanelaExportadorRealTime hwnd then
            InLab_Log "Real-Time Exporter já estava aberto — janela trazida ao foco." tipo:#ok
        else
            InLab_Log "Real-Time Exporter já estava aberto, mas não foi possível confirmar que a janela foi trazida ao foco." tipo:#warn
        true
    )
    else
    (
        local ok = try ( GameExporterOpenDialog() ) catch ( undefined )
        if ok == true then
        (
            InLab_Log ("Real-Time Exporter aberto" +
                       (if somenteSelecao then " · seleção atual (" + objs.count as string + " objeto(s))" else " · cena inteira") +
                       " — escolha formato/compressão/caminho na própria janela.") tipo:#ok
            local hwnd = InLab_LocalizarJanelaExportadorRealTime()
            if InLab_FocarJanelaExportadorRealTime hwnd then
                InLab_Log "Real-Time Exporter trazido ao foco." tipo:#ok
            true
        )
        else
        (
            InLab_Log "Não foi possível abrir o Real-Time Exporter — GameExporterOpenDialog() falhou ou está indisponível nesta build (requer 3ds Max 2017+)." tipo:#err
            false
        )
    )
)
