function sys = linearizar_planta(op, p, pc)
%LINEARIZAR_PLANTA Modelo de pequenos sinais (A, B, C, D) do painel + buck-boost.
%   sys = linearizar_planta(op, p, pc)
%
%   op : ponto de operacao, com .vpv [V], .G (1 x Nsub) [W/m^2], .T [K]
%   p  : parametros_painel();  pc : parametros_conversor()
%
%   Estados x = [v_pv; i_L], entrada u = d (razao ciclica), saida y = v_pv.
%
%   O que e a linearizacao de pequenos sinais:
%   o modelo medio dx/dt = f(x, d) e nao linear (produto d*iL, curva I-V do
%   painel). Em torno de um equilibrio (x0, d0), onde f(x0, d0) = 0, escrevemos
%   x = x0 + x~ e d = d0 + d~ com x~ e d~ pequenos. Pela serie de Taylor de
%   1a ordem:
%       dx~/dt ~= A x~ + B d~,   A = df/dx (x0, d0),   B = df/dd (x0, d0)
%   e o resultado e um sistema LINEAR, que vale enquanto as perturbacoes
%   forem pequenas. E nele que se projeta o controlador (Tarefa 8).
%
%   A e B sao obtidas por diferencas centrais: f(x0 + h) - f(x0 - h) / (2h),
%   que tem erro O(h^2). Assim a mesma funcao serve com ou sem perdas, e para
%   qualquer padrao de sombra, sem derivar o painel a mao.
%
%   Saida: sys.A, sys.B, sys.C, sys.D, sys.x0, sys.d0, sys.ipv0, sys.rpv.

% 1) Equilibrio: corrente do painel em vpv e razao ciclica que mantem vpv
[ipv0, sol] = painel_sombreado(op.vpv, op.G, op.T, p);
eq = equilibrio_conversor(op.vpv, ipv0, pc);
assert(eq.viavel, ['linearizar_planta: ponto de operacao inviavel ' ...
    '(vpv = %.3g V, ipv = %.3g A): o conversor nao alcanca este ponto ' ...
    'com d em [Dmin, Dmax] ou nao ha corrente do painel.'], op.vpv, ipv0);
x0 = [op.vpv; eq.iL];
d0 = eq.d;
z0 = sol.z;   % solucao interna do painel, usada como chute (warm start)

% 2) Matriz A: derivada de f em relacao a cada estado (coluna j <-> estado j)
A = zeros(2);
for j = 1:2
    h = zeros(2, 1);
    h(j) = 1e-5 * max(1, abs(x0(j)));   % passo relativo ao tamanho do estado
    f_mais  = derivadas(x0 + h, d0, op, p, pc, z0);
    f_menos = derivadas(x0 - h, d0, op, p, pc, z0);
    A(:, j) = (f_mais - f_menos) / (2 * h(j));
end

% 3) Vetor B: derivada de f em relacao a d
hd = 1e-6;
B = (derivadas(x0, d0 + hd, op, p, pc, z0) ...
   - derivadas(x0, d0 - hd, op, p, pc, z0)) / (2 * hd);

% 4) Resistencia dinamica do painel: r_pv = -dV/dI = -1 / (dI/dV).
%    O sinal "-" deixa r_pv positiva, pois a corrente do painel cai quando a
%    tensao sobe. No MPP, dP/dV = d(V*I)/dV = I + V*dI/dV = 0, logo
%    dI/dV = -I/V e r_pv = Vmp/Imp: a resistencia dinamica iguala a estatica.
%    E o principio do metodo da condutancia incremental (InC).
hv = 1e-4;
i_mais  = painel_sombreado(op.vpv + hv, op.G, op.T, p, z0);
i_menos = painel_sombreado(op.vpv - hv, op.G, op.T, p, z0);
rpv = -2 * hv / (i_mais - i_menos);

sys = struct('A', A, 'B', B, 'C', [1 0], 'D', 0, 'x0', x0, 'd0', d0, ...
    'ipv0', ipv0, 'rpv', rpv);
end

function dx = derivadas(x, d, op, p, pc, z0)
% f(x, d) do modelo medio: a corrente do painel depende de v_pv = x(1)
% (o painel e algebrico, entao ele entra em A atraves de dI/dV).
ipv = painel_sombreado(x(1), op.G, op.T, p, z0);
dx = conversor_medio_rhs(x(1), x(2), ipv, d, pc);
end
