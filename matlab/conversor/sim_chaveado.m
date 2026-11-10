function r = sim_chaveado(t_fim, dfun, G, T, p, pc, x0)
%SIM_CHAVEADO Buck-boost chaveado alimentado pelo painel (Euler, 200 passos/periodo).
%   r = sim_chaveado(t_fim, dfun, G, T, p, pc, x0)
%
%   t_fim : duracao da simulacao [s]
%   dfun  : razao ciclica em funcao do tempo, d = dfun(t)
%   G, T  : irradiancia por submodulo [W/m^2] e temperatura [K] (fixas)
%   p, pc : parametros do painel e do conversor
%   x0    : estado MEDIO inicial [v_pv; i_L] (o mesmo usado no modelo medio)
%
%   Saida: r.t, r.v (v_pv) e r.iL; r.v(k) e r.iL(k) sao o estado no instante r.t(k).
%
%   Diferente do modelo medio, aqui as duas topologias se alternam de fato:
%     chave ligada:    L di/dt = v_pv - iL*(rL + Ron),        C dv/dt = i_pv - iL
%     chave desligada: L di/dt = -(Vbat + VF) - iL*(rL + RD), C dv/dt = i_pv
%   O diodo nao conduz corrente reversa: se o indutor descarrega ate zero com
%   a chave desligada, i_L fica em zero (conducao descontinua, DCM).
%
%   Passo fixo de Ts/200: a cada passo o painel e resolvido por Newton com
%   warm start (a solucao do passo anterior); leva cerca de 1-2 s para 6 ms.

passos_por_periodo = 200;
dt = pc.Ts / passos_por_periodo;
n = round(t_fim / dt);
r.t = (0:n - 1).' * dt;
r.v = zeros(n, 1);  r.iL = zeros(n, 1);

% Condicao inicial: x0 e a media do periodo, mas o chaveado comeca no instante
% em que a chave liga. Nesse instante i_L esta no VALE (vai subir durante d*Ts)
% e v_pv esta no PICO (o capacitor carregou com i_pv durante a chave desligada).
% Partir de i_L = media deslocaria a media do chaveado em meio ripple (~17 % em
% STC) e excitaria uma oscilacao LC que nao existe no modelo medio.
% Ripples pela aproximacao linear (rampas retas):
%   delta_i = v*d*Ts/L,   delta_v = (i_L - i_pv)*d*Ts/C
d0 = dfun(0);
ipv0 = painel_sombreado(x0(1), G, T, p);
delta_i = x0(1) * d0 * pc.Ts / pc.L;
delta_v = (x0(2) - ipv0) * d0 * pc.Ts / pc.C;
v = x0(1) + delta_v / 2;
iL = max(x0(2) - delta_i / 2, 0);
z = [];                                  % sem chute inicial no primeiro passo
d_per = d0;

for k = 1:n
    t = r.t(k);

    % Guarda o estado ANTES de avancar: r.v(k), r.iL(k) valem em r.t(k)
    r.v(k) = v;  r.iL(k) = iL;

    % Indice do passo dentro do periodo (inteiro: evita erro de mod em ponto flutuante)
    j = mod(k - 1, passos_por_periodo);

    % PWM real: a razao ciclica e amostrada no inicio de cada periodo e fica
    % fixa ate o proximo (uma mudanca de d no meio do periodo so vale no seguinte)
    if j == 0
        d_per = dfun(t);
    end

    % Fracao do passo j com a chave ligada. A chave liga em t = 0 do periodo e
    % desliga em d*Ts, ou seja, no passo d*200. Os passos antes disso ficam
    % ligados inteiros (f = 1), os depois desligados (f = 0) e o passo onde
    % ocorre a comutacao fica ligado so em parte (0 < f < 1). Sem isso a chave
    % ficaria ligada ceil(200*d) passos inteiros, e o d efetivo erraria em ate 1/200.
    f = min(max(d_per * passos_por_periodo - j, 0), 1);

    % Corrente do painel na tensao atual do capacitor (warm start em z)
    [ipv, s] = painel_sombreado(v, G, T, p, z);
    z = s.z;

    % Chave ligada: indutor carrega a partir do painel/capacitor
    di_on = (v - iL * (pc.rL + pc.Ron)) / pc.L;
    dv_on = (ipv - iL) / pc.C;
    % Chave desligada: indutor descarrega na bateria pelo diodo;
    % o capacitor so recebe a corrente do painel
    di_off = (-(pc.Vbat + pc.VF) - iL * (pc.rL + pc.RD)) / pc.L;
    dv_off = ipv / pc.C;

    % Derivada media no passo, ponderada pelo tempo em cada topologia
    di = f * di_on + (1 - f) * di_off;
    dv = f * dv_on + (1 - f) * dv_off;

    % Euler explicito; o diodo bloqueia corrente negativa (i_L >= 0)
    v = v + dv * dt;
    iL = max(iL + di * dt, 0);
end
end
