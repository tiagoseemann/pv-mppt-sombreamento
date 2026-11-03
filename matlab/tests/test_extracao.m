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
% Confere resistencias e gap plausiveis e que as 5 condicoes fecham.
p = tc.TestData.p;
verifyGreaterThan(tc, p.Rs * p.Ns, 0.01);                % Rs do modulo [ohm]
verifyLessThan(tc, p.Rs * p.Ns, 1);
verifyGreaterThan(tc, p.Rp * p.Ns, 50);                  % Rp do modulo [ohm]
verifyLessThan(tc, tc.TestData.info.residuo, 1e-6);
verifyGreaterThan(tc, p.Eg, 1.0);                        % gap efetivo [eV]
verifyLessThan(tc, p.Eg, 1.5);
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
% Confere que razoes I02/I01 = 1 e 10 fecham o datasheet com o mesmo Pmax
% (o datasheet nao distingue as duas: I02 nao e identificavel).
p1 = tc.TestData.p;                                      % razao = 1 (padrao)
[p10, info] = extrair_parametros(tc.TestData.ds, '2d', 10);
verifyLessThan(tc, info.residuo, 1e-6);
G = 1000 * ones(1, p1.Nsub);
c1  = curva_pv(G, p1.Tn, p1, 2000);
c10 = curva_pv(G, p10.Tn, p10, 2000);
verifyEqual(tc, c10.Pmp, c1.Pmp, 'RelTol', 1e-3);
end

function test_benchmark_villalva_1d(tc)
% Compara o '1d' do KC200GT com Villalva et al. (2009): Ipv, I0 e Rs.
% Rp nao e comparado: e pouco determinado perto do MPP e Villalva usa
% outra lei I0(T), entao os valores divergem sem que um esteja errado.
p1 = extrair_parametros(tc.TestData.ds, '1d');
verifyEqual(tc, p1.Ipv_n, 8.214, 'RelTol', 0.01);       % [A]
verifyEqual(tc, p1.I01_n, 9.825e-8, 'RelTol', 0.05);    % [A]
verifyEqual(tc, p1.Rs * p1.Ns, 0.221, 'RelTol', 0.10);  % Rs do modulo [ohm]
end
