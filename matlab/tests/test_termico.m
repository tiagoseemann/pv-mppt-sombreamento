% Testes do modelo termico do modulo ZTP-160M calibrado pelo NMOT.
function tests = test_termico
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('ztp160m');
tc.TestData.pt = parametros_termicos(tc.TestData.ds);
end

function test_nmot_reproduzido(tc)
% Na condicao NMOT (800 W/m2, 20 C, 1 m/s, no MPP) o regime permanente deve dar 45 C.
ds = tc.TestData.ds;  pt = tc.TestData.pt;
Pel = @(T) ds.Pmax * 0.8 * (1 + ds.gamaP * (T - 298.15));
Tss = fzero(@(T) termico_dTdt(T, 800, 293.15, 1, Pel(T), pt), [250 400]);
verifyEqual(tc, Tss - 273.15, ds.NMOT, 'AbsTol', 0.05);
end

function test_constante_de_tempo(tc)
% A constante de tempo termica de um modulo de vidro fica na faixa de 3 a 10 min.
pt = tc.TestData.pt;
h = 1e-3;  T0 = 320;
dfdT = (termico_dTdt(T0 + h, 800, 298.15, 1, 0, pt) - ...
        termico_dTdt(T0 - h, 800, 298.15, 1, 0, pt)) / (2 * h);
tau_min = -1 / dfdT / 60;          % tau = -1 / (d(dT/dt)/dT)
verifyGreaterThan(tc, tau_min, 3);
verifyLessThan(tc, tau_min, 10);
end

function test_vento_resfria(tc)
% Mais vento aumenta a conveccao, entao a temperatura de regime cai.
pt = tc.TestData.pt;
T1 = fzero(@(T) termico_dTdt(T, 1000, 298.15, 1, 0, pt), [250 400]);
T5 = fzero(@(T) termico_dTdt(T, 1000, 298.15, 5, 0, pt), [250 400]);
verifyLessThan(tc, T5, T1);
end

function test_extrair_eletricidade_resfria(tc)
% Parte da luz vira eletricidade em vez de calor, entao o modulo esfria.
pt = tc.TestData.pt;
T0 = fzero(@(T) termico_dTdt(T, 1000, 298.15, 1, 0, pt), [250 400]);
Tp = fzero(@(T) termico_dTdt(T, 1000, 298.15, 1, 150, pt), [250 400]);
verifyLessThan(tc, Tp, T0);
end
