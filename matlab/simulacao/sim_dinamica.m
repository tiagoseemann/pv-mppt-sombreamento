function r = sim_dinamica(cen, alg, cfg, ctl, p, pc, pt, op)
%SIM_DINAMICA Malha fechada completa: modelo medio com perdas + PI + MPPT + termico.
%   r = sim_dinamica(cen, alg, cfg, ctl, p, pc, pt, op)
%
%   cen : cenario (cenario_constante etc.): cen.G(t) (1 x Nsub), cen.Tamb(t),
%         cen.vw(t), cen.t_fim
%   alg : algoritmo de MPPT, [Vref, e] = alg(V, I, e, cfg) (mppt_po, mppt_inc,
%         mppt_pso, mppt_fixo); cfg = config_mppt(p)
%   ctl : PI de tensao (projeto_pi): ctl.Kp, ctl.Ti, ctl.Ta
%   p, pc, pt : painel, conversor e parametros termicos
%   op.termico : true -> temperatura do modulo evolui pelo balanco de energia;
%                false -> fica constante em op.T
%   op.T  : temperatura fixa quando op.termico = false [K] (padrao 298,15)
%   op.V0 : tensao inicial do painel [V] (padrao cfg.Vref0). Com V0 diferente
%           de cfg.Vref0 a simulacao comeca com um degrau de referencia.
%
%   ESTADO: x = [v_pv; i_L; xi; T]
%       v_pv : tensao do capacitor de entrada = tensao do painel [V]
%       i_L  : corrente media no indutor [A]
%       xi   : integral do erro do PI, xi' = v_pv - V_ref [V s]
%       T    : temperatura das celulas [K]
%   A corrente do painel I nao e estado: o painel nao tem dinamica propria
%   nesta escala, I e a solucao das equacoes algebricas do modulo (KCL em
%   cada submodulo com o bypass + KVL na serie, residuo_painel) para a
%   tensao v_pv atual. O modelo e uma DAE de indice 1:
%       x' = f(x, I),   0 = R(z; v_pv, G, T),   z = [I; Vd_1..Vd_N]
%
%   POR QUE NAO PASSAR A DAE DIRETO AO ode15s (matriz de massa singular,
%   como em sim_medio_aberta): foi a primeira versao, e falhava ("unable to
%   meet integration tolerances") nos degraus grandes de V_ref do PSO
%   (ex.: 18,7 V -> 6 V com sombra): 9 de 36 casos de teste com
%   RelTol = 1e-5, 3 de 36 mesmo com RelTol = 1e-6. Causa: o ode15s
%   reaproveita o jacobiano por varios passos, e a derivada das KCL em
%   relacao a Vd_j varia exponencialmente (de ~1e-2 S na regiao de fonte de
%   corrente a ~1e2 S com o bypass conduzindo); com um jacobiano velho o
%   Newton interno deixa de corrigir erros em Vd (ex.: Vd_1 sobe e Vd_2
%   desce em dois submodulos iguais, sem mudar sum(Vj)) e o erro cresce em
%   silencio. Aqui a restricao algebrica e resolvida por completo a cada
%   avaliacao (painel_sombreado: Newton com passo limitado ate 1e-9), e o
%   ode15s so ve a EDO reduzida x' = f(x, I(x)), que e suave. O modelo e o
%   mesmo; nos casos em que a DAE passava, os resultados coincidem.
%   O ode15s (implicito) continua necessario: a ressonancia LC, o PI e a
%   inclinacao dI/dV do painel sao rapidos e o termico e lento (rigidez).
%
%   MPPT AMOSTRADO: o algoritmo roda a cada ctl.Ta. Entre duas chamadas a
%   referencia V_ref fica constante (segurador de ordem zero): integramos
%   em [t0, t0 + Ta] com V_ref fixo, medimos, chamamos o MPPT e comecamos o
%   intervalo seguinte com o novo V_ref.
%   A medida entregue ao MPPT e a MEDIA de v e I nos ultimos 20 % de cada
%   Ta: espera o transitorio do PI depois do degrau de V_ref (criterio de
%   Femia, Ta = 1,5 ts no pior caso) e filtra o resto de oscilacao.
%
%   PI COM ANTI-WINDUP: d = Kp*(e + xi/Ti), e = v_pv - V_ref (sinal invertido:
%   mais d tira mais corrente e a tensao do painel cai). d e saturado em
%   [Dmin, Dmax]; quando satura e o erro empurraria d mais para fora, o
%   integrador para (xi' = 0), senao xi cresceria sem limite e a malha
%   demoraria a sair da saturacao.
%   O atraso do PWM (pc.atraso) nao entra aqui: ~75 us, muito menor que o
%   tempo de acomodacao (~20 ms); ele foi considerado nas margens do PI.
%
%   ENERGIA E ORACULO: E = integral de v_pv*I (energia tirada do painel, nos
%   pontos do integrador). A referencia Eg soma, a cada Ta, a potencia
%   maxima GLOBAL (oraculo_pmax) na irradiancia do meio do intervalo e na
%   temperatura atual, vezes Ta. eta = E/Eg e a eficiencia de rastreamento:
%   um MPPT preso num pico local da eta < 1 mesmo estando "no maximo".
%
%   Saida (um valor por periodo Ta, k = 1..nK):
%   r.t (fim do periodo), r.V, r.I, r.P (medias da janela), r.T, r.Vref
%   (referencia aplicada no periodo), r.Pg (oraculo), r.d (razao ciclica no
%   fim), r.ccm (conducao continua no fim do periodo, verifica_ccm).
%   Totais: r.E, r.Eg [J], r.eta, r.T0 (temperatura inicial),
%   r.fracDCM (fracao dos periodos em DCM: ali o modelo medio de CCM e
%   otimista), r.nReinicios (reinicios do PSO; NaN se o algoritmo nao tem),
%   r.tempo_cpu [s].

if ~isfield(op, 'T'), op.T = 298.15; end
if ~isfield(op, 'V0'), op.V0 = cfg.Vref0; end
tic;
Ta = ctl.Ta;
nK = floor(cen.t_fim / Ta);
% Tudo o que as funcoes do ode15s precisam, num struct so
m = struct('cen', cen, 'ctl', ctl, 'p', p, 'pc', pc, 'pt', pt, 'termico', op.termico);

% --- Condicao inicial ---
G0 = cen.G(0);
if op.termico
    % Modulo em equilibrio termico com o conversor desligado (Pel = 0):
    % e como ele esta antes do MPPT comecar a tirar potencia
    T0 = fzero(@(T) termico_dTdt(T, mean(G0), cen.Tamb(0), cen.vw(0), 0, pt), [250 400]);
else
    T0 = op.T;
end
v0 = op.V0;
I0 = painel_sombreado(v0, G0, T0, p);
% Conversor em regime em v0: i_L = I/d. O integrador comeca no valor que da
% exatamente esse d (partida sem tranco): d = Kp*((v0 - Vref) + xi0/Ti)
eq = equilibrio_conversor(v0, I0, pc);
if ~eq.viavel
    error('sim_dinamica:inicioInviavel', ...
        ['Ponto inicial V0 = %.3f V (I = %.3f A) sem equilibrio do conversor ' ...
         '(I <= 0 ou d fora de [%.2f, %.2f]): escolha outro op.V0'], ...
        v0, I0, pc.Dmin, pc.Dmax);
end
xi0 = ctl.Ti * (eq.d / ctl.Kp - (v0 - cfg.Vref0));
x = [v0; eq.iL; xi0; T0];

% MaxStep = Ta/20: garante varios pontos na janela de medida (20 % de Ta)
base = odeset('RelTol', 1e-5, 'AbsTol', 1e-7, 'MaxStep', Ta / 20);

Vref = cfg.Vref0;
e = [];                                % estado interno do MPPT (vazio = primeira chamada)
r.t = zeros(nK, 1);  r.V = r.t;  r.I = r.t;  r.P = r.t;  r.T = r.t;
r.Vref = r.t;  r.Pg = r.t;  r.d = r.t;  r.ccm = false(nK, 1);
E = 0;  Eg = 0;
Gant = [];  Tant = NaN;  Pg = NaN;     % cache do oraculo

for k = 1:nK
    t0 = (k - 1) * Ta;
    t1 = t0 + Ta;
    % V_ref fica constante dentro do intervalo (segurador de ordem zero)
    f = @(t, x) rhs(t, x, Vref, m);
    opts = odeset(base, 'Jacobian', @(t, x) jacobiano(t, x, Vref, m));
    [tt, xx] = ode15s(f, [t0, t1], x, opts);
    if tt(end) < t1 - 1e-9 * Ta
        error('sim_dinamica:ode15s', 'ode15s parou em t = %.6f s (periodo %d)', tt(end), k);
    end
    x = xx(end, :).';

    % Corrente do painel em cada ponto do integrador (o Newton parte da
    % solucao do ponto anterior, que esta perto)
    Ik = zeros(numel(tt), 1);
    z = [];
    for i = 1:numel(tt)
        [Ik(i), sol] = painel_sombreado(xx(i, 1), cen.G(tt(i)), xx(i, 4), p, z);
        z = sol.z;
    end

    % Energia tirada do painel no periodo: integral de v_pv * I
    E = E + trapz(tt, xx(:, 1) .* Ik);

    % Medida do MPPT: media nos ultimos 20 % do periodo
    Vm = media_janela(tt, xx(:, 1), t0 + 0.8 * Ta);
    Im = media_janela(tt, Ik, t0 + 0.8 * Ta);

    % Oraculo: pico global no meio do periodo. So recalcula se G ou T
    % mudaram (0,01 K muda Pmp em ~4e-5, desprezivel)
    Gk = cen.G(t0 + Ta / 2);
    if ~isequal(Gk, Gant) || abs(x(4) - Tant) > 0.01
        Pg = oraculo_pmax(Gk, x(4), p);
        Gant = Gk;  Tant = x(4);
    end
    Eg = Eg + Pg * Ta;

    % Conducao continua no fim do periodo (estado medio)
    dk = lei_pi(x(1), x(3), Vref, ctl, pc);
    r.ccm(k) = verifica_ccm(x(1), dk, x(2), pc);

    r.t(k) = t1;  r.V(k) = Vm;  r.I(k) = Im;  r.P(k) = Vm * Im;
    r.T(k) = x(4);  r.Vref(k) = Vref;  r.Pg(k) = Pg;  r.d(k) = dk;

    % MPPT: nova referencia para o proximo periodo
    [Vref, e] = alg(Vm, Im, e, cfg);
end

r.E = E;  r.Eg = Eg;  r.eta = E / Eg;
r.T0 = T0;
r.fracDCM = sum(~r.ccm) / nK;
if isstruct(e) && isfield(e, 'nReinicios')
    r.nReinicios = e.nReinicios;
else
    r.nReinicios = NaN;
end
r.tempo_cpu = toc;
end

function ym = media_janela(tt, y, t_ini)
% Media no tempo de y(t) em [t_ini, tt(end)] (os passos do ode15s nao sao
% uniformes, entao a media simples das amostras pesaria errado)
k = find(tt >= t_ini);
if numel(k) < 2
    ym = y(end);
    return
end
ym = trapz(tt(k), y(k)) / (tt(k(end)) - tt(k(1)));
end

function [d, dxi, modo] = lei_pi(v, xi, Vref, ctl, pc, modo)
% PI com saturacao e anti-windup.
%   modo = [lado, integra]: lado = +1 (d em Dmax), -1 (d em Dmin) ou 0
%   (linear); integra = 1 se o integrador esta ativo, 0 se congelado.
%   Sem o argumento modo, ele e decidido pelo estado atual. Passar modo
%   congela a logica de saturacao (usado no jacobiano, ver jacobiano).
err = v - Vref;
du = ctl.Kp * (err + xi / ctl.Ti);        % comando antes da saturacao
if nargin < 6
    lado = 0;
    if du > pc.Dmax
        lado = 1;
    elseif du < pc.Dmin
        lado = -1;
    end
    % Anti-windup: com d saturado, para de integrar se o erro empurraria
    % du ainda mais para fora da faixa (err > 0 aumenta du)
    integra = ~((lado == 1 && err > 0) || (lado == -1 && err < 0));
    modo = [lado, integra];
end
if modo(1) == 1
    d = pc.Dmax;
elseif modo(1) == -1
    d = pc.Dmin;
else
    d = du;
end
dxi = modo(2) * err;
end

function f = derivadas(t, x, I, Vref, m, modo)
% [dv_pv/dt; di_L/dt; dxi/dt; dT/dt] com a corrente do painel I dada.
v = x(1);  iL = x(2);  xi = x(3);  T = x(4);
if nargin < 6
    [d, dxi] = lei_pi(v, xi, Vref, m.ctl, m.pc);
else
    [d, dxi] = lei_pi(v, xi, Vref, m.ctl, m.pc, modo);
end
if m.termico
    % G do balanco termico = media das irradiancias dos submodulos; a
    % potencia eletrica v*I sai do modulo e nao vira calor
    dT = termico_dTdt(T, mean(m.cen.G(t)), m.cen.Tamb(t), m.cen.vw(t), v * I, m.pt);
else
    dT = 0;
end
f = [conversor_medio_rhs(v, iL, I, d, m.pc); dxi; dT];
end

function f = rhs(t, x, Vref, m)
% Lado direito da EDO reduzida: resolve o painel em v_pv e aplica derivadas.
I = painel_sombreado(x(1), m.cen.G(t), x(4), m.p);
f = derivadas(t, x, I, Vref, m);
end

function J = jacobiano(t, x, Vref, m)
% Jacobiano df/dx da EDO reduzida f(x) = derivadas(x, I(x)), pela regra
% da cadeia: df/dx = df/dx|_I + df/dI * dI/dx.
%
% 1) df/dx|_I e df/dI: diferencas finitas de derivadas() (suave em x e I).
%    A saturacao e o anti-windup do PI sao descontinuos: se o passo de
%    diferenca atravessasse Dmax/Dmin a coluna sairia com um salto enorme.
%    Por isso o modo do PI (lado saturado e integrador ativo/congelado) e
%    decidido UMA vez em x e congelado nas avaliacoes perturbadas: o
%    jacobiano e o do ramo ativo, que e o que o Newton do ode15s precisa.
% 2) dI/dv e dI/dT: derivada implicita das equacoes do painel R(z) = 0,
%    com o jacobiano ANALITICO Jz = dR/dz de residuo_painel:
%        Jz * dz/dv = -dR/dv = [0; ...; 0; 1]   (so a KVL tem v_pv)
%        Jz * dz/dT = -dR/dT                    (dR/dT por diferenca centrada)
%    e dI/dv, dI/dT sao a primeira componente (z(1) = I). Diferencas
%    finitas em v passando pelo Newton do painel seriam imprecisas perto
%    dos joelhos do bypass (exponencial ingreme).
N = m.p.Nsub;
G = m.cen.G(t);
[I, sol] = painel_sombreado(x(1), G, x(4), m.p);
z = sol.z;
[~, Jz] = residuo_painel(z, x(1), G, x(4), m.p);
dz_dv = Jz \ [zeros(N, 1); 1];
hT = 1e-4;
dR_dT = (residuo_painel(z, x(1), G, x(4) + hT, m.p) ...
       - residuo_painel(z, x(1), G, x(4) - hT, m.p)) / (2 * hT);
dz_dT = -(Jz \ dR_dT);

[~, ~, modo] = lei_pi(x(1), x(3), Vref, m.ctl, m.pc);
f0 = derivadas(t, x, I, Vref, m, modo);
J = zeros(4);
for j = 1:4
    h = 1e-6 * max(1, abs(x(j)));
    xp = x;
    xp(j) = xp(j) + h;
    J(:, j) = (derivadas(t, xp, I, Vref, m, modo) - f0) / h;
end
hI = 1e-6 * max(1, abs(I));
df_dI = (derivadas(t, x, I + hI, Vref, m, modo) - f0) / hI;

% Regra da cadeia: I depende de v_pv (curva I-V) e de T (celula aquece)
J(:, 1) = J(:, 1) + df_dI * dz_dv(1);
J(:, 4) = J(:, 4) + df_dI * dz_dT(1);
end
