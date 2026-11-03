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
%   Saida: r.t, r.v (v_pv), r.iL e r.q (estado da chave: true = ligada).
%
%   Diferente do modelo medio, aqui as duas topologias se alternam de fato:
%     chave ligada:    L di/dt = v_pv - iL*(rL + Ron),        C dv/dt = i_pv - iL
%     chave desligada: L di/dt = -(Vbat + VF) - iL*(rL + RD), C dv/dt = i_pv
%   O diodo nao conduz corrente reversa: se o indutor descarrega ate zero com
%   a chave desligada, i_L fica em zero (conducao descontinua, DCM).
%
%   Passo fixo de Ts/200: a cada passo o painel e resolvido por Newton com
%   warm start (a solucao do passo anterior), por isso a simulacao e lenta.

dt = pc.Ts / 200;
n = round(t_fim / dt);
r.t = (0:n - 1).' * dt;
r.v = zeros(n, 1);  r.iL = zeros(n, 1);  r.q = false(n, 1);

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
for k = 1:n
    t = r.t(k);

    % PWM: chave ligada na fracao d do inicio de cada periodo
    q = mod(t, pc.Ts) < dfun(t) * pc.Ts;

    % Corrente do painel na tensao atual do capacitor (warm start em z)
    [ipv, s] = painel_sombreado(v, G, T, p, z);
    z = s.z;

    if q
        % Chave ligada: indutor carrega a partir do painel/capacitor
        di = (v - iL * (pc.rL + pc.Ron)) / pc.L;
        dv = (ipv - iL) / pc.C;
    else
        % Chave desligada: indutor descarrega na bateria pelo diodo;
        % o capacitor so recebe a corrente do painel
        di = (-(pc.Vbat + pc.VF) - iL * (pc.rL + pc.RD)) / pc.L;
        dv = ipv / pc.C;
    end

    % Euler explicito; o diodo bloqueia corrente negativa (i_L >= 0)
    v = v + dv * dt;
    iL = max(iL + di * dt, 0);

    r.v(k) = v;  r.iL(k) = iL;  r.q(k) = q;
end
end
