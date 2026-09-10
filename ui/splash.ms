/*
================================================================================
 ui\splash.ms — Tela de abertura (item 8, 13/Jul)
--------------------------------------------------------------------------------
 CAUSA-RAIZ DO ERRO "No outer local variable references permitted here":
 eventos de controles dotNet (Tick, MouseDown etc.) rodam num escopo que NÃO
 enxerga variáveis `local` do rollout que os declarou — só GLOBAIS e funções
 de nível superior. Um handler dotNet que tenta ler uma `local` (ex.: um
 timer guardado em variável local) quebra na compilação, sempre, em
 qualquer máquina — não é falha de ambiente, é regra da linguagem.

 CORREÇÃO: nenhum handler abaixo referencia local do rollout — só a função
 de nível superior InLab_Splash_Encerrar (que só usa globais).

 CONTRATO COM rollout_main.ms: expõe InLab_MostrarSplash(), chamada de
 dentro de InLab_AbrirUI ANTES de abrir a janela principal — o splash é
 não-bloqueante (fecha sozinho por timer ou clique) e não decide quando a
 janela principal abre; isso é responsabilidade de rollout_main.ms.

 AJUSTE 10/Set — SPLASH NÃO ACOMPANHAVA A JANELA DO PLUGIN:
 createDialog sem pos: deixava o splash cair onde o Windows/Max decidisse
 (centralizado na tela, no teste do Rafael) — sem relação nenhuma com onde
 a janela principal ia abrir. Referência ArchToolz: painel sempre no TOPO
 da tela. Agora InLab_MostrarSplash calcula a posição explicitamente a
 partir do WorkingArea (canto superior direito, mesmo canto-padrão do
 InLabChecker_Rollout — ver "AJUSTE 10/Set" espelhado em rollout_main.ms),
 em vez de depender do posicionamento automático do SO.
================================================================================
*/

-- Declarada antes do rollout para garantir que o addEventHandler a encontre
fn InLab_Splash_Encerrar sender arg =
(
    try ( InLabSplash.dntTimer.Enabled = false ) catch()
    try ( destroyDialog InLabSplash ) catch()
)

rollout InLabSplash "" width:360 height:220
(
    dotNetControl pnlFundo  "System.Windows.Forms.Panel" pos:[0,0] width:360 height:220
    dotNetControl lblTitulo "System.Windows.Forms.Label" pos:[0,70] width:360 height:44
    dotNetControl lblSub    "System.Windows.Forms.Label" pos:[0,118] width:360 height:26
    
    -- CORREÇÃO: Removido o dotNetControl. O Timer é apenas uma variável na memória.
    local dntTimer  

    on InLabSplash open do
    (
        -- Inicializa o Timer como um objeto não-visual
        dntTimer = dotNetObject "System.Windows.Forms.Timer"

        local preto  = (dotNetClass "System.Drawing.Color").Black
        local branco = (dotNetClass "System.Drawing.Color").White
        local cinza  = (dotNetClass "System.Drawing.Color").FromArgb 190 190 190

        pnlFundo.BackColor = preto

        lblTitulo.Text = "InLabChecker"
        lblTitulo.ForeColor = branco
        lblTitulo.BackColor = preto
        lblTitulo.Font = dotNetObject "System.Drawing.Font" "Arial" 22.0 ((dotNetClass "System.Drawing.FontStyle").Bold)
        lblTitulo.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter

        lblSub.Text = "Artefacto"
        lblSub.ForeColor = cinza
        lblSub.BackColor = preto
        lblSub.Font = dotNetObject "System.Drawing.Font" "Arial" 12.0
        lblSub.TextAlign = (dotNetClass "System.Drawing.ContentAlignment").MiddleCenter

        dntTimer.Interval = 1200
        
        -- CORREÇÃO: Liga o evento Tick do dotNetObject diretamente à função global
        dotnet.addEventHandler dntTimer "Tick" InLab_Splash_Encerrar
        
        dntTimer.Enabled = true
    )

    -- Passamos 'undefined' duas vezes apenas para respeitar os parâmetros (sender, arg) da função
    on pnlFundo MouseDown evt do InLab_Splash_Encerrar undefined undefined
)

--------------------------------------------------------------------------------
-- Ponto de entrada esperado por rollout_main.ms (InLab_AbrirUI): exibe o
-- splash sem bloquear — a janela principal abre em seguida, sobrepondo-o.
--------------------------------------------------------------------------------
fn InLab_MostrarSplash =
(
    try ( destroyDialog InLabSplash ) catch()

    -- Topo da tela, no MESMO lado (esquerda/direita) que InLabChecker_Rollout
    -- vai abrir — lê o InLab_LadoPainel definido em rollout_main.ms, pra
    -- splash e janela principal ficarem sempre alinhados. InLab_LadoPainel
    -- só existe depois que rollout_main.ms carrega (ordem do manifesto em
    -- InLabChecker.ms) — como splash.ms só LÊ o global dentro da função,
    -- não na definição, isso resolve certo em tempo de execução; o "2" é
    -- só um default de segurança caso a função seja chamada antes disso.
    local area = (dotNetClass "System.Windows.Forms.Screen").PrimaryScreen.WorkingArea
    local lado = if InLab_LadoPainel != undefined then InLab_LadoPainel else 2
    local x = if lado == 1 then area.Left else (area.Right - 360)
    local y = area.Top

    createDialog InLabSplash 360 220 pos:[x, y] style:#(#style_border) modal:false
)