# Simplificação do código MATLAB — design

**Data:** 10/11/2026
**Contexto:** o trabalho está concluído (main em 82233a5). Antes de escrever um guia que explique
todo o código linha a linha (subprojeto 2, com spec próprio), o código passa por uma
auditoria de simplicidade. O contrato do plano original (`docs/superpowers/plans/2026-10-27-trabalho-final-pv-mppt.md`,
linha 11) pede código "que um júnior entenda": nomes claros, laços explícitos, sem
abstrações desnecessárias e comentários explicando a física.

## Ponto de partida (medido em 10/11/2026)

| Pasta | Arquivos | Código | Comentário | Branco |
|---|---|---|---|---|
| painel | 10 | 242 | 191 | 46 |
| termico | 3 | 35 | 26 | 4 |
| conversor | 7 | 125 | 136 | 22 |
| controle | 7 | 224 | 259 | 17 |
| mppt | 6 | 140 | 135 | 16 |
| simulacao | 3 | 324 | 285 | 40 |
| cenarios | 5 | 91 | 48 | 4 |
| numerico | 1 | 56 | 30 | 9 |
| raiz (setup_path etc.) | 3 | 19 | 5 | 0 |
| experimentos | 9 | 480 | 204 | 63 |
| tests | 15 | 812 | 175 | 93 |
| **Total** | **69** | **2548** | **1494** | **314** |

Todas as funções do modelo são usadas fora dos testes (não há código morto). Candidatos
iniciais, ainda não auditados: `simulacao/sim_quase_estatica.m` (opções acumuladas, `op.V0`
sem efeito), `simulacao/sim_dinamica.m`, `controle/projeto_pi.m` (101 linhas de código),
`experimentos/exp04_controle.m` (110).

## Objetivo

Reduzir a complexidade do código sem mudar a física nem as conclusões do trabalho, deixando-o
mais fácil de ler, validar e ensinar.

## Etapas

1. **Etapa 1: código do modelo e experimentos** (todas as pastas exceto `tests/`). Os testes
   ficam **congelados** e servem de rede de segurança. Só mudam se uma função for removida ou
   tiver a assinatura alterada; nesse caso, a mudança no teste é mínima e aparece no relato.
2. **Etapa 2: testes.** Depois da etapa 1 estável, mesma auditoria aplicada a `tests/`
   (duplicação de montagem do painel, verificações redundantes etc.).

Cada etapa segue o mesmo fluxo: auditoria → lista de achados → aprovação do usuário →
aplicação em lotes → verificação.

## O que a auditoria procura

- **Opções sem uso real:** parâmetros `op.*` ou campos de configuração que nenhum experimento
  varia, ou que não têm efeito.
- **Duplicação:** o mesmo trecho em mais de um lugar (inicialização dos simuladores,
  boilerplate dos experimentos).
- **Generalidade não usada:** código preparado para casos que o trabalho nunca exercita.
- **Ramos defensivos redundantes:** checagens já garantidas por quem chama.
- **Tamanho:** funções triviais que caberiam no chamador, ou funções longas demais para ler de
  uma vez e que ficariam mais claras se divididas.
- **Precisão excessiva:** tolerâncias de solver ou critérios de parada mais rígidos que o
  necessário para as conclusões.

## O que não muda

- Os comentários de física e lógica (são o contrato). Saem só os comentários que descrevem
  código removido.
- Os laços explícitos (nada de vetorizar para economizar linhas).
- A estrutura de pastas.
- Os modelos físicos: as equações implementadas continuam as mesmas.
- **Os dois simuladores continuam separados.** A comparação dinâmico × quase-estático é o
  experimento E6b e justifica o uso do quase-estático em E6–E8.

## Saída da auditoria

Uma tabela por etapa, antes de qualquer alteração:

| # | Arquivo | Achado | Mudança proposta | Linhas economizadas | Risco |
|---|---|---|---|---|---|

- **Risco baixo:** só reorganiza, sem afetar os resultados.
- **Risco médio:** muda a ordem das contas, tolerâncias ou o consumo de números aleatórios. Os
  números podem mudar um pouco.

O usuário aprova, recusa ou edita cada linha. Só os achados aprovados são aplicados.

## Critério de aceite: as mesmas conclusões

Os números não precisam ser idênticos, mas precisam levar às mesmas conclusões. A referência é
o conteúdo atual de `resultados/` (salvo antes de qualquer mudança). Todas as checagens abaixo
precisam passar:

| # | Conclusão | Checagem (fonte) |
|---|---|---|
| C1 | E1: o modelo extraído reproduz o datasheet | `e1_validacao_painel.csv`: \|erro Pmax\|, \|erro Voc\| ≤ 0,5 %; γ_P do modelo a ±0,05 %/K do valor atual (≈ −0,36 %/K) |
| C2 | E2: a sombra cria múltiplos picos | `e2_picos.csv`: mesmos números de picos por cenário, mesmo pico marcado como global; P de cada pico a ±1 % |
| C3 | E3: o modelo médio reproduz o chaveado em CCM e se separa dele em DCM | Caso STC do exp03: erro máximo ≤ 0,5 % na tensão e ≤ 1,5 % em i_L (relatório: ~0,1 % e ~0,7 %); ripple simulado a ±5 % do analítico; o caso de 50 W/m² continua em DCM. Frações de DCM do E6/E7 a ±2 p.p. (32 % e 13 %) |
| C4 | E4: o PI atende às margens com tolerâncias de L e C | `e4_margens.csv`: MF ≥ 45° em todas as linhas (critério de `projeto_pi`); MF, MG e t_s a ±5 % do valor atual |
| C5 | E5: P&O e InC param em pico local sob sombra e o PSO acha o global | `e5_mppt_estatico.csv`: o mesmo pico é atingido por algoritmo e cenário; η a ±0,5 p.p. |
| C6 | E6 (EN 50530): ordem P&O > InC > PSO, com o melhor Δ de cada um | `e6_en50530.csv`: η do melhor caso de cada algoritmo a ±0,1 p.p. (atual: 99,92 / 99,58 / 98,62 %; a menor diferença entre eles é de 0,34 p.p.); ordem preservada |
| C7 | E6b: o quase-estático é válido | `e6_dinamico.csv`: \|η_din − η_qe\| ≤ 0,4 p.p. (P&O, InC) e ≤ 1,1 p.p. (PSO), como na decisão D16 |
| C8 | E7 completo: ordem PSO > P&O > InC em η e em energia na bateria | `e7_dia.csv`: η a ±0,3 p.p. (atual: 98,70 / 95,71 / 93,78 %); E_bat a ±1 % (941,7 / 913,4 / 896,5 Wh) |
| C9 | E7 ablação: ignorar o aquecimento superestima ≈ 9 %; ignorar as perdas, ≈ 11 % | Razões E_bat(variante)/E_bat(completo) − 1, por algoritmo, a ±1 p.p. dos valores atuais |
| C10 | E8: as simplificações do trabalho anterior superestimam ≈ 22 % | `e8_baseline.csv`: `dif_vs_completo_pct` a ±1 p.p. de 21,9 % |
| C11 | As três limitações dos MPPT continuam aparecendo | Nas séries do E7: o PSO não acompanha a deriva térmica depois de convergir; o InC "congela"; o PSO erra o pico global no evento "poste (mais fraca)" (15:00–15:30) |

Como o exp03 só imprime no console, a saída atual dele também é guardada como referência. Se
algum limite acima se mostrar mais apertado que a variação natural
(por exemplo, entre execuções), ele é ajustado e o ajuste é registrado no relato.

O PSO usa um `RandStream` próprio com `cfg.seed = 1` (`mppt/config_mppt.m`), então o código
atual é reprodutível. Uma mudança que altere a ordem de consumo dos números aleatórios é de
risco médio: a trajetória do PSO muda, e o aceite fica por conta de C5–C11.

## Fluxo de execução

1. Branch `simplificacao` a partir de main.
2. **Referência:** copiar `resultados/*.csv`, `resultados/e7_series.mat` e a saída de console do exp03 para
   `docs/superpowers/simplificacao/referencia/` e confirmar que o `run_tests` passa no estado
   atual.
3. **Script de comparação:** `docs/superpowers/simplificacao/comparar_conclusoes.m` implementa
   C1–C11 (C11 com uma checagem objetiva por limitação, definida a partir das séries) e imprime
   PASSA/FALHA por item. Fica fora de `matlab/` porque não faz parte do modelo.
4. **Auditoria da etapa 1** → tabela de achados → aprovação do usuário.
5. **Aplicação em lotes por módulo**, na ordem do fluxo de dados: numérico → painel → térmico →
   conversor → controle → cenários → experimentos (partes não ligadas à simulação). Os lotes que
   tocam `mppt/` e `simulacao/` ficam juntos no fim. Depois de cada lote: `run_tests` +
   experimentos rápidos afetados (E1–E5, E6b) + as checagens correspondentes. Se passar, um
   commit por lote. Se falhar, o lote é revertido e o achado volta para o usuário marcado como
   "altera conclusão".
6. **Experimentos longos, uma única vez no fim e um por vez** (em paralelo esgotam a memória):
   E6 (≈ 1 h), E7 (≈ 2–3 h, apagando antes `e7_series.mat` para forçar a simulação completa),
   E8 (≈ 30 min). Depois, as checagens C6, C8–C11.
7. **Atualização dos documentos:** se algum número mudou, regenerar as figuras e atualizar os
   valores no relatório (`relatorio/relatorio.tex`, recompilando o PDF) e no `README.md`. O texto
   das conclusões não muda. Conferir também se o relatório cita nome de função ou opção alterada.
8. **Etapa 2 (testes):** auditoria de `tests/` → aprovação → aplicação → `run_tests`.
9. **Relato final:** linhas antes/depois por pasta, lista de achados aplicados e recusados,
   resultado de C1–C11 e diferenças numéricas. O merge em main acontece só com a aprovação do
   usuário.

## Fora de escopo

- Escrever o guia de estudo (subprojeto 2, spec próprio depois desta simplificação).
- Atualizar os guias antigos em `guia/` (não versionados).
- Mudar modelos, cenários, algoritmos ou conclusões.
