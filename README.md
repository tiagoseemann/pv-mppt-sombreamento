# Energia fotovoltaica sob sombreamento parcial

Trabalho final de **DAS5109 – Modelagem e Simulação de Processos** (UFSC).

Modelagem eletrotérmica de um painel fotovoltaico (ZTROON ZTP-160M) conectado a um
conversor buck-boost que carrega uma bateria de 12 V, com comparação de algoritmos de MPPT
local (P&O, InC) e global (PSO) sob sombreamento parcial.

**Pergunta central:** quanta energia o P&O deixa de captar sob sombreamento parcial, e quanto
um MPPT global (PSO) recupera, considerando o aquecimento do painel e as perdas do conversor?

O relatório completo está em [`relatorio/relatorio.pdf`](relatorio/relatorio.pdf).

## Escopo

| Bloco | Modelo |
|---|---|
| Painel | 2 diodos (convenção de Ishaque), parâmetros extraídos do datasheet com `fsolve`; R_p(G) de De Soto |
| Sombreamento | 3 submódulos com irradiâncias diferentes e diodos de bypass (Newton com jacobiano analítico) |
| Térmico | Balanço de energia de 1ª ordem (convecção de Watmuff, radiação para céu e solo), calibrado pelo NMOT |
| Conversor | Buck-boost inversor: modelo médio com perdas, validado contra o modelo chaveado |
| Controle | Linearização, resposta em frequência e projeto do PI por margens (com tolerâncias de L e C) |
| MPPT | P&O, Condutância Incremental e PSO |
| Cenários | Perfil dinâmico da EN 50530 e o dia 26/01/2020 em Florianópolis (PVGIS) com nuvens e sombra de poste sintéticas |

## Principais resultados

| Experimento | Resultado |
|---|---|
| E6 – EN 50530 (sem sombra) | η_MPPT: P&O 99,9 %, InC 99,6 %, PSO 98,6 % |
| E7 – dia em Florianópolis com sombras | η_MPPT: PSO 98,7 %, P&O 95,7 %, InC 93,8 %; energia na bateria 942 / 913 / 897 Wh |
| E7 – ablação | ignorar o aquecimento superestima a energia em ≈ 9 %; ignorar as perdas do conversor, em ≈ 11 % |
| E8 – simplificações do trabalho anterior | superestimam a energia entregue à bateria em 21,9 % |

O relatório discute também três limitações dos MPPT que só aparecem com o modelo térmico e o
dia real (o PSO não acompanha a deriva térmica após convergir, o InC "congela" e o PSO erra o
pico global com sombra fraca e módulo quente).

## Estrutura

```
matlab/
  setup_path.m, run_tests.m, raiz_projeto.m
  painel/        # modelo de 2 diodos, extração de parâmetros, sombreamento com bypass
  termico/       # balanço térmico e calibração pelo NMOT
  conversor/     # buck-boost: ideal, médio com perdas, chaveado, equilíbrio, CCM/DCM
  controle/      # linearização, resposta em frequência, margens, projeto do PI
  mppt/          # P&O, InC, PSO e rastreamento estático
  simulacao/     # simulação dinâmica (EDO), quase-estática e oráculo do máximo global
  cenarios/      # perfil EN 50530, dia do PVGIS, eventos de sombra
  experimentos/  # exp01 ... exp08 (geram resultados/ e relatorio/figs/)
  tests/         # testes (matlab.unittest)
data/
  en50530_rampas.csv          # tabelas B.2–B.4 da EN 50530
  clima/pvgis_floripa_2020.csv
resultados/      # tabelas (CSV) geradas pelos experimentos
relatorio/       # relatório final (LaTeX) e figuras
proposta/        # proposta do trabalho (LaTeX)
referencias/     # bibliografia e datasheet do painel
docs/superpowers/plans/  # plano de execução e registro das decisões (D1–D17)
```

## Como rodar

Requer o **MATLAB** com a **Optimization Toolbox** (só para o `fsolve` da extração de parâmetros). Testado no R2026b.

```matlab
cd matlab
run_tests                 % todos os testes
exp01_validacao_painel    % cada experimento grava em resultados/ e relatorio/figs/
```

Tempos aproximados de CPU: exp01–exp05 e exp06b levam minutos; `exp06_en50530` (≈ 1 h),
`exp07_dia` (≈ 2–3 h; se `resultados/e7_series.mat` existir, só redesenha a figura) e
`exp08_baseline` (≈ 30 min) são longos. Rode um de cada vez: processos MATLAB em paralelo
esgotam a memória.

Os dados do PVGIS já estão versionados; para baixá-los de novo: `baixar_pvgis(2020)`.

## Como compilar os documentos

```bash
cd relatorio && tectonic -X compile relatorio.tex

cd proposta
python3 gerar_figuras.py        # requer numpy e matplotlib
tectonic -X compile proposta.tex
```
