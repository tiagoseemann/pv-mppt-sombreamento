% Testes do conversor buck-boost: modelo medio com perdas, equilibrio e CCM/DCM.
function tests = test_conversor
tests = functiontests(localfunctions);
end

function setupOnce(tc)
% Conversor projetado para o painel generico e bateria de 12 V
tc.TestData.pc = parametros_conversor(parametros_painel('generico'), 12);
end

function test_ganho_ideal(tc)
% Sem perdas, o ganho do buck-boost e d/(1-d) = Vbat/vpv e a eficiencia e 1.
pc = conversor_ideal(tc.TestData.pc);
eq = equilibrio_conversor(18, 7.7, pc);
verifyEqual(tc, eq.d / (1 - eq.d), 12 / 18, 'RelTol', 1e-9);
verifyEqual(tc, eq.eta, 1, 'AbsTol', 1e-9);
end

function test_balanco_de_energia(tc)
% Potencia de entrada = potencia na bateria + perdas de conducao, e Pout = Pin - Pcond - Psw; eta fica entre 0,85 e 1.
pc = tc.TestData.pc;
v = 18;  i = 7.7;
eq = equilibrio_conversor(v, i, pc);
verifyEqual(tc, v * i, (1 - eq.d) * eq.iL * pc.Vbat + eq.Pcond, 'RelTol', 1e-9);
verifyEqual(tc, eq.Pout, v * i - eq.Pcond - eq.Psw, 'RelTol', 1e-9);
verifyLessThan(tc, eq.eta, 1);
verifyGreaterThan(tc, eq.eta, 0.85);
end

function test_rhs_nulo_no_equilibrio(tc)
% No equilibrio calculado, as derivadas do modelo medio sao nulas.
pc = tc.TestData.pc;
eq = equilibrio_conversor(18, 7.7, pc);
dx = conversor_medio_rhs(18, eq.iL, 7.7, eq.d, pc);
verifyEqual(tc, dx, [0; 0], 'AbsTol', 1e-6);
end

function test_ccm_e_dcm(tc)
% Em plena irradiancia o conversor esta em CCM; com ~30 W/m2 a corrente e baixa e cai em DCM.
pc = tc.TestData.pc;
eqA = equilibrio_conversor(18, 7.7, pc);
verifyTrue(tc, verifica_ccm(18, eqA.d, eqA.iL, pc));
eqB = equilibrio_conversor(17, 0.25, pc);          % G ~ 30 W/m^2
verifyFalse(tc, verifica_ccm(17, eqB.d, eqB.iL, pc));
end

function test_d_fechado_satisfaz_equilibrio(tc)
% O d da formula fechada satisfaz a equacao de equilibrio original (sem multiplicar por d).
pc = tc.TestData.pc;
pontos = [18 7.7; 18 1e-3; 5 8; 25 2];
for k = 1:size(pontos, 1)
    v = pontos(k, 1);  i = pontos(k, 2);
    eq = equilibrio_conversor(v, i, pc);
    d = eq.d;
    f = d * v - (1 - d) * (pc.Vbat + pc.VF) ...
        - (i / d) * (pc.rL + d * pc.Ron + (1 - d) * pc.RD);
    verifyEqual(tc, f, 0, 'AbsTol', 1e-9);
end
end

function test_ponto_inviavel(tc)
% Com vpv muito baixo o d necessario passa de Dmax: ponto inviavel, sem erro e sem potencia.
eq = equilibrio_conversor(0.2, 8, tc.TestData.pc);
verifyFalse(tc, eq.viavel);
verifyEqual(tc, eq.Pout, 0);
end

function test_sem_transferencia(tc)
% Sem corrente do painel nao ha transferencia de potencia.
eq = equilibrio_conversor(18, 0, tc.TestData.pc);
verifyFalse(tc, eq.viavel);
end

function test_dimensionamento(tc)
% Snapshot do projeto para o ZTP-160M: L ~ 57,5 uH e C ~ 1,298 mF (tolerancia de 5 %).
pz = parametros_conversor(parametros_painel('ztp160m'), 12);
verifyEqual(tc, pz.L, 57.5e-6, 'RelTol', 0.05);
verifyEqual(tc, pz.C, 1.298e-3, 'RelTol', 0.05);
end
