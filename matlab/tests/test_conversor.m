% Testes do conversor buck-boost: modelo medio com perdas, equilibrio e CCM/DCM.
function tests = test_conversor
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.p = parametros_painel('generico');
tc.TestData.pc = parametros_conversor(tc.TestData.p, 12);
end

function test_ganho_ideal(tc)
% Sem perdas, o ganho do buck-boost e d/(1-d) = Vbat/vpv e a eficiencia e 1.
pc = conversor_ideal(tc.TestData.pc);
eq = equilibrio_conversor(18, 7.7, pc);
verifyEqual(tc, eq.d / (1 - eq.d), 12 / 18, 'RelTol', 1e-9);
verifyEqual(tc, eq.eta, 1, 'AbsTol', 1e-9);
end

function test_balanco_de_energia(tc)
% Potencia de entrada = potencia na bateria + perdas de conducao; eta fica entre 0,85 e 1.
pc = tc.TestData.pc;
v = 18;  i = 7.7;
eq = equilibrio_conversor(v, i, pc);
verifyEqual(tc, v * i, (1 - eq.d) * eq.iL * pc.Vbat + eq.Pcond, 'RelTol', 1e-9);
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
