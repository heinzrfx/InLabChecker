# Grupo 6 · Verificações de geometria (V-07, V-08, V-09, V-10, V-13)

Issue #102, parte do epic #38. Desenho aprovado em 05/10/2026.

## 1. Objetivo

Ligar ao motor de verificação as cinco checagens de malha do grupo 6 da spec v2.0 (seção 5, "Pesadas"), com critérios que façam sentido para os blocos reais do piloto. A spec funcional fica fora do repo (documento interno, repo público): v2.0 em `G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Specs\plugin_spec_inlab_v2.pdf`, critérios da V-07 à V-13 na v1.0 (`...\SCRIPT GLB\plugin_spec_inlab.md`, seção 2.4).

Sucesso: as cinco verificações rodam pela UI e pelo motor, com teste, sem travar o Max em peça de centenas de milhares de triângulos, e sem reprovar peça correta do piloto.

## 2. O que a sondagem mostrou (Max 2024, 05/10/2026)

Medido em Aparador Zucchi e Puff Dorset do piloto, e em primitivas.

- **Ratio vértices/triângulos da malha fica sempre perto de 0,50.** A V-07 literal ("total_vertices / total_triangles ≤ 1,2") nunca reprova. O que separa peça boa de ruim é o vértice como o GLB conta: separado por costura de UV, por quina dura e por troca de material. No glTF exportado deu 0,57 (BASE003), 0,69 (cilindros) e 1,59 (duas peças do Puff com normais editadas).
- **Estimar esse vértice pela malha erra.** Uma chave por canto (vértice + UV + smoothing group) acertou primitivas e peças sem UV, mas ficou 5% a 10% acima em peças com smoothing groups que dividem bits e 44% abaixo nas peças com normais editadas. Essas normais o `snapshotAsMesh` não mostra.
- **Exportar a cena para glTF e ler o arquivo é exato e rápido:** 0,6 s (Aparador, 79 mil triângulos) e 0,3 s (Puff), mais 50 ms para ler o JSON. Cada nó do glTF sai com o nome do objeto no Max.
- **Arestas abertas existem em peça correta.** As duas bases do Puff Dorset têm 88 cada (fundo aberto). O passo 3 da Otimização apaga faces escondidas, e depois do colapso que a V-11 exige isso também vira aresta aberta.
- **No Mesh do Max, aresta cujas duas faces vizinhas têm o mesmo sentido já aparece em `meshop.getOpenEdges`.** No Editable Poly, a face invertida vira costura aberta. Medido: 0 casos nos arquivos do piloto.
- **Ngons nas peças do piloto são tampas de cilindro**, planas, com smoothing próprio e a 90° do lado.
- **Velocidade (Teapot de 262 mil triângulos):** `getFace` em todas as faces 74 ms, volume com sinal 0,5 s, smoothing e normal 0,17 s, `getOpenEdges` 28 ms. O `Dictionary` do MaxScript usado como mapa de arestas levou 565 s, e a chave inteira estourou. **Nenhuma verificação usa `Dictionary` em laço por canto ou por face.** Duplicata e contagem de únicos saem de `sort` nativo sobre um array de doubles.

## 3. Regras

| ID | Nome no relatório | Critério | Severidade |
|---|---|---|---|
| V-07 | Ratio vértices/triângulos (GLB) | Por objeto: vértices do glTF ÷ triângulos do glTF ≤ `cfg.maxRatioVT` (1,2). | Crítica com `provisorio:true` (advertência enquanto `INLAB_LIMITES_PROVISORIOS`) |
| V-08 | Malha fechada (arestas abertas) | Por objeto: arestas abertas que não são da V-10. Lista objeto e contagem. | Advertência (`critico:false`) |
| V-09 | Faces e objetos duplicados | (a) faces coincidentes no mesmo objeto: os 3 cantos na mesma posição, em qualquer ordem, ou seja, no mesmo sentido ou costas com costas; (b) objeto em cima de outro: mesma contagem de triângulos e mesmo bbox de mundo. | Crítica |
| V-10 | Normais invertidas | (a) vizinhas com sentido oposto: aresta aberta com uma gêmea no mesmo sentido; (b) elemento fechado com volume negativo (peça do avesso). | Crítica |
| V-13 | Ngons em superfície curva | Ngon (5+ lados) não plana, ou que divide smoothing group com uma vizinha a mais de 15°. | Crítica |

Tolerância de posição: `units.decodeValue "0.01mm"`. Ângulos: 1° (planaridade) e 15° (curvatura).

### 3.1 V-07 · pelo exportador

1. Resolve o exportador com `InLab_ResolverExportadorGLTF` (`fn_export_gltf.ms`). Sem exportador: `#warning` "não medido: nenhum exportador glTF instalado".
2. Exporta a cena inteira com `exportFile <temp>\inlab_v07\cena.gltf #noPrompt selectedOnly:false using:cls`. Na sondagem o exportador ignorou `selectedOnly:true` e exportou tudo, então não adianta exportar só a seleção.
3. Lê o `.gltf` com `InLab_ParseJSON`. Para cada nó com `mesh`, soma `accessors[POSITION].count` e `accessors[indices].count / 3` de todas as primitives.
4. Liga o nó ao objeto pelo nome, só para objetos do universo da verificação (`InLab_ObjetosVerificacao`). Nome repetido no Max soma no mesmo item: a V-20 já reprova nome repetido.
5. Apaga a pasta temporária. Falha no export ou na leitura vira `#warning` "não medido", com o motivo no log.

Mensagem: `TAMPO: 1,59 (560 v / 352 t)`, só os que passam do limite, no máximo 8 e depois "(+N)". Quando passa: maior ratio encontrado e o limite.

### 3.2 V-08 e V-10 · arestas abertas e sentido

Para cada malha analisada:
1. `abertas = meshop.getOpenEdges m`. Aresta `e` é da face `(e-1)/3+1`, canto `mod (e-1) 3`. Os vértices dirigidos saem de `getFace`.
2. Chave dirigida `a × (nv+1) + b` (double) só das arestas abertas, que são poucas. Ordena e acha as chaves repetidas: são pares de vizinhas com o mesmo sentido (V-10a). Essas arestas saem da contagem da V-08.
3. Elementos: `meshop.getElementsUsingFace` repetido sobre as faces restantes. Elemento sem nenhuma aresta aberta entra no volume com sinal, `Σ dot p1 (cross p2 p3) / 6`. Volume abaixo de `-ε` = do avesso (V-10b). Elemento aberto não entra.

O volume é medido no `snapshotAsMesh` (espaço de mundo). Rotação, translação e escala positiva não mudam o sinal. Espelho (escala negativa) muda, e é a V-12 que pega.

### 3.3 V-09 · duplicatas

(a) Faces coincidentes: para cada face, o centro quantizado na tolerância vira inteiro por eixo. Chave de ordenação `(qx − qxMin) × (nf+1) + f` (double, positiva; com ±10 m e 0,01 mm fica perto de 2·10⁶ × 3·10⁵, bem dentro dos 53 bits). A face sai de volta por `mod chave (nf+1)`. Ordena, junta as faces com o mesmo `qx` e, dentro do grupo, confere `qy`, `qz` e os 3 cantos quantizados ordenados. Duas faces com os mesmos 3 cantos são duplicata.

(b) Objetos duplicados: pares de objetos do universo com a mesma contagem de triângulos e o mesmo bbox de mundo, dentro da tolerância. Vale também para instâncias no mesmo lugar. O laço é O(n²) sobre objetos, que são poucos.

### 3.4 V-13 · ngons

Só em objeto com base `Editable_Poly` e stack vazio. Com stack, a V-11 já reprova; em Editable Mesh a V-13 sai "não se aplica" para aquele objeto. Para cada face com `polyop.getFaceDeg > 4`:
- **Não plana:** maior distância de um vértice ao plano (centro da face, `polyop.getFaceNormal`) ÷ maior extensão da face > `tan 1°`.
- **Suavizada na curva:** alguma vizinha (pelas arestas, `polyop.getEdgesUsingFace` → `polyop.getFacesUsingEdge`) com `bit.and sgA sgB != 0` e ângulo entre as normais > 15°.

Mensagem: objeto e número de ngons, com o motivo.

## 4. Estrutura

- **`verifications/verif_malha.ms` (novo)**, no manifesto logo depois de `verif_geometria.ms`. O cabeçalho de `verif_geometria.ms` deixa de anunciar o grupo 6 e aponta para ele.
  - `struct MalhaAnalise`: nó representante, instâncias, triângulos, arestas abertas (furos), faces com vizinha invertida, elementos do avesso, faces duplicadas, ngons não planas, ngons suavizadas na curva, e "não se aplica" da V-13.
  - `InLab_Malha_Analisar o` tira o `snapshotAsMesh` uma vez, preenche a análise da V-08/09a/10 e apaga a malha. A V-13 lê o Editable Poly direto.
  - `InLab_Malha_AnalisarCena objs` roda uma análise por grupo de instâncias (`InLab_DeduplicarInstancias`) e loga o tempo das peças grandes.
  - `InLab_GLTF_VerticesPorNo` exporta, lê e devolve `#(nome, vértices, triângulos)` por nó (V-07).
  - `InLab_V07_RatioVT cfg objetos`, `InLab_V08_MalhaFechada analises`, `InLab_V09_Duplicados analises objetos`, `InLab_V10_Normais analises`, `InLab_V13_Ngons analises`.
- **`verif_orquestrador.ms`:** bloco "Grupo 6 · Pesadas" depois do grupo 3, que analisa a cena uma vez e chama as cinco. O aviso de relatório parcial passa a citar só os grupos 4, 5 e 7. O cabeçalho de status marca o grupo 6 como entregue.
- **`core/struct_result.ms`:** a V-08 entra na lista de não críticas do cabeçalho.
- Operação só de leitura: nada muda na cena. O export da V-07 escreve em `getDir #temp` e apaga em seguida.

## 5. Testes

`tests/test_verif_malha.ms`, no padrão de `tests/test_renomear_produto.ms` (logger no arquivo de saída, cena criada e apagada no teste). Escritos antes do código.

| Caso | Espera |
|---|---|
| Box fechado | V-08, V-09, V-10, V-13 passam |
| Box com uma face apagada | V-08 `#warning` com a contagem; V-10 passa |
| Box com uma face com o sentido trocado | V-10 `#fail` (vizinhas); a V-08 não conta essas arestas |
| Box com todas as faces trocadas | V-10 `#fail` (avesso) |
| Box com uma face clonada no lugar | V-09 `#fail` (faces) |
| Dois Box iguais no mesmo lugar | V-09 `#fail` (objetos) |
| Esfera suavizada / esfera sem smoothing | V-07 passa / V-07 acima do limite (ratio perto de 3) |
| Poly com ngon não plana | V-13 `#fail` |
| Cilindro poly (tampa ngon plana) | V-13 passa |
| Editable Mesh | V-13 "não se aplica" |
| Sem exportador glTF (simulado: cache do exportador forçado a falhar) | V-07 `#warning` "não medido" |
| Desempenho: Teapot de 262 mil triângulos | análise abaixo do teto fixado na 1ª medição do plano |

E também: rodada completa do motor sem ID repetido (`tests/test_verificacoes.ms`), a suíte inteira no Max e a análise dos arquivos do piloto (Aparador, Puff), conferindo que nenhuma peça correta reprova.

## 6. Fora do escopo

- Ngons em Editable Mesh (polígono por aresta invisível).
- Face invertida numa costura não soldada (vértices diferentes na mesma posição): ela aparece como furo na V-08, não na V-10.
- Faces coincidentes entre objetos diferentes, fora o caso do objeto inteiro duplicado.
- Corrigir: as verificações só apontam.
