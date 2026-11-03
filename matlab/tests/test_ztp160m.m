% Testes da validacao do ZTP-160M sem curvas do fabricante (STC, gamaP e 2o diodo).
function tests = test_ztp160m
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.ds = datasheet_painel('ztp160m');
tc.TestData.v = validar_painel('ztp160m');
end

function test_pontos_de_stc(tc)
% O ajuste impoe estes pontos: o erro tem de ser pequeno nos dois modelos.
% Contra Pmax o erro e ~0,3 % porque o datasheet arredonda (Vmp*Imp = 160,47 W);
% contra Vmp*Imp, que e o que o ajuste impoe, o erro tem de ser ~0.
v = tc.TestData.v;
for m = 1:2
    verifyLessThan(tc, abs(v.erroPmax_STC(m)), 0.005);
    verifyLessThan(tc, abs(v.erroVoc_STC(m)), 0.005);
    verifyLessThan(tc, abs(v.erroPmp_VmpImp(m)), 1e-3);
end
end

function test_coeficiente_de_Pmax_independente(tc)
% gamaP NAO entra no ajuste: e a validacao independente do modelo termico-eletrico.
% Tolerancia de 0,05 %/K (o datasheet arredonda para -0,4 %/K). Se falhar, e
% um RESULTADO de modelagem a reportar, nao motivo para afrouxar a tolerancia.
v = tc.TestData.v;
for m = 1:2                                   % 1d e 2d
    verifyEqual(tc, v.gamaP_modelo(m), tc.TestData.ds.gamaP, 'AbsTol', 0.0005);
end
end

function test_identificabilidade_2o_diodo(tc)
% Toda a familia de razoes I02/I01 satisfaz as 5 condicoes do datasheet, mas a
% previsao em baixa irradiancia (e o Eg efetivo) muda: e a nao-identificabilidade
% do 2o diodo afirmada na decisao D9.
tab = identificabilidade_2d('ztp160m');
verifyLessThan(tc, tab.residuo, 1e-6);
verifyGreaterThan(tc, max(tab.eta200_rel) - min(tab.eta200_rel), 0.005);   % faixa (range e da Statistics Toolbox)
verifyGreaterThan(tc, max(tab.Eg_ef_eV) - min(tab.Eg_ef_eV), 0.05);
end

function test_eficiencia_em_baixa_irradiancia(tc)
% Confere que a perda em 200 W/m^2 deixou de ser os 26 % do Rp constante.
% A literatura da 3-5 % de perda para Si monocristalino em 200 W/m^2; aqui
% so se afirma que o resultado nao e mais o valor sem significado fisico,
% e que 1d e 2d nao divergem muito (menos de 3 pontos).
v = tc.TestData.v;
k1000 = find(v.G == 1000);  k200 = find(v.G == 200);
eta200_rel = zeros(1, 2);
for m = 1:2
    eta200_rel(m) = (v.Pmax_G(m, k200) / 200) / (v.Pmax_G(m, k1000) / 1000);
end
verifyGreaterThan(tc, eta200_rel(2), 0.90);
verifyLessThan(tc, eta200_rel(2), 1.0);
verifyLessThan(tc, abs(eta200_rel(1) - eta200_rel(2)), 0.03);
end

function test_submodulos_no_escuro(tc)
% Confere a curva com 2 submodulos no escuro (G = 0): sem NaN e sem aviso.
% A decisao D10 faz Rp infinito em G = 0; os submodulos escuros ficam
% totalmente em bypass. Pmp = 46,9 W e um snapshot (03/11/2026), nao referencia.
p = parametros_painel('ztp160m');
c = verifyWarningFree(tc, @() curva_pv([1000 0 0], p.Tn, p));
verifyTrue(tc, all(isfinite(c.I)));
verifyTrue(tc, all(isfinite(c.P)));
verifyEqual(tc, c.Pmp, 46.9, 'RelTol', 1e-2);
end
