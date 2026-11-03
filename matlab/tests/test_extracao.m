% Testes da extracao de parametros (2 diodos e 1 diodo) validada no KC200GT.
% Referencia: Villalva et al. (2009), dados de catalogo do Kyocera KC200GT.
function tests = test_extracao
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('kc200gt');
[tc.TestData.p, tc.TestData.info] = extrair_parametros(tc.TestData.ds, '2d');
end

function test_pontos_chave_2d(tc)
% Confere que a curva do modelo de 2 diodos passa por Isc, Voc e MPP do catalogo.
ds = tc.TestData.ds;  p = tc.TestData.p;
c = curva_pv(1000 * ones(1, p.Nsub), p.Tn, p, 2000);
verifyEqual(tc, c.Pmp, ds.Pmax, 'RelTol', 0.005);
verifyEqual(tc, c.Vmp, ds.Vmp, 'RelTol', 0.01);
verifyEqual(tc, c.I(1), ds.Isc, 'RelTol', 0.005);
verifyEqual(tc, c.V(end), ds.Voc, 'RelTol', 0.005);
end

function test_coeficiente_Voc(tc)
% Confere que o Voc cai com a temperatura na taxa Kv do catalogo.
ds = tc.TestData.ds;  p = tc.TestData.p;
G = 1000 * ones(1, p.Nsub);
c25 = curva_pv(G, p.Tn, p, 2000);
c50 = curva_pv(G, p.Tn + 25, p, 2000);
verifyEqual(tc, (c50.V(end) - c25.V(end)) / 25, ds.Kv, 'RelTol', 0.05);
end

function test_parametros_fisicos(tc)
% Confere resistencias e gap plausiveis, I01 = I02 e que as 5 condicoes fecham.
p = tc.TestData.p;
verifyGreaterThan(tc, p.Rs * p.Ns, 0.01);                % Rs do modulo [ohm]
verifyLessThan(tc, p.Rs * p.Ns, 1);
verifyGreaterThan(tc, p.Rp * p.Ns, 50);                  % Rp do modulo [ohm]
verifyLessThan(tc, tc.TestData.info.residuo, 1e-6);
verifyGreaterThan(tc, p.Eg, 1.0);                        % gap efetivo [eV]
verifyLessThan(tc, p.Eg, 1.5);
verifyEqual(tc, p.I01_n, p.I02_n);                       % hipotese de Ishaque
end

function test_modelo_1d(tc)
% Confere que o modelo de 1 diodo reproduz Pmax e Kv e nao tem diodo 2.
ds = tc.TestData.ds;
p1 = extrair_parametros(ds, '1d');
G = 1000 * ones(1, p1.Nsub);
c25 = curva_pv(G, p1.Tn, p1, 2000);
c50 = curva_pv(G, p1.Tn + 25, p1, 2000);
verifyEqual(tc, c25.Pmp, ds.Pmax, 'RelTol', 0.005);
verifyEqual(tc, (c50.V(end) - c25.V(end)) / 25, ds.Kv, 'RelTol', 0.05);
verifyEqual(tc, p1.I02_n, 0);
end

function test_razao_I02_I01(tc)
% Confere que outra razao I02/I01 tambem satisfaz o datasheet (I02 nao e identificavel).
[p10, info] = extrair_parametros(tc.TestData.ds, '2d', 10);
verifyLessThan(tc, info.residuo, 1e-6);
verifyEqual(tc, p10.I02_n, 10 * p10.I01_n, 'RelTol', 1e-12);
end
