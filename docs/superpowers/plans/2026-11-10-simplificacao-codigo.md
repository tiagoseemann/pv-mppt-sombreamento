# Simplificação do código — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enxugar o código MATLAB do trabalho (etapa 1: modelo e experimentos; etapa 2: testes) sem mudar a física nem as conclusões C1–C11.

**Architecture:** Primeiro congelamos uma referência (CSVs, séries do E7, saída do exp03) e escrevemos um comparador automático das conclusões. Depois, auditoria → lista de achados aprovada pelo usuário → aplicação em lotes por módulo, com testes + experimentos rápidos + comparador a cada lote. Os experimentos longos (E6, E7, E8) rodam uma única vez no fim. Por fim, documentos atualizados e etapa 2 nos testes.

**Tech Stack:** MATLAB R2026b base (sem toolboxes), `matlab.unittest`, tectonic (LaTeX), git.

**Spec:** `docs/superpowers/specs/2026-11-10-simplificacao-codigo-design.md`

**Exceção à regra "sem placeholders":** as edições de código de cada lote (Tarefas 5 e 9) não podem ser escritas aqui, porque dependem da auditoria (Tarefas 4 e 8) e da aprovação do usuário. O plano fixa o *protocolo* exato de cada lote; a tabela de achados aprovada passa a ser o anexo que diz *o que* editar.

---

## Convenções usadas em todas as tarefas

- Raiz do repositório: `/Users/tiagoseemann/Projetos/TrabalhoModelagem` (todos os comandos partem dela).
- MATLAB em modo batch (não está no PATH):
  ```bash
  M=/Applications/MATLAB_R2026b.app/bin/matlab
  ```
- Rodar um experimento: `$M -batch "cd matlab; exp01_validacao_painel"`. Os scripts começam com `clear` e chamam `setup_path()` sozinhos.
- Rodar os testes: `$M -batch "cd matlab; run_tests"`. Sucesso = termina sem `Error` e a tabela mostra todos `Passed = true`.
- **Nunca rodar dois processos MATLAB ao mesmo tempo** (esgota a memória).
- Pasta de trabalho da simplificação: `docs/superpowers/simplificacao/` (fora de `matlab/`, porque não faz parte do modelo).
- Estilo do código (contrato): nomes claros, laços explícitos, comentários explicando física e lógica. Vale também para o comparador.
- Branch: `simplificacao` (já criada, com o spec commitado em 90d0852).

## Mapa de arquivos

| Arquivo | Papel |
|---|---|
| Create `docs/superpowers/simplificacao/referencia/` | Cópia congelada de `resultados/*.csv`, `e7_series.mat` e `exp03.log` antes de qualquer mudança |
| Create `docs/superpowers/simplificacao/comparar_conclusoes.m` | Checa C1–C11 (ref × novo) e imprime PASSA/FALHA |
| Create `docs/superpowers/simplificacao/testar_comparador.m` | Prova que o comparador passa em ref × ref e falha num resultado perturbado |
| Create `docs/superpowers/simplificacao/achados_etapa1.md` | Tabela de achados do código (aprovada pelo usuário) |
| Create `docs/superpowers/simplificacao/achados_etapa2.md` | Tabela de achados dos testes |
| Create `docs/superpowers/simplificacao/relato.md` | Relato final: linhas antes/depois, achados, resultado de C1–C11 |
| Create `docs/superpowers/simplificacao/logs/` | Saídas de console das rodadas (exp03 e os longos) |
| Modify `matlab/**` | Conforme os achados aprovados |
| Modify `resultados/*`, `relatorio/figs/*`, `relatorio/relatorio.tex`, `relatorio/relatorio.pdf`, `README.md` | Só se algum número mudar (Tarefa 7) |

---

### Tarefa 0: Licença do MATLAB

A licença trial do MATLAB **vence em 12/11/2026** (aviso visto em 10/11). O plano todo precisa de cerca de 1 a 2 dias de trabalho mais ~5 h de CPU nos experimentos longos.

- [ ] **Passo 1: Confirmar com o usuário** que a licença foi renovada (ou que há outra licença) antes de começar a Tarefa 1. Conferir o aviso:
  ```bash
  $M -batch "disp(version)" 2>&1 | grep -i "expire"
  ```
  Esperado: nenhuma linha, ou uma data de expiração posterior ao fim previsto do trabalho. Se a licença vencer no meio, o trabalho para: os commits por lote garantem que nada se perde.

---

### Tarefa 1: Congelar a referência

**Files:**
- Create: `docs/superpowers/simplificacao/referencia/` (cópias)
- Create: `docs/superpowers/simplificacao/logs/`

- [ ] **Passo 1: Confirmar que a árvore de `matlab/` e `resultados/` está limpa**
  ```bash
  git status --short matlab resultados
  ```
  Esperado: saída vazia.

- [ ] **Passo 2: Copiar os resultados atuais**
  ```bash
  mkdir -p docs/superpowers/simplificacao/referencia docs/superpowers/simplificacao/logs
  cp resultados/*.csv resultados/e7_series.mat resultados/dia_escolhido.txt docs/superpowers/simplificacao/referencia/
  ls docs/superpowers/simplificacao/referencia
  ```
  Esperado: 10 CSVs, `e7_series.mat`, `dia_escolhido.txt`.

- [ ] **Passo 3: Capturar a saída do exp03 (ele só imprime no console)**
  ```bash
  $M -batch "cd matlab; exp03_chaveado_medio" > docs/superpowers/simplificacao/referencia/exp03.log 2>&1
  grep -E "^---|CCM =|erro max|ripple" docs/superpowers/simplificacao/referencia/exp03.log
  ```
  Esperado: dois blocos (`--- STC (CCM) ---` com `CCM = 1` e `--- 50 W/m^2 ... ---` com `CCM = 0`), cada um com uma linha `erro max` e uma `ripple`.

- [ ] **Passo 4: Descartar a figura regenerada pelo exp03** (o PDF muda só nos metadados)
  ```bash
  git restore relatorio/figs
  ```

- [ ] **Passo 5: Rodar os testes no estado atual e medir o tempo**
  ```bash
  time $M -batch "cd matlab; run_tests" > docs/superpowers/simplificacao/logs/testes_referencia.log 2>&1; tail -5 docs/superpowers/simplificacao/logs/testes_referencia.log
  ```
  Esperado: sem `Error`, todos os testes passando. Anotar o tempo no relato (Tarefa 10).

- [ ] **Passo 6: Commit**
  ```bash
  git add docs/superpowers/simplificacao/referencia
  git commit -m "Simplificacao: referencia congelada dos resultados

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

---

### Tarefa 2: Comparador das conclusões (C1–C11)

**Files:**
- Create: `docs/superpowers/simplificacao/testar_comparador.m`
- Create: `docs/superpowers/simplificacao/comparar_conclusoes.m`

As janelas e os limiares de C11 foram medidos em 10/11 nas séries de referência (fração P/Pg integrada na janela):

| Janela (h) | P&O | InC | PSO | Uso |
|---|---|---|---|---|
| 10,65–11,20 (depois da nuvem) | 0,999 | 0,919 | 0,962 | C11(i) PSO não acompanha a deriva; C11(ii) InC congela |
| 14,05–14,70 (poste, sombra forte) | 0,515 | 0,491 | 0,994 | C11(iv) PSO acha o global, locais presos |
| 15,05–15,45 (poste, sombra fraca) | 0,847 | 0,806 | 0,850 | C11(iii) PSO erra o global |

- [ ] **Passo 1: Escrever o teste do comparador**

  `docs/superpowers/simplificacao/testar_comparador.m`:
  ```matlab
  %TESTAR_COMPARADOR Confere o proprio comparador antes de confiar nele.
  % 1) A referencia comparada com ela mesma tem que passar em tudo.
  % 2) Um resultado perturbado (PSO "ganhando" no E6, o que inverte a
  %    ordem da conclusao C6) tem que falhar.
  aqui = fileparts(mfilename('fullpath'));
  ref = fullfile(aqui, 'referencia');
  log_ref = fullfile(ref, 'exp03.log');

  assert(comparar_conclusoes(ref, ref, log_ref), ...
      'A referencia contra ela mesma deveria passar em C1-C11');

  % Copia da referencia com o E6 adulterado
  tmp = tempname;
  copyfile(ref, tmp);
  arq = fullfile(tmp, 'e6_en50530.csv');
  t = readtable(arq, 'VariableNamingRule', 'preserve', 'TextType', 'string');
  t.eta_MPPT(t.algoritmo == "PSO") = 0.9999;
  writetable(t, arq);
  assert(~comparar_conclusoes(ref, tmp, log_ref), ...
      'Com o PSO melhor que o P&O no E6, C6 deveria falhar');
  rmdir(tmp, 's');
  disp('testar_comparador: OK');
  ```

- [ ] **Passo 2: Rodar e ver falhar**
  ```bash
  $M -batch "cd docs/superpowers/simplificacao; testar_comparador" 2>&1 | tail -5
  ```
  Esperado: erro `Unrecognized function or variable 'comparar_conclusoes'`.

- [ ] **Passo 3: Escrever o comparador**

  `docs/superpowers/simplificacao/comparar_conclusoes.m`:
  ```matlab
  function ok = comparar_conclusoes(pasta_ref, pasta_nova, log_exp03)
  %COMPARAR_CONCLUSOES Os resultados novos levam as mesmas conclusoes (C1-C11)?
  %   ok = comparar_conclusoes(pasta_ref, pasta_nova, log_exp03)
  %   pasta_ref  : CSVs e e7_series.mat de referencia (antes da simplificacao)
  %   pasta_nova : resultados novos (normalmente resultados/)
  %   log_exp03  : saida de console do exp03 da rodada nova
  %   Imprime PASSA/FALHA por checagem; ok = true se todas passarem.
  %   Criterios e tolerancias: docs/superpowers/specs/2026-11-10-simplificacao-codigo-design.md
  %   Os numeros nao precisam ser identicos: so precisam continuar dizendo
  %   a mesma coisa (mesma ordem entre algoritmos, mesmos picos etc.).
  r = {};      % lista de {id, descricao, passou}
  algs = ["P&O", "InC", "PSO"];

  % ---- C1: o painel extraido reproduz o datasheet (E1) ----
  e1r = ler(pasta_ref, 'e1_validacao_painel.csv');
  e1n = ler(pasta_nova, 'e1_validacao_painel.csv');
  for k = 1:height(e1n)
      passou = abs(e1n.erroPmax_pct(k)) <= 0.5 && abs(e1n.erroVoc_pct(k)) <= 0.5 && ...
          abs(e1n.gamaP_modelo_pct_K(k) - e1r.gamaP_modelo_pct_K(k)) <= 0.05;
      r = checar(r, 'C1', sprintf('%s: erro Pmax %.3f %%, gama_P %.3f %%/K (ref %.3f)', ...
          e1n.modelo(k), e1n.erroPmax_pct(k), e1n.gamaP_modelo_pct_K(k), ...
          e1r.gamaP_modelo_pct_K(k)), passou);
  end

  % ---- C2: a sombra cria multiplos picos (E2) ----
  % Mesmas linhas (= mesmo numero de picos por cenario), mesmo pico global,
  % potencia de cada pico a +-1 %
  e2r = ler(pasta_ref, 'e2_picos.csv');
  e2n = ler(pasta_nova, 'e2_picos.csv');
  passou = height(e2r) == height(e2n) && all(e2r.cenario == e2n.cenario) && ...
      all(e2r.("global") == e2n.("global")) && all(abs(e2n.P ./ e2r.P - 1) <= 0.01);
  r = checar(r, 'C2', sprintf('%d picos, mesmos globais, P a +-1 %%', height(e2n)), passou);

  % ---- C3: medio = chaveado em CCM; separa em DCM (E3) ----
  txt = fileread(log_exp03);
  erros = regexp(txt, 'v = [\d.]+ V \(([\d.]+) %\), iL = [\d.]+ A \(([\d.]+) %\)', 'tokens');
  ripple = regexp(txt, 'ripple iL: simulado ([\d.]+) A, analitico ([\d.]+) A', 'tokens');
  ccm = regexp(txt, 'CCM = (\d)', 'tokens');
  if numel(erros) < 2 || numel(ripple) < 2 || numel(ccm) < 2
      r = checar(r, 'C3', 'saida do exp03 incompleta', false);
  else
      erro_v = str2double(erros{1}{1});      % caso 1 = STC (CCM)
      erro_i = str2double(erros{1}{2});
      razao_ripple = str2double(ripple{1}{1}) / str2double(ripple{1}{2});
      passou = erro_v <= 0.5 && erro_i <= 1.5 && abs(razao_ripple - 1) <= 0.05 && ...
          strcmp(ccm{1}{1}, '1') && strcmp(ccm{2}{1}, '0');   % caso 2 = 50 W/m^2 (DCM)
      r = checar(r, 'C3', sprintf('STC: erro v %.2f %%, iL %.2f %%, ripple sim/ana %.3f; 50 W/m^2 em DCM', ...
          erro_v, erro_i, razao_ripple), passou);
  end
  % Fracao de periodos em DCM nas simulacoes longas (E6 e E7) a +-2 p.p.
  e6r = ler(pasta_ref, 'e6_en50530.csv');
  e6n = ler(pasta_nova, 'e6_en50530.csv');
  e7r = ler(pasta_ref, 'e7_dia.csv');
  e7n = ler(pasta_nova, 'e7_dia.csv');
  passou = all(abs(e6n.frac_DCM - e6r.frac_DCM) <= 0.02) && ...
      all(abs(e7n.frac_DCM - e7r.frac_DCM) <= 0.02);
  r = checar(r, 'C3', 'fracao em DCM de E6 e E7 a +-2 p.p.', passou);

  % ---- C4: PI com MF >= 45 graus, tolerancias de L e C (E4) ----
  % Mesmos pontos em CCM; neles MF >= 45 e MF, MG, t_s a +-5 % da referencia
  e4r = ler(pasta_ref, 'e4_margens.csv');
  e4n = ler(pasta_nova, 'e4_margens.csv');
  passou = height(e4r) == height(e4n) && all(e4r.ccm == e4n.ccm);
  if passou
      c = e4n.ccm == 1;
      passou = all(e4n.MF_graus(c) >= 45) && ...
          all(abs(e4n.MF_graus(c) ./ e4r.MF_graus(c) - 1) <= 0.05) && ...
          all(abs(e4n.MG_dB(c) ./ e4r.MG_dB(c) - 1) <= 0.05) && ...
          all(abs(e4n.ts_ms(c) ./ e4r.ts_ms(c) - 1) <= 0.05);
  end
  r = checar(r, 'C4', sprintf('MF min %.1f graus (ref %.1f)', min(e4n.MF_graus(e4n.ccm == 1)), ...
      min(e4r.MF_graus(e4r.ccm == 1))), passou);

  % ---- C5: P&O/InC param no pico local, PSO acha o global (E5) ----
  % Cada linha: eta a +-0,5 p.p. e a mesma classificacao (global = eta >= 0,99)
  e5r = ler(pasta_ref, 'e5_mppt_estatico.csv');
  e5n = ler(pasta_nova, 'e5_mppt_estatico.csv');
  passou = height(e5r) == height(e5n) && all(abs(e5n.eta - e5r.eta) <= 0.005) && ...
      all((e5n.eta >= 0.99) == (e5r.eta >= 0.99));
  r = checar(r, 'C5', sprintf('%d casos com o mesmo pico atingido', height(e5n)), passou);

  % ---- C6: EN 50530, ordem P&O > InC > PSO no melhor caso de cada um ----
  melhor_r = zeros(1, 3);  melhor_n = zeros(1, 3);
  for a = 1:3
      melhor_r(a) = max(e6r.eta_MPPT(e6r.algoritmo == algs(a)));
      melhor_n(a) = max(e6n.eta_MPPT(e6n.algoritmo == algs(a)));
  end
  passou = all(abs(melhor_n - melhor_r) <= 0.001) && melhor_n(1) > melhor_n(2) && ...
      melhor_n(2) > melhor_n(3);
  r = checar(r, 'C6', sprintf('eta P&O/InC/PSO = %.2f / %.2f / %.2f %%', 100 * melhor_n), passou);

  % ---- C7: o quase-estatico e valido (E6b, decisao D16) ----
  e6d = ler(pasta_nova, 'e6_dinamico.csv');
  limite = [0.004, 0.004, 0.011];
  passou = true;
  for a = 1:3
      k = e6d.algoritmo == algs(a);
      passou = passou && abs(e6d.eta_dinamico(k) - e6d.eta_quase_estatico(k)) <= limite(a);
  end
  r = checar(r, 'C7', 'eta dinamico x quase-estatico dentro de D16', passou);

  % ---- C8: dia real, ordem PSO > P&O > InC em eta e em energia (E7) ----
  cr = e7r.variante == "completo";
  cn = e7n.variante == "completo";
  eta_r = zeros(1, 3);  eta_n = zeros(1, 3);  E_r = zeros(1, 3);  E_n = zeros(1, 3);
  for a = 1:3
      eta_r(a) = e7r.eta_MPPT(cr & e7r.algoritmo == algs(a));
      eta_n(a) = e7n.eta_MPPT(cn & e7n.algoritmo == algs(a));
      E_r(a) = e7r.E_bat_Wh(cr & e7r.algoritmo == algs(a));
      E_n(a) = e7n.E_bat_Wh(cn & e7n.algoritmo == algs(a));
  end
  passou = all(abs(eta_n - eta_r) <= 0.003) && all(abs(E_n ./ E_r - 1) <= 0.01) && ...
      eta_n(3) > eta_n(1) && eta_n(1) > eta_n(2) && E_n(3) > E_n(1) && E_n(1) > E_n(2);
  r = checar(r, 'C8', sprintf('E_bat P&O/InC/PSO = %.1f / %.1f / %.1f Wh', E_n), passou);

  % ---- C9: ablacao, efeito do termico (~9 %) e das perdas (~11 %) ----
  variantes = ["sem termico (T = 25 C)", "sem perdas"];
  for v = 1:2
      passou = true;
      for a = 1:3
          ganho_r = e7r.E_bat_Wh(e7r.variante == variantes(v) & e7r.algoritmo == algs(a)) / E_r(a) - 1;
          ganho_n = e7n.E_bat_Wh(e7n.variante == variantes(v) & e7n.algoritmo == algs(a)) / E_n(a) - 1;
          passou = passou && abs(ganho_n - ganho_r) <= 0.01;
      end
      r = checar(r, 'C9', sprintf('%s: ganho de E_bat a +-1 p.p.', variantes(v)), passou);
  end

  % ---- C10: o trabalho anterior superestima ~22 % (E8) ----
  e8r = ler(pasta_ref, 'e8_baseline.csv');
  e8n = ler(pasta_nova, 'e8_baseline.csv');
  passou = abs(e8n.dif_vs_completo_pct(1) - e8r.dif_vs_completo_pct(1)) <= 1;
  r = checar(r, 'C10', sprintf('superestimativa %.1f %% (ref %.1f %%)', ...
      e8n.dif_vs_completo_pct(1), e8r.dif_vs_completo_pct(1)), passou);

  % ---- C11: as limitacoes dos MPPT continuam aparecendo (series do E7) ----
  % res{1..3} = P&O, InC, PSO (variante completa): t [s], P e Pg [W]
  s = load(fullfile(pasta_nova, 'e7_series.mat'), 'res');
  depois_nuvem = [10.65, 11.20];    % h: modulo esquentando depois da nuvem
  poste_forte = [14.05, 14.70];     % h: sombra do poste com fator 0,3
  poste_fraco = [15.05, 15.45];     % h: sombra mais fraca (fator 0,5), modulo quente
  po = eta_janela(s.res{1}, depois_nuvem);
  inc = eta_janela(s.res{2}, depois_nuvem);
  pso = eta_janela(s.res{3}, depois_nuvem);
  r = checar(r, 'C11', sprintf('(i) PSO nao acompanha a deriva: PSO %.3f <= 0,98 e P&O %.3f >= 0,99', ...
      pso, po), pso <= 0.98 && po >= 0.99);
  r = checar(r, 'C11', sprintf('(ii) InC congela: InC %.3f ao menos 3 p.p. abaixo do P&O', inc), ...
      inc <= po - 0.03);
  pso = eta_janela(s.res{3}, poste_fraco);
  r = checar(r, 'C11', sprintf('(iii) sombra fraca engana o PSO: PSO %.3f <= 0,95', pso), pso <= 0.95);
  po = eta_janela(s.res{1}, poste_forte);
  inc = eta_janela(s.res{2}, poste_forte);
  pso = eta_janela(s.res{3}, poste_forte);
  r = checar(r, 'C11', sprintf('(iv) poste forte: PSO %.3f >= 0,98; P&O %.3f e InC %.3f <= 0,7', ...
      pso, po, inc), pso >= 0.98 && po <= 0.7 && inc <= 0.7);

  % ---- Resumo ----
  passaram = cellfun(@(x) x, r(:, 3));
  fprintf('\n%d de %d checagens passaram\n', sum(passaram), numel(passaram));
  ok = all(passaram);
  end

  function t = ler(pasta, nome)
  % Le um CSV de resultados mantendo os nomes de coluna (ex.: "global")
  t = readtable(fullfile(pasta, nome), 'VariableNamingRule', 'preserve', 'TextType', 'string');
  end

  function r = checar(r, id, descricao, passou)
  % Registra e imprime uma checagem
  if passou
      fprintf('PASSA  %-4s %s\n', id, descricao);
  else
      fprintf('FALHA  %-4s %s\n', id, descricao);
  end
  r(end + 1, :) = {id, descricao, passou};
  end

  function eta = eta_janela(serie, janela_h)
  % Fracao da potencia maxima captada numa janela de horas: soma(P)/soma(Pg)
  t = serie.t / 3600;
  k = t >= janela_h(1) & t <= janela_h(2);
  eta = sum(serie.P(k)) / sum(serie.Pg(k));
  end
  ```

- [ ] **Passo 4: Rodar o teste do comparador e ver passar**
  ```bash
  $M -batch "cd docs/superpowers/simplificacao; testar_comparador" 2>&1 | grep -E "PASSA|FALHA|checagens|OK|Error"
  ```
  Esperado: na primeira chamada, `17 de 17 checagens passaram` (C1 ×2, C2, C3 ×2, C4, C5, C6, C7, C8, C9 ×2, C10, C11 ×4); na segunda, uma `FALHA C6`; no fim, `testar_comparador: OK`.
  Se alguma checagem falhar na referência contra ela mesma, o limiar está errado: ajustar o limiar (não o dado), registrar o ajuste para o relato e rodar de novo.

- [ ] **Passo 5: Commit**
  ```bash
  git add docs/superpowers/simplificacao/comparar_conclusoes.m docs/superpowers/simplificacao/testar_comparador.m
  git commit -m "Simplificacao: comparador das conclusoes C1-C11

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

---

### Tarefa 3: Script de verificação rápida de um lote

**Files:**
- Create: `docs/superpowers/simplificacao/verificar_lote.sh`

- [ ] **Passo 1: Escrever o script** (roda tudo o que é rápido, um MATLAB de cada vez, e para no primeiro erro)

  `docs/superpowers/simplificacao/verificar_lote.sh`:
  ```bash
  #!/bin/bash
  # Verificacao rapida depois de cada lote: testes, experimentos rapidos e comparador.
  # Uso: docs/superpowers/simplificacao/verificar_lote.sh <nome-do-lote>
  # Roda um MATLAB por vez (em paralelo esgota a memoria).
  set -eo pipefail
  cd "$(dirname "$0")/../../.."
  M=/Applications/MATLAB_R2026b.app/bin/matlab
  LOGS=docs/superpowers/simplificacao/logs/$1
  mkdir -p "$LOGS"

  echo "== testes"
  $M -batch "cd matlab; run_tests" > "$LOGS/testes.log" 2>&1 || { tail -20 "$LOGS/testes.log"; exit 1; }

  for exp in exp01_validacao_painel exp02_curvas_sombra exp03_chaveado_medio \
             exp04_controle exp05_mppt_estatico exp06b_en50530_dinamico; do
      echo "== $exp"
      $M -batch "cd matlab; $exp" > "$LOGS/$exp.log" 2>&1 || { tail -20 "$LOGS/$exp.log"; exit 1; }
  done

  echo "== comparador"
  $M -batch "addpath('docs/superpowers/simplificacao'); \
      ok = comparar_conclusoes('docs/superpowers/simplificacao/referencia', 'resultados', \
      '$LOGS/exp03_chaveado_medio.log'); if ~ok, exit(1); end" 2>&1 | grep -E "PASSA|FALHA|checagens"
  ```
  Observação: neste ponto o E6, o E7 e o E8 ainda não rodaram de novo, então C6 e C8–C11 comparam a referência com ela mesma e passam. Eles só valem de verdade na Tarefa 6.

- [ ] **Passo 2: Rodar no estado atual (sem mudanças) para validar o script**
  ```bash
  chmod +x docs/superpowers/simplificacao/verificar_lote.sh
  time docs/superpowers/simplificacao/verificar_lote.sh 00_base
  ```
  Esperado: `17 de 17 checagens passaram`. Anotar o tempo (é o custo de cada lote).

- [ ] **Passo 3: Descartar artefatos regenerados idênticos e commitar o script**
  ```bash
  git status --short resultados relatorio/figs
  git restore relatorio/figs resultados
  git add docs/superpowers/simplificacao/verificar_lote.sh
  git commit -m "Simplificacao: script de verificacao rapida por lote

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```
  Se `git status` mostrar mudança *numérica* em algum CSV de `resultados/` sem nenhuma mudança no código, o experimento não é determinístico: parar e investigar antes de seguir.

---

### Tarefa 4: Auditoria da etapa 1 (código do modelo e experimentos)

**Files:**
- Create: `docs/superpowers/simplificacao/achados_etapa1.md`
- Read: todos os `.m` de `matlab/` exceto `matlab/tests/` (54 arquivos)

- [ ] **Passo 1: Ler cada arquivo, na ordem do fluxo de dados:** `numerico/` → `painel/` → `termico/` → `conversor/` → `controle/` → `cenarios/` → `mppt/` → `simulacao/` → `experimentos/` → raiz (`setup_path`, `run_tests`, `raiz_projeto`). Para cada arquivo, aplicar os seis critérios do spec (opções sem uso real, duplicação, generalidade não usada, ramos defensivos redundantes, tamanho, precisão excessiva).

- [ ] **Passo 2: Para cada opção ou campo de configuração suspeito, provar o uso com grep** antes de anotar o achado. Exemplo para `op.V0` no quase-estático:
  ```bash
  grep -rn "V0" matlab --include='*.m' | grep -v "^matlab/tests/"
  ```
  O achado registra quem usa (ou ninguém).

- [ ] **Passo 3: Escrever `achados_etapa1.md`** com este formato:
  ```markdown
  # Achados da etapa 1 (código do modelo e experimentos)

  Legenda de risco: **baixo** = só reorganiza, números não mudam;
  **médio** = muda ordem de contas, tolerâncias ou consumo de aleatórios; números podem mudar um pouco.

  | # | Lote | Arquivo | Achado | Mudança proposta | Linhas (−) | Risco | Decisão |
  |---|---|---|---|---|---|---|---|
  | 1 | simulacao | `simulacao/sim_quase_estatica.m:20-21` | `op.V0` aceito mas sem efeito | Remover a opção e o comentário; remover `V0` das chamadas | ~4 | baixo | |

  Total estimado: −N linhas de código.
  ```
  Cada achado tem linha exata, evidência (grep ou trecho) na coluna "Achado" e uma mudança concreta. Agrupar por lote: `numerico`, `painel`, `termico`, `conversor`, `controle`, `cenarios`, `experimentos` (só achados que não tocam mppt/simulacao), e por último um lote único `mppt+simulacao`.

- [ ] **Passo 4: Commit e PARAR para aprovação**
  ```bash
  git add docs/superpowers/simplificacao/achados_etapa1.md
  git commit -m "Simplificacao: achados da auditoria (etapa 1)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```
  Apresentar a tabela ao usuário. Ele preenche a coluna **Decisão** (aprovado / recusado / editado). Nada é aplicado antes disso.

---

### Tarefa 5: Aplicar os lotes aprovados (protocolo, repetido por lote)

**Files:** os arquivos listados nos achados aprovados do lote.

Ordem dos lotes: `numerico` → `painel` → `termico` → `conversor` → `controle` → `cenarios` → `experimentos` → `mppt+simulacao` (por último, porque é o único que afeta E6/E7/E8). Lote sem achados aprovados é pulado.

Para **cada** lote:

- [ ] **Passo 1: Aplicar só os achados aprovados do lote,** exatamente como descritos na tabela. Mantêm-se os comentários de física; saem apenas os comentários que descreviam código removido. Os testes não mudam, exceto se uma função removida ou com assinatura alterada for chamada por eles (mudança mínima, anotada na coluna Decisão).

- [ ] **Passo 2: Verificar**
  ```bash
  docs/superpowers/simplificacao/verificar_lote.sh <lote>
  ```
  Esperado: `17 de 17 checagens passaram`.

- [ ] **Passo 3a: Se passou, conferir o que mudou nos resultados e commitar**
  ```bash
  git diff --stat resultados
  git restore relatorio/figs      # figuras só são regeneradas de vez na Tarefa 7
  git add matlab resultados docs/superpowers/simplificacao/achados_etapa1.md
  git commit -m "Simplificacao (lote <lote>): <resumo dos achados aplicados>

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

- [ ] **Passo 3b: Se falhou,** identificar qual achado causou a falha (reaplicar um por um). Reverter esse achado (`git restore` nos arquivos dele), marcar na tabela como "altera conclusão (Cn)" e voltar ao Passo 2 com o restante. Avisar o usuário no fim do lote.

---

### Tarefa 6: Experimentos longos e checagem final das conclusões

Só depois do lote `mppt+simulacao` (ou do último lote, se aquele não tiver achados). Se nenhum achado aprovado tocou `mppt/`, `simulacao/`, `cenarios/`, `painel/`, `termico/`, `conversor/` ou os scripts exp06/exp07/exp08, esta tarefa é pulada e isso fica registrado no relato.

- [ ] **Passo 1: E6 (≈ 1 h), em segundo plano**
  ```bash
  $M -batch "cd matlab; exp06_en50530" > docs/superpowers/simplificacao/logs/exp06.log 2>&1
  ```
  Esperado: termina sem `Error`; `resultados/e6_en50530.csv` regravado.

- [ ] **Passo 2: E7 (≈ 2–3 h), só depois do E6 terminar.** As séries antigas estão na referência; apagar força a simulação completa:
  ```bash
  rm resultados/e7_series.mat
  $M -batch "cd matlab; exp07_dia" > docs/superpowers/simplificacao/logs/exp07.log 2>&1
  ```
  Esperado: `resultados/e7_dia.csv` com 9 linhas e um `resultados/e7_series.mat` novo.

- [ ] **Passo 3: E8 (≈ 30 min), só depois do E7 terminar**
  ```bash
  $M -batch "cd matlab; exp08_baseline" > docs/superpowers/simplificacao/logs/exp08.log 2>&1
  ```

- [ ] **Passo 4: Comparador completo**
  ```bash
  ULTIMO=$(ls -td docs/superpowers/simplificacao/logs/*/ | head -1)
  $M -batch "addpath('docs/superpowers/simplificacao'); comparar_conclusoes('docs/superpowers/simplificacao/referencia', 'resultados', '${ULTIMO}exp03_chaveado_medio.log');" 2>&1 | grep -E "PASSA|FALHA|checagens"
  ```
  Esperado: `17 de 17 checagens passaram`. Se algo falhar, **parar e levar ao usuário** com os números (não reverter sozinho: cada rodada custa horas).

- [ ] **Passo 5: Commit**
  ```bash
  git add resultados docs/superpowers/simplificacao/logs
  git commit -m "Simplificacao: E6, E7 e E8 rodados de novo; C1-C11 passam

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

---

### Tarefa 7: Atualizar figuras, relatório e README

- [ ] **Passo 1: Listar os números que mudaram**
  ```bash
  git diff main -- resultados/*.csv
  ```
  Se não houver diferença numérica, pular para o Passo 4.

- [ ] **Passo 2: Regenerar as figuras** dos experimentos cujos CSVs mudaram, um por vez (o exp07 com o `e7_series.mat` novo só refaz a figura):
  ```bash
  $M -batch "cd matlab; exp07_dia"
  ```
  (repetir para cada `expNN` afetado)

- [ ] **Passo 3: Atualizar os valores citados** em `relatorio/relatorio.tex` (tabelas e texto: procurar cada número antigo com `grep -n "941,7" relatorio/relatorio.tex` etc.) e em `README.md` ("Principais resultados"). O texto das conclusões não muda. Recompilar:
  ```bash
  cd relatorio && tectonic relatorio.tex && cd ..
  ```
  Esperado: `relatorio/relatorio.pdf` gerado sem erro.

- [ ] **Passo 4: Conferir se o relatório cita nome de função ou opção alterada/removida**
  ```bash
  grep -n "texttt{" relatorio/relatorio.tex | grep -o "texttt{[^}]*}" | sort -u
  ```
  Cada nome que não existir mais em `matlab/` é corrigido no texto.

- [ ] **Passo 5: Commit**
  ```bash
  git add relatorio README.md
  git commit -m "Relatorio e README: valores apos a simplificacao do codigo

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

---

### Tarefa 8: Auditoria da etapa 2 (testes)

**Files:**
- Create: `docs/superpowers/simplificacao/achados_etapa2.md`
- Read: os 15 arquivos de `matlab/tests/`

- [ ] **Passo 1: Ler cada teste** com os critérios do spec e mais dois específicos de testes: (a) montagem repetida do mesmo painel/conversor em vários arquivos; (b) verificações que repetem outra verificação do mesmo teste ou de outro arquivo. **Nenhum teste deixa de cobrir um comportamento**: remover um teste só se outro cobre exatamente a mesma coisa (citar qual).

- [ ] **Passo 2: Escrever `achados_etapa2.md`** no mesmo formato da Tarefa 4 (coluna extra: "Cobertura mantida por").

- [ ] **Passo 3: Commit e PARAR para aprovação** do usuário (coluna Decisão).

---

### Tarefa 9: Aplicar os achados dos testes

- [ ] **Passo 1: Aplicar os achados aprovados**, um arquivo de teste por vez.

- [ ] **Passo 2: Rodar os testes depois de cada arquivo**
  ```bash
  $M -batch "cd matlab; run_tests" 2>&1 | tail -5
  ```
  Esperado: todos passando.

- [ ] **Passo 3: Prova de que os testes enxutos ainda detectam erro** (teste removido ou afrouxado pode deixar de pegar defeitos). Para **cada arquivo de teste alterado**, escolher uma perturbação pequena no código que ele testa (ex.: em `test_ztp160m`, multiplicar `Rs` por 1,1 no `parametros_painel.m`; em `test_mppt`, inverter o sinal do passo do P&O em `mppt_po.m`) e rodar só aquele arquivo, primeiro com o teste **antigo** e depois com o **novo**:
  ```bash
  # 1) aplicar a perturbacao no codigo (edicao manual, uma linha)
  git stash push matlab/tests/test_X.m          # volta temporariamente ao teste antigo
  $M -batch "cd matlab; setup_path; r = runtests('tests/test_X.m'); disp(sum(~[r.Passed]))"
  git stash pop                                  # teste novo
  $M -batch "cd matlab; setup_path; r = runtests('tests/test_X.m'); disp(sum(~[r.Passed]))"
  git restore matlab/<arquivo perturbado>        # desfaz a perturbacao
  ```
  Esperado: o antigo falha (número > 0) **e** o novo também falha. Se o antigo falha e o novo não, a simplificação afrouxou o teste: reverter aquele achado. Se nem o antigo falha, trocar de perturbação. Registrar as perturbações usadas na tabela da etapa 2.

- [ ] **Passo 4: Commit**
  ```bash
  git add matlab/tests docs/superpowers/simplificacao/achados_etapa2.md
  git commit -m "Simplificacao (etapa 2): testes enxutos

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
  ```

---

### Tarefa 10: Relato final e merge

**Files:**
- Create: `docs/superpowers/simplificacao/relato.md`

- [ ] **Passo 1: Contar as linhas depois** (mesmo método da medição de 10/11):
  ```bash
  cd matlab && for d in $(find . -name '*.m' -exec dirname {} \; | sort -u); do awk -v d="$d" '/^[[:space:]]*$/{b++;next} /^[[:space:]]*%/{c++;next} {k++} END{printf "%-14s codigo=%5d comentario=%5d branco=%4d\n", d, k, c, b}' $d/*.m; done; cd ..
  ```

- [ ] **Passo 2: Escrever `relato.md`** com:
  - tabela antes/depois por pasta (o "antes" está no spec);
  - achados aplicados, recusados e revertidos ("altera conclusão"), com links para as tabelas;
  - saída do comparador (17 linhas PASSA/FALHA) e a lista das diferenças numéricas relevantes;
  - limiares ajustados na Tarefa 2, se houver;
  - tempo dos testes antes/depois.

- [ ] **Passo 3: Verificação final**
  ```bash
  $M -batch "cd matlab; run_tests" 2>&1 | tail -3
  git status --short
  ```
  Esperado: testes passando; árvore limpa (exceto as pastas não versionadas `guia/`, `docs/diagramas/`, `referencias/experimento/`).

- [ ] **Passo 4: Commit do relato e PARAR.** Apresentar o relato ao usuário e perguntar: (a) se pode fazer o merge em `main` e o push; (b) se a pasta `docs/superpowers/simplificacao/referencia/` (~2 MB) deve ir para `main` ou ser removida antes do merge.
