# Energia fotovoltaica sob sombreamento parcial

Trabalho final de **DAS5109 – Modelagem e Simulação de Processos** (UFSC).

Modelagem eletrotérmica de um painel fotovoltaico (ZTROON ZTP-160M) conectado a um
conversor buck-boost, com comparação de algoritmos de MPPT local (P&O, InC) e global (PSO)
sob sombreamento parcial.

**Pergunta central:** quanta energia o P&O deixa de captar sob sombreamento parcial, e quanto
um MPPT global (PSO) recupera, considerando o aquecimento do painel e as perdas do conversor?

## Escopo

| Bloco | Modelo |
|---|---|
| Painel | 2 diodos, parâmetros extraídos do datasheet e validados contra as curvas I-V |
| Sombreamento | Submódulos com irradiâncias diferentes e diodos de bypass |
| Térmico | Balanço de energia de 1ª ordem, calibrado pelo NOCT |
| Conversor | Modelo médio com perdas, validado contra o modelo chaveado |
| Controle | Linearização, função de transferência e projeto do PI |
| MPPT | P&O, Condutância Incremental e PSO |
| Testes | Perfil EN 50530 e um dia real em Florianópolis |

## Estrutura

```
referencias/
  README.md          # índice comentado das referências
  referencias.bib    # BibTeX (mesmas chaves da proposta)
  pdfs/              # PDFs dos artigos (não versionados)
proposta/
  proposta.tex       # documento da proposta (LaTeX)
  proposta.pdf       # versão compilada
  gerar_figuras.py   # gera as figuras ilustrativas em figs/
  figs/
```

## Como compilar a proposta

```bash
cd proposta
python3 gerar_figuras.py        # requer numpy e matplotlib
tectonic -X compile proposta.tex
```
