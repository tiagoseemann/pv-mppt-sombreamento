# Relato da simplificação do código (10/11/2026)

Spec: `docs/superpowers/specs/2026-11-10-simplificacao-codigo-design.md`
Plano: `docs/superpowers/plans/2026-11-10-simplificacao-codigo.md`, com a alteração de 10/11: os
experimentos **não** foram rodados de novo (licença do MATLAB vencendo). Por isso só entraram
mudanças de risco baixo, que não alteram nenhum número. `resultados/`, as figuras e o relatório
continuam válidos sem alteração.

## Linhas de código (sem comentário e sem branco)

| Pasta | Antes | Depois | Δ |
|---|---|---|---|
| numerico | 56 | 47 | −9 |
| painel | 242 | 240 | −2 |
| termico | 35 | 35 | 0 |
| conversor | 125 | 117 | −8 |
| controle | 224 | 216 | −8 |
| mppt | 140 | 140 | 0 |
| simulacao | 324 | 315 | −9 (com o arquivo novo `oraculo_com_cache.m`) |
| cenarios | 91 | 91 | 0 |
| raiz | 19 | 19 | 0 |
| experimentos | 480 | 466 | −14 |
| tests | 812 | 806 | −6 |
| **Total** | **2548** | **2492** | **−56** |

Comentários: de 1494 para 1486. Os comentários de física foram mantidos, conforme o contrato.

**Conclusão:** o código já estava enxuto. As cerca de 4.400 linhas totais se explicam pelos
fatores abaixo, não por inchaço:

- 34 % são comentários;
- os testes somam 806 linhas de código;
- os experimentos somam 466;
- o escopo é amplo;
- só havia o MATLAB base, sem toolboxes.

## Achados

- **Etapa 1 (modelo e experimentos):** `achados_etapa1.md`. Os 9 de risco baixo foram
  aplicados. O 10 (unificar as resoluções de `curva_pv`) é de risco médio e não foi aplicado,
  porque exige rodar os experimentos de novo.
- **Etapa 2 (testes):** `achados_etapa2.md`. Os achados 1, 2 e 5 foram aplicados. O 3 e o 4
  foram recusados, para que o teste de extração continue autossuficiente.
  `test_fechada_igual_fzero` foi renomeado para `test_d_fechado_satisfaz_equilibrio`.

## Verificação

- **Testes:** 81/81 passando antes; 81/81 depois da etapa 1; 80/80 depois da etapa 2 (dois
  testes de `test_conversor` que checavam o mesmo ponto viraram um).
- **`checkcode`** nos arquivos alterados: nenhum aviso, nem antes nem depois.
- **Revisão independente da etapa 1:** conformidade ✅ e qualidade ✅. As duas observações
  menores, só de comentário, foram corrigidas (commit e101893).
- **Prova de que os testes enxutos não afrouxaram:** a mesma perturbação no modelo faz o teste
  antigo e o novo falharem.
  - Achado 1: apagar `- eq.Psw` em `equilibrio_conversor.m` dá 1 falha no antigo e 1 no novo.
  - Achado 5: trocar `r.E = E` por `1.02 * E` em `sim_quase_estatica.m` dá 4 falhas no antigo
    e 4 no novo.
- **Referências:** nenhuma referência órfã em `matlab/`, `relatorio/relatorio.tex` ou
  `README.md`.
- **Experimentos:** não foram executados. A garantia de que os números não mudam vem da
  natureza das mudanças, que só removem código não usado, tiram duplicação ou reorganizam sem
  mudar a ordem das contas. Cada achado registra o porquê, e o revisor confirmou.

## Pendências registradas (fora do escopo)

- `test_controle.m:57`: a folga `- 1e-3` em `Ta >= 1,5 ts_max` deixaria passar um `floor` no
  lugar do `ceil`. Apertar a folga endureceria o teste.
- Os logs de teste (`logs/*.log`) ficam fora do git por causa do `*.log` no `.gitignore`.
