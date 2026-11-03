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
v = tc.TestData.v;
for m = 1:2
    verifyLessThan(tc, abs(v.erroPmax_STC(m)), 0.005);
    verifyLessThan(tc, abs(v.erroVoc_STC(m)), 0.005);
end
end

function test_coeficiente_de_Pmax_independente(tc)
% gamaP NAO entra no ajuste: e a validacao independente do modelo termico-eletrico.
% Tolerancia de 0,05 %/K (o datasheet arredonda para -0,4 %/K).
v = tc.TestData.v;
verifyEqual(tc, v.gamaP_modelo(2), tc.TestData.ds.gamaP, 'AbsTol', 0.0005);
end

function test_identificabilidade_2o_diodo(tc)
% Toda a familia de razoes I02/I01 satisfaz as 5 condicoes do datasheet.
tab = identificabilidade_2d('ztp160m');
verifyLessThan(tc, tab.residuo, 1e-6);
end
