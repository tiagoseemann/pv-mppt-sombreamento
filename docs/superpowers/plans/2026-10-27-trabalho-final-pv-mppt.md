# Trabalho Final DAS5109 — PV sob Sombreamento Parcial: Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar, validar e documentar o modelo eletrotérmico de um módulo FV sob sombreamento parcial acoplado a um buck-boost com perdas, e comparar P&O, InC e PSO (eficiência de rastreamento e energia), conforme `proposta/proposta.pdf`.

**Architecture:** Funções MATLAB pequenas, uma responsabilidade por arquivo, organizadas por bloco físico (`painel/`, `termico/`, `conversor/`, `controle/`, `mppt/`, `simulacao/`, `cenarios/`). Três níveis de modelo: chaveado (validação), médio em DAE com `ode15s` + matriz de massa (transitórios) e quase-estático (dia inteiro). Cada bloco tem testes `matlab.unittest`; cada experimento é um script que gera figuras em `relatorio/figs/` e tabelas em `resultados/`.

**Figuras:** toda `figure(...)` de experimento usa `'Theme', 'light'` (em modo batch o MATLAB R2026b gera fundo escuro por padrão, inclusive no PDF).

**Estilo de código (exigência do usuário):** código simples e direto, que um júnior entenda: nomes claros, laços explícitos em vez de vetorização obscura, sem abstrações desnecessárias, e **comentários explicando a física e a lógica** de cada equação. Todo código de implementação abaixo segue essa regra; ao executar, manter o padrão.

**Tech Stack:** MATLAB R2026b **apenas o núcleo** (verificado: sem Optimization nem Control System Toolbox → Levenberg-Marquardt, resposta em frequência e margens implementados à mão); `matlab.unittest`; LaTeX via `tectonic` para o relatório; dados climáticos do PVGIS.

---

## Decisões (validadas em 03/11/2026)

| # | Decisão | Valor adotado | Justificativa |
|---|---|---|---|
| D1 | Painel | **ZTROON ZTP-160M** (`referencias/datasheets/ZTP-160M_Datasheet_v.4.2.pdf`). O **KC200GT** fica só como benchmark da extração (resultado publicado por Villalva 2009) | Valida o método contra a literatura e aplica ao painel real |
| D1a | Diodos de bypass do ZTP-160M | **3 submódulos de 11 células** (hipótese) | O datasheet informa "Associação das células 3x11" mas não o número de diodos; 3 colunas de 11 células com um bypass por coluna é a configuração usual. Declarar como hipótese no relatório |
| D2 | Ferramentas | **Só MATLAB base** | Toolboxes não instaladas; código roda em qualquer MATLAB |
| D3 | Bateria | **12 V constante** (fonte ideal) | Sem sombra, Vmp = 19,6 V > 12 V → conversor abaixa (buck). Com sombra, o pico global cai para ~7–13 V (1 ou 2 submódulos) < 12 V → precisa **elevar** (boost). Logo o buck-boost é necessário justamente para o MPPT global, o que dá um argumento físico para a topologia. Simplificação declarada: tensão da bateria não varia com o estado de carga |
| D4 | Conversor | f_s = 20 kHz; L e C pelo ripple (Δi_L = 30 %, Δv_pv = 1 %) → L ≈ 57 µH, C ≈ 1,3 mF; MOSFET R_on = 18 mΩ (classe 60 V: a chave vê V_pv + V_bat ≈ 37 V), Schottky V_F = 0,45 V, R_D = 10 mΩ, r_L = 20 mΩ, t_r+t_f = 100 ns | 20 kHz: acima da faixa audível e com perdas de chaveamento pequenas nessa potência (o trabalho anterior usou 2 kHz, o que exige um indutor 10× maior). As perdas são valores típicos de catálogo; o experimento E7 mede o efeito delas (variante "sem perdas"), então a conclusão não depende de valores exatos |
| D5 | Perfil EN 50530 | Tabelas B.2, B.3 e B.4 transcritas em `data/en50530_rampas.csv` a partir do relatório de ensaio TÜV Rheinland No. CN21VE2D 001 (EN 50530:2010+A1:2013) | O texto da norma é pago; os valores do relatório conferem aritmeticamente com as durações impressas. Duração total ≈ 7,0 h → simulado em modelo quase-estático |
| D6 | Dia em Florianópolis | PVGIS horário (lat −27,595; lon −48,548; inclinação 27°; azimute norte), dia de céu claro de verão + nuvens e sombra de poste **sintéticas e documentadas** | Dados horários não têm transitórios rápidos |
| D7 | Relatório | LaTeX, mesmo estilo de artigo do trabalho anterior, em `relatorio/` | Continuidade com a disciplina |
| D9 | Modelo de 2 diodos (decidido após a Tarefa 2) | **Convenção de Ishaque (2011): a₁ = 1, a₂ = 1,2, I₀₁ = I₀₂**; lei térmica **efetiva** I₀(T) ∝ T³·exp(−E_g,ef/kT) com **E_g,ef ajustado pelo Kv**, igual nos dois modelos (1d e 2d), ambos com as 5 condições | A Tarefa 2 mostrou que (i) com E_g = 1,12 eV o modelo dá Kv = −0,106 V/K contra −0,123 V/K medido (KC200GT), e (ii) o datasheet não identifica I₀₂: as 4 condições de STC fecham para qualquer I₀₂ entre 10⁻¹² e 10⁻⁵ A. A não-identificabilidade vira resultado do relatório (Tarefa 3, análise de sensibilidade à razão I₀₂/I₀₁) |
| D10 | Resistência paralela (decidido após a Tarefa 3) | **R_p(G) = R_p,ref·(G_n/G)** (De Soto, Klein e Beckman, 2006) | Com R_p constante, o ajuste do ZTP-160M (R_p ≈ 41 Ω) previa perda de 26 % de eficiência em 200 W/m², contra 3–5 % típicos de módulos mono-Si. Em STC nada muda (extração inalterada); afeta baixa irradiância e submódulos sombreados |
| D11 | Modelo térmico (decidido na Tarefa 4) | Convecção de **Watmuff (h = 2,8 + 3,0v)** nas duas faces; radiação: **frente → céu, verso → solo (≈ T_amb)**; capacidade térmica pela **massa do datasheet** (8,9 kg × 840 J/kgK / 0,82 m² ≈ 9,1 kJ/m²K) | McAdams (5,7 + 3,8v) já inclui radiação e a contava duas vezes; com tudo irradiando para o céu, a calibração pelo NMOT exigia k_h = 0,33. Com as correções: k_h = 0,79 e τ ≈ 7,0 min (faixa típica 5–7 min) |
| D12 | Regra de projeto do PI (decidido na Tarefa 8) | Varrer **f_c e a posição do zero** ω_z = r·ω_c, r ∈ {0,2; 0,5; 1; 2; 5}, mantendo MF ≥ 45°, MG ≥ 6 dB (pontos em CCM) e t_s < 20 ms; escolher a maior f_c | A regra do plano (zero em ω_c/5, r = 0,2) falha para qualquer f_c: a ressonância LC (~240 Hz, ζ ≈ 0,16) cruza 0 dB com fase ≈ −150°. Cruzar bem abaixo da ressonância com ação integral dominante (r > 1) resolve; a regra antiga fica na varredura para comparação |
| D8 | Validação do painel | O datasheet **não tem curvas I-V**: não há o que digitalizar. Validação por (a) pontos de STC, (b) coeficiente térmico de **Pmax (−0,4 %/K), que não entra no ajuste** e serve de teste independente, (c) **NMOT 45 °C** no modelo térmico, (d) KC200GT contra Villalva | Usa só informação publicada; o relatório declara a limitação |

Dados do ZTP-160M (datasheet v4.3, dez/2024): Pmax 160 W, Vmp 19,57 V, Imp 8,20 A, Voc 22,64 V, Isc 9,02 A, 33 células (3x11), área 0,82 m², NMOT 45 °C, coeficientes −0,4 %/K (Pmax), −0,34 %/K (Voc), +0,05 %/K (Isc). O trabalho anterior leu "Pmax 4,8 W / 11 células": era a divisão por célula, não o painel.

---

## Estrutura de arquivos

```
matlab/
  setup_path.m            raiz_projeto.m          run_tests.m
  numerico/  levenberg_marquardt.m
  painel/    celula_params.m  residuo_painel.m  painel_sombreado.m  curva_pv.m
             kcl_modulo.m  extrair_parametros.m  datasheet_painel.m
             parametros_painel.m  validar_painel.m
  termico/   parametros_termicos.m  termico_dTdt.m  calibrar_nmot.m
  conversor/ parametros_conversor.m  conversor_ideal.m  conversor_medio_rhs.m
             equilibrio_conversor.m  verifica_ccm.m  sim_chaveado.m  sim_medio_aberta.m
  controle/  linearizar_planta.m  resposta_freq.m  gvd_analitico.m  margens.m
             projeto_pi.m  resposta_degrau_mf.m
  mppt/      mppt_po.m  mppt_inc.m  mppt_pso.m  mppt_fixo.m  config_mppt.m
             rastrear_estatico.m
  simulacao/ sim_dinamica.m  sim_quase_estatica.m  oraculo_pmax.m
  cenarios/  cenario_constante.m  perfil_en50530.m  baixar_pvgis.m
             dia_florianopolis.m  aplicar_sombras.m
  experimentos/ exp01_validacao_painel.m ... exp08_baseline.m
  tests/     test_*.m
data/        clima/  en50530_rampas.csv
resultados/  *.csv (tabelas geradas)
relatorio/   relatorio.tex  figs/
```

Comando padrão de teste (usado em todas as tarefas):

```bash
cd /Users/tiagoseemann/Projetos/TrabalhoModelagem/matlab && \
/Applications/MATLAB_R2026b.app/bin/matlab -batch "run_tests" 2>&1 | grep -v "Trial License"
```

Para rodar um único arquivo de teste: `-batch "setup_path; r = runtests('tests/test_X.m'); disp(table(r))"`.

---

### Tarefa 0: Reorganizar o código existente e criar o harness de testes

**Files:**
- Create: `matlab/setup_path.m`, `matlab/raiz_projeto.m`, `matlab/run_tests.m`, `matlab/tests/test_sombreamento.m`
- Move: `matlab/{parametros_painel,residuo_painel,painel_sombreado,curva_pv}.m` → `matlab/painel/`; `matlab/exemplo_*.m` → `matlab/experimentos/`
- Modify: `.gitignore`

- [ ] **Passo 1: Mover arquivos**

```bash
cd /Users/tiagoseemann/Projetos/TrabalhoModelagem/matlab
mkdir -p painel termico conversor controle mppt simulacao cenarios experimentos tests numerico
mv parametros_painel.m residuo_painel.m painel_sombreado.m curva_pv.m painel/
mv exemplo_sombreamento.m exemplo_dae_conversor.m experimentos/
mkdir -p ../data/clima ../resultados ../relatorio/figs
```

- [ ] **Passo 2: Criar `setup_path.m`, `raiz_projeto.m`, `run_tests.m`**

```matlab
function setup_path()
%SETUP_PATH Adiciona as pastas do projeto ao path.
raiz = fileparts(mfilename('fullpath'));
pastas = {'numerico', 'painel', 'termico', 'conversor', 'controle', ...
          'mppt', 'simulacao', 'cenarios', 'experimentos'};
addpath(raiz);
for k = 1:numel(pastas)
    addpath(fullfile(raiz, pastas{k}));
end
end
```

```matlab
function r = raiz_projeto()
%RAIZ_PROJETO Pasta raiz do repositorio (pai de matlab/).
r = fileparts(fileparts(mfilename('fullpath')));
end
```

```matlab
function run_tests()
%RUN_TESTS Roda todos os testes de matlab/tests e falha se algum falhar.
setup_path();
r = runtests(fullfile(fileparts(mfilename('fullpath')), 'tests'));
disp(table(r));
assert(all([r.Passed]), '%d teste(s) falhando', sum(~[r.Passed]));
end
```

- [ ] **Passo 3: Escrever teste de regressão do código existente**

Valores medidos na execução de 27/10/2026 com `parametros_painel()` genérico.

```matlab
function tests = test_sombreamento
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.p = parametros_painel('generico');
end

function test_regressao_curvas(tc)
p = tc.TestData.p;
c1 = curva_pv([1000 1000 1000], p.Tn, p);
c2 = curva_pv([1000 1000  400], p.Tn, p);
c3 = curva_pv([1000  600  300], p.Tn, p);
verifyEqual(tc, c1.Pmp, 138.2, 'RelTol', 0.01);
verifyEqual(tc, c2.Pmp,  89.2, 'RelTol', 0.01);
verifyEqual(tc, c2.Vmp,  11.58, 'AbsTol', 0.2);
verifyEqual(tc, c3.Pmp,  57.8, 'RelTol', 0.01);
end

function test_numero_de_picos(tc)
p = tc.TestData.p;
verifyEqual(tc, height(curva_pv([1000 1000 1000], p.Tn, p).picos), 1);
verifyEqual(tc, height(curva_pv([1000 1000  400], p.Tn, p).picos), 2);
verifyEqual(tc, height(curva_pv([1000  600  300], p.Tn, p).picos), 3);
end

function test_newton_converge(tc)
p = tc.TestData.p;
[~, s] = painel_sombreado(15, [1000 1000 400], p.Tn, p);
verifyLessThan(tc, s.res, 1e-9);
verifyLessThan(tc, s.iter, 30);
end

function test_bypass_conduz_quando_sombreado(tc)
p = tc.TestData.p;
[I, s] = painel_sombreado(9, [1000 1000 400], p.Tn, p);
verifyLessThan(tc, s.Vj(3), -0.2);                       % submodulo 3 bypassado
verifyEqual(tc, s.Ic(3) + s.Ibp(3), I, 'AbsTol', 1e-8);  % KCL
verifyGreaterThan(tc, s.Ibp(3), 1);                      % bypass carrega o excesso
end

function test_uniforme_igual_modulo_unico(tc)
p = tc.TestData.p;
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;
for V = [0 5 10 15 18 20]
    I3 = painel_sombreado(V, [1000 1000 1000], p.Tn, p);
    I1 = painel_sombreado(V, 1000, p.Tn, q);
    verifyEqual(tc, I3, I1, 'AbsTol', 1e-3);
end
end
```

- [ ] **Passo 4: Adaptar `parametros_painel` para aceitar nome**

Trocar a assinatura em `matlab/painel/parametros_painel.m` para `function p = parametros_painel(nome)`, mantendo o corpo atual como caso `'generico'`. (O caso de painéis reais entra na Tarefa 2.)

```matlab
function p = parametros_painel(nome)
%PARAMETROS_PAINEL Parametros do modulo FV.
%   p = parametros_painel('generico')  painel generico de 36 celulas (~140 W)
if nargin < 1, nome = 'generico'; end
if ~strcmpi(nome, 'generico')
    error('parametros_painel:nome', 'Painel "%s" ainda nao suportado', nome);
end
p.nome = 'generico';
% ... (corpo atual, inalterado, a partir de "% Constantes fisicas")
end
```

- [ ] **Passo 5: Rodar testes**

Run: comando padrão. Expected: 5 testes `Passed`.

- [ ] **Passo 6: Atualizar `.gitignore` e commitar**

Acrescentar ao `.gitignore`:
```
```

```bash
cd /Users/tiagoseemann/Projetos/TrabalhoModelagem
git add .gitignore matlab
git commit -m "Modelo de sombreamento em MATLAB com harness de testes"
```

---

### Tarefa 1: Fatorar dependência com G e T (`celula_params`) e criar `kcl_modulo`

**Files:**
- Create: `matlab/painel/celula_params.m`, `matlab/painel/kcl_modulo.m`, `matlab/tests/test_kcl_modulo.m`
- Modify: `matlab/painel/residuo_painel.m` (usar `celula_params`)

- [ ] **Passo 1: Escrever teste que falha**

```matlab
function tests = test_kcl_modulo
tests = functiontests(localfunctions);
end

function test_kcl_zero_em_ponto_da_curva(tc)
p = parametros_painel('generico');
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;  q.I0bp = 0;   % kcl_modulo nao tem diodo de bypass
I = painel_sombreado(15, 1000, p.Tn, q);
F = kcl_modulo(15, I, 1000, p.Tn, p);
verifyEqual(tc, F, 0, 'AbsTol', 1e-6);
end

function test_derivada_analitica(tc)
p = parametros_painel('generico');
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;
V = 17;  h = 1e-4;
I  = painel_sombreado(V, 1000, p.Tn, q);
Ip = painel_sombreado(V + h, 1000, p.Tn, q);
Im = painel_sombreado(V - h, 1000, p.Tn, q);
[~, ~, dIdV] = kcl_modulo(V, I, 1000, p.Tn, p);
verifyEqual(tc, dIdV, (Ip - Im) / (2 * h), 'RelTol', 1e-3);
end
```

- [ ] **Passo 2: Rodar e ver falhar**

Run: `-batch "setup_path; r = runtests('tests/test_kcl_modulo.m'); disp(table(r))"`
Expected: FAIL, `Undefined function 'kcl_modulo'`.

- [ ] **Passo 3: Implementar `celula_params.m` e `kcl_modulo.m`**

```matlab
function c = celula_params(G, T, p)
%CELULA_PARAMS Grandezas dependentes de G e T de um grupo de p.Ncel celulas.
%   G pode ser vetor (uma irradiancia por submodulo); c.Ipv tem o mesmo tamanho.
c.Vt   = p.k * T / p.q;
c.Vt_s = p.Ncel * c.Vt;
c.Rs_s = p.Ncel * p.Rs;
c.Rp_s = p.Ncel * p.Rp;
c.Ipv  = (G(:) / p.Gn) * (p.Ipv_n + p.Ki * (T - p.Tn));
c.I01  = p.I01_n * fator_T(p.a1, 3);
c.I02  = p.I02_n * fator_T(p.a2, 1.5);

    function f = fator_T(a, gam)
        f = (T / p.Tn)^gam * exp(p.q * p.Eg / (a * p.k) * (1 / p.Tn - 1 / T));
    end
end
```

```matlab
function [F, g] = kcl_modulo(V, I, G, T, p)
%KCL_MODULO Residuo explicito da equacao do modulo inteiro (sem sombra) em (V, I).
%   F = 0 quando (V, I) esta sobre a curva. g = -dIc/dVd, usado em
%   dI/dV = -g / (1 + Rs_modulo * g).
q = p;  q.Ncel = p.Ns;            % modulo inteiro como um unico grupo
c = celula_params(G, T, q);
Vd = V + c.Rs_s * I;
e1 = exp(Vd / (p.a1 * c.Vt_s));
e2 = exp(Vd / (p.a2 * c.Vt_s));
F = c.Ipv - c.I01 * (e1 - 1) - c.I02 * (e2 - 1) - Vd / c.Rp_s - I;
g = c.I01 * e1 / (p.a1 * c.Vt_s) + c.I02 * e2 / (p.a2 * c.Vt_s) + 1 / c.Rp_s;
end
```

- [ ] **Passo 4: Refatorar `residuo_painel.m` para usar `celula_params`**

Substituir o bloco que vai de `% Parametros do submodulo` até `I02 = ...` por:

```matlab
c = celula_params(G, T, p);
Vt_s = c.Vt_s;  Rs_s = c.Rs_s;  Rp_s = c.Rp_s;
Ipv = c.Ipv;  I01 = c.I01;  I02 = c.I02;
Vt_bp = p.nbp * c.Vt;
```

- [ ] **Passo 5: Rodar todos os testes**

Run: comando padrão. Expected: todos `Passed` (inclusive a regressão da Tarefa 0, provando que a refatoração não mudou resultados).

- [ ] **Passo 6: Commit**

```bash
git add matlab && git commit -m "Fatora celula_params e cria kcl_modulo explicito"
```

---

### Tarefa 2: Extração de parâmetros (2 diodos e 1 diodo) validada no KC200GT

**Files:**
- Create: `matlab/numerico/levenberg_marquardt.m`, `matlab/painel/datasheet_painel.m`, `matlab/painel/extrair_parametros.m`, `matlab/tests/test_levenberg_marquardt.m`, `matlab/tests/test_extracao.m`
- Modify: `matlab/painel/parametros_painel.m`

- [ ] **Passo 1: Teste do Levenberg-Marquardt (falha)**

```matlab
function tests = test_levenberg_marquardt
tests = functiontests(localfunctions);
end

function test_rosenbrock(tc)
f = @(x) [10 * (x(2) - x(1)^2); 1 - x(1)];
x = levenberg_marquardt(f, [-1.2; 1], [-5; -5], [5; 5]);
verifyEqual(tc, x, [1; 1], 'AbsTol', 1e-6);
end

function test_respeita_limites(tc)
f = @(x) x - 3;                       % minimo irrestrito em 3
x = levenberg_marquardt(f, 0, -1, 2);
verifyEqual(tc, x, 2, 'AbsTol', 1e-9);
end
```

- [ ] **Passo 2: Implementar `levenberg_marquardt.m`**

```matlab
function [x, info] = levenberg_marquardt(fun, x0, lb, ub, opts)
%LEVENBERG_MARQUARDT Minimiza ||fun(x)||^2 com limites (projecao nos limites).
%   Jacobiano por diferencas centrais. Substitui lsqnonlin (toolbox ausente).
if nargin < 5, opts = struct(); end
maxIt = campo(opts, 'maxIt', 500);
tol   = campo(opts, 'tol', 1e-14);
lb = lb(:);  ub = ub(:);
x = min(max(x0(:), lb), ub);
r = fun(x);  custo = r.' * r;  mu = 1e-3;
for it = 1:maxIt
    J = jac_num(fun, x, r, lb, ub);
    A = J.' * J;  b = J.' * r;
    aceitou = false;
    while mu < 1e12
        dx = -(A + mu * diag(diag(A) + eps)) \ b;
        xn = min(max(x + dx, lb), ub);
        rn = fun(xn);  cn = rn.' * rn;
        if cn < custo
            passo = norm(xn - x);
            x = xn;  r = rn;  custo = cn;  mu = max(mu / 3, 1e-12);
            aceitou = true;
            break
        end
        mu = mu * 4;
    end
    if ~aceitou || custo < tol || passo < 1e-12 * (1 + norm(x))
        break
    end
end
info = struct('iter', it, 'residuo', sqrt(custo), 'r', r);
end

function J = jac_num(fun, x, r, lb, ub)
J = zeros(numel(r), numel(x));
for j = 1:numel(x)
    h = 1e-6 * max(1, abs(x(j)));
    xp = x;  xp(j) = min(x(j) + h, ub(j));
    xm = x;  xm(j) = max(x(j) - h, lb(j));
    J(:, j) = (fun(xp) - fun(xm)) / (xp(j) - xm(j));
end
end

function v = campo(s, nome, padrao)
if isfield(s, nome), v = s.(nome); else, v = padrao; end
end
```

- [ ] **Passo 3: Rodar `test_levenberg_marquardt`** — Expected: 2 `Passed`.

- [ ] **Passo 4: Teste da extração (falha)**

```matlab
function tests = test_extracao
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('kc200gt');
[tc.TestData.p, tc.TestData.info] = extrair_parametros(tc.TestData.ds, '2d');
end

function test_pontos_chave_2d(tc)
ds = tc.TestData.ds;  p = tc.TestData.p;
c = curva_pv(1000 * ones(1, p.Nsub), p.Tn, p, 2000);
verifyEqual(tc, c.Pmp, ds.Pmax, 'RelTol', 0.005);
verifyEqual(tc, c.Vmp, ds.Vmp, 'RelTol', 0.01);
verifyEqual(tc, c.I(1), ds.Isc, 'RelTol', 0.005);
verifyEqual(tc, c.V(end), ds.Voc, 'RelTol', 0.005);
end

function test_coeficiente_Voc(tc)
ds = tc.TestData.ds;  p = tc.TestData.p;
G = 1000 * ones(1, p.Nsub);
c25 = curva_pv(G, p.Tn, p, 2000);
c50 = curva_pv(G, p.Tn + 25, p, 2000);
verifyEqual(tc, (c50.V(end) - c25.V(end)) / 25, ds.Kv, 'RelTol', 0.05);
end

function test_parametros_fisicos(tc)
p = tc.TestData.p;
verifyGreaterThan(tc, p.Rs * p.Ns, 0.01);
verifyLessThan(tc, p.Rs * p.Ns, 1);
verifyGreaterThan(tc, p.Rp * p.Ns, 50);
verifyLessThan(tc, tc.TestData.info.residuo, 1e-6);
end

function test_modelo_1d(tc)
ds = tc.TestData.ds;
p1 = extrair_parametros(ds, '1d');
c = curva_pv(1000 * ones(1, p1.Nsub), p1.Tn, p1, 2000);
verifyEqual(tc, c.Pmp, ds.Pmax, 'RelTol', 0.005);
verifyEqual(tc, p1.I02_n, 0);
end
```

- [ ] **Passo 5: Implementar `datasheet_painel.m`**

KC200GT: Villalva et al. (2009), Tabela I (só para validar a extração). ZTP-160M: datasheet v4.3; coeficientes em %/K convertidos para A/K e V/K.

```matlab
function ds = datasheet_painel(nome)
%DATASHEET_PAINEL Dados de catalogo (STC) usados na extracao de parametros.
switch lower(nome)
%   Isc, Imp [A]; Voc, Vmp [V]; Pmax [W]; Ki [A/K]; Kv [V/K];
%   gamaP = coeficiente termico de Pmax [1/K] (usado so para VALIDAR o modelo);
%   Ns = celulas em serie; Nsub = submodulos (= diodos de bypass);
%   a_1d = fator de idealidade adotado no modelo de 1 diodo.
switch lower(nome)
    case 'kc200gt'
        % Kyocera KC200GT -- Villalva et al. (2009), Tabela I.
        % Usado apenas como benchmark da extracao de parametros.
        ds.nome = 'KC200GT';
        ds.Isc = 8.21;   ds.Voc = 32.9;
        ds.Imp = 7.61;   ds.Vmp = 26.3;   ds.Pmax = 200.143;
        ds.Ki = 3.18e-3; ds.Kv = -0.123;  ds.gamaP = NaN;
        ds.Ns = 54;      ds.Nsub = 3;
        ds.a_1d = 1.3;
    case 'ztp160m'
        % ZTROON ZTP-160M -- datasheet v4.3 (dez/2024).
        ds.nome = 'ZTP-160M';
        ds.Isc = 9.02;   ds.Voc = 22.64;
        ds.Imp = 8.20;   ds.Vmp = 19.57;  ds.Pmax = 160;
        ds.Ki = 0.0005 * ds.Isc;          % +0,05 %/K de Isc
        ds.Kv = -0.0034 * ds.Voc;         % -0,34 %/K de Voc
        ds.gamaP = -0.004;                % -0,4 %/K de Pmax
        ds.Ns = 33;                       % "Associacao das celulas 3x11"
        ds.Nsub = 3;                      % HIPOTESE: 1 bypass por coluna de 11
        ds.A = 0.82;                      % area [m^2]
        ds.NMOT = 45;                     % [C]
        ds.a_1d = 1.1;                    % FF alto (0,78): a = 1,3 nao fecha (revisao Tarefa 2)
    otherwise
        error('datasheet_painel:nome', 'Painel desconhecido: %s', nome);
end
end
```

- [ ] **Passo 6: Implementar `extrair_parametros.m`**

```matlab
function [p, info] = extrair_parametros(ds, modelo)
%EXTRAIR_PARAMETROS Parametros do modelo de 2 (ou 1) diodos a partir do datasheet.
%   '2d': a1=1, a2=2; incognitas [Ipv, log10 I01, log10 I02, Rs, Rp] (modulo)
%         condicoes: Isc, Voc, MPP, dP/dV=0 no MPP, coef. Kv de Voc
%   '1d': a1=ds.a_1d, I02=0; incognitas [Ipv, log10 I01, Rs, Rp]
%         condicoes: Isc, Voc, MPP, dP/dV=0 no MPP
%   Todas as condicoes sao residuos EXPLICITOS de kcl_modulo nos pontos dados.
if nargin < 2, modelo = '2d'; end
p0 = parametros_base(ds);
dT = 25;
switch modelo
    case '2d'
        p0.a1 = 1;  p0.a2 = 2;
        x0 = [ds.Isc; -10; -6; 0.2; 300];
        lb = [ds.Isc; -14; -10; 1e-4; 10];
        ub = [1.05 * ds.Isc; -5; -3; 2; 1e4];
    case '1d'
        p0.a1 = ds.a_1d;  p0.a2 = 2;
        x0 = [ds.Isc; -8; 0.2; 300];
        lb = [ds.Isc; -14; 1e-4; 10];
        ub = [1.05 * ds.Isc; -4; 2; 1e4];
    otherwise
        error('extrair_parametros:modelo', 'Modelo deve ser 1d ou 2d');
end
[x, info] = levenberg_marquardt(@residuos, x0, lb, ub);
p = aplicar(x);

    function q = aplicar(x)
        q = p0;
        q.Ipv_n = x(1);
        q.I01_n = 10^x(2);
        if strcmp(modelo, '2d')
            q.I02_n = 10^x(3);  k = 4;
        else
            q.I02_n = 0;        k = 3;
        end
        q.Rs = x(k) / p0.Ns;
        q.Rp = x(k + 1) / p0.Ns;
    end

    function r = residuos(x)
        q = aplicar(x);
        Gn = q.Gn;  Tn = q.Tn;
        F1 = kcl_modulo(0, ds.Isc, Gn, Tn, q);
        F2 = kcl_modulo(ds.Voc, 0, Gn, Tn, q);
        [F3, ~, dIdV] = kcl_modulo(ds.Vmp, ds.Imp, Gn, Tn, q);
        F4 = ds.Imp + ds.Vmp * dIdV;
        r = [F1; F2; F3; F4] / ds.Isc;
        if strcmp(modelo, '2d')
            F5 = kcl_modulo(ds.Voc + ds.Kv * dT, 0, Gn, Tn + dT, q);
            r = [r; F5 / ds.Isc];
        end
    end
end

function p = parametros_base(ds)
p.nome = ds.nome;
p.q = 1.602176634e-19;  p.k = 1.380649e-23;  p.Eg = 1.12;
p.Gn = 1000;  p.Tn = 298.15;
p.Ns = ds.Ns;  p.Nsub = ds.Nsub;  p.Ncel = ds.Ns / ds.Nsub;
p.Ki = ds.Ki;
p.I0bp = 1.4e-6;  p.nbp = 1.0;
end
```

- [ ] **Passo 7: Rodar `test_extracao`**

Expected: 4 `Passed`. Se `test_parametros_fisicos` falhar por resíduo alto no `2d`, imprimir `info.r` para ver qual condição não fecha; a correção provável é ajustar `x0` de `log10 I02` (testar −7 e −5) — registrar no relatório.

- [ ] **Passo 8: Ligar `parametros_painel` aos painéis reais (sem cache)**

Para painéis reais, `p = extrair_parametros(datasheet_painel(nome), '2d');`. A extração leva menos de 0,5 s, então não há cache em disco: um cache esconderia mudanças no código (decisão da revisão da Tarefa 2).

- [ ] **Passo 9: Rodar todos os testes e commitar**

```bash
git add matlab && git commit -m "Extracao de parametros 1d/2d com Levenberg-Marquardt validada no KC200GT"
```

---

### Tarefa 3: Painel real (ZTP-160M) e validação sem curvas do fabricante

O datasheet do ZTP-160M não traz curvas I-V. A validação usa o que ele publica e que **não** entra no ajuste: o coeficiente térmico de Pmax. A comparação 1 diodo × 2 diodos em baixa irradiância é apresentada como diferença entre modelos (não há dado medido para decidir qual acerta) e discutida com a literatura (Ishaque 2011).

**Files:**
- Create: `matlab/painel/validar_painel.m`, `matlab/tests/test_ztp160m.m`, `matlab/experimentos/exp01_validacao_painel.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_ztp160m
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('ztp160m');
tc.TestData.v = validar_painel('ztp160m');
end

function test_pontos_de_stc(tc)
% O ajuste impoe estes pontos: o erro tem de ser pequeno nos dois modelos.
v = tc.TestData.v;
for m = 1:2
    verifyLessThan(tc, abs(v.erroPmax_STC(m)), 0.005);
    verifyLessThan(tc, abs(v.erroVoc_STC(m)), 0.005);
end
end

function test_coeficiente_de_Pmax_independente(tc)
% gamaP NAO entra no ajuste: e a validacao independente do modelo termico-eletrico.
% Tolerancia de 0,05 %/K (o datasheet arredonda para -0,4 %/K).
v = tc.TestData.v;
verifyEqual(tc, v.gamaP_modelo(2), tc.TestData.ds.gamaP, 'AbsTol', 0.0005);
end
```

- [ ] **Passo 2: Implementar `validar_painel.m`**

```matlab
function v = validar_painel(nome)
%VALIDAR_PAINEL Compara os modelos de 1 e 2 diodos com o que o datasheet publica.
%   v.erroPmax_STC, v.erroVoc_STC : erro relativo em STC   [1d 2d]
%   v.gamaP_modelo                : dPmax/dT / Pmax  [1/K]  [1d 2d]
%   v.Pmax_G                      : Pmax em G = [1000 800 600 400 200] [W] (linhas: 1d, 2d)
ds = datasheet_painel(nome);
modelos = {extrair_parametros(ds, '1d'), extrair_parametros(ds, '2d')};
Gs = [1000 800 600 400 200];
v.G = Gs;
for m = 1:2
    p = modelos{m};
    uniforme = ones(1, p.Nsub);

    % Pontos de STC (impostos no ajuste)
    c = curva_pv(1000 * uniforme, p.Tn, p, 2000);
    v.erroPmax_STC(m) = (c.Pmp - ds.Pmax) / ds.Pmax;
    v.erroVoc_STC(m) = (c.V(end) - ds.Voc) / ds.Voc;

    % Coeficiente termico de Pmax: derivada central entre 15 C e 35 C
    cq = curva_pv(1000 * uniforme, p.Tn + 10, p, 2000);
    cf = curva_pv(1000 * uniforme, p.Tn - 10, p, 2000);
    v.gamaP_modelo(m) = (cq.Pmp - cf.Pmp) / 20 / c.Pmp;

    % Potencia maxima em varias irradiancias (onde 1d e 2d diferem)
    for k = 1:numel(Gs)
        v.Pmax_G(m, k) = curva_pv(Gs(k) * uniforme, p.Tn, p, 1000).Pmp;
    end
end
end
```

- [ ] **Passo 3: Rodar `test_ztp160m`** — Expected: 2 `Passed`. Se `test_coeficiente_de_Pmax_independente` falhar, isso é um **resultado** (o modelo não reproduz a sensibilidade térmica do fabricante): imprimir `v.gamaP_modelo`, investigar `Eg` e os expoentes 3 e 1,5 de `celula_params` (o divisor de Eg é fixo pelo mecanismo: 1 para difusão, 2 para recombinação, independente de a₁/a₂ ajustados), e reportar no relatório em vez de afrouxar a tolerância.

- [ ] **Passo 3b: Análise de identificabilidade do 2º diodo (decisão D9)**

`extrair_parametros(ds, '2d', razao)` aceita um 3º argumento opcional `razao = I02_n/I01_n` (padrão 1, convenção de Ishaque). Criar `matlab/painel/identificabilidade_2d.m`:

```matlab
function tab = identificabilidade_2d(nome, razoes)
%IDENTIFICABILIDADE_2D Mostra que o datasheet nao determina o 2o diodo.
%   Para cada razao r = I02/I01, ajusta o modelo de 2 diodos com as mesmas
%   5 condicoes do datasheet. Se todas fecham (residuo ~0) mas as previsoes
%   fora do STC mudam, o parametro nao e identificavel so com o datasheet.
if nargin < 2, razoes = [0.01 0.1 1 10 100]; end
ds = datasheet_painel(nome);
n = numel(razoes);
residuo = zeros(n, 1);  Eg = zeros(n, 1);
eta200_rel = zeros(n, 1);  gamaP = zeros(n, 1);
for k = 1:n
    [p, info] = extrair_parametros(ds, '2d', razoes(k));
    residuo(k) = info.residuo;
    Eg(k) = p.Eg;
    uniforme = ones(1, p.Nsub);
    P1000 = curva_pv(1000 * uniforme, p.Tn, p, 1000).Pmp;
    P200  = curva_pv( 200 * uniforme, p.Tn, p, 1000).Pmp;
    eta200_rel(k) = (P200 / 200) / (P1000 / 1000);      % eficiencia relativa em baixa luz
    Pq = curva_pv(1000 * uniforme, p.Tn + 10, p, 1000).Pmp;
    Pf = curva_pv(1000 * uniforme, p.Tn - 10, p, 1000).Pmp;
    gamaP(k) = (Pq - Pf) / 20 / P1000;                  % coeficiente termico de Pmax
end
tab = table(razoes(:), residuo, Eg, eta200_rel, gamaP, ...
    'VariableNames', {'razao_I02_I01', 'residuo', 'Eg_ef_eV', 'eta200_rel', 'gamaP_1_K'});
end
```

Teste em `test_ztp160m.m`: todas as linhas com `residuo < 1e-6` (o datasheet é satisfeito por toda a família). No E1, gravar `resultados/e1_identificabilidade.csv` e plotar `eta200_rel` × razão (eixo log): a faixa de variação é a incerteza que o datasheet deixa na previsão em baixa irradiância, e entra na discussão do relatório.

- [ ] **Passo 4: Script E1** (tabela de validação + figura da eficiência relativa η(G)/η(STC) dos dois modelos)

```matlab
%EXP01 Validacao do ZTP-160M: pontos de STC, coeficiente de Pmax e baixa irradiancia.
setup_path();
ds = datasheet_painel('ztp160m');
v = validar_painel('ztp160m');

modelo = {'1 diodo'; '2 diodos'};
tab = table(modelo, 100 * v.erroPmax_STC(:), 100 * v.erroVoc_STC(:), ...
    100 * v.gamaP_modelo(:), 100 * ds.gamaP * [1; 1], ...
    'VariableNames', {'modelo', 'erroPmax_pct', 'erroVoc_pct', ...
                      'gamaP_modelo_pct_K', 'gamaP_datasheet_pct_K'});
disp(tab);
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e1_validacao_painel.csv'));

% Eficiencia relativa: eta(G)/eta(1000) = (Pmax(G)/G) / (Pmax(1000)/1000)
eta_rel = (v.Pmax_G ./ v.G) ./ (v.Pmax_G(:, 1) / 1000);
figure('Position', [100 100 600 400]);
plot(v.G, 100 * eta_rel(1, :), 'o--', v.G, 100 * eta_rel(2, :), 's-', 'LineWidth', 1.3);
grid on; xlabel('G [W/m^2]'); ylabel('\eta(G) / \eta(STC) [%]');
legend(modelo, 'Location', 'southeast');
title('ZTP-160M: eficiencia relativa em baixa irradiancia');
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e1_eficiencia_relativa.pdf'));
```

- [ ] **Passo 5: Rodar E1** e conferir: erros de STC < 0,5 %; γ_P do modelo perto de −0,4 %/K; a eficiência relativa em 200 W/m² deve ficar entre 90 % e 100 % (com R_p(G) de De Soto, decisão D10); a diferença entre 1d e 2d é pequena e a variação ao longo da família de razões I₀₂/I₀₁ quantifica a incerteza do datasheet.

- [ ] **Passo 6: Commit** `"Validacao do ZTP-160M (E1)"` (incluir `resultados/e1_*.csv` e a figura).

---

### Tarefa 4: Modelo térmico calibrado pelo NMOT

O datasheet informa o **NMOT** (IEC 61215): temperatura da célula com G = 800 W/m², T_amb = 20 °C, vento de 1 m/s e **módulo operando no MPP** (diferente do antigo NOCT, medido em circuito aberto). Por isso a calibração desconta a potência elétrica extraída, estimada pelo próprio datasheet: P_el = Pmax·(800/1000)·[1 + γ_P (T − 25 °C)].

**Files:**
- Create: `matlab/termico/parametros_termicos.m`, `matlab/termico/termico_dTdt.m`, `matlab/termico/calibrar_nmot.m`, `matlab/tests/test_termico.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_termico
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('ztp160m');
tc.TestData.pt = parametros_termicos(tc.TestData.ds);
end

function test_nmot_reproduzido(tc)
ds = tc.TestData.ds;  pt = tc.TestData.pt;
Pel = @(T) ds.Pmax * 0.8 * (1 + ds.gamaP * (T - 298.15));
Tss = fzero(@(T) termico_dTdt(T, 800, 293.15, 1, Pel(T), pt), [250 400]);
verifyEqual(tc, Tss - 273.15, ds.NMOT, 'AbsTol', 0.05);
end

function test_constante_de_tempo(tc)
pt = tc.TestData.pt;
h = 1e-3;  T0 = 320;
dfdT = (termico_dTdt(T0 + h, 800, 298.15, 1, 0, pt) - ...
        termico_dTdt(T0 - h, 800, 298.15, 1, 0, pt)) / (2 * h);
tau_min = -1 / dfdT / 60;          % tau = -1 / (d(dT/dt)/dT)
verifyGreaterThan(tc, tau_min, 3);
verifyLessThan(tc, tau_min, 10);
end

function test_vento_resfria(tc)
pt = tc.TestData.pt;
T1 = fzero(@(T) termico_dTdt(T, 1000, 298.15, 1, 0, pt), [250 400]);
T5 = fzero(@(T) termico_dTdt(T, 1000, 298.15, 5, 0, pt), [250 400]);
verifyLessThan(tc, T5, T1);
end

function test_extrair_eletricidade_resfria(tc)
pt = tc.TestData.pt;
T0 = fzero(@(T) termico_dTdt(T, 1000, 298.15, 1, 0, pt), [250 400]);
Tp = fzero(@(T) termico_dTdt(T, 1000, 298.15, 1, 150, pt), [250 400]);
verifyLessThan(tc, Tp, T0);
end
```

- [ ] **Passo 2: Implementar**

```matlab
function dTdt = termico_dTdt(T, G, Tamb, vw, Pel, pt)
%TERMICO_DTDT Balanco de energia do modulo como um unico corpo [K/s].
%   m*cp*dT/dt = sol absorvido - eletricidade - conveccao - radiacao
%   T, Tamb [K]; G [W/m^2] (media dos submodulos); vw = vento [m/s]; Pel [W].
sigma = 5.670374419e-8;               % constante de Stefan-Boltzmann [W/(m^2 K^4)]
At = 2 * pt.A;                        % troca calor pela frente e pelo verso
hc = pt.kh * (5.7 + 3.8 * vw);        % conveccao forcada (McAdams), fator calibrado
Tceu = 0.0552 * Tamb^1.5;             % temperatura efetiva do ceu (Swinbank)

Q_sol  = pt.alpha * pt.A * G;                      % radiacao solar absorvida
Q_conv = hc * At * (T - Tamb);                     % calor levado pelo ar
Q_rad  = pt.eps * sigma * At * (T^4 - Tceu^4);     % radiacao de onda longa

dTdt = (Q_sol - Pel - Q_conv - Q_rad) / (pt.mcp_area * pt.A);
end
```

```matlab
function pt = calibrar_nmot(pt, ds)
%CALIBRAR_NMOT Ajusta pt.kh para que o regime permanente reproduza o NMOT.
%   Condicao NMOT: G = 800 W/m^2, Tamb = 20 C, vento 1 m/s, modulo no MPP.
%   A potencia eletrica no MPP e estimada pelo datasheet (Pmax e gamaP).
T_alvo = ds.NMOT + 273.15;
Pel = ds.Pmax * 0.8 * (1 + ds.gamaP * (T_alvo - 298.15));

% No regime permanente dT/dt = 0. Procuramos o kh que zera dT/dt em T_alvo.
balanco = @(kh) termico_dTdt(T_alvo, 800, 293.15, 1, Pel, setfield(pt, 'kh', kh));
pt.kh = fzero(balanco, [0.1 10]);
end
```

```matlab
function pt = parametros_termicos(ds)
%PARAMETROS_TERMICOS Parametros do modelo termico do modulo, calibrado pelo NMOT.
pt.A = ds.A;             % area do modulo [m^2]
pt.mcp_area = 11e3;      % capacidade termica por area: vidro+EVA+celula [J/(m^2 K)]
pt.alpha = 0.9;          % fracao da radiacao solar absorvida
pt.eps = 0.85;           % emissividade do vidro
pt.kh = 1;               % fator de correcao da conveccao (calibrado abaixo)
pt = calibrar_nmot(pt, ds);
end
```

- [ ] **Passo 3: Rodar `test_termico`** — Expected: 4 `Passed`.
- [ ] **Passo 4: Commit** `"Modelo termico concentrado calibrado pelo NMOT"`.

---

### Tarefa 5: Conversor — modelo médio com perdas, equilíbrio e CCM/DCM

**Files:**
- Create: `matlab/conversor/parametros_conversor.m`, `conversor_ideal.m`, `conversor_medio_rhs.m`, `equilibrio_conversor.m`, `verifica_ccm.m`, `matlab/tests/test_conversor.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_conversor
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.p = parametros_painel('generico');
tc.TestData.pc = parametros_conversor(tc.TestData.p, 12);
end

function test_ganho_ideal(tc)
pc = conversor_ideal(tc.TestData.pc);
eq = equilibrio_conversor(18, 7.7, pc);
verifyEqual(tc, eq.d / (1 - eq.d), 12 / 18, 'RelTol', 1e-9);
verifyEqual(tc, eq.eta, 1, 'AbsTol', 1e-9);
end

function test_balanco_de_energia(tc)
pc = tc.TestData.pc;
v = 18;  i = 7.7;
eq = equilibrio_conversor(v, i, pc);
verifyEqual(tc, v * i, (1 - eq.d) * eq.iL * pc.Vbat + eq.Pcond, 'RelTol', 1e-9);
verifyLessThan(tc, eq.eta, 1);
verifyGreaterThan(tc, eq.eta, 0.85);
end

function test_rhs_nulo_no_equilibrio(tc)
pc = tc.TestData.pc;
eq = equilibrio_conversor(18, 7.7, pc);
dx = conversor_medio_rhs(18, eq.iL, 7.7, eq.d, pc);
verifyEqual(tc, dx, [0; 0], 'AbsTol', 1e-6);
end

function test_ccm_e_dcm(tc)
pc = tc.TestData.pc;
eqA = equilibrio_conversor(18, 7.7, pc);
verifyTrue(tc, verifica_ccm(18, eqA.d, eqA.iL, pc));
eqB = equilibrio_conversor(17, 0.25, pc);          % G ~ 30 W/m^2
verifyFalse(tc, verifica_ccm(17, eqB.d, eqB.iL, pc));
end
```

- [ ] **Passo 2: Implementar**

```matlab
function pc = parametros_conversor(p, Vbat)
%PARAMETROS_CONVERSOR Buck-boost dimensionado pelo ripple no MPP em STC.
if nargin < 2, Vbat = 12; end
pc.Vbat = Vbat;
pc.fs = 20e3;  pc.Ts = 1 / pc.fs;
c = curva_pv(1000 * ones(1, p.Nsub), p.Tn, p, 1000);
D = Vbat / (Vbat + c.Vmp);
IL = c.Imp / D;
pc.L = c.Vmp * D / (0.30 * IL * pc.fs);              % ripple de corrente 30 %
pc.C = IL * D * (1 - D) / (0.01 * c.Vmp * pc.fs);    % ripple de tensao 1 %
pc.rL = 0.020;  pc.Ron = 0.018;  pc.VF = 0.45;  pc.RD = 0.010;
pc.ttr = 100e-9;                                     % t_r + t_f
pc.Dmin = 0.02;  pc.Dmax = 0.95;
pc.atraso = 1.5 * pc.Ts;                             % PWM digital
end
```

```matlab
function pc = conversor_ideal(pc)
%CONVERSOR_IDEAL Mesmo conversor sem perdas.
pc.rL = 0;  pc.Ron = 0;  pc.VF = 0;  pc.RD = 0;  pc.ttr = 0;
end
```

```matlab
function dx = conversor_medio_rhs(vpv, iL, ipv, d, pc)
%CONVERSOR_MEDIO_RHS Derivadas do modelo medio com perdas: [dv_pv/dt; di_L/dt].
dv = (ipv - d * iL) / pc.C;
di = (d * vpv - (1 - d) * (pc.Vbat + pc.VF) ...
      - iL * (pc.rL + d * pc.Ron + (1 - d) * pc.RD)) / pc.L;
dx = [dv; di];
end
```

```matlab
function eq = equilibrio_conversor(vpv, ipv, pc)
%EQUILIBRIO_CONVERSOR Regime permanente do modelo medio para (vpv, ipv) impostos.
if ipv <= 0
    eq = struct('d', NaN, 'iL', 0, 'Pcond', 0, 'Psw', 0, 'Pout', 0, 'eta', 0);
    return
end
f = @(d) d * vpv - (1 - d) * (pc.Vbat + pc.VF) ...
         - (ipv / d) * (pc.rL + d * pc.Ron + (1 - d) * pc.RD);
eq.d = fzero(f, [1e-3, 0.999]);
eq.iL = ipv / eq.d;
eq.Pcond = eq.iL^2 * (pc.rL + eq.d * pc.Ron + (1 - eq.d) * pc.RD) ...
           + (1 - eq.d) * eq.iL * pc.VF;
eq.Psw = 0.5 * (vpv + pc.Vbat) * eq.iL * pc.ttr * pc.fs;
eq.Pout = (1 - eq.d) * eq.iL * pc.Vbat - eq.Psw;
eq.eta = eq.Pout / (vpv * ipv);
end
```

```matlab
function ccm = verifica_ccm(vpv, d, iL, pc)
%VERIFICA_CCM true se a corrente no indutor nao zera (conducao continua).
ccm = iL > vpv * d / (pc.L * pc.fs) / 2;
end
```

- [ ] **Passo 3: Rodar `test_conversor`** — Expected: 4 `Passed`.
- [ ] **Passo 4: Commit** `"Conversor buck-boost: modelo medio com perdas, equilibrio e CCM"`.

---

### Tarefa 6: Modelo chaveado e validação chaveado × médio (E3)

**Files:**
- Create: `matlab/conversor/sim_chaveado.m`, `matlab/conversor/sim_medio_aberta.m`, `matlab/tests/test_chaveado_medio.m`, `matlab/experimentos/exp03_chaveado_medio.m`
- Delete: `matlab/experimentos/exemplo_dae_conversor.m` (substituído por `sim_medio_aberta`)

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_chaveado_medio
tests = functiontests(localfunctions);
end

function test_media_do_chaveado_igual_ao_medio(tc)
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
G = [1000 1000 1000];  T = p.Tn;
v0 = 18;  I0 = painel_sombreado(v0, G, T, p);
eq = equilibrio_conversor(v0, I0, pc);
dfun = @(t) eq.d + 0.02 * (t >= 2e-3);
x0 = [v0; eq.iL];
rs = sim_chaveado(6e-3, dfun, G, T, p, pc, x0);
rm = sim_medio_aberta(6e-3, dfun, G, T, p, pc, x0);
nper = round(pc.Ts / (rs.t(2) - rs.t(1)));
vbar = movmean(rs.v, nper);  ibar = movmean(rs.iL, nper);
vm = interp1(rm.t, rm.v, rs.t);  im = interp1(rm.t, rm.iL, rs.t);
k = rs.t > pc.Ts;                                  % ignora o primeiro periodo
verifyLessThan(tc, max(abs(vbar(k) - vm(k))) / v0, 0.01);
verifyLessThan(tc, max(abs(ibar(k) - im(k))) / eq.iL, 0.03);
end

function test_ripple_analitico(tc)
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
G = [1000 1000 1000];  T = p.Tn;
v0 = 18;  I0 = painel_sombreado(v0, G, T, p);
eq = equilibrio_conversor(v0, I0, pc);
rs = sim_chaveado(2e-3, @(t) eq.d, G, T, p, pc, [v0; eq.iL]);
k = rs.t > rs.t(end) - pc.Ts;
verifyEqual(tc, max(rs.iL(k)) - min(rs.iL(k)), v0 * eq.d / (pc.L * pc.fs), 'RelTol', 0.15);
end
```

- [ ] **Passo 2: Implementar**

```matlab
function r = sim_chaveado(t_fim, dfun, G, T, p, pc, x0)
%SIM_CHAVEADO Buck-boost chaveado alimentado pelo painel (Euler, 200 passos/periodo).
%   Diodo bloqueia corrente reversa: i_L >= 0 (captura DCM).
dt = pc.Ts / 200;
n = round(t_fim / dt);
r.t = (0:n - 1).' * dt;  r.v = zeros(n, 1);  r.iL = zeros(n, 1);  r.q = false(n, 1);
v = x0(1);  iL = x0(2);  z = [];
for k = 1:n
    t = r.t(k);
    q = mod(t, pc.Ts) < dfun(t) * pc.Ts;
    [ipv, s] = painel_sombreado(v, G, T, p, z);  z = s.z;
    if q
        di = (v - iL * (pc.rL + pc.Ron)) / pc.L;
        dv = (ipv - iL) / pc.C;
    else
        di = (-(pc.Vbat + pc.VF) - iL * (pc.rL + pc.RD)) / pc.L;
        dv = ipv / pc.C;
    end
    v = v + dv * dt;
    iL = max(iL + di * dt, 0);
    r.v(k) = v;  r.iL(k) = iL;  r.q(k) = q;
end
end
```

```matlab
function r = sim_medio_aberta(t_fim, dfun, G, T, p, pc, x0)
%SIM_MEDIO_ABERTA Modelo medio + painel como DAE (ode15s, matriz de massa).
%   x = [v_pv; i_L; I; Vd_1..Vd_N]; G pode ser vetor fixo ou funcao de t.
N = p.Nsub;
if ~isa(G, 'function_handle'), G = @(t) G; end
[~, s0] = painel_sombreado(x0(1), G(0), T, p);
x0 = [x0(:); s0.z];
M = blkdiag(eye(2), zeros(N + 1));
opts = odeset('Mass', M, 'MassSingular', 'yes', 'RelTol', 1e-6, 'AbsTol', 1e-8, ...
    'MaxStep', pc.Ts, 'Jacobian', @jac);
[r.t, x] = ode15s(@rhs, [0 t_fim], x0, opts);
r.v = x(:, 1);  r.iL = x(:, 2);  r.I = x(:, 3);

    function dx = rhs(t, x)
        dx = [conversor_medio_rhs(x(1), x(2), x(3), dfun(t), pc)
              residuo_painel(x(3:end), x(1), G(t), T, p)];
    end

    function Jf = jac(t, x)
        d = dfun(t);
        [~, Jz] = residuo_painel(x(3:end), x(1), G(t), T, p);
        Jf = zeros(N + 3);
        Jf(1, 2:3) = [-d, 1] / pc.C;
        Jf(2, 1:2) = [d, -(pc.rL + d * pc.Ron + (1 - d) * pc.RD)] / pc.L;
        Jf(3:end, 1) = [zeros(N, 1); -1];
        Jf(3:end, 3:end) = Jz;
    end
end
```

- [ ] **Passo 3: Rodar `test_chaveado_medio`** — Expected: 2 `Passed`.

- [ ] **Passo 4: Script E3** (figura do relatório: degrau de d, chaveado × médio; e uma segunda simulação em G = 50 W/m² mostrando DCM e o erro do modelo médio)

```matlab
%EXP03 Modelo chaveado x medio em CCM (STC) e em DCM (baixa irradiancia).
setup_path();
p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
casos = {1000, 'STC (CCM)'; 50, '50 W/m^2 (DCM)'};
figure('Position', [100 100 900 650]);
for c = 1:2
    G = casos{c, 1} * ones(1, p.Nsub);
    cv = curva_pv(G, p.Tn, p);
    v0 = cv.Vmp;  I0 = painel_sombreado(v0, G, p.Tn, p);
    eq = equilibrio_conversor(v0, I0, pc);
    dfun = @(t) eq.d + 0.02 * (t >= 2e-3);
    rs = sim_chaveado(6e-3, dfun, G, p.Tn, p, pc, [v0; eq.iL]);
    rm = sim_medio_aberta(6e-3, dfun, G, p.Tn, p, pc, [v0; eq.iL]);
    subplot(2, 2, 2 * c - 1);
    plot(rs.t * 1e3, rs.v, rm.t * 1e3, rm.v, '--', 'LineWidth', 1.2); grid on;
    ylabel('v_{pv} [V]'); title(casos{c, 2}); legend('chaveado', 'medio');
    subplot(2, 2, 2 * c);
    plot(rs.t * 1e3, rs.iL, rm.t * 1e3, rm.iL, '--', 'LineWidth', 1.2); grid on;
    ylabel('i_L [A]'); xlabel('t [ms]');
end
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e3_chaveado_medio.pdf'));
```

- [ ] **Passo 5: Rodar E3, remover `exemplo_dae_conversor.m`, commit** `"Modelo chaveado e validacao do modelo medio (E3)"`.

---

### Tarefa 7: Linearização e resposta em frequência

**Files:**
- Create: `matlab/controle/linearizar_planta.m`, `resposta_freq.m`, `gvd_analitico.m`, `matlab/tests/test_linearizacao.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_linearizacao
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
tc.TestData.p = p;
tc.TestData.pc = parametros_conversor(p, 12);
tc.TestData.op = struct('vpv', 17, 'G', [1000 1000 1000], 'T', p.Tn);
end

function test_numerico_igual_analitico_sem_perdas(tc)
pc = conversor_ideal(tc.TestData.pc);
sys = linearizar_planta(tc.TestData.op, tc.TestData.p, pc);
w = logspace(1, 5, 200);
verifyEqual(tc, resposta_freq(sys, w), gvd_analitico(sys, pc, w), 'RelTol', 1e-3);
end

function test_rpv_no_mpp(tc)
p = tc.TestData.p;
c = curva_pv([1000 1000 1000], p.Tn, p, 3000);
op = struct('vpv', c.Vmp, 'G', [1000 1000 1000], 'T', p.Tn);
sys = linearizar_planta(op, p, tc.TestData.pc);
verifyEqual(tc, sys.rpv, c.Vmp / c.Imp, 'RelTol', 0.02);
end

function test_degrau_pequeno_nao_linear_igual_linear(tc)
p = tc.TestData.p;  pc = tc.TestData.pc;  op = tc.TestData.op;
sys = linearizar_planta(op, p, pc);
dd = 0.005;  t_fim = 10e-3;
rm = sim_medio_aberta(t_fim, @(t) sys.d0 + dd * (t > 0), op.G, op.T, p, pc, sys.x0);
dv_nl = rm.v - sys.x0(1);
dv_l = zeros(size(rm.t));
for k = 1:numel(rm.t)
    xk = sys.A \ ((expm(sys.A * rm.t(k)) - eye(2)) * sys.B * dd);
    dv_l(k) = sys.C * xk;
end
verifyLessThan(tc, sqrt(mean((dv_nl - dv_l).^2)) / max(abs(dv_l)), 0.05);
end
```

- [ ] **Passo 2: Implementar**

```matlab
function sys = linearizar_planta(op, p, pc)
%LINEARIZAR_PLANTA Modelo de pequenos sinais (A, B, C) do conversor + painel.
%   op: .vpv [V], .G (1 x Nsub), .T [K]. Equilibrio com d tal que v_pv = op.vpv.
%   Estados [v_pv; i_L], entrada d, saida v_pv. Derivadas por diferencas centrais.
[ipv0, s] = painel_sombreado(op.vpv, op.G, op.T, p);
eq = equilibrio_conversor(op.vpv, ipv0, pc);
x0 = [op.vpv; eq.iL];  d0 = eq.d;
ipv = @(v) painel_sombreado(v, op.G, op.T, p, s.z);
f = @(x, d) conversor_medio_rhs(x(1), x(2), ipv(x(1)), d, pc);
A = zeros(2);
for j = 1:2
    h = zeros(2, 1);  h(j) = 1e-5 * max(1, abs(x0(j)));
    A(:, j) = (f(x0 + h, d0) - f(x0 - h, d0)) / (2 * h(j));
end
hd = 1e-6;
B = (f(x0, d0 + hd) - f(x0, d0 - hd)) / (2 * hd);
hv = 1e-4;
sys = struct('A', A, 'B', B, 'C', [1 0], 'D', 0, 'x0', x0, 'd0', d0, ...
    'ipv0', ipv0, 'rpv', -2 * hv / (ipv(op.vpv + hv) - ipv(op.vpv - hv)));
end
```

```matlab
function H = resposta_freq(sys, w)
%RESPOSTA_FREQ H(jw) = C (jwI - A)^-1 B + D, para cada w (substitui bode/freqresp).
H = zeros(size(w));
n = size(sys.A, 1);
for k = 1:numel(w)
    H(k) = sys.C * ((1j * w(k) * eye(n) - sys.A) \ sys.B) + sys.D;
end
end
```

```matlab
function H = gvd_analitico(sys, pc, w)
%GVD_ANALITICO G_vd(jw) do conversor sem perdas (expressao da proposta).
s = 1j * w;
D = sys.d0;  IL = sys.x0(2);  Vsum = sys.x0(1) + pc.Vbat;
H = -(pc.L * IL * s + D * Vsum) ./ (pc.L * pc.C * s.^2 + (pc.L / sys.rpv) * s + D^2);
end
```

- [ ] **Passo 3: Rodar `test_linearizacao`** — Expected: 3 `Passed`.
- [ ] **Passo 4: Commit** `"Linearizacao da planta e resposta em frequencia"`.

---

### Tarefa 8: Projeto do PI por margens e período do MPPT (Femia)

**Files:**
- Create: `matlab/controle/margens.m`, `projeto_pi.m`, `resposta_degrau_mf.m`, `matlab/tests/test_controle.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_controle
tests = functiontests(localfunctions);
end

function test_margens_sistema_conhecido(tc)
% L(s) = 10/(s(s+1)(s+10)): wc e MF conferidos pela definicao; MG = 11 (w180 = sqrt(10))
L = @(w) 10 ./ ((1j * w) .* (1j * w + 1) .* (1j * w + 10));
wg = logspace(-2, 3, 20000);
m = margens(wg, L(wg));
wc = fzero(@(w) abs(L(w)) - 1, [0.1 10]);
verifyEqual(tc, m.wc, wc, 'RelTol', 1e-3);
verifyEqual(tc, m.PM, 180 + rad2deg(angle(L(wc))), 'AbsTol', 0.1);
verifyEqual(tc, m.GM, 20 * log10(11), 'AbsTol', 0.05);   % w180 = sqrt(10), |L| = 1/11
end

function test_pi_robusto(tc)
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
[ctl, rel] = projeto_pi(p, pc);
verifyGreaterThanOrEqual(tc, rel.PMmin, 45);
verifyGreaterThanOrEqual(tc, rel.GMmin, 6);
verifyGreaterThan(tc, ctl.Kp, 0);
verifyLessThan(tc, ctl.ts, 0.02);
verifyGreaterThanOrEqual(tc, numel(rel.ops), 8);    % quase todos os pontos em CCM
end
```

- [ ] **Passo 2: Implementar**

```matlab
function m = margens(w, L)
%MARGENS Margens de fase e de ganho a partir de L(jw) amostrado em w
%   (substitui margin, que e da Control System Toolbox).
%   m.wc, m.PM: cruzamento de ganho (|L| = 1) e margem de fase [graus]
%   m.w180, m.GM: cruzamento de fase (-180 graus) e margem de ganho [dB]
%   Inf quando o cruzamento nao existe na faixa de w.
magn = abs(L);
fase = unwrap(angle(L)) * 180 / pi;

% Cruzamento de ganho: primeiro ponto em que |L| passa de >= 1 para < 1
k = find(magn(1:end - 1) >= 1 & magn(2:end) < 1, 1);
if isempty(k)
    m.wc = NaN;  m.PM = Inf;
else
    % interpola em log|L| (|L| varia exponencialmente com w no Bode)
    m.wc = interp1(log(magn(k:k + 1)), w(k:k + 1), 0);
    fase_wc = interp1(w(k:k + 1), fase(k:k + 1), m.wc);
    m.PM = mod(180 + fase_wc + 180, 360) - 180;       % leva para (-180, 180]
end

% Cruzamento de fase: fase + 180 muda de sinal (modulo 360)
fr = mod(fase + 180 + 180, 360) - 180;
j = find(fr(1:end - 1) .* fr(2:end) < 0 & abs(diff(fr)) < 180, 1);
if isempty(j)
    m.w180 = NaN;  m.GM = Inf;
else
    m.w180 = interp1(fr(j:j + 1), w(j:j + 1), 0);
    magn180 = exp(interp1(w(j:j + 1), log(magn(j:j + 1)), m.w180));
    m.GM = -20 * log10(magn180);
end
end
```

```matlab
function [t, v, ts] = resposta_degrau_mf(sys, ctl, t_fim)
%RESPOSTA_DEGRAU_MF Degrau unitario em V_ref na malha fechada linear.
%   d~ = Kp*(e + xi/Ti), e = v~ - r (sinal invertido: planta tem ganho negativo).
A = sys.A;  B = sys.B;  C = sys.C;  Kp = ctl.Kp;  Ti = ctl.Ti;
Acl = [A + B * Kp * C, B * Kp / Ti; C, 0];
Bcl = [-B * Kp; -1];
dt = t_fim / 4000;
Ad = expm(Acl * dt);
Bd = Acl \ ((Ad - eye(3)) * Bcl);
x = zeros(3, 1);  t = (0:4000).' * dt;  v = zeros(size(t));
for k = 2:numel(t)
    x = Ad * x + Bd;
    v(k) = C * x(1:2);
end
fora = abs(v - 1) > 0.02;
ts = t(find(fora, 1, 'last') + 1);
if isempty(ts), ts = 0; end
end
```

```matlab
function [ctl, rel] = projeto_pi(p, pc)
%PROJETO_PI PI de tensao do painel com a maior banda que mantem MF >= 45 graus
%   e MG >= 6 dB em todos os pontos de operacao de robustez em CCM.
%   Zero do PI em wc/5 (Ti = 5/wc), abaixo do cruzamento.
%   Pontos em DCM ficam fora da verificacao (o modelo linear so vale em CCM)
%   e sao listados em rel.ops_dcm.
ops = pontos_robustez(p);
w = logspace(0, log10(pi * pc.fs), 3000);
atraso = exp(-1j * w * pc.atraso);                    % atraso do PWM digital

% A resposta da planta nao depende do PI: calcula uma vez por ponto.
sysn = linearizar_planta(ops(1), p, pc);              % ponto nominal (MPP em STC)
Gplanta = {};  ops_ccm = ops([]);  ops_dcm = ops([]);
for k = 1:numel(ops)
    sys = linearizar_planta(ops(k), p, pc);
    if sys.ccm
        Gplanta{end + 1} = -resposta_freq(sys, w) .* atraso; %#ok<AGROW> sinal invertido
        ops_ccm(end + 1) = ops(k); %#ok<AGROW>
    else
        ops_dcm(end + 1) = ops(k); %#ok<AGROW>
    end
end

ctl = [];
for fc = logspace(log10(20), log10(pc.fs / 10), 60)
    wc = 2 * pi * fc;  Ti = 5 / wc;
    % Kp: ganho de malha unitario em wc no ponto nominal
    Gwc = -resposta_freq(sysn, wc) * exp(-1j * wc * pc.atraso);
    Kp = 1 / abs(Gwc * (1 + 1 / (1j * wc * Ti)));
    Cw = Kp * (1 + 1 ./ (1j * w * Ti));               % PI na grade de frequencias
    PM = zeros(numel(Gplanta), 1);  GM = PM;
    for k = 1:numel(Gplanta)
        m = margens(w, Cw .* Gplanta{k});
        PM(k) = m.PM;  GM(k) = m.GM;
    end
    if all(PM >= 45) && all(GM >= 6)                  % guarda a maior banda que passa
        ctl = struct('Kp', Kp, 'Ti', Ti, 'fc', fc);
        rel = struct('PMmin', min(PM), 'GMmin', min(GM), 'PM', PM, 'GM', GM);
    end
end
assert(~isempty(ctl), 'projeto_pi:inviavel', 'Nenhuma banda atende as margens');
[~, ~, ctl.ts] = resposta_degrau_mf(sysn, ctl, 0.05);
ctl.Ta = 1e-3 * ceil(1.5 * ctl.ts / 1e-3);           % Femia: Ta > tempo de acomodacao
rel.ops = ops_ccm;  rel.ops_dcm = ops_dcm;
end

function ops = pontos_robustez(p)
%Primeiro ponto = nominal (MPP em STC).
ops = struct('vpv', {}, 'G', {}, 'T', {});
for G = [1000 600 200]
    Gv = G * ones(1, p.Nsub);
    c = curva_pv(Gv, p.Tn, p);
    for f = [1.0 0.8 1.1]
        ops(end + 1) = struct('vpv', f * c.Vmp, 'G', Gv, 'T', p.Tn); %#ok<AGROW>
    end
end
Gs = [1000 * ones(1, p.Nsub - 1), 400];             % sombra: os dois picos
c = curva_pv(Gs, p.Tn, p);
for k = 1:height(c.picos)
    ops(end + 1) = struct('vpv', c.picos.V(k), 'G', Gs, 'T', p.Tn); %#ok<AGROW>
end
end
```

- [ ] **Passo 3: Rodar `test_controle`** — Expected: 2 `Passed`. Se `test_margens_sistema_conhecido` falhar só no `GM`, conferir o tratamento de `mod` da fase (o caso de teste cruza −180° uma única vez).
- [ ] **Passo 4: Commit** `"Projeto do PI por margens com robustez e periodo do MPPT"`.

---

### Tarefa 9: Algoritmos de MPPT e rastreamento estático (E5)

**Files:**
- Create: `matlab/mppt/config_mppt.m`, `mppt_po.m`, `mppt_inc.m`, `mppt_pso.m`, `mppt_fixo.m`, `rastrear_estatico.m`, `matlab/tests/test_mppt.m`, `matlab/experimentos/exp05_mppt_estatico.m`

Interface comum: `[Vref, e] = mppt_X(V, I, e, cfg)` — chamado a cada `Ta` com a média medida de V e I; `e = []` na primeira chamada.

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_mppt
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
tc.TestData.p = p;
tc.TestData.cfg = config_mppt(p);
end

function test_po_uniforme_converge(tc)
p = tc.TestData.p;  G = [1000 1000 1000];
r = rastrear_estatico(@mppt_po, tc.TestData.cfg, @(k) G, p.Tn, p, 150);
Pmp = curva_pv(G, p.Tn, p).Pmp;
verifyGreaterThan(tc, mean(r.P(end - 20:end)), 0.98 * Pmp);
end

function test_po_preso_no_maximo_local(tc)
% Caracteriza a falha que o trabalho investiga.
p = tc.TestData.p;  G = [1000 1000 400];
r = rastrear_estatico(@mppt_po, tc.TestData.cfg, @(k) G, p.Tn, p, 150);
Pg = curva_pv(G, p.Tn, p).Pmp;
verifyLessThan(tc, mean(r.P(end - 20:end)), 0.75 * Pg);
end

function test_inc_para_no_mpp(tc)
p = tc.TestData.p;  G = [1000 1000 1000];
r = rastrear_estatico(@mppt_inc, tc.TestData.cfg, @(k) G, p.Tn, p, 150);
verifyLessThan(tc, std(r.V(end - 10:end)), 1e-9);
verifyGreaterThan(tc, r.P(end), 0.98 * curva_pv(G, p.Tn, p).Pmp);
end

function test_pso_acha_global(tc)
p = tc.TestData.p;
for G = {[1000 1000 400], [1000 600 300], [1000 1000 1000]}
    for seed = 1:5
        cfg = tc.TestData.cfg;  cfg.seed = seed;
        r = rastrear_estatico(@mppt_pso, cfg, @(k) G{1}, p.Tn, p, 120);
        verifyGreaterThan(tc, r.P(end), 0.98 * curva_pv(G{1}, p.Tn, p).Pmp);
    end
end
end

function test_pso_reinicia_quando_sombra_muda(tc)
p = tc.TestData.p;
Gf = @(k) [1000 1000 1000] .* (k <= 80) + [1000 600 300] .* (k > 80);
r = rastrear_estatico(@mppt_pso, tc.TestData.cfg, Gf, p.Tn, p, 200);
verifyGreaterThan(tc, r.P(end), 0.98 * curva_pv([1000 600 300], p.Tn, p).Pmp);
end
```

- [ ] **Passo 2: Implementar**

```matlab
function cfg = config_mppt(p)
%CONFIG_MPPT Configuracao padrao comum aos algoritmos.
c = curva_pv(1000 * ones(1, p.Nsub), p.Tn, p);
Voc = c.V(end);
cfg.Voc = Voc;
cfg.Vref0 = 0.85 * Voc;          % partida tipica (perto de Voc)
cfg.Vmin = 0.10 * Voc;  cfg.Vmax = 0.95 * Voc;
cfg.delta = 0.01 * Voc;          % passo P&O/InC (ajustado no E6)
cfg.eps = 0.002;                 % tolerancia InC em |dI/dV + I/V| [S]
cfg.epsI = 0.01;                 % [A]
cfg.N = 4;  cfg.w = 0.4;  cfg.c1 = 1.2;  cfg.c2 = 2.0;
cfg.x0 = linspace(0.15, 0.90, cfg.N).' * Voc;
cfg.tolV = 0.01 * Voc;  cfg.maxIter = 15;
cfg.limiarReinicio = 0.10;  cfg.seed = 1;
end
```

```matlab
function [Vref, e] = mppt_po(V, I, e, cfg)
%MPPT_PO Perturba e Observa: se a potencia caiu, inverte a direcao.
P = V * I;
if isempty(e)
    e = struct('Vref', cfg.Vref0, 'Pant', P, 'dir', -1);
else
    if P < e.Pant, e.dir = -e.dir; end
    e.Pant = P;
end
e.Vref = min(max(e.Vref + e.dir * cfg.delta, cfg.Vmin), cfg.Vmax);
Vref = e.Vref;
end
```

```matlab
function [Vref, e] = mppt_inc(V, I, e, cfg)
%MPPT_INC Condutancia incremental: dI/dV = -I/V no MPP.
if isempty(e)
    e = struct('Vref', cfg.Vref0, 'Vant', V, 'Iant', I);
    Vref = e.Vref - cfg.delta;  e.Vref = Vref;
    return
end
dV = V - e.Vant;  dI = I - e.Iant;
if abs(dV) < 1e-6
    if abs(dI) > cfg.epsI
        e.Vref = e.Vref + sign(dI) * cfg.delta;
    end
else
    s = dI / dV + I / V;                 % = dP/dV / V
    if abs(s) > cfg.eps
        e.Vref = e.Vref + sign(s) * cfg.delta;
    end
end
e.Vref = min(max(e.Vref, cfg.Vmin), cfg.Vmax);
e.Vant = V;  e.Iant = I;
Vref = e.Vref;
end
```

```matlab
function [Vref, e] = mppt_pso(V, I, e, cfg)
%MPPT_PSO Enxame de particulas com avaliacao sequencial (uma particula por Ta).
%   Cada chamada recebe a medicao da particula aplicada na chamada anterior.
P = V * I;
if isempty(e)
    e = iniciar(cfg);  Vref = e.x(1);
    return
end
if e.convergido
    if abs(P - e.Pconv) > cfg.limiarReinicio * max(e.Pconv, 1)
        e = iniciar(cfg);  Vref = e.x(1);
        return
    end
    Vref = e.gbest;
    return
end
k = e.k;
if P > e.pbestP(k), e.pbestP(k) = P;  e.pbest(k) = e.x(k); end
if P > e.gbestP,    e.gbestP = P;     e.gbest = e.x(k);    end
e.k = k + 1;
if e.k > cfg.N
    e.k = 1;  e.iter = e.iter + 1;
    r1 = rand(e.rs, cfg.N, 1);  r2 = rand(e.rs, cfg.N, 1);
    e.v = cfg.w * e.v + cfg.c1 * r1 .* (e.pbest - e.x) + cfg.c2 * r2 .* (e.gbest - e.x);
    e.x = min(max(e.x + e.v, cfg.Vmin), cfg.Vmax);
    if max(abs(e.x - e.gbest)) < cfg.tolV || e.iter >= cfg.maxIter
        e.convergido = true;  e.Pconv = e.gbestP;
        Vref = e.gbest;
        return
    end
end
Vref = e.x(e.k);
end

function e = iniciar(cfg)
e.rs = RandStream('mt19937ar', 'Seed', cfg.seed);
e.x = cfg.x0(:);  e.v = zeros(cfg.N, 1);
e.pbest = e.x;  e.pbestP = -inf(cfg.N, 1);
e.gbest = e.x(1);  e.gbestP = -inf;
e.k = 1;  e.iter = 0;  e.convergido = false;  e.Pconv = 0;
end
```

```matlab
function [Vref, e] = mppt_fixo(~, ~, e, cfg)
%MPPT_FIXO Referencia constante (testes da malha de tensao e oraculo).
Vref = cfg.Vref0;
end
```

```matlab
function r = rastrear_estatico(alg, cfg, Gfun, T, p, nPassos)
%RASTREAR_ESTATICO MPPT sobre o mapa estatico (tensao assentada a cada passo).
e = [];  V = cfg.Vref0;  z = [];
r.V = zeros(nPassos, 1);  r.P = zeros(nPassos, 1);
for k = 1:nPassos
    [I, s] = painel_sombreado(V, Gfun(k), T, p, z);  z = s.z;
    r.V(k) = V;  r.P(k) = V * I;
    [V, e] = alg(V, I, e, cfg);
end
end
```

- [ ] **Passo 3: Rodar `test_mppt`** — Expected: 5 `Passed`. Se `test_pso_reinicia...` falhar, verificar se a variação de potência ao mudar a sombra (138 → 58 W) dispara `limiarReinicio`.

- [ ] **Passo 4: Script E5** (tabela: 3 algoritmos × 6 padrões de sombra × 10 sementes do PSO → eficiência final e passos até convergir)

```matlab
%EXP05 Eficiencia de P&O, InC e PSO em padroes de sombra estaticos.
setup_path();
p = parametros_painel('ztp160m');  cfg = config_mppt(p);
padroes = {[1 1 1], [1 1 0.4], [1 0.6 0.3], [1 0.3 0.3], [0.8 0.8 0.2], [1 0.5 0.5]};
algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
linhas = {};
for g = 1:numel(padroes)
    G = 1000 * padroes{g}(1:p.Nsub);
    Pg = curva_pv(G, p.Tn, p).Pmp;
    for a = 1:size(algs, 1)
        nSeeds = 1 + 9 * strcmp(algs{a, 2}, 'PSO');
        for seed = 1:nSeeds
            c = cfg;  c.seed = seed;
            r = rastrear_estatico(algs{a, 1}, c, @(k) G, p.Tn, p, 200);
            eta = mean(r.P(end - 20:end)) / Pg;
            conv = find(abs(r.P - r.P(end)) > 0.01 * Pg, 1, 'last') + 1;
            linhas(end + 1, :) = {mat2str(padroes{g}), algs{a, 2}, seed, eta, conv}; %#ok<SAGROW>
        end
    end
end
tab = cell2table(linhas, 'VariableNames', {'sombra', 'algoritmo', 'semente', 'eta', 'passos_conv'});
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e5_mppt_estatico.csv'));
disp(groupsummary(tab, {'sombra', 'algoritmo'}, {'mean', 'min'}, 'eta'));
```

- [ ] **Passo 5: Rodar E5 e commit** `"Algoritmos de MPPT (P&O, InC, PSO) e experimento estatico E5"`.

---

### Tarefa 10: Simulação dinâmica completa (DAE em malha fechada + MPPT + térmico)

**Files:**
- Create: `matlab/simulacao/oraculo_pmax.m`, `matlab/simulacao/sim_dinamica.m`, `matlab/cenarios/cenario_constante.m`, `matlab/tests/test_sim_dinamica.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_sim_dinamica
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
pc = parametros_conversor(p, 12);
[ctl, ~] = projeto_pi(p, pc);
tc.TestData = struct('p', p, 'pc', pc, 'ctl', ctl, ...
    'pt', parametros_termicos(datasheet_painel('ztp160m')), 'cfg', config_mppt(p));
end

function test_pi_segue_referencia(tc)
d = tc.TestData;  cfg = d.cfg;  cfg.Vref0 = 16;
cen = cenario_constante([1000 1000 1000], 298.15, 1, 20 * d.ctl.Ta);
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', false));
verifyEqual(tc, r.V(end), 16, 'RelTol', 0.005);
end

function test_oraculo_eficiencia_unitaria(tc)
d = tc.TestData;  G = [1000 1000 400];
c = curva_pv(G, d.p.Tn, d.p);
cfg = d.cfg;  cfg.Vref0 = c.Vmp;
cen = cenario_constante(G, 298.15, 1, 30 * d.ctl.Ta);
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', false));
verifyGreaterThan(tc, r.eta, 0.99);
end

function test_termico_aquece(tc)
d = tc.TestData;  cfg = d.cfg;  cfg.Vref0 = 17;
cen = cenario_constante([1000 1000 1000], 298.15, 1, 20 * d.ctl.Ta);
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', true));
verifyGreaterThan(tc, r.T(end), 298.15 + 10);
end
```

- [ ] **Passo 2: Implementar**

```matlab
function cen = cenario_constante(G, Tamb, vw, t_fim)
%CENARIO_CONSTANTE Cenario com G (1 x Nsub), Tamb [K] e vento constantes.
cen.G = @(t) G;  cen.Tamb = @(t) Tamb;  cen.vw = @(t) vw;  cen.t_fim = t_fim;
end
```

```matlab
function [Pg, Vg] = oraculo_pmax(G, T, p)
%ORACULO_PMAX Maximo GLOBAL da curva P-V: varredura grossa + refinamento local.
c = curva_pv(G, T, p, 150);
[~, k] = max(c.P);
a = c.V(max(k - 1, 1));  b = c.V(min(k + 1, numel(c.V)));
[Vg, nP] = fminbnd(@(v) -v * painel_sombreado(v, G, T, p), a, b);
Pg = -nP;
end
```

```matlab
function r = sim_dinamica(cen, alg, cfg, ctl, p, pc, pt, op)
%SIM_DINAMICA Modelo medio com perdas + PI + MPPT + termico, como DAE.
%   x = [v_pv; i_L; xi; T; I; Vd_1..Vd_N]. MPPT atualiza V_ref a cada ctl.Ta.
%   op.termico: false -> T fica constante em op.T (padrao 298,15 K).
if ~isfield(op, 'T'), op.T = 298.15; end
N = p.Nsub;  Ta = ctl.Ta;  nK = floor(cen.t_fim / Ta);
G0 = cen.G(0);
if op.termico
    T0 = fzero(@(T) termico_dTdt(T, mean(G0), cen.Tamb(0), cen.vw(0), 0, pt), [250 400]);
else
    T0 = op.T;
end
v0 = cfg.Vref0;
[I0, s0] = painel_sombreado(v0, G0, T0, p);
eq = equilibrio_conversor(v0, max(I0, 1e-3), pc);
x = [v0; eq.iL; eq.d * ctl.Ti / ctl.Kp; T0; s0.z];
M = blkdiag(eye(4), zeros(N + 1));
base = odeset('Mass', M, 'MassSingular', 'yes', 'RelTol', 1e-5, 'AbsTol', 1e-7, ...
              'MaxStep', Ta / 20);
Vref = cfg.Vref0;  e = [];
r.t = zeros(nK, 1);  r.V = r.t;  r.I = r.t;  r.P = r.t;  r.T = r.t;  r.Vref = r.t;  r.Pg = r.t;
E = 0;  Eg = 0;
for k = 1:nK
    t0 = (k - 1) * Ta;
    opts = odeset(base, 'Jacobian', @(t, x) jac(t, x, Vref));
    [tt, xx] = ode15s(@(t, x) rhs(t, x, Vref), [t0, t0 + Ta], x, opts);
    x = xx(end, :).';
    E = E + trapz(tt, xx(:, 1) .* xx(:, 5));
    m = tt >= t0 + 0.8 * Ta;
    Vm = mean(xx(m, 1));  Im = mean(xx(m, 5));
    Pg = oraculo_pmax(cen.G(t0 + Ta / 2), x(4), p);
    Eg = Eg + Pg * Ta;
    r.t(k) = t0 + Ta;  r.V(k) = Vm;  r.I(k) = Im;  r.P(k) = Vm * Im;
    r.T(k) = x(4);  r.Vref(k) = Vref;  r.Pg(k) = Pg;
    [Vref, e] = alg(Vm, Im, e, cfg);
end
r.E = E;  r.Eg = Eg;  r.eta = E / Eg;

    function d = duty(x, Vref)
        du = ctl.Kp * ((x(1) - Vref) + x(3) / ctl.Ti);
        d = min(max(du, pc.Dmin), pc.Dmax);
    end

    function dx = rhs(t, x, Vref)
        v = x(1);  iL = x(2);  T = x(4);  z = x(5:end);
        err = v - Vref;
        du = ctl.Kp * (err + x(3) / ctl.Ti);
        d = duty(x, Vref);
        dxi = err;
        if (du > pc.Dmax && err > 0) || (du < pc.Dmin && err < 0)
            dxi = 0;                                     % anti-windup
        end
        if op.termico
            dT = termico_dTdt(T, mean(cen.G(t)), cen.Tamb(t), cen.vw(t), v * z(1), pt);
        else
            dT = 0;
        end
        dx = [conversor_medio_rhs(v, iL, z(1), d, pc); dxi; dT
              residuo_painel(z, v, cen.G(t), T, p)];
    end

    function Jf = jac(t, x, Vref)
    % Linhas diferenciais (suaves): diferencas finitas. Linhas algebricas (bypass,
    % exponencial ingreme): jacobiano analitico -- o numerico faz o ode15s falhar.
        n = numel(x);  Jf = zeros(n);
        f0 = rhs(t, x, Vref);
        for j = 1:4
            h = 1e-6 * max(1, abs(x(j)));
            xp = x;  xp(j) = xp(j) + h;
            fp = rhs(t, xp, Vref);
            Jf(1:4, j) = (fp(1:4) - f0(1:4)) / h;
        end
        Jf(1, 5) = 1 / pc.C;                             % C dv/dt = I - d*iL
        if op.termico
            Jf(4, 5) = -x(1) / (pt.mcp_area * pt.A);    % Pel = v*I sai do balanco
        end
        hT = 1e-4;
        Rp = residuo_painel(x(5:end), x(1), cen.G(t), x(4) + hT, p);
        Rm = residuo_painel(x(5:end), x(1), cen.G(t), x(4) - hT, p);
        [~, Jz] = residuo_painel(x(5:end), x(1), cen.G(t), x(4), p);
        Jf(5:end, 1) = [zeros(N, 1); -1];
        Jf(5:end, 4) = (Rp - Rm) / (2 * hT);
        Jf(5:end, 5:end) = Jz;
    end
end
```

- [ ] **Passo 3: Rodar `test_sim_dinamica`** — Expected: 3 `Passed`. Medir o tempo de execução (`tic/toc`) e anotar: define quanto de cada cenário dá para rodar em modelo médio.
- [ ] **Passo 4: Commit** `"Simulacao dinamica em malha fechada com MPPT e termico"`.

---

### Tarefa 11: Simulação quase-estática e validação contra a dinâmica

**Files:**
- Create: `matlab/simulacao/sim_quase_estatica.m`, `matlab/tests/test_quase_estatica.m`

- [ ] **Passo 1: Teste (falha)**

```matlab
function tests = test_quase_estatica
tests = functiontests(localfunctions);
end

function test_energia_igual_a_dinamica(tc)
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
ctl = projeto_pi(p, pc);  pt = parametros_termicos(datasheet_painel('ztp160m'));
cfg = config_mppt(p);
cen.G = @(t) [1000 1000 1000 - 600 * (t > 2)];
cen.Tamb = @(t) 298.15;  cen.vw = @(t) 1;  cen.t_fim = 4;
op = struct('termico', true, 'perdas', false);
rd = sim_dinamica(cen, @mppt_po, cfg, ctl, p, pc, pt, op);
rq = sim_quase_estatica(cen, @mppt_po, cfg, ctl, p, pc, pt, op);
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
end
```

- [ ] **Passo 2: Implementar**

```matlab
function r = sim_quase_estatica(cen, alg, cfg, ctl, p, pc, pt, op)
%SIM_QUASE_ESTATICA Conversor + PI assumidos assentados a cada Ta (v_pv = V_ref).
%   Termico integrado por Euler com passo Ta. Oraculo a cada op.dt_oraculo [s].
if ~isfield(op, 'T'), op.T = 298.15; end
if ~isfield(op, 'perdas'), op.perdas = true; end
if ~isfield(op, 'dt_oraculo'), op.dt_oraculo = ctl.Ta; end
if ~isfield(op, 't_ini'), op.t_ini = 0; end
Ta = ctl.Ta;  nK = floor((cen.t_fim - op.t_ini) / Ta);
passoOr = max(1, round(op.dt_oraculo / Ta));
G0 = cen.G(op.t_ini);
if op.termico
    T = fzero(@(T) termico_dTdt(T, mean(G0), cen.Tamb(op.t_ini), cen.vw(op.t_ini), 0, pt), [250 400]);
else
    T = op.T;
end
Vref = cfg.Vref0;  e = [];  z = [];  Pg = 0;
E = 0;  Eg = 0;  Eout = 0;  nDCM = 0;  nInviavel = 0;
r.t = zeros(nK, 1);  r.V = r.t;  r.P = r.t;  r.Pg = r.t;  r.T = r.t;
for k = 1:nK
    t = op.t_ini + (k - 0.5) * Ta;
    G = cen.G(t);
    [I, s] = painel_sombreado(Vref, G, T, p, z);  z = s.z;
    I = max(I, 0);  P = Vref * I;
    if mod(k - 1, passoOr) == 0, Pg = oraculo_pmax(G, T, p); end
    Pout = P;
    if op.perdas && I > 0
        eq = equilibrio_conversor(Vref, I, pc);
        if eq.viavel
            Pout = eq.Pout;
            nDCM = nDCM + ~verifica_ccm(Vref, eq.d, eq.iL, pc);
        else
            % d necessario fora de [Dmin, Dmax]: o conversor nao opera neste ponto
            Pout = 0;
            nInviavel = nInviavel + 1;
        end
    end
    if op.termico
        T = T + Ta * termico_dTdt(T, mean(G), cen.Tamb(t), cen.vw(t), P, pt);
    end
    E = E + P * Ta;  Eg = Eg + Pg * Ta;  Eout = Eout + Pout * Ta;
    r.t(k) = t;  r.V(k) = Vref;  r.P(k) = P;  r.Pg(k) = Pg;  r.T(k) = T;
    [Vref, e] = alg(Vref, I, e, cfg);
end
r.E = E;  r.Eg = Eg;  r.Eout = Eout;  r.eta = E / Eg;
r.eta_conv = Eout / max(E, eps);  r.fracDCM = nDCM / nK;  r.fracInviavel = nInviavel / nK;
end
```

- [ ] **Passo 3: Rodar `test_quase_estatica`** — Expected: `Passed`. Se falhar por > 1 %, investigar se `Ta` é curto demais para a malha assentar (aumentar o fator 1,5 em `projeto_pi`), e registrar no relatório.
- [ ] **Passo 4: Commit** `"Simulacao quase-estatica validada contra a dinamica"`.

---

### Tarefa 12: Cenários — EN 50530 e dia em Florianópolis

**Files:**
- Already created: `data/en50530_rampas.csv` (tabelas B.2–B.4, fonte no cabeçalho do arquivo)
- Create: `matlab/cenarios/perfil_en50530.m`, `baixar_pvgis.m`, `dia_florianopolis.m`, `aplicar_sombras.m`, `matlab/tests/test_cenarios.m`

- [ ] **Passo 1: Conferir `data/en50530_rampas.csv`** (já no repositório). Cada linha: espera de `espera_s` em `G_baixo`, depois `repeticoes` trapézios (rampa até `G_alto`, `patamar_s`, rampa até `G_baixo`, `patamar_s`). Duração de uma linha = espera + repetições × (2·rampa + 2·patamar), com rampa = (G_alto − G_baixo)/inclinação. Duração total esperada (rampas calculadas pela inclinação, sem o arredondamento do relatório): B.2 = 15 939,0 s, B.3 = 6 986,7 s, B.4 = 2 160 s → **25 085,7 s ≈ 7,0 h**.

- [ ] **Passo 2: Teste (falha)**

```matlab
function tests = test_cenarios
tests = functiontests(localfunctions);
end

function test_en50530_trapezio(tc)
arq = [tempname '.csv'];
writelines(["% teste"
             "sequencia,G_baixo,G_alto,inclinacao_Wm2s,patamar_s,repeticoes,espera_s"
             "X,100,500,10,5,2,20"], arq);
cen = perfil_en50530(arq, 3);
% espera 20 s em 100; trapezio: sobe 40 s, 5 s em 500, desce 40 s, 5 s em 100 (x2)
verifyEqual(tc, cen.t_fim, 20 + 2 * 90, 'AbsTol', 1e-9);
verifyEqual(tc, cen.G(10), [100 100 100], 'AbsTol', 1e-9);   % espera
verifyEqual(tc, cen.G(40), [300 300 300], 'AbsTol', 1e-6);   % meio da 1a rampa
verifyEqual(tc, cen.G(62), [500 500 500], 'AbsTol', 1e-9);   % patamar alto
delete(arq);
end

function test_en50530_tabela_real(tc)
arq = fullfile(raiz_projeto(), 'data', 'en50530_rampas.csv');
cen = perfil_en50530(arq, 3);
% rampas calculadas pela inclinacao (ex.: 400/3 = 133,3 s; o relatorio imprime 133)
verifyEqual(tc, cen.t_fim, 25085.714, 'AbsTol', 1e-3);       % B.2 + B.3 + B.4
verifyEqual(tc, cen.G(300 + 800), [500 500 500], 'AbsTol', 1e-6);  % fim da 1a rampa a 0,5 W/m2/s
end

function test_sombra_afeta_so_um_submodulo(tc)
cen = cenario_constante([1000 1000 1000], 298.15, 1, 100);
ev = table(10, 20, 3, 0.3, 1, 'VariableNames', {'t_ini', 't_fim', 'sub', 'fator', 'rampa_s'});
cen = aplicar_sombras(cen, ev);
verifyEqual(tc, cen.G(5), [1000 1000 1000], 'AbsTol', 1e-9);
verifyEqual(tc, cen.G(15), [1000 1000 300], 'AbsTol', 1e-6);
end

function test_nuvem_afeta_todos(tc)
cen = cenario_constante([1000 1000 1000], 298.15, 1, 100);
ev = table(10, 20, 0, 0.5, 1, 'VariableNames', {'t_ini', 't_fim', 'sub', 'fator', 'rampa_s'});
cen = aplicar_sombras(cen, ev);
verifyEqual(tc, cen.G(15), [500 500 500], 'AbsTol', 1e-6);
end
```

- [ ] **Passo 3: Implementar**

```matlab
function cen = perfil_en50530(arq, Nsub, Tamb, vw)
%PERFIL_EN50530 Irradiancia uniforme G(t) dos ensaios dinamicos da EN 50530 (Anexo B).
%   Cada linha da tabela gera: espera em G_baixo e depois 'repeticoes' trapezios
%   (rampa de subida, patamar em G_alto, rampa de descida, patamar em G_baixo).
%   G(t) e montado como uma lista de pontos (tempo, irradiancia) interpolada
%   linearmente entre eles.
if nargin < 3, Tamb = 298.15; end
if nargin < 4, vw = 1; end
tab = readtable(arq, 'CommentStyle', '%', 'TextType', 'string');

t_pts = [];  G_pts = [];  t = 0;
for i = 1:height(tab)
    Gb = tab.G_baixo(i);  Ga = tab.G_alto(i);
    rampa = (Ga - Gb) / tab.inclinacao_Wm2s(i);      % duracao da rampa [s]
    patamar = tab.patamar_s(i);

    % Inicio da linha: degrau para G_baixo e espera (1 ms para o degrau ser vertical)
    t_pts(end + 1) = t + 1e-3;           G_pts(end + 1) = Gb;   %#ok<AGROW>
    t = t + tab.espera_s(i);
    t_pts(end + 1) = t;                  G_pts(end + 1) = Gb;   %#ok<AGROW>

    for rep = 1:tab.repeticoes(i)
        t = t + rampa;    t_pts(end + 1) = t;  G_pts(end + 1) = Ga;  %#ok<AGROW> sobe
        t = t + patamar;  t_pts(end + 1) = t;  G_pts(end + 1) = Ga;  %#ok<AGROW> fica no alto
        t = t + rampa;    t_pts(end + 1) = t;  G_pts(end + 1) = Gb;  %#ok<AGROW> desce
        t = t + patamar;  t_pts(end + 1) = t;  G_pts(end + 1) = Gb;  %#ok<AGROW> fica no baixo
    end
end
t_pts = [0, t_pts];  G_pts = [G_pts(1), G_pts];

interp_G = griddedInterpolant(t_pts, G_pts, 'linear', 'nearest');
cen.G = @(tq) interp_G(tq) * ones(1, Nsub);          % mesma irradiancia em todos
cen.Tamb = @(tq) Tamb;
cen.vw = @(tq) vw;
cen.t_fim = t;
end
```

```matlab
function cen = aplicar_sombras(cen, ev)
%APLICAR_SOMBRAS Multiplica G por 'fator' entre t_ini e t_fim (rampas de rampa_s).
%   ev.sub = 0 -> todos os submodulos (nuvem); sub = j -> so o submodulo j.
Gbase = cen.G;
cen.G = @(t) Gbase(t) .* fatores(t, numel(Gbase(t)));
    function f = fatores(t, N)
        f = ones(1, N);
        for i = 1:height(ev)
            a = min(max((t - ev.t_ini(i)) / ev.rampa_s(i), 0), 1) ...
              - min(max((t - ev.t_fim(i)) / ev.rampa_s(i), 0), 1);
            fi = 1 - (1 - ev.fator(i)) * a;
            if ev.sub(i) == 0
                f = f * fi;
            else
                f(ev.sub(i)) = f(ev.sub(i)) * fi;
            end
        end
    end
end
```

```matlab
function arq = baixar_pvgis(ano)
%BAIXAR_PVGIS Serie horaria do PVGIS para Florianopolis no plano do modulo.
%   Conferir nomes dos parametros em https://joint-research-centre.ec.europa.eu/pvgis
%   (API seriescalc) antes de rodar. aspect: 0 = sul, 180 = norte.
url = 'https://re.jrc.ec.europa.eu/api/v5_3/seriescalc';
arq = fullfile(raiz_projeto(), 'data', 'clima', sprintf('pvgis_floripa_%d.csv', ano));
txt = webread(url, 'lat', -27.595, 'lon', -48.548, 'startyear', ano, ...
    'endyear', ano, 'angle', 27, 'aspect', 180, 'outputformat', 'csv', ...
    weboptions('ContentType', 'text', 'Timeout', 60));
fid = fopen(arq, 'w');  fprintf(fid, '%s', txt);  fclose(fid);
end
```

```matlab
function cen = dia_florianopolis(arq, dia, Nsub)
%DIA_FLORIANOPOLIS Cenario de um dia (t em segundos desde 00:00, hora UTC do PVGIS).
%   dia: datetime (hora local). O PVGIS entrega UTC; converte para UTC-3, de modo
%   que t = 0 e a meia-noite LOCAL e os eventos de sombra usam hora local.
%   Colunas usadas: time, G(i), T2m, WS10m. O CSV tem cabecalho e rodape de texto:
%   so as linhas que comecam com a data (yyyyMMdd:HHmm) sao dados.
linhas = splitlines(string(fileread(arq)));
ini = find(startsWith(linhas, "time,"), 1);
dados = linhas(ini + 1:end);
dados = dados(~cellfun(@isempty, regexp(cellstr(dados), '^\d{8}:\d{4},', 'once')));
tmp = [tempname '.csv'];
writelines([linhas(ini); dados], tmp);
tab = readtable(tmp, 'VariableNamingRule', 'preserve', 'Delimiter', ',', ...
    'TextType', 'string');
delete(tmp);
tt = datetime(tab.time, 'InputFormat', 'yyyyMMdd:HHmm') - hours(3);
sel = dateshift(tt, 'start', 'day') == dateshift(dia, 'start', 'day');
h = hours(tt(sel) - dateshift(dia, 'start', 'day')) * 3600;
G = tab.("G(i)")(sel);  Ta = tab.T2m(sel) + 273.15;  vw = tab.WS10m(sel);
gi = griddedInterpolant(h, G, 'pchip', 'nearest');
ti = griddedInterpolant(h, Ta, 'pchip', 'nearest');
vi = griddedInterpolant(h, vw, 'pchip', 'nearest');
cen.G = @(t) max(gi(t), 0) * ones(1, Nsub);
cen.Tamb = @(t) ti(t);
% Vento: o PVGIS da WS10m (10 m de altura); Watmuff usa o vento junto ao modulo.
% Lei de potencia do perfil de vento (expoente 1/7, terreno aberto), modulo a ~2 m:
fator_altura = (2 / 10)^(1/7);                 % ~0,79
cen.vw = @(t) fator_altura * max(vi(t), 0);
cen.t_fim = h(end);  cen.t_ini_dia = h(find(G > 5, 1));  cen.t_fim_dia = h(find(G > 5, 1, 'last'));
end
```

- [ ] **Passo 3b: Teste do leitor do PVGIS com arquivo sintético** (acrescentar a `test_cenarios.m`)

```matlab
function test_dia_florianopolis_utc_para_local(tc)
arq = [tempname '.csv'];
L = ["Latitude (decimal degrees):	-27.595"; ""; "time,G(i),H_sun,T2m,WS10m,Int"];
for hu = 0:23                                   % 15/01/2020, hora UTC
    G = max(0, 1000 * sin(pi * (hu - 3 - 6) / 13));   % sol entre 6h e 19h local
    L(end + 1) = sprintf('20200115:%02d10,%.1f,30,%.1f,2.0,0', hu, G, 25 + hu / 10); %#ok<AGROW>
end
L(end + 1) = "";  L(end + 1) = "G(i): Global irradiance on the inclined plane (W/m2)";
writelines(L, arq);
cen = dia_florianopolis(arq, datetime(2020, 1, 15), 3);
% amostra das 15:10 UTC = 12:10 local (no proprio ponto, a interpolacao e exata)
verifyEqual(tc, cen.G(12 * 3600 + 600), 1000 * sin(pi * 6 / 13) * [1 1 1], 'RelTol', 1e-6);
verifyEqual(tc, cen.Tamb(12 * 3600 + 600), 25 + 15 / 10 + 273.15, 'AbsTol', 1e-9);
verifyEqual(tc, cen.t_ini_dia, 6 * 3600 + 600, 'AbsTol', 1e-6);   % primeiro G > 5
delete(arq);
end
```

(O PVGIS registra os valores horários em hh:10; o teste usa o mesmo formato. Rodar e ver `Passed`.)

- [ ] **Passo 4: Rodar `test_cenarios`** — Expected: 5 `Passed`.
- [ ] **Passo 5: Baixar os dados** (`-batch "setup_path; baixar_pvgis(2020)"`), abrir o CSV e conferir cabeçalho e colunas. Escolher o dia: maior irradiação diária de janeiro de 2020 com perfil de sino (céu claro). Gravar a data (ex.: `2020-01-17`) em `resultados/dia_escolhido.txt`, que os experimentos E7 e E8 leem.
- [ ] **Passo 6: Commit** `"Cenarios: EN 50530, PVGIS Florianopolis e eventos de sombra"` (incluir o CSV do PVGIS).

---

### Tarefa 13: Experimentos de resultados (E2, E4, E6, E7, E8)

**Files:**
- Create: `matlab/experimentos/exp02_curvas_sombra.m`, `exp04_controle.m`, `exp06_en50530.m`, `exp07_dia.m`, `exp08_baseline.m`
- Delete: `matlab/experimentos/exemplo_sombreamento.m` (substituído por E2)

- [ ] **Passo 1: E2 — curvas com sombra** (o `exemplo_sombreamento.m` com `parametros_painel('ztp160m')`, salvando `relatorio/figs/e2_curvas_sombra.pdf` e `resultados/e2_picos.csv`).

```matlab
%EXP02 Curvas I-V e P-V do ZTP-160M sob sombreamento parcial.
setup_path();
p = parametros_painel('ztp160m');
padroes = {ones(1, p.Nsub), [ones(1, p.Nsub - 1) 0.4], linspace(1, 0.3, p.Nsub)};
nomes = {'sem sombra', '1 submodulo a 40 %', 'degrade'};
cores = lines(numel(padroes));  linhas = {};
figure('Position', [100 100 1000 420]);
for n = 1:numel(padroes)
    c = curva_pv(1000 * padroes{n}, p.Tn, p);
    subplot(1, 2, 1); hold on;
    plot(c.V, c.I, 'Color', cores(n, :), 'LineWidth', 1.5, 'DisplayName', nomes{n});
    subplot(1, 2, 2); hold on;
    plot(c.V, c.P, 'Color', cores(n, :), 'LineWidth', 1.5, 'DisplayName', nomes{n});
    plot(c.Vmp, c.Pmp, 'o', 'Color', cores(n, :), 'MarkerFaceColor', cores(n, :), 'HandleVisibility', 'off');
    for k = 1:height(c.picos)
        linhas(end + 1, :) = {nomes{n}, c.picos.V(k), c.picos.P(k), c.picos.P(k) == c.Pmp}; %#ok<SAGROW>
    end
end
subplot(1, 2, 1); grid on; xlabel('V [V]'); ylabel('I [A]'); legend('Location', 'southwest');
subplot(1, 2, 2); grid on; xlabel('V [V]'); ylabel('P [W]');
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e2_curvas_sombra.pdf'));
writetable(cell2table(linhas, 'VariableNames', {'cenario', 'V', 'P', 'global'}), ...
    fullfile(raiz_projeto(), 'resultados', 'e2_picos.csv'));
```

- [ ] **Passo 2: E4 — controle** (Bode de G_vd nos pontos de robustez; laço aberto com o PI; degrau linear × não linear)

```matlab
%EXP04 Bode da planta em varios pontos, margens do PI e validacao do degrau.
setup_path();
p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
[ctl, rel] = projeto_pi(p, pc);
w = logspace(1, log10(pi * pc.fs), 600);
figure('Position', [100 100 900 600]);
for k = 1:numel(rel.ops)
    sys = linearizar_planta(rel.ops(k), p, pc);
    H = resposta_freq(sys, w);
    subplot(2, 1, 1); semilogx(w / 2 / pi, 20 * log10(abs(H))); hold on;
    subplot(2, 1, 2); semilogx(w / 2 / pi, unwrap(angle(H)) * 180 / pi); hold on;
end
subplot(2, 1, 1); grid on; ylabel('|G_{vd}| [dB]');
title(sprintf('PI: Kp = %.3g, Ti = %.3g ms, f_c = %.0f Hz, MF_{min} = %.0f°', ...
    ctl.Kp, 1e3 * ctl.Ti, ctl.fc, rel.PMmin));
subplot(2, 1, 2); grid on; ylabel('fase [°]'); xlabel('f [Hz]');
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e4_bode.pdf'));
tab = struct2table(rel.ops);  tab.PM = rel.PM;  tab.GM = rel.GM;
tab.G = mat2str_cell(tab.G);
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e4_margens.csv'));
fprintf('Ta = %.1f ms (ts = %.1f ms)\n', 1e3 * ctl.Ta, 1e3 * ctl.ts);
fprintf('Pontos em DCM fora da verificacao: %d\n', numel(rel.ops_dcm));

function c = mat2str_cell(G)
c = cellfun(@mat2str, num2cell(G, 2), 'UniformOutput', false);
end
```

- [ ] **Passo 3: E6 — EN 50530** (quase-estático no perfil inteiro; dinâmico num trecho de 2 rampas para figura). Ajuste de `delta` do P&O/InC: varrer `delta ∈ {0,5; 1; 2} % de Voc` e reportar o melhor de cada.

```matlab
%EXP06 Eficiencia dinamica (perfil EN 50530) de P&O, InC e PSO.
setup_path();
p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
ds = datasheet_painel('ztp160m');  pt = parametros_termicos(ds);
ctl = projeto_pi(p, pc);  cfg0 = config_mppt(p);
cen = perfil_en50530(fullfile(raiz_projeto(), 'data', 'en50530_rampas.csv'), p.Nsub);
op = struct('termico', false, 'perdas', true, 'dt_oraculo', 1);
algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
linhas = {};
for a = 1:size(algs, 1)
    for dlt = [0.005 0.01 0.02]
        cfg = cfg0;  cfg.delta = dlt * cfg.Voc;
        r = sim_quase_estatica(cen, algs{a, 1}, cfg, ctl, p, pc, pt, op);
        linhas(end + 1, :) = {algs{a, 2}, dlt, r.eta, r.E / 3600}; %#ok<SAGROW>
        if strcmp(algs{a, 2}, 'PSO'), break, end      % delta nao se aplica ao PSO
    end
end
tab = cell2table(linhas, 'VariableNames', {'algoritmo', 'delta_rel', 'eta', 'E_Wh'});
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e6_en50530.csv'));
disp(tab);
```

- [ ] **Passo 4: E7 — dia em Florianópolis** com sombra de poste e nuvens; tabela de energia por algoritmo e **ablação** (completo / sem térmico / sem perdas). Eventos sintéticos (documentar no relatório):

```matlab
%EXP07 Dia real em Florianopolis com sombras sinteticas: energia e ablacao.
setup_path();
p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
ds = datasheet_painel('ztp160m');  pt = parametros_termicos(ds);
ctl = projeto_pi(p, pc);  cfg = config_mppt(p);
dia = datetime(fileread(fullfile(raiz_projeto(), 'resultados', 'dia_escolhido.txt')));
cen = dia_florianopolis(fullfile(raiz_projeto(), 'data', 'clima', 'pvgis_floripa_2020.csv'), dia, p.Nsub);
h = 3600;                                       % hora LOCAL (dia_florianopolis ja converte)
% 10:30 e 11:15: nuvens rapidas (todos os submodulos)
% 14:00-15:30: sombra de poste varrendo os submodulos N -> N-1 -> N (mais fraca)
ev = table([10.5; 11.25; 14.0; 14.75; 15.0] * h, [10.6; 11.27; 14.75; 15.0; 15.5] * h, ...
           [0; 0; p.Nsub; p.Nsub - 1; p.Nsub], [0.4; 0.3; 0.3; 0.3; 0.5], [20; 10; 60; 60; 60], ...
           'VariableNames', {'t_ini', 't_fim', 'sub', 'fator', 'rampa_s'});
cen = aplicar_sombras(cen, ev);
writetable(ev, fullfile(raiz_projeto(), 'resultados', 'e7_eventos.csv'));
cen.t_fim = cen.t_fim_dia;
variantes = {struct('termico', true,  'perdas', true),  'completo'
             struct('termico', false, 'perdas', true),  'sem termico (T = 25 C)'
             struct('termico', true,  'perdas', false), 'sem perdas'};
algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
linhas = {};
for v = 1:size(variantes, 1)
    op = variantes{v, 1};  op.dt_oraculo = 1;  op.t_ini = cen.t_ini_dia;
    for a = 1:size(algs, 1)
        r = sim_quase_estatica(cen, algs{a, 1}, cfg, ctl, p, pc, pt, op);
        linhas(end + 1, :) = {variantes{v, 2}, algs{a, 2}, r.E / 3600, r.Eout / 3600, ...
                              r.Eg / 3600, r.eta, r.eta_conv, r.fracDCM}; %#ok<SAGROW>
        if v == 1, res.(matlab.lang.makeValidName(algs{a, 2})) = r; end
    end
end
tab = cell2table(linhas, 'VariableNames', {'variante', 'algoritmo', 'E_pv_Wh', ...
    'E_bat_Wh', 'E_max_Wh', 'eta_MPPT', 'eta_conv', 'frac_DCM'});
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e7_dia.csv'));
disp(tab);

% Figura: potencia maxima disponivel x extraida (dia inteiro e zoom na sombra)
nomes = fieldnames(res);
figure('Position', [100 100 1000 650]);
janelas = {[cen.t_ini_dia, cen.t_fim_dia], [13.8, 15.7] * h};
for j = 1:2
    subplot(2, 1, j); hold on;
    r0 = res.(nomes{1});
    plot(r0.t / h, r0.Pg, 'k', 'LineWidth', 1.5, 'DisplayName', 'maximo global');
    for a = 1:numel(nomes)
        ra = res.(nomes{a});
        plot(ra.t / h, movmean(ra.P, 20), 'DisplayName', algs{a, 2});
    end
    xlim(janelas{j} / h); grid on; ylabel('P [W]');
end
xlabel('hora local'); legend('Location', 'best');
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e7_dia.pdf'));
```

Antes de rodar: conferir que `resultados/dia_escolhido.txt` existe (Tarefa 12, Passo 5). Uso de memória: `r.t`, `r.P` têm ~1 milhão de pontos por algoritmo (Ta ≈ 50 ms × 13 h), cerca de 40 MB no total, aceitável.

- [ ] **Passo 5: E8 — linha de base do trabalho anterior**: mesmo dia, sem sombras; modelo "anterior" = `extrair_parametros(ds, '1d')`, `conversor_ideal(pc)`, `termico = false`; modelo completo = 2d, perdas, térmico; ambos com P&O. Saída `resultados/e8_baseline.csv` com a diferença percentual de energia → responde "quanto as simplificações erravam".

```matlab
%EXP08 Modelo do trabalho anterior x modelo completo no mesmo dia (sem sombra).
setup_path();
ds = datasheet_painel('ztp160m');
p2 = parametros_painel('ztp160m');  p1 = extrair_parametros(ds, '1d');
pc = parametros_conversor(p2, 12);  pt = parametros_termicos(ds);
ctl = projeto_pi(p2, pc);
dia = datetime(fileread(fullfile(raiz_projeto(), 'resultados', 'dia_escolhido.txt')));
cen = dia_florianopolis(fullfile(raiz_projeto(), 'data', 'clima', 'pvgis_floripa_2020.csv'), dia, p2.Nsub);
cen.t_fim = cen.t_fim_dia;
opA = struct('termico', false, 'perdas', false, 'dt_oraculo', 1, 't_ini', cen.t_ini_dia);
opB = struct('termico', true,  'perdas', true,  'dt_oraculo', 1, 't_ini', cen.t_ini_dia);
rA = sim_quase_estatica(cen, @mppt_po, config_mppt(p1), ctl, p1, conversor_ideal(pc), pt, opA);
rB = sim_quase_estatica(cen, @mppt_po, config_mppt(p2), ctl, p2, pc, pt, opB);
tab = table({'anterior (1d, ideal, T=25C)'; 'completo (2d, perdas, termico)'}, ...
    [rA.Eout; rB.Eout] / 3600, 'VariableNames', {'modelo', 'E_bateria_Wh'});
tab.diferenca_pct = 100 * (tab.E_bateria_Wh - tab.E_bateria_Wh(2)) / tab.E_bateria_Wh(2);
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e8_baseline.csv'));
disp(tab);
```

- [ ] **Passo 6: Rodar E2, E4, E6, E7, E8**, conferir as figuras e as tabelas, remover `exemplo_sombreamento.m`, rodar a suíte inteira e commitar `"Experimentos E2-E8"` (incluir `resultados/*.csv` e `relatorio/figs/*.pdf`).

---

### Tarefa 14: Relatório final

**Files:**
- Create: `relatorio/relatorio.tex`, `relatorio/referencias.bib`

- [ ] **Passo 1: Estrutura** (reaproveitar o texto de `proposta/proposta.tex` na fundamentação; resultados exclusivamente dos CSVs/figuras de `resultados/` e `relatorio/figs/`):

1. Introdução: problema, pergunta central, contribuição sobre o trabalho anterior
2. Fundamentação: modelo de 2 diodos; bypass e múltiplos picos; balanço térmico; buck-boost médio/chaveado; MPPTs
3. Modelagem e métodos numéricos: extração por LM (bem posta × mal posta); Newton com jacobiano analítico; DAE com matriz de massa (e a falha do jacobiano numérico como achado); hierarquia de modelos e escalas de tempo; projeto do PI por margens
4. Validação: E1 (datasheet), E3 (chaveado × médio, DCM), E4 (linearização), equivalência quase-estático × dinâmico (Tarefa 11)
5. Resultados: E2, E5, E6, E7 (incluindo ablação), E8
6. Conclusão: resposta numérica à pergunta central; limitações (ruptura reversa não modelada, sombras sintéticas, temperatura uniforme no módulo)

- [ ] **Passo 2: Compilar** `cd relatorio && tectonic -X compile relatorio.tex` sem erros; conferir as páginas renderizadas.
- [ ] **Passo 3: Commit** `"Relatorio final"`.

---

### Tarefa 15: Revisão final e publicação

- [ ] **Passo 1:** Rodar a suíte completa (comando padrão) — todos `Passed`.
- [ ] **Passo 2:** Rodar todos os experimentos do zero (`exp01` … `exp08`) e conferir que as tabelas batem com as do relatório.
- [ ] **Passo 3:** Atualizar `README.md` (estrutura, como rodar testes e experimentos, dados necessários).
- [ ] **Passo 4:** `git push` para `origin/main`.
