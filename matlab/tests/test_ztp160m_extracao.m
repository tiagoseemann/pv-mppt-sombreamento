% Testes da extracao de parametros aplicada ao painel real ZTROON ZTP-160M.
function tests = test_ztp160m_extracao
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('ztp160m');
end

function test_parametros_painel_2d(tc)
% Confere que parametros_painel('ztp160m') reproduz Isc, Voc, MPP e Kv do catalogo.
ds = tc.TestData.ds;
p = parametros_painel('ztp160m');
G = 1000 * ones(1, p.Nsub);
c25 = curva_pv(G, p.Tn, p, 2000);
c50 = curva_pv(G, p.Tn + 25, p, 2000);
verifyEqual(tc, c25.Pmp, ds.Pmax, 'RelTol', 0.005);
verifyEqual(tc, c25.Vmp, ds.Vmp, 'RelTol', 0.01);
verifyEqual(tc, c25.I(1), ds.Isc, 'RelTol', 0.005);
verifyEqual(tc, c25.V(end), ds.Voc, 'RelTol', 0.005);
verifyEqual(tc, (c50.V(end) - c25.V(end)) / 25, ds.Kv, 'RelTol', 0.05);
end

function test_modelo_1d(tc)
% Confere que o modelo de 1 diodo (a = 1,1) converge e reproduz Pmax.
ds = tc.TestData.ds;
[p1, info] = extrair_parametros(ds, '1d');
verifyTrue(tc, info.convergiu);
c = curva_pv(1000 * ones(1, p1.Nsub), p1.Tn, p1, 2000);
verifyEqual(tc, c.Pmp, ds.Pmax, 'RelTol', 0.005);
end
