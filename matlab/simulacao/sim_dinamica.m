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
%   PRE-CONDICAO: a simulacao comeca com G > 0, dentro de uma janela de dia.
%   Em G = 0 o painel nao fornece corrente, o conversor nao tem equilibrio
%   e a partida e recusada de proposito (erro sim_dinamica:inicioInviavel).
%   Depois da partida G pode cair (nuvem, anoitecer): o diodo do conversor
%   bloqueia corrente reversa (ver derivadas) e o oraculo devolve Pg = 0.
%
%   ESTADO: x = [v_pv; i_L; xi; T]
%       v_pv : tensao do capacitor de entrada = tensao do painel [V]
%       i_L  : corrente media no indutor [A]
%       xi   : integral do erro do PI, xi' = v_pv - V_ref [V s]
%       T    : temperatura das celulas [K]
%   A corrente do painel I nao e estado: o painel nao tem dinamica propria
%   nesta escala, I e a solucao das equacoes algebricas do modulo (KCL em
%   cada submodulo com o bypass + KVL na serie, residuo_painel) para a
%   tensao v_pv atual. O ode15s integra a EDO reduzida x' = f(x, I(x)).
%   A DAE com matriz de massa singular falhava nos degraus grandes do PSO
%   (jacobiano velho no ode15s); ver decisao D15 no plano.
%   O ode15s (implicito) e necessario: a ressonancia LC, o PI e a
%   inclinacao dI/dV do painel sao rapidos e o termico e lento (rigidez).
%
%   SEM WARM START NO LADO DIREITO (de proposito): rhs e jacobiano resolvem
%   o painel partindo do chute padrao de painel_sombreado a cada chamada.
%   O ode15s avalia o lado direito fora de ordem e em passos que depois
%   rejeita; guardar a ultima solucao entre chamadas poderia dar resultados
%   dependentes dessa ordem. Custa CPU (mais iteracoes de Newton), mas e
%   seguro. O warm start do laco principal so vale no pos-processamento
%   (corrente nos pontos ja aceitos, em ordem).
%
%   MPPT AMOSTRADO: o algoritmo roda a cada ctl.Ta. Entre duas chamadas a
%   referencia V_ref fica constante (segurador de ordem zero): integramos
%   em [t0, t0 + Ta] com V_ref fixo, medimos, chamamos o MPPT e comecamos o
%   intervalo seguinte com o novo V_ref.
%   A medida entregue ao MPPT e a MEDIA de v e I nos ultimos 20 % de cada
%   Ta: espera o transitorio do PI depois do degrau de V_ref (criterio de
%   Femia, Ta = 1,5 ts no pior caso) e filtra o resto de oscilacao.
%
%   PI COM ANTI-WINDUP: lei_pi (pasta controle), d = Kp*(e + xi/Ti),
%   e = v_pv - V_ref, saturado em [Dmin, Dmax], integrador congelado quando
%   satura. O lado direito e DESCONTINUO nas trocas de saturacao/anti-windup;
%   nao usamos funcoes de evento: o ode15s atravessa a descontinuidade
%   rejeitando passos e reduzindo o passo ali. Isso pode gerar pequenas
%   diferencas que dependem do passo (e da tolerancia).
%   O atraso do PWM (pc.atraso) nao entra aqui: ~75 us, muito menor que o
%   tempo de acomodacao (~20 ms); ele foi considerado nas margens do PI.
%
%   ENERGIA E ORACULO: E = integral de v_pv*I (energia tirada do painel),
%   pela regra do trapezio nos pontos do integrador; MaxStep = Ta/20 tambem
%   limita o erro dessa integral. A referencia Eg soma, a cada Ta, a media
%   da potencia maxima GLOBAL (oraculo_pmax) no inicio e no fim do
%   intervalo (G e T de cada ponta, G lida logo dentro do intervalo), vezes
%   Ta (trapezio): um degrau de G dentro do intervalo nao fica enviesado
%   para um lado, e um degrau na fronteira conta para o periodo certo. eta = E/Eg e a
%   eficiencia de rastreamento: um MPPT preso num pico local da eta < 1.
%
%   Saida (um valor por periodo Ta, k = 1..nK):
%   r.t (fim do periodo), r.V, r.I (medias da janela), r.P = r.V*r.I
%   (produto das medias, nao a media de v*I: para comparar energia use r.E),
%   r.T, r.Vref (referencia aplicada no periodo), r.Pg (oraculo, media das
%   duas pontas), r.d (razao ciclica no fim), r.ccm (conducao continua no
%   fim do periodo, verifica_ccm).
%   Totais: r.E, r.Eg [J], r.eta (NaN se Eg = 0, ex. noite), r.T0,
%   r.fracDCM (fracao dos periodos em DCM: o modelo medio e o de CCM, que em
%   DCM subestima as perdas de conducao e nao tem a dinamica certa; ali os
%   resultados sao otimistas/aproximados), r.nReinicios (reinicios do PSO;
%   NaN se o algoritmo nao tem), r.iLmin (menor i_L em todos os pontos),
%   r.nAvisosNewton (periodos com aviso de Newton do painel sem
%   convergencia), r.tempo_cpu [s].

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
         '(I <= 0 ou d fora de [%.2f, %.2f]): comece com G > 0 ou escolha outro op.V0'], ...
        v0, I0, pc.Dmin, pc.Dmax);
end
xi0 = ctl.Ti * (eq.d / ctl.Kp - (v0 - cfg.Vref0));
x = [v0; eq.iL; xi0; T0];

% MaxStep = Ta/20: garante varios pontos na janela de medida (20 % de Ta)
% e limita o erro do trapezio na integral da energia
% Sem a opcao NonNegative em i_L: testada, ela fez o ode15s falhar no
% anoitecer (G -> 0). O bloqueio do diodo em derivadas basta; i_L pode
% passar de 0 so pelo erro do integrador (ordem de AbsTol = 1e-7 A).
base = odeset('RelTol', 1e-5, 'AbsTol', 1e-7, 'MaxStep', Ta / 20);

Vref = cfg.Vref0;
e = [];                                % estado interno do MPPT (vazio = primeira chamada)
r.t = zeros(nK, 1);  r.V = r.t;  r.I = r.t;  r.P = r.t;  r.T = r.t;
r.Vref = r.t;  r.Pg = r.t;  r.d = r.t;  r.ccm = false(nK, 1);
E = 0;  Eg = 0;
iLmin = x(2);
nAvisos = 0;
cache = struct('G', [], 'T', NaN, 'Pg', NaN);   % cache do oraculo

for k = 1:nK
    t0 = (k - 1) * Ta;
    t1 = t0 + Ta;
    % Oraculo na ponta inicial (G e T no inicio do intervalo). G e lida um
    % instante DENTRO do intervalo (dt = 1e-9 Ta): um degrau de G exatamente
    % na fronteira entre dois periodos conta inteiro para o periodo em que
    % ele vale, e nao pela metade
    dt = 1e-9 * Ta;
    [Pg0, cache] = oraculo_com_cache(cen.G(t0 + dt), x(4), p, cache);

    % Aviso de Newton sem convergencia: zera o ultimo aviso e confere no
    % fim do periodo (conta periodos com aviso, nao avisos individuais)
    lastwarn('', '');

    % V_ref fica constante dentro do intervalo (segurador de ordem zero)
    f = @(t, x) rhs(t, x, Vref, m);
    opts = odeset(base, 'Jacobian', @(t, x) jacobiano(t, x, Vref, m));
    [tt, xx] = ode15s(f, [t0, t1], x, opts);
    if tt(end) < t1 - 1e-9 * Ta
        error('sim_dinamica:ode15s', 'ode15s parou em t = %.6f s (periodo %d)', tt(end), k);
    end
    iLmin = min(iLmin, min(xx(:, 2)));
    x = xx(end, :).';
    % O diodo nao deixa i_L ficar negativa: corta o erro numerico residual
    x(2) = max(x(2), 0);

    % Corrente do painel em cada ponto aceito pelo integrador (pos-
    % processamento: aqui o warm start e seguro, os pontos estao em ordem)
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

    % Oraculo na ponta final e trapezio: Eg += (Pg0 + Pg1)/2 * Ta
    [Pg1, cache] = oraculo_com_cache(cen.G(t1 - dt), x(4), p, cache);
    Pg = (Pg0 + Pg1) / 2;
    Eg = Eg + Pg * Ta;

    [~, id] = lastwarn;
    if strcmp(id, 'painel_sombreado:naoConvergiu')
        nAvisos = nAvisos + 1;
    end

    % Conducao continua no fim do periodo (estado medio)
    dk = lei_pi(x(1), x(3), Vref, ctl, pc);
    r.ccm(k) = verifica_ccm(x(1), dk, x(2), pc);

    r.t(k) = t1;  r.V(k) = Vm;  r.I(k) = Im;  r.P(k) = Vm * Im;
    r.T(k) = x(4);  r.Vref(k) = Vref;  r.Pg(k) = Pg;  r.d(k) = dk;

    % MPPT: nova referencia para o proximo periodo
    [Vref, e] = alg(Vm, Im, e, cfg);
end

r.E = E;  r.Eg = Eg;
if Eg > 0
    r.eta = E / Eg;
else
    r.eta = NaN;     % sem potencia disponivel (noite): eficiencia indefinida
end
r.T0 = T0;
r.fracDCM = sum(~r.ccm) / nK;
if isstruct(e) && isfield(e, 'nReinicios')
    r.nReinicios = e.nReinicios;
else
    r.nReinicios = NaN;
end
r.iLmin = iLmin;
r.nAvisosNewton = nAvisos;
r.tempo_cpu = toc;
end

function [Pg, cache] = oraculo_com_cache(G, T, p, cache)
% oraculo_pmax so e recalculado se G ou T mudaram (0,01 K muda Pmp em
% ~4e-5, desprezivel). Com G constante, a ponta final de um intervalo e a
% inicial do seguinte caem no cache.
if ~isequal(G, cache.G) || abs(T - cache.T) > 0.01
    cache.Pg = oraculo_pmax(G, T, p);
    cache.G = G;
    cache.T = T;
end
Pg = cache.Pg;
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

function f = derivadas(t, x, I, Vref, m, modo, bloqueado)
% [dv_pv/dt; di_L/dt; dxi/dt; dT/dt] com a corrente do painel I dada.
% modo (PI) e bloqueado (diodo) opcionais: quando passados, ficam
% congelados (jacobiano por diferencas finitas, ver jacobiano).
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
dx = conversor_medio_rhs(v, iL, I, d, m.pc);
% Diodo bloqueia corrente reversa: o indutor so descarrega na bateria pelo
% diodo, entao a corrente media nao pode ficar negativa (a bateria nao
% empurra corrente de volta). Com i_L ja em 0 e a derivada apontando para
% baixo (pouca irradiancia: d*v_pv nao vence Vbat), i_L fica parada em 0.
if nargin < 7
    bloqueado = iL <= 0 && dx(2) < 0;
end
if bloqueado
    dx(2) = 0;
end
f = [dx; dxi; dT];
end

function f = rhs(t, x, Vref, m)
% Lado direito da EDO reduzida: resolve o painel em v_pv (sem warm start,
% ver cabecalho) e aplica derivadas.
I = painel_sombreado(x(1), m.cen.G(t), x(4), m.p);
f = derivadas(t, x, I, Vref, m);
end

function J = jacobiano(t, x, Vref, m)
% Jacobiano df/dx da EDO reduzida f(x) = derivadas(x, I(x)), pela regra
% da cadeia: df/dx = df/dx|_I + df/dI * dI/dx.
%
% 1) df/dx|_I e df/dI: diferencas finitas de derivadas() (suave em x e I).
%    A saturacao e o anti-windup do PI e o bloqueio do diodo sao
%    descontinuos: se o passo de diferenca atravessasse um desses limites a
%    coluna sairia com um salto enorme. Por isso o modo do PI e o estado do
%    diodo sao decididos UMA vez em x e congelados nas avaliacoes
%    perturbadas: o jacobiano e o do ramo ativo, que e o que o Newton do
%    ode15s precisa.
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
d = lei_pi(x(1), x(3), Vref, m.ctl, m.pc, modo);
di = conversor_medio_rhs(x(1), x(2), I, d, m.pc);
bloqueado = x(2) <= 0 && di(2) < 0;
f0 = derivadas(t, x, I, Vref, m, modo, bloqueado);
J = zeros(4);
for j = 1:4
    h = 1e-6 * max(1, abs(x(j)));
    xp = x;
    xp(j) = xp(j) + h;
    J(:, j) = (derivadas(t, xp, I, Vref, m, modo, bloqueado) - f0) / h;
end
hI = 1e-6 * max(1, abs(I));
df_dI = (derivadas(t, x, I + hI, Vref, m, modo, bloqueado) - f0) / hI;

% Regra da cadeia: I depende de v_pv (curva I-V) e de T (celula aquece)
J(:, 1) = J(:, 1) + df_dI * dz_dv(1);
J(:, 4) = J(:, 4) + df_dI * dz_dT(1);
end
