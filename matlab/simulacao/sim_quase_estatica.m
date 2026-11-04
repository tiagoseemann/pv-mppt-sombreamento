function r = sim_quase_estatica(cen, alg, cfg, ctl, p, pc, pt, op)
%SIM_QUASE_ESTATICA Simulacao rapida (horas/dias): conversor + PI assentados a cada Ta.
%   r = sim_quase_estatica(cen, alg, cfg, ctl, p, pc, pt, op)
%   (mesma interface de sim_dinamica)
%
%   cen : cenario: cen.G(t) (1 x Nsub), cen.Tamb(t), cen.vw(t), cen.t_fim
%   alg : algoritmo de MPPT, [Vref, e] = alg(V, I, e, cfg); cfg = config_mppt(p)
%   ctl : PI de tensao (projeto_pi); aqui so o periodo do MPPT ctl.Ta e usado
%   p, pc, pt : painel, conversor e parametros termicos
%   op.termico    : true -> temperatura evolui pelo balanco de energia;
%                   false -> fica constante em op.T
%   op.T          : temperatura fixa quando op.termico = false [K] (padrao 298,15)
%   op.perdas     : true (padrao) -> potencia na bateria com as perdas do
%                   conversor; false -> conversor ideal (Pout = P do painel)
%   op.dt_oraculo : intervalo entre avaliacoes do oraculo [s] (padrao ctl.Ta)
%   op.t_ini      : instante inicial da simulacao [s] (padrao 0); simula
%                   de t_ini a cen.t_fim (ex.: so a janela de dia)
%   op.V0         : aceito por compatibilidade com sim_dinamica, mas SEM
%                   EFEITO: aqui o PI ja chega em V_ref no 1o periodo.
%
%   O QUE E "QUASE-ESTATICO": a dinamica eletrica (ressonancia LC, ~240 Hz)
%   e a malha do PI (t_s ~ 20 ms) sao bem mais rapidas que o periodo do
%   MPPT: Ta = 1,5 t_s no pior caso (criterio de Femia, decisao D13). Entao,
%   em cada Ta, tratamos o sistema como em REGIME PERMANENTE: a tensao do
%   painel ja e igual a V_ref e a potencia e P = V_ref * I(V_ref) durante
%   o periodo inteiro. Nao ha EDO eletrica para integrar: so resolvemos o
%   painel (painel_sombreado) nas duas pontas de cada periodo. O erro desta
%   hipotese e a energia do transitorio depois de cada degrau de V_ref
%   (pequeno para P&O/InC, maior para os degraus grandes do PSO); o teste
%   test_quase_estatica mede essa diferenca contra sim_dinamica.
%   VIES DO PSO: com o PSO buscando o tempo todo (4 s com reinicio), o
%   quase-estatico da ~-1,1 % de energia. Causa: depois de um degrau grande
%   de V_ref, o transitorio do PI passa por tensoes ENTRE as particulas
%   (perto do pico), com mais potencia que nas pontas; o quase-estatico so
%   conta a potencia em V_ref. O erro e CONSERVADOR contra o PSO e so pesa
%   enquanto ele busca: numa janela tipica de 20 s (busca de ~1-2 s e depois
%   segura o gbest) a diferenca cai para ~-0,3 %; em P&O/InC fica < 0,4 %.
%
%   SEPARACAO DE ESCALAS DE TEMPO: o termico tem constantes de tempo de
%   minutos (a menor ~2,3 min) e Ta e de ~30 ms (milhares de vezes menor).
%   Por isso integramos a temperatura por Euler explicito com passo Ta,
%       T(k+1) = T(k) + Ta * dT/dt(T(k), G, Tamb, vw, P),
%   que e estavel (precisa de Ta < 2*tau) e preciso nessa escala.
%   Acoplamento igual ao de sim_dinamica: G do balanco = media dos
%   submodulos; a potencia eletrica P do painel sai do modulo e nao vira calor.
%
%   ENERGIA E ORACULO (mesma conta de sim_dinamica, para comparar 1 a 1):
%   - E: regra do trapezio com a potencia nas duas pontas do periodo
%     (G e T de cada ponta, G lida logo DENTRO do intervalo, 1e-9 Ta), vezes
%     Ta. Um degrau de G dentro do periodo conta pela metade nos dois lados,
%     como na integral da dinamica.
%   - Eg: com op.dt_oraculo = Ta, trapezio do oraculo nas duas pontas,
%     exatamente como sim_dinamica. Com op.dt_oraculo > Ta (simulacoes
%     longas: o oraculo e a parte cara), o oraculo e avaliado no inicio de
%     cada bloco de dt_oraculo e SEGURADO no bloco (ordem zero). APROXIMACAO:
%     em rampas de G o oraculo fica atrasado em ate dt_oraculo; escolha
%     dt_oraculo bem menor que a escala das variacoes de G.
%     RECOMENDADO para simulacoes longas (EN 50530, dia): dt_oraculo = 1 s.
%     Custo medido (G variando a cada instante, por hora simulada):
%     dt_oraculo = 1 s -> ~61-67 s de CPU; dt_oraculo = Ta -> ~2500 s;
%     dt_oraculo = 60 s -> ~20 s, mas atrasa nas rampas: com ~0,5 W/m^2/s
%     o oraculo segurado ja da eta ~ 1,02 (as rampas da EN 50530 sao mais
%     ingremes).
%   - eta = E/Eg (NaN se Eg = 0, ex. noite).
%   - Medida do MPPT: V_ref e a corrente na ponta FINAL do periodo (na
%     dinamica e a media dos ultimos 20 % do periodo).
%
%   PERDAS DO CONVERSOR: em regime o modelo medio tem solucao fechada
%   (equilibrio_conversor: razao ciclica, i_L, perdas de conducao e de
%   chaveamento para o par (V, I) imposto). Como o conversor e considerado
%   em regime, basta essa formula: nao precisamos integrar v e i_L.
%   PONTO INVIAVEL: o painel fornece corrente (I > 0) mas a razao ciclica
%   necessaria fica fora de [Dmin, Dmax] (so acontece com V_pv muito baixa,
%   < ~1 V): o PI satura e o conversor nao consegue manter V_ref, entao nao
%   ha transferencia para a bateria (Pout = 0). E continua contando P do
%   painel (aproximacao; potencia desprezivel nessas tensoes).
%   Sem corrente (I <= 0, ex. noite) nao e inviavel: so nao ha transferencia.
%
%   Saida (um valor por periodo Ta, k = 1..nK):
%   r.t (fim do periodo), r.V = r.Vref (tensao aplicada = V_ref), r.I e
%   r.P (na ponta final), r.Pg (oraculo do periodo), r.T (fim do periodo).
%   Totais: r.E, r.Eg, r.Eout [J] (energia na bateria), r.eta, r.eta_conv =
%   Eout/E (NaN se E = 0), r.fracDCM (fracao dos periodos com transferencia
%   em DCM, na ponta final), r.fracInviavel, r.nReinicios (PSO; NaN se o
%   algoritmo nao tem), r.T0, r.tempo_cpu [s].

if ~isfield(op, 'T'), op.T = 298.15; end
if ~isfield(op, 'perdas'), op.perdas = true; end
if ~isfield(op, 'dt_oraculo'), op.dt_oraculo = ctl.Ta; end
if ~isfield(op, 't_ini'), op.t_ini = 0; end
tic;
Ta = ctl.Ta;
nK = floor((cen.t_fim - op.t_ini) / Ta);
% Numero de periodos Ta entre duas avaliacoes do oraculo
passoOr = max(1, round(op.dt_oraculo / Ta));
dt = 1e-9 * Ta;          % "logo dentro" do intervalo (ver ENERGIA E ORACULO)

% --- Temperatura inicial ---
if op.termico
    % Equilibrio termico com o conversor desligado (Pel = 0), como em sim_dinamica
    G0 = cen.G(op.t_ini);
    T = fzero(@(T) termico_dTdt(T, mean(G0), cen.Tamb(op.t_ini), cen.vw(op.t_ini), 0, pt), [250 400]);
else
    T = op.T;
end
T0 = T;

Vref = cfg.Vref0;
e = [];                  % estado interno do MPPT (vazio = primeira chamada)
z = [];                  % ultima solucao do painel (warm start do Newton)
cache = struct('G', [], 'T', NaN, 'Pg', NaN);   % cache do oraculo
PgSegurado = 0;
E = 0;  Eg = 0;  Eout = 0;  nDCM = 0;  nInviavel = 0;
r.t = zeros(nK, 1);  r.V = r.t;  r.Vref = r.t;  r.I = r.t;  r.P = r.t;
r.Pg = r.t;  r.T = r.t;

for k = 1:nK
    t0 = op.t_ini + (k - 1) * Ta;
    t1 = t0 + Ta;
    Ga = cen.G(t0 + dt);     % irradiancia na ponta inicial
    Gb = cen.G(t1 - dt);     % irradiancia na ponta final

    % --- Ponta inicial: painel em V_ref (PI assentado) ---
    [Ia, sol] = painel_sombreado(Vref, Ga, T, p, z);
    z = sol.z;
    % O diodo do conversor nao deixa corrente voltar para o painel
    Ia = max(Ia, 0);
    Pa = Vref * Ia;

    % --- Oraculo ---
    if passoOr == 1
        [Pga, cache] = oraculo_com_cache(Ga, T, p, cache);
    elseif mod(k - 1, passoOr) == 0
        % Inicio de um bloco de dt_oraculo: avalia e segura ate o proximo
        PgSegurado = oraculo_pmax(Ga, T, p);
    end

    % --- Termico: um passo de Euler de tamanho Ta ---
    if op.termico
        Tb = T + Ta * termico_dTdt(T, mean(Ga), cen.Tamb(t0), cen.vw(t0), Pa, pt);
    else
        Tb = T;
    end

    % --- Ponta final ---
    [Ib, sol] = painel_sombreado(Vref, Gb, Tb, p, z);
    z = sol.z;
    Ib = max(Ib, 0);
    Pb = Vref * Ib;

    % Energia do painel no periodo (trapezio, como a integral da dinamica)
    E = E + (Pa + Pb) / 2 * Ta;

    % Energia de referencia (oraculo)
    if passoOr == 1
        [Pgb, cache] = oraculo_com_cache(Gb, Tb, p, cache);
        Pg = (Pga + Pgb) / 2;
    else
        Pg = PgSegurado;
    end
    Eg = Eg + Pg * Ta;

    % Energia entregue a bateria (trapezio); DCM/inviavel na ponta final,
    % como a conducao continua em sim_dinamica
    Pouta = potencia_saida(Vref, Ia, pc, op.perdas);
    [Poutb, situacao] = potencia_saida(Vref, Ib, pc, op.perdas);
    Eout = Eout + (Pouta + Poutb) / 2 * Ta;
    if strcmp(situacao, 'dcm')
        nDCM = nDCM + 1;
    elseif strcmp(situacao, 'inviavel')
        nInviavel = nInviavel + 1;
    end

    T = Tb;
    r.t(k) = t1;  r.V(k) = Vref;  r.Vref(k) = Vref;  r.I(k) = Ib;
    r.P(k) = Pb;  r.Pg(k) = Pg;  r.T(k) = T;

    % MPPT: mede (V_ref, I) no fim do periodo e escolhe a proxima referencia
    [Vref, e] = alg(Vref, Ib, e, cfg);
end

r.E = E;  r.Eg = Eg;  r.Eout = Eout;
if Eg > 0
    r.eta = E / Eg;
else
    r.eta = NaN;         % sem potencia disponivel (noite): eficiencia indefinida
end
if E > 0
    r.eta_conv = Eout / E;
else
    r.eta_conv = NaN;    % nada passou pelo conversor
end
r.fracDCM = nDCM / nK;
r.fracInviavel = nInviavel / nK;
if isstruct(e) && isfield(e, 'nReinicios')
    r.nReinicios = e.nReinicios;
else
    r.nReinicios = NaN;
end
r.T0 = T0;
r.tempo_cpu = toc;
end

function [Pout, situacao] = potencia_saida(V, I, pc, perdas)
% Potencia entregue a bateria com o conversor em regime no ponto (V, I).
% situacao: 'semCorrente' (I <= 0), 'inviavel' (d fora de [Dmin, Dmax]),
% 'dcm' (conducao descontinua) ou 'ccm'.
if I <= 0
    Pout = 0;
    situacao = 'semCorrente';
    return
end
eq = equilibrio_conversor(V, I, pc);
if ~eq.viavel
    % O PI satura e nao segura V_ref: nada chega a bateria
    Pout = 0;
    situacao = 'inviavel';
    return
end
if perdas
    Pout = eq.Pout;
else
    Pout = V * I;        % conversor ideal: tudo o que sai do painel chega a bateria
end
% d e i_L vem do equilibrio com perdas (diferenca desprezivel para o teste de CCM).
% Em DCM as perdas de CCM sao otimistas (ver equilibrio_conversor).
if verifica_ccm(V, eq.d, eq.iL, pc)
    situacao = 'ccm';
else
    situacao = 'dcm';
end
end

function [Pg, cache] = oraculo_com_cache(G, T, p, cache)
% Mesmo cache de sim_dinamica: oraculo_pmax so e recalculado se G ou T
% mudaram (0,01 K muda Pmp em ~4e-5, desprezivel).
if ~isequal(G, cache.G) || abs(T - cache.T) > 0.01
    cache.Pg = oraculo_pmax(G, T, p);
    cache.G = G;
    cache.T = T;
end
Pg = cache.Pg;
end
