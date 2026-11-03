function r = sim_medio_aberta(t_fim, dfun, G, T, p, pc, x0)
%SIM_MEDIO_ABERTA Modelo medio + painel como DAE (ode15s, matriz de massa).
%   r = sim_medio_aberta(t_fim, dfun, G, T, p, pc, x0)
%
%   Malha aberta: a razao ciclica e imposta por d = dfun(t).
%   G pode ser um vetor fixo (1 x Nsub) ou uma funcao de t.
%   x0 = [v_pv; i_L]; o estado algebrico do painel e calculado aqui.
%
%   Estado completo: x = [v_pv; i_L; I; Vd_1..Vd_N]
%       dv_pv/dt = (I - d*iL)/C                     (diferencial)
%       di_L/dt  = modelo medio com perdas           (diferencial)
%       0        = residuo_painel(z, v_pv)           (algebrica, N+1 linhas)
%   A matriz de massa M = diag(1, 1, 0, ..., 0) diz ao ode15s quais linhas sao
%   EDOs e quais sao restricoes algebricas.
%
%   O jacobiano analitico e obrigatorio: com o de diferencas finitas, a
%   exponencial do diodo de bypass faz o ode15s falhar.
%
%   Saida: r.t, r.v, r.iL, r.I (corrente do painel).

N = p.Nsub;
if ~isa(G, 'function_handle')
    Gfixo = G;
    G = @(t) Gfixo;
end

% Condicao inicial consistente: resolve o painel em v_pv(0)
[~, s0] = painel_sombreado(x0(1), G(0), T, p);
x0 = [x0(:); s0.z];

M = blkdiag(eye(2), zeros(N + 1));
f = @(t, x) rhs_dae(t, x, dfun, G, T, p, pc);
jac = @(t, x) jacobiano_dae(t, x, dfun, G, T, p, pc);
% MaxStep = Ts: o degrau de d nao pode ser "pulado" pelo integrador
opts = odeset('Mass', M, 'MassSingular', 'yes', 'RelTol', 1e-6, 'AbsTol', 1e-8, ...
    'MaxStep', pc.Ts, 'Jacobian', jac);
[r.t, x] = ode15s(f, [0 t_fim], x0, opts);
r.v = x(:, 1);  r.iL = x(:, 2);  r.I = x(:, 3);
end

function dx = rhs_dae(t, x, dfun, G, T, p, pc)
% Lado direito F(t, x) da DAE M*dx/dt = F(t, x).
vpv = x(1);  iL = x(2);  ipv = x(3);  z = x(3:end);
dx = [conversor_medio_rhs(vpv, iL, ipv, dfun(t), pc)
      residuo_painel(z, vpv, G(t), T, p)];
end

function Jf = jacobiano_dae(t, x, dfun, G, T, p, pc)
% Jacobiano dF/dx, conferido linha a linha com conversor_medio_rhs:
%   dv/dt = (I - d*iL)/C
%   di/dt = (d*v - (1-d)*(Vbat+VF) - iL*(rL + d*Ron + (1-d)*RD))/L
N = p.Nsub;
d = dfun(t);
[~, Jz] = residuo_painel(x(3:end), x(1), G(t), T, p);
Jf = zeros(N + 3);
% Linha 1: derivadas de dv/dt em relacao a (v, iL, I)
Jf(1, 2) = -d / pc.C;
Jf(1, 3) = 1 / pc.C;
% Linha 2: derivadas de di/dt em relacao a (v, iL)
Jf(2, 1) = d / pc.L;
Jf(2, 2) = -(pc.rL + d * pc.Ron + (1 - d) * pc.RD) / pc.L;
% Linhas do painel: so a KVL (ultima linha, sum(Vj) - v_pv) depende de v_pv
Jf(3:end, 1) = [zeros(N, 1); -1];
% Bloco do painel em relacao a z = [I; Vd]: jacobiano analitico do residuo
Jf(3:end, 3:end) = Jz;
end
