# Estudo: mapeamento automático do canal 1 sem unwrap

**Data:** 22/10/2026
**Situação:** estudo em andamento; não há código no plugin. Continua com novos assets que o usuário vai mandar.
**Objetivo:** achar um mapeamento do canal 1 automático e fácil, sem unwrap, que chegue perto do UV dos assets profissionais.

## Contexto (decisões do usuário)

- O unwrap ficou opcional; o GLB só precisa do canal 1 mapeado. Ver a spec do grupo 5, seção 7.
- O Real World Fix só é necessário para as texturas da biblioteca do Corona com Real-World Map Size. A V-42 exige o RWF só para o desenhista não esquecer.
- **No futuro, a InLab vai usar só a biblioteca própria feita no Substance**, e as texturas do Corona deixam de ser usadas. O alvo do automapeamento é a convenção de escala dessa biblioteca, não o Real-World.
- **Pergunta em aberto:** quantos cm reais um tile das texturas Substance cobre? É fixo ou varia por tipo de material? O veio da madeira vem sempre na mesma direção da imagem?

## 1. Cadeira de teste (cena não salva)

Peças: encosto, assento, pés+travessa (`pe`, uma malha soldada só) e um aro de alumínio.

**Diagnóstico do canal 1:**

| Peça | Achado |
|---|---|
| Encosto | O UV era um UVW Box colapsado; escala real ok |
| Assento | A borda da frente estava esticada: 6,8% das faces com distorção > 1,5 |
| `pe` | UV com 2× a escala real |
| Aro de alumínio | Sem canal 1, com textura |

**Métodos testados**, com UVW Map em `realWorldMapSize`:

- O **Box** foi o melhor em todas as peças: escala mediana de 0,92 a 0,98 e distorção mediana de 1,04 a 1,18.
- O **cilíndrico com tampa** foi muito pior: de 52 a 90% das faces com distorção > 1,5.
- **Problema do Box na madeira:** a textura tem o veio horizontal. Com Box, todas as faces laterais ficam com U horizontal, então o veio cruza os pés. É o mesmo tipo de "mudou o sentido" do relato do Monzon.

**Regra "veio segue a aresta longa"** (testada, funciona):

- Em cada face, a projeção é de Box: o eixo dominante da normal escolhe o plano.
- O U vai na direção da aresta mais longa do polígono. Nas faces laterais, se essa aresta for mais vertical que horizontal, usa U = Z. Nas faces de topo, se ela estiver mais em Y que em X, usa U = Y.
- A decisão é alisada por voto dos vizinhos por aresta, em 4 passes. O peso de cada voto é a razão `(lado maior / lado menor − 1)`, limitada a 4, para que faces quase quadradas quase não votem.
- Os vértices de UV são criados por par (vértice, modo); vértices vizinhos no mesmo modo compartilham o UV.
- **Resultado:** 4 s em 12.864 faces. A escala e a distorção ficam iguais às do Box. No render Corona o veio fica vertical nos pés e acompanha a travessa, inclusive nas curvas.
- **Limites:**
  - onde a travessa curva a 45°, o veio fica diagonal (a projeção encaixa em X ou Y);
  - nas juntas com faces minúsculas de chanfro (3.608 faces < 0,05 cm²) sobra ruído;
  - não serve para tecido, porque a direção trocaria de face para face. Para tecido, use Box simples.

## 2. Padrão de 31 objetos profissionais (`G:\Meu Drive\Trabalhos\2026\Artefacto\Substance\trest.max`)

A sonda está em `2026-10-22-sonda-uv-assets.ms` (só leitura). Ela grava em `(getDir #temp)\inlab_sonda_uv_assets.txt`. Mede, por objeto e por ID de material: escala do UV por cm, distorção, se as direções U/V caem nos eixos do mundo (assinatura de projeção), a razão vértices de UV / vértices da malha (cortes) e a direção do U ou do V em relação à aresta longa.

**Padrões encontrados:**

1. **Ninguém usa Real-World.** Todas as texturas estão com `rw:false`. O UV é normalizado (1 unidade de UV = 50 a 350 cm) e a escala vem do tiling do bitmap (1 a 10).
2. **Densidade uniforme por material.** É o padrão mais forte: a escala p10–p90 quase não varia.
   - Tanso assento: 0,0028 a 0,0029
   - Times madeira: 0,0032 a 0,0033
   - Armchair linho: 0,0146 a 0,0156
   - Armchair 291 tecido: 0,0178 a 0,0188
3. **Unwrap, não projeção.**
   - A distorção mediana fica entre 1,00 e 1,10.
   - U e V no eixo do mundo só em 13 a 25% das faces; numa projeção seria 100%.
   - Vértices de UV / vértices fica entre 1,02 e 1,20, ou seja, poucas ilhas.
   - Exceção: superfícies planas, onde planar e unwrap dão o mesmo.
4. **Madeira com o comprimento da peça no V**, e o veio acertado pela rotação do bitmap:
   - Tanso pés: V acompanha o comprimento em 34–76% das faces alongadas, U em 2–15%, e o bitmap tem W 90°.
   - Times: V 73%. Chair 024: V 60%. Chair 033: V 53%.
   - Armchair carvalho: o oposto, U 55%, com o veio no U.
   - Regra geral: o veio segue o comprimento de cada parte.
   - A medida é aproximada, porque usa a aresta mais longa do triângulo como comprimento da peça.
5. **Material sem textura, ou com textura uniforme, não se preocupa com UV.** Há casos de UV esmagado ou colapsado em metal e plástico. Regra possível: só exigir mapeamento onde houver bitmap.

## 2b. Segundo lote: 151 objetos (`G:\Meu Drive\Trabalhos\2026\Artefacto\InlabChecker\Assets para teste\TESTE TEXTURA.max`, 23/10/2026)

A sonda rodou em 21 s, sem erro, depois de protegido o bitmap sem arquivo. São 289 pares objeto × ID de material: 114 sem textura e 13 objetos sem canal 1. Os assets misturam Corona e VRay (Verity, Minotti Fynn, Samurai, Rene, Capitol Complex, Times, Julep, Bed Desiree, Kangoroo).

**Confirma os padrões do primeiro lote:**

1. **Nenhuma textura usa Real-World.** A única exceção é um metal do Fynn com bitmap sem arquivo. O UV é normalizado e a escala vem do tiling.
2. **Densidade uniforme por material.** A razão p90/p10 da escala fica entre 1,00 e 1,20 na maioria. Fora disso: Rene encosto (2,25), Kangoroo (1,85), pés e trama do Fynn (1,76 e 2,73), a sujeira do cromado do Samurai (sem importância).
3. **Unwrap.** A distorção mediana fica entre 1,00 e 1,10, e U e V caem no eixo do mundo em 0 a 36% das faces. Os mais "projetados" são peças planas ou retas: carvalho do Rene (64%), cama Bed Desiree (60%), madeira do Object015 (46%).
4. **O veio segue o comprimento da peça. O eixo (U ou V) depende da imagem, e o W compensa:**
   - Com V ao longo: Times 73%, Capitol madeira 65%, carvalho do Rene 81% (com W 90°), Samurai madeira 59% (W 90°).
   - Com U ao longo: madeira do Fynn 44 a 88% (W 0°) e trama do Ren Dining 68%.

**Achado novo: tamanho do tile em cm reais**, calculado como `1 / (escala UV por cm × tiling)`:

| Material | cm por tile |
|---|---|
| Madeira (Object015, Times, Capitol, Fynn, carvalho do Rene, Samurai) | **43 a 76, quase sempre ~60** |
| Kangoroo (madeira, com UV irregular) | 72 |
| Tecido liso / linho (Verity) | 37 a 62 |
| Bouclê (Rene) | 85 a 89 |
| Tecido do Fynn | 20 |
| Couro (Samurai) | 17 |
| Rattan (Capitol, padrão de trama) | 10 |

Para madeira, a convenção de fato é de **~60 cm por tile**. Para tecido e couro, o tamanho depende do padrão da imagem (bouclê grande, trama fina). Isso sugere uma escala **por tipo de material**, não uma só. Ainda falta confirmar com a biblioteca Substance.

## 3. Direção proposta (a testar)

| Padrão profissional | Automático sem unwrap | Situação |
|---|---|---|
| Densidade uniforme por material | Box com uma escala fixa (a convenção da biblioteca Substance) | Funciona |
| Veio ao longo da peça | Regra da aresta longa + alisamento | Testada na cadeira |
| Pouca distorção | Caixa orientada por elemento: medir o eixo principal de cada elemento, projetar alinhado a ele, com o V no comprimento. Malha soldada cai na regra da aresta longa | Próximo teste |
| Poucas emendas, escondidas | Não dá com projeção | Limite; só com unwrap |

## Próximos passos

1. ~~Analisar o próximo arquivo de assets do usuário com a mesma sonda~~ (feito em 23/10, seção 2b).
2. Testar a caixa orientada por elemento.
3. Obter a convenção de escala e de direção do veio da biblioteca Substance.
4. Se aprovado, desenhar o botão "Mapear canal 1" (spec + plano) antes de escrever código.
