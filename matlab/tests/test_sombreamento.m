% Testes de regressao do modelo de sombreamento parcial.
% Os numeros esperados sao "fotografias" (snapshots) medidas em 27/10/2026
% com parametros_painel('generico') e re-medidas em 03/11/2026 apos adotar
% Rp(G) de De Soto (2006); NAO sao valores de referencia da literatura.
% Servem para detectar mudancas acidentais no codigo.
function tests = test_sombreamento
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.p = parametros_painel('generico');
end

function test_regressao_curvas(tc)
% Confere potencia e tensao do ponto de maxima potencia global (snapshots).
p = tc.TestData.p;
c1 = curva_pv([1000 1000 1000], p.Tn, p);
c2 = curva_pv([1000 1000  400], p.Tn, p);
c3 = curva_pv([1000  600  300], p.Tn, p);
verifyEqual(tc, c1.Pmp, 138.2, 'RelTol', 0.01);
verifyEqual(tc, c2.Pmp,  89.2, 'RelTol', 0.01);
verifyEqual(tc, c2.Vmp,  11.58, 'AbsTol', 0.2);
verifyEqual(tc, c3.Pmp,  58.0, 'RelTol', 0.01);
end

function test_numero_de_picos(tc)
% Confere que a curva P-V tem um pico por nivel distinto de irradiancia.
% Cada diodo de bypass que liga abre um novo ramo da curva P-V, entao cada
% nivel diferente de irradiancia adiciona um pico.
p = tc.TestData.p;
verifyEqual(tc, height(curva_pv([1000 1000 1000], p.Tn, p).picos), 1);
verifyEqual(tc, height(curva_pv([1000 1000  400], p.Tn, p).picos), 2);
verifyEqual(tc, height(curva_pv([1000  600  300], p.Tn, p).picos), 3);
end

function test_newton_converge(tc)
% Confere que o Newton converge: residuo pequeno em poucas iteracoes.
p = tc.TestData.p;
[~, s] = painel_sombreado(15, [1000 1000 400], p.Tn, p);
verifyLessThan(tc, s.res, 1e-9);
verifyLessThan(tc, s.iter, 30);
end

function test_bypass_conduz_quando_sombreado(tc)
% Confere que o bypass do submodulo sombreado conduz e que a tensao fecha.
p = tc.TestData.p;
[~, s] = painel_sombreado(9, [1000 1000 400], p.Tn, p);
verifyLessThan(tc, s.Vj(3), -0.2);                       % submodulo 3 bypassado
verifyEqual(tc, sum(s.Vj), 9, 'AbsTol', 1e-6);           % KVL: soma das tensoes = Vpv
verifyGreaterThan(tc, s.Ibp(3), 1);                      % bypass carrega o excesso
verifyTrue(tc, all(abs(s.Ibp(1:2)) < 1e-3));             % sem sombra: bypass nao conduz
end

function test_uniforme_igual_modulo_unico(tc)
% Confere que luz uniforme equivale a um modulo de um unico grupo de celulas.
p = tc.TestData.p;
% Com luz uniforme os diodos de bypass ficam desligados, entao 3 submodulos
% de 12 celulas devem se comportar como 1 grupo de 36 celulas.
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;
for V = [0 5 10 15 18 20]
    I3 = painel_sombreado(V, [1000 1000 1000], p.Tn, p);
    I1 = painel_sombreado(V, 1000, p.Tn, q);
    verifyEqual(tc, I3, I1, 'AbsTol', 1e-3);
end
end
