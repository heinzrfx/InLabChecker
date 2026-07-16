/*
================================================================================
 functions\fn_autouv.ms — FUNÇÃO 2 · "Auto UV" (reescrita · bug 2, 13/Jul)
--------------------------------------------------------------------------------
 PIPELINE ÚNICO (sem submenus, conforme decisão do Rafael), na sequência
 validada: UNFOLD → RELAX → PACK.

   UNFOLD: Unfold3D (Autoseams → Solve → Optimize) — otimização determinística,
           mesmo perfil da referência ArchToolz. Fallbacks internos:
           Flatten por Smoothing Groups → Flatten por ângulo (55°).
   RELAX:  CAUSA-RAIZ DO BUG 2 — o relax falhava silenciosamente (assinatura
           errada engolida por try/catch) e só existia em um dos métodos.
           Agora roda SEMPRE, com cadeia de 3 assinaturas testadas em ordem,
           e o log registra QUAL rodou (ou acusa "relax indisponível").
   PACK:   pack recursivo com padding; fallback Unfold3DPack.

 CLEAN UV (novo): remove modificadores de UV do stack e aplica o UVW Mapping
 Clear no canal padrão — zera o mapeamento para recomeçar limpo.

 UNDO: mesmo padrão das demais funções (registro dedicado + Ctrl+Z).
================================================================================
*/

-- ===== PADRÃO InLab: canal de UV (ponto único de mudança) =====
global INLAB_CANAL_UV = 1

-- Registro de um Auto UV aplicado (para o revert dedicado).
struct AutoUVRecord
(
    no,            -- nó da cena
    modificador    -- instância exata do Unwrap_UVW adicionada
)

global InLab_UltimoAutoUV = #()

--------------------------------------------------------------------------------
-- RELAX com cadeia de assinaturas (a causa do bug 2 era confiar numa só):
-- tenta as variantes documentadas em ordem e retorna o nome da que rodou,
-- ou undefined se nenhuma existir nesta build.
--------------------------------------------------------------------------------
fn InLab_TentarRelax uvw =
(
    local usado = undefined
    try ( uvw.relax 100 0.1 false true ; usado = "relax(100, 0.1)" ) catch()
    if usado == undefined do
        try ( uvw.RelaxOneClick() ; usado = "RelaxOneClick" ) catch()
    if usado == undefined do
        try ( uvw.relaxByFaceAngle 100 0.05 0.05 false ; usado = "relaxByFaceAngle" ) catch()
    usado
)

--------------------------------------------------------------------------------
-- AUTO UV — pipeline único sobre a seleção. Grava no canal INLAB_CANAL_UV.
--------------------------------------------------------------------------------
fn InLab_AutoUV objs padding:0.005 =
(
    InLab_UltimoAutoUV = #()
    local processados = 0
    local normais = #([1,0,0], [-1,0,0], [0,1,0], [0,-1,0], [0,0,1], [0,0,-1])

    undo "InLab AutoUV" on
    (
        max modify mode

        for o in objs where InLab_EhGeometria o do
        (
            local nFaces = (getPolygonCount o)[1]
            if nFaces == 0 then
                InLab_Log (o.name + ": sem faces — ignorado.") tipo:#warn
            else
            (
                select o
                local uvw = Unwrap_UVW()
                uvw.name = "InLab AutoUV"
                modPanel.addModToSelection uvw
                modPanel.setCurrentObject uvw

                local falhou = false
                try ( uvw.setMapChannel INLAB_CANAL_UV )
                catch ( InLab_Log (o.name + ": falha em setMapChannel.") tipo:#err ; falhou = true )

                local nPolysUV = nFaces
                try ( nPolysUV = uvw.numberPolygons() ) catch ( nPolysUV = (GetTriMeshFaceCount o)[1] )
                try ( uvw.selectFaces #{1..nPolysUV} )
                catch ( InLab_Log (o.name + ": falha em selectFaces.") tipo:#err ; falhou = true )

                if not falhou do
                (
                    InLab_Log (o.name + ": Auto UV em processamento (a UI pode congelar alguns segundos)...")
                    try ( windows.processPostedMessages() ) catch()

                    ------------------------------------------------------
                    -- 1 · UNFOLD (Unfold3D → SG → ângulo)
                    ------------------------------------------------------
                    local metodo = undefined
                    try
                    (
                        uvw.Unfold3DAutoseams()
                        uvw.Unfold3DSolve()
                        uvw.Unfold3DOptimize()
                        metodo = "Unfold3D"
                    )
                    catch()
                    if metodo == undefined do
                        try ( uvw.FlattenBySmoothingGroup true true padding ; metodo = "Smoothing Groups" ) catch()
                    if metodo == undefined do
                        try ( uvw.flattenMap 55.0 normais padding true 0 true true ; metodo = "Flatten 55°" ) catch()

                    if metodo == undefined then
                        InLab_Log (o.name + ": TODOS os métodos de unfold falharam — reportar.") tipo:#err
                    else
                    (
                        ------------------------------------------------------
                        -- 2 · RELAX (sempre — correção do bug 2)
                        ------------------------------------------------------
                        local relaxUsado = InLab_TentarRelax uvw
                        if relaxUsado == undefined do
                            InLab_Log (o.name + ": relax indisponível nesta build — resultado pode sair distorcido; reportar.") tipo:#warn

                        ------------------------------------------------------
                        -- 3 · PACK (recursivo com padding; fallback Unfold3D)
                        ------------------------------------------------------
                        local packUsado = undefined
                        try ( uvw.pack 1 padding true true true ; packUsado = "pack recursivo" ) catch()
                        if packUsado == undefined do
                            try ( uvw.Unfold3DPack() ; packUsado = "Unfold3DPack" ) catch()
                        if packUsado == undefined do
                            InLab_Log (o.name + ": pack indisponível — clusters podem ficar fora do 0-1.") tipo:#warn

                        local rec = AutoUVRecord()
                        rec.no = o
                        rec.modificador = uvw
                        append InLab_UltimoAutoUV rec

                        InLab_Log (o.name + ": Auto UV OK · " + metodo +
                                   " → " + (if relaxUsado != undefined then relaxUsado else "sem relax") +
                                   " → " + (if packUsado != undefined then packUsado else "sem pack") +
                                   " · canal " + INLAB_CANAL_UV as string) tipo:#ok
                        processados += 1
                    )
                )
            )
        )
        try ( select objs ) catch()
    )

    InLab_Log ("Auto UV: " + processados as string + " de " + objs.count as string + " objeto(s).")
    processados
)

--------------------------------------------------------------------------------
-- CLEAN UV (novo · bug 2): remove os modificadores de UV existentes e aplica
-- o UVW Mapping Clear no canal padrão. O modificador Clear FICA no stack
-- (colapso é decisão do desenhista — V-11 aponta antes do export).
--------------------------------------------------------------------------------
fn InLab_CleanUV objs =
(
    local n = 0
    undo "InLab CleanUV" on
    (
        for o in objs where InLab_EhGeometria o do
        (
            -- Remove modificadores de UV (Unwrap, UVW Map e afins), de cima
            -- para baixo para não invalidar os índices.
            local removidos = 0
            for i = o.modifiers.count to 1 by -1 do
            (
                local nomeCls = (classof o.modifiers[i]) as string
                if (matchPattern nomeCls pattern:"*Unwrap*") or (matchPattern nomeCls pattern:"*UVW*") do
                (
                    deleteModifier o i
                    removidos += 1
                )
            )

            -- Limpa o canal com o modificador nativo (se existir na build).
            local limpou = false
            try
            (
                local clr = UVW_Mapping_Clear()
                try ( clr.channel = INLAB_CANAL_UV ) catch()
                try ( clr.mapID   = INLAB_CANAL_UV ) catch()
                addModifier o clr
                limpou = true
            )
            catch()

            InLab_Log (o.name + ": Clean UV · " + removidos as string + " modificador(es) de UV removido(s)" +
                       (if limpou then " · canal " + INLAB_CANAL_UV as string + " limpo (colapsar antes do export)" else " · UVW Mapping Clear indisponível nesta build")) tipo:#ok
            n += 1
        )
    )
    InLab_Log ("Clean UV: " + n as string + " objeto(s).")
    n
)

--------------------------------------------------------------------------------
-- Reverte a ÚLTIMA rodada de Auto UV (remove os Unwrap registrados).
--------------------------------------------------------------------------------
fn InLab_ReverterAutoUV =
(
    if InLab_UltimoAutoUV.count == 0 then
        InLab_Log "Nenhum Auto UV registrado nesta sessão para reverter." tipo:#warn
    else
    (
        local revertidos = 0
        undo "InLab Reverter AutoUV" on
        (
            for r in InLab_UltimoAutoUV do
                if isValidNode r.no do
                (
                    try
                    (
                        deleteModifier r.no r.modificador
                        InLab_Log (r.no.name + ": Unwrap removido — UV anterior restaurado.") tipo:#ok
                        revertidos += 1
                    )
                    catch ( InLab_Log (r.no.name + ": modificador não encontrado (colapsado?).") tipo:#warn )
                )
        )
        InLab_UltimoAutoUV = #()
        InLab_Log ("Reversão de UV concluída: " + revertidos as string + " objeto(s).")
    )
)
