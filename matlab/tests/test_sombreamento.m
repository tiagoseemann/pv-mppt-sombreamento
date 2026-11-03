% matlab/tests/test_sombreamento.m
function tests = test_sombreamento
tests = functiontests(localfunctions);
end

function setupOnce(tc)
tc.TestData.p = parametros_painel('generico');
end

function test_regressao_curvas(tc)
p = tc.TestData.p;
c1 = curva_pv([1000 1000 1000], p.Tn, p);
c2 = curva_pv([1000 1000  400], p.Tn, p);
c3 = curva_pv([1000  600  300], p.Tn, p);
verifyEqual(tc, c1.Pmp, 138.2, 'RelTol', 0.01);
verifyEqual(tc, c2.Pmp,  89.2, 'RelTol', 0.01);
verifyEqual(tc, c2.Vmp,  11.58, 'AbsTol', 0.2);
verifyEqual(tc, c3.Pmp,  57.8, 'RelTol', 0.01);
end

function test_numero_de_picos(tc)
p = tc.TestData.p;
verifyEqual(tc, height(curva_pv([1000 1000 1000], p.Tn, p).picos), 1);
verifyEqual(tc, height(curva_pv([1000 1000  400], p.Tn, p).picos), 2);
verifyEqual(tc, height(curva_pv([1000  600  300], p.Tn, p).picos), 3);
end

function test_newton_converge(tc)
p = tc.TestData.p;
[~, s] = painel_sombreado(15, [1000 1000 400], p.Tn, p);
verifyLessThan(tc, s.res, 1e-9);
verifyLessThan(tc, s.iter, 30);
end

function test_bypass_conduz_quando_sombreado(tc)
p = tc.TestData.p;
[I, s] = painel_sombreado(9, [1000 1000 400], p.Tn, p);
verifyLessThan(tc, s.Vj(3), -0.2);                       % submodulo 3 bypassado
verifyEqual(tc, s.Ic(3) + s.Ibp(3), I, 'AbsTol', 1e-8);  % KCL
verifyGreaterThan(tc, s.Ibp(3), 1);                      % bypass carrega o excesso
end

function test_uniforme_igual_modulo_unico(tc)
p = tc.TestData.p;
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;
for V = [0 5 10 15 18 20]
    I3 = painel_sombreado(V, [1000 1000 1000], p.Tn, p);
    I1 = painel_sombreado(V, 1000, p.Tn, q);
    verifyEqual(tc, I3, I1, 'AbsTol', 1e-3);
end
end
