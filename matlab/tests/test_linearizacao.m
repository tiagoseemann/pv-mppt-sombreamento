% Testes da linearizacao (pequenos sinais) da planta painel + buck-boost.
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
% Sem perdas, a resposta em frequencia do modelo linearizado numericamente bate com G_vd(s) analitico.
pc = conversor_ideal(tc.TestData.pc);
sys = linearizar_planta(tc.TestData.op, tc.TestData.p, pc);
w = logspace(1, 5, 200);
verifyEqual(tc, resposta_freq(sys, w), gvd_analitico(sys, pc, w), 'RelTol', 1e-3);
end

function test_rpv_no_mpp(tc)
% No MPP, a resistencia dinamica do painel -dV/dI e igual a resistencia estatica Vmp/Imp.
p = tc.TestData.p;
c = curva_pv([1000 1000 1000], p.Tn, p, 3000);
op = struct('vpv', c.Vmp, 'G', [1000 1000 1000], 'T', p.Tn);
sys = linearizar_planta(op, p, tc.TestData.pc);
% RelTol 0,02 vem da grade de 3000 pontos de curva_pv (Vmp aproximado), nao da linearizacao
verifyEqual(tc, sys.rpv, c.Vmp / c.Imp, 'RelTol', 0.02);
end

function test_rpv_no_pico_sombreado(tc)
% Com sombra (2 picos), r_pv = V/I em cada pico: dP/dV = 0 vale tambem num maximo local (caminho do bypass, usado na Tarefa 8).
p = tc.TestData.p;
G = [1000 1000 400];
c = curva_pv(G, p.Tn, p, 3000);
verifyEqual(tc, height(c.picos), 2);
for k = 1:height(c.picos)
    op = struct('vpv', c.picos.V(k), 'G', G, 'T', p.Tn);
    sys = linearizar_planta(op, p, tc.TestData.pc);
    verifyEqual(tc, sys.rpv, c.picos.V(k) / c.picos.I(k), 'RelTol', 0.02);
end
end

function test_erro_acima_de_Voc(tc)
% Acima de Voc o painel nao entrega corrente: linearizar_planta deve parar com erro identificado.
p = tc.TestData.p;
op = struct('vpv', 30, 'G', [1000 1000 1000], 'T', p.Tn);
verifyError(tc, @() linearizar_planta(op, p, tc.TestData.pc), 'linearizar_planta:inviavel');
end

function test_degrau_pequeno_nao_linear_igual_linear(tc)
% Para um degrau pequeno de d, o modelo medio nao linear e o linearizado dao a mesma resposta de v_pv.
p = tc.TestData.p;  pc = tc.TestData.pc;  op = tc.TestData.op;
sys = linearizar_planta(op, p, pc);
dd = 0.005;  t_fim = 10e-3;
rm = sim_medio_aberta(t_fim, @(t) sys.d0 + dd * (t > 0), op.G, op.T, p, pc, sys.x0);
dv_nl = rm.v - sys.x0(1);
dv_l = zeros(size(rm.t));
for k = 1:numel(rm.t)
    % Resposta ao degrau de x' = A x + B u: x(t) = A^-1 (e^(At) - I) B dd
    xk = sys.A \ ((expm(sys.A * rm.t(k)) - eye(2)) * sys.B * dd);
    dv_l(k) = sys.C * xk;
end
verifyLessThan(tc, sqrt(mean((dv_nl - dv_l).^2)) / max(abs(dv_l)), 0.05);
end
