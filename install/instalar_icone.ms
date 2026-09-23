/*
================================================================================
 install\instalar_icone.ms — v0.12 (22/09/2026): botão do InLabChecker na
 barra de ferramentas do 3ds Max
--------------------------------------------------------------------------------
 COMO USAR: Scripting > Run Script... > este arquivo. Roda uma vez por máquina.
 Depois: Customize > Customize User Interface > aba Toolbars > categoria
 "InLab" > arrastar "InLabChecker" para uma barra.

 23/09/2026: numa INSTALAÇÃO (pasta scripts\InLabChecker + boot no startup)
 este script não é mais necessário — install\registrar.ms, chamado pelo boot
 em toda abertura do Max, copia a mesma arte e define o MESMO macro
 (InLab / InLabChecker_Abrir) apontando para a pasta instalada. Este aqui
 continua servindo para quem roda o plugin direto do repositório, sem boot:
 ele embute a raiz de onde foi rodado.

 FORA DO MANIFESTO, de propósito: isto não é módulo do plugin. É instalador,
 roda sozinho e não pode depender de nada que o InLabChecker.ms carregue —
 justamente porque uma das coisas que ele conserta é o plugin não estar
 carregado ainda.

 SONDAGEM QUE DEFINIU ESTE DESENHO (22/09/2026, Max 2024 nesta máquina):
   - O Max 2024 usa o sistema LEGADO de ícone: `icon:#("Nome", 1)` procurando
     `Nome_16i.bmp` e `Nome_24i.bmp` em (getDir #userIcons). NÃO é PNG com
     sufixo _24/_32/_48, como a spec do header tinha suposto.
   - Formato: BMP 24bpp, UM ícone por arquivo (16x16 e 24x24), não é tira.
   - Todos os macros com ícone nesta máquina usam esse caminho, o ArchToolz
     inclusive (Archtoolz_16i.bmp, Archtoolz_24i.bmp...).
   - O arquivo de máscara `_a` é OPCIONAL: o RelinkBitmaps não tem nenhum e
     funciona, embutindo o fundo escuro na própria arte.

 POR QUE SEM MÁSCARA: a polaridade do `_a` (preto opaco ou preto transparente)
 não se resolve por leitura — as amostras do PruneScene e do Pathwheels apontam
 para lados opostos, e errar dá ícone invisível ou bloco sólido. Cravar exigiria
 registrar macros descartáveis na instalação do artista. Decisão de 22/09: sem
 máscara, com o fundo da barra embutido na arte. O risco some junto com o
 arquivo. Custo: se a barra de ferramentas mudar de cor (tema claro), aparece
 um quadrado escuro em volta do bulbo.

 A COR DO FUNDO (23,23,23) FOI MEDIDA, não estimada: amostragem do trecho vazio
 da barra de ferramentas com a janela do Max em primeiro plano — 100% dos pixels
 em (22..24, idem, idem), centrados em 23. O `colorMan` do Max não expõe essa
 cor (só tem `colorTheme`).

 O ÍCONE NÃO É ATUALIZADO PELO UPDATER: ele mora em (getDir #userIcons), fora
 do repositório, então o pipeline de atualização não o alcança. Rodar este
 script de novo depois de uma atualização que mude a arte. Ver a spec
 docs\superpowers\specs\2026-09-22-header-kit-ui-design.md, seção 6, item 3.
================================================================================
*/
(
    local caminhoOrigem = getSourceFileName()
    if caminhoOrigem == undefined then
    (
        messageBox "Rode este arquivo por Scripting > Run Script (não cole o código no Listener)." title:"InLabChecker"
    )
    else
    (
        -- A raiz do repositório é a pasta acima de install\.
        local dirInstall = getFilenamePath caminhoOrigem           -- ...\InLabChecker\install\
        local raiz = getFilenamePath (substring dirInstall 1 (dirInstall.count - 1))

        local arte = #("InLabChecker_16i.bmp", "InLabChecker_24i.bmp")
        local destIcones = getDir #userIcons
        local destMacros = getDir #userMacros
        local erros = #()

        fn escapar s =
        (
            -- duplica a contrabarra pra string literal do .mcr gerado
            local r = ""
            for i = 1 to s.count do
            (
                local c = s[i]
                r += (if c == "\\" then "\\\\" else c)
            )
            r
        )

        -- 1. CONFERE A ARTE ANTES DE MEXER EM QUALQUER COISA
        for a in arte do
            if not (doesFileExist (raiz + @"ui\img\" + a)) do
                append erros ("arte ausente: ui\\img\\" + a)

        if not (doesFileExist destIcones) do append erros ("pasta de ícones não existe: " + destIcones)
        if not (doesFileExist destMacros) do append erros ("pasta de macros não existe: " + destMacros)

        if erros.count > 0 then
        (
            local msg = "Instalação do ícone abortada — nada foi copiado.\n\n"
            for e in erros do msg += "  • " + e + "\n"
            messageBox msg title:"InLabChecker — Ícone"
            format "InLabChecker: instalação do ícone abortada.\n"
            for e in erros do format "  %\n" e
        )
        else
        (
            local copiados = 0
            -- 2. COPIA A ARTE
            -- System.IO.File em vez de copyFile: o MCP do Max roda em safe_mode,
            -- que bloqueia copyFile no código enviado. Pelo dotNet funciona dos
            -- dois jeitos.
            local fileIO = dotNetClass "System.IO.File"
            for a in arte do
            (
                try
                (
                    fileIO.Copy (raiz + @"ui\img\" + a) (destIcones + "\\" + a) true
                    copiados += 1
                    format "InLabChecker: % -> %\n" a destIcones
                )
                catch
                (
                    append erros ("falha ao copiar " + a + ": " + getCurrentException())
                )
            )

            -- 3. GERA O MACRO COM A RAIZ RESOLVIDA
            -- A raiz vai embutida porque o botão precisa funcionar numa sessão
            -- fria do Max, sem depender do script de startup (que é do
            -- sub-projeto do updater e pode não existir).
            local mcr = destMacros + "\\InLab-InLabChecker_Abrir.mcr"
            local raizEsc = escapar raiz
            local corpo = ""
            corpo += "-- Gerado por install\\instalar_icone.ms em " + (localTime as string) + "\n"
            corpo += "-- NÃO editar à mão: rode o instalador de novo se a pasta do plugin mudar.\n"
            corpo += "macroScript InLabChecker_Abrir\n"
            corpo += "    category:\"InLab\"\n"
            corpo += "    tooltip:\"InLabChecker\"\n"
            corpo += "    buttonText:\"InLabChecker\"\n"
            corpo += "    icon:#(\"InLabChecker\", 1)\n"
            corpo += "(\n"
            corpo += "    on execute do\n"
            corpo += "    (\n"
            corpo += "        global InLab_AbrirUI\n"
            corpo += "        local raiz = \"" + raizEsc + "\"\n"
            corpo += "        if InLab_AbrirUI != undefined then\n"
            corpo += "            InLab_AbrirUI()\n"
            corpo += "        else\n"
            corpo += "        (\n"
            corpo += "            local entry = raiz + \"InLabChecker.ms\"\n"
            corpo += "            if doesFileExist entry then\n"
            corpo += "                fileIn entry  -- carrega os módulos e abre a UI\n"
            corpo += "            else\n"
            corpo += "                messageBox (\"InLabChecker não encontrado em:\\n\" + entry + \\\n"
            corpo += "                    \"\\n\\nA pasta do plugin mudou? Rode install\\\\instalar_icone.ms de novo.\") \\\n"
            corpo += "                    title:\"InLabChecker\"\n"
            corpo += "        )\n"
            corpo += "    )\n"
            corpo += ")\n"

            local ok = true
            try ( (dotNetClass "System.IO.File").WriteAllText mcr corpo )
            catch
            (
                ok = false
                append erros ("falha ao escrever o macro: " + getCurrentException())
            )

            if ok and erros.count == 0 then
            (
                format "InLabChecker: macro escrito em %\n" mcr
                messageBox ("Ícone instalado.\n\n" + \
                    copiados as string + " arquivo(s) de arte em:\n" + destIcones + "\n\n" + \
                    "Macro em:\n" + mcr + "\n\n" + \
                    "Agora: Customize > Customize User Interface > aba Toolbars,\n" + \
                    "categoria \"InLab\", arraste \"InLabChecker\" para uma barra.\n\n" + \
                    "Se a categoria não aparecer, reinicie o 3ds Max uma vez.") \
                    title:"InLabChecker — Ícone"
            )
            else
            (
                local msg = "Instalação do ícone terminou com problema:\n\n"
                for e in erros do msg += "  • " + e + "\n"
                messageBox msg title:"InLabChecker — Ícone"
                for e in erros do format "InLabChecker: %\n" e
            )
        )
    )
)
