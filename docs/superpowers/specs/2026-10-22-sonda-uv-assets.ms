-- Sonda: padrão de mapeamento (canal 1) dos assets da cena. Só leitura.
-- Saída: (getDir #temp)\inlab_sonda_uv_assets.txt
global SondaUV_Saida = (getDir #temp) + "\\inlab_sonda_uv_assets.txt"
global SondaUV_MaxAmostra = 3000

fn SondaUV_Q arr p = if arr.count == 0 then 0 else arr[amax 1 (amin arr.count ((p*arr.count) as integer))]
fn SondaUV_F v = formattedPrint v format:".2f"
-- bitmap sem arquivo (filename undefined) quebrava o filenameFromPath
fn SondaUV_Arq f = if f == undefined or f == "" then "(sem arquivo)" else filenameFromPath f
fn pct a b = if b == 0 then "-" else ((100*a/b) as integer) as string + "%"

-- texturas de um material (recursivo, só bitmaps)
fn SondaUV_Bitmaps t lista = (
    if t == undefined then return lista
    local c = classof t
    if c == Bitmaptexture then append lista ("BMP " + (SondaUV_Arq t.filename) + " rw:" + t.coords.realWorldScale as string + " tile:" + (SondaUV_F t.coords.U_Tiling) + "/" + (SondaUV_F t.coords.V_Tiling) + " W:" + (SondaUV_F t.coords.W_angle) + " ch:" + t.coords.mapChannel as string + (if t.coords.realWorldScale then " rwW:" + (SondaUV_F t.coords.realWorldWidth) else ""))
    else if c == CoronaBitmap then append lista ("CBMP " + (SondaUV_Arq t.filename) + " rw:" + t.realWorldScale as string + " scale:" + t.uvwScale as string + " w:" + (SondaUV_F t.wAngle) + " ch:" + t.uvwChannel as string + " env:" + t.enviroMapping as string)
    else if c == CoronaTriplanar then append lista ("TRIPLANAR scale:" + t.scale as string + " rot:" + t.rotation as string + " space:" + t.space as string)
    for i = 1 to (getNumSubTexmaps t) do SondaUV_Bitmaps (getSubTexmap t i) lista
    lista
)
fn SondaUV_TexDoMat m = (
    local lista = #()
    if m == undefined then return lista
    for i = 1 to (getNumSubTexmaps m) do SondaUV_Bitmaps (getSubTexmap m i) lista
    -- materiais aninhados (layered/blend)
    for i = 1 to (getNumSubMtls m) do (local sm = getSubMtl m i; if sm != undefined then join lista (SondaUV_TexDoMat sm))
    makeUniqueArray lista
)

-- métricas de um conjunto de faces (triângulos da malha)
fn SondaUV_Medir m faces = (
    local esc = #(); local est = #()
    local eixoU = 0; local eixoAmbos = 0; local uVert = 0; local uLongo = 0; local vLongo = 0; local n = 0
    local passo = amax 1 (faces.count / SondaUV_MaxAmostra)
    for i = 1 to faces.count by passo do (
        local f = faces[i]
        local fv = getFace m f; local tv = meshop.getMapFace m 1 f
        local p1 = getVert m fv.x; local p2 = getVert m fv.y; local p3 = getVert m fv.z
        local u1 = meshop.getMapVert m 1 tv.x; local u2 = meshop.getMapVert m 1 tv.y; local u3 = meshop.getMapVert m 1 tv.z
        local e1 = p2-p1; local e2 = p3-p1
        local du1 = u2-u1; local du2 = u3-u1
        local det = du1.x*du2.y - du2.x*du1.y
        local nn = cross e1 e2
        if abs det > 1e-12 and length nn > 1e-9 then (
            local dPdu = (e1*du2.y - e2*du1.y)/det
            local dPdv = (e2*du1.x - e1*du2.x)/det
            local lu = length dPdu; local lv = length dPdv
            if lu > 1e-9 and lv > 1e-9 then (
                n += 1
                -- escala UV por cm e esticamento (pelos comprimentos dos tangentes + ângulo)
                local cosuv = abs (dot (dPdu/lu) (dPdv/lv))
                local s = sqrt (1.0/(lu*lv*(sqrt (amax 1e-6 (1-cosuv*cosuv)))))
                append esc s
                append est ((amax lu lv)/(amin lu lv) + 2*cosuv)
                local tu = dPdu/lu; local tvv = dPdv/lv
                local au = amax (abs tu.x) (amax (abs tu.y) (abs tu.z))
                local av = amax (abs tvv.x) (amax (abs tvv.y) (abs tvv.z))
                if au > 0.985 then eixoU += 1
                if au > 0.985 and av > 0.985 then eixoAmbos += 1
                if abs tu.z > 0.8 then uVert += 1
                -- aresta mais longa do triângulo
                local e3 = p3-p2
                local lg = e1; if length e2 > length lg then lg = e2; if length e3 > length lg then lg = e3
                local lgn = normalize lg
                -- só conta face alongada (2:1)
                local curta = amin (length e1) (amin (length e2) (length e3))
                if (length lg) > 2*curta then (
                    if abs (dot lgn tu) > 0.9 then uLongo += 1
                    if abs (dot lgn tvv) > 0.9 then vLongo += 1
                )
            )
        )
    )
    sort esc; sort est
    local ruins = 0; for v in est where v > 1.6 do ruins += 1
    "amostra:" + n as string + " escala(UV/cm) med:" + (formattedPrint (SondaUV_Q esc 0.5) format:".4f") + " p10:" + (formattedPrint (SondaUV_Q esc 0.1) format:".4f") + " p90:" + (formattedPrint (SondaUV_Q esc 0.9) format:".4f") + \
    " | estica med:" + (SondaUV_F (SondaUV_Q est 0.5)) + " >1.6:" + (pct ruins n) + \
    " | U em eixo do mundo:" + (pct eixoU n) + " U e V em eixo:" + (pct eixoAmbos n) + " | U vertical:" + (pct uVert n) + \
    " | face alongada: U ao longo:" + (pct uLongo n) + " V ao longo:" + (pct vLongo n)
)

fn SondaUV_Objeto o arq = (
    local m = snapshotAsMesh o
    format "\n=== % (%) faces:% verts:%\n" o.name (classof o.baseobject) m.numfaces m.numverts to:arq
    if not (meshop.getMapSupport m 1) then (format "  SEM canal 1\n" to:arq; delete m; return ok)
    local nmv = meshop.getNumMapVerts m 1
    format "  mapVerts/verts: % (1 = sem cortes; alto = muitas ilhas/emendas)\n" (SondaUV_F (nmv as float / m.numverts)) to:arq
    -- extensão do UV
    local mn = [1e9,1e9,0]; local mx = [-1e9,-1e9,0]
    local passoV = amax 1 (nmv/20000)
    for i = 1 to nmv by passoV do (local v = meshop.getMapVert m 1 i; mn.x = amin mn.x v.x; mn.y = amin mn.y v.y; mx.x = amax mx.x v.x; mx.y = amax mx.y v.y)
    format "  UV de [%,%] a [%,%]\n" (SondaUV_F mn.x) (SondaUV_F mn.y) (SondaUV_F mx.x) (SondaUV_F mx.y) to:arq
    -- por material ID
    local porId = #()
    for f = 1 to m.numfaces do (
        local id = getFaceMatID m f
        if porId[id] == undefined then porId[id] = #()
        append porId[id] f
    )
    local mat = o.material
    for id = 1 to porId.count where porId[id] != undefined do (
        local sub = mat
        if classof mat == Multimaterial then (
            local k = findItem mat.materialIDList id
            sub = if k > 0 then mat.materialList[k] else undefined
        )
        local nomeSub = if sub == undefined then "-" else (sub.name + " (" + (classof sub) as string + ")")
        format "  id% faces:% mat:%\n" id porId[id].count nomeSub to:arq
        for t in (SondaUV_TexDoMat sub) do format "      %\n" t to:arq
        format "      %\n" (SondaUV_Medir m porId[id]) to:arq
    )
    delete m
)

(
    local arq = openFile SondaUV_Saida mode:"wt"
    format "Sonda UV dos assets · %\n" localTime to:arq
    local t0 = timestamp()
    for o in geometry where not o.isHidden do (
        try (SondaUV_Objeto o arq) catch (format "  ERRO em %: %\n" o.name (getCurrentException()) to:arq)
    )
    format "\nTempo: %s\n" ((timestamp() - t0)/1000.0) to:arq
    close arq
)
