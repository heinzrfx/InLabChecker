# Benchmark de draw calls por família (V-05, issue #32)

28/09/2026. Tetos **provisórios** para a V-05 até a validação do Birô. Não havia dado interno, então os números saíram de guias públicos, de uma inferência a partir deles e de uma medição num produto real.

## Como a V-05 conta

Uma draw call corresponde a um primitive do glTF, ou seja, a um material usado pelas faces de um objeto. A V-05 soma, objeto a objeto:

- objeto sem material, ou com um material simples: **1**;
- objeto com Multi/Sub: o **nº de sub-materiais que alguma face usa** (um slot sem face não é exportado);
- instância conta por nó, porque o glTF básico não tem instancing.

Decisão da issue #32: os rodízios ficam atachados num objeto só.

## Fontes (dado)

| Fonte | Número | Observação |
| --- | --- | --- |
| Google Scene Viewer (AR Android) | **10 materiais**, "1 mesh per material", 100k triângulos, 10 MB | único teto concreto de materiais encontrado ([link](https://developers.google.com/ar/develop/scene-viewer)) |
| Google Merchant Center 3D | 10 MB recomendado, 15 MB máx. | não fixa materiais; remete ao Scene Viewer |
| Khronos 3D Commerce Guidelines v1.0 / 2.0 | sem número de draw calls ("minimizar") | o glTF Asset Auditor tem `maxMaterialCount`/`maxPrimitiveCount` desligados por padrão |
| Shopify (checklist de parceiros) | **1 material** "unless otherwise necessary" | modelo de produto |
| three.js (mantenedores) | **< 100 draw calls por cena** no mobile | orçamento da cena inteira |
| Apple AR Quick Look, Amazon, Wayfair, IKEA, Threekit, Meta | sem número público | as specs da Amazon e da Wayfair ficam atrás dos portais de vendedor/fornecedor |

## Medição

- `Poltrona IANDARA.max` (produto real): 3 objetos, **3 draw calls**, 146 mil triângulos.

## Inferência

- **Família estática:** o teto é ≤ 10, derivado do Google (10 materiais × 1 malha por material). O ideal da Shopify fica entre 1 e 3.
- **Família animada:** cada peça que se move é um nó próprio e soma pelo menos 1 draw call, mesmo sem material novo. Por isso essas famílias têm mais folga.
- **Orçamento de cena:** uma cena mobile fica abaixo de 100 draw calls e divide esse orçamento com o chão, a sombra e às vezes outros produtos. Um produto deveria usar no máximo ~20–25% disso, ou seja, ≤ ~24.

## Tetos adotados (`maxDrawCalls` em `familias/*.ms`)

| Família | Teto | Por quê |
| --- | --- | --- |
| corpo_unico | 6 | peça única, 2 a 4 materiais |
| pernas_tampo | 8 | tampo + pernas juntas por material |
| estrutura_estofado | 10 | tecidos, almofadas e pés; é o teto do Google |
| giro_assento | 12 | conjunto giratório, base e rodízios separados |
| estrutura_modular | 16 | muitas peças; as fixas ficam juntas por material |
| rotacao | 16 | cada porta é um nó |
| translacao | 20 | cada gaveta é um nó (frente, caixa, puxador) |
| movimento_especial | 20 | vários conjuntos articulados |

A V-05 continua `provisorio:true`: enquanto `INLAB_LIMITES_PROVISORIOS` estiver ligado, estourar o teto dá advertência e não reprova.

## Como alterar

- **Sem mexer no código:** grave `maxDrawCalls_<família>=<n>` na seção `[InLabChecker]` do `InLabChecker.ini` (`getDir #plugcfg`), por exemplo `maxDrawCalls_giro_assento=14`. Esse valor tem precedência sobre o da família, sobrevive às atualizações do plugin e aparece como "(ini)" na mensagem da V-05. Um valor inválido é ignorado com aviso no log.
- **Valor oficial:** troque `maxDrawCalls` no arquivo da família quando o Birô validar.

## Em aberto

- Uma advertência separada acima de 10 materiais distintos no produto (o número do Google), independente da família.
- Uma forma de editar o teto pela UI, se a equipe precisar.
