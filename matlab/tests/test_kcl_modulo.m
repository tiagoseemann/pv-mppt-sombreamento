% Testes do residuo explicito do modulo inteiro (sem sombra), kcl_modulo.
function tests = test_kcl_modulo
tests = functiontests(localfunctions);
end

function test_kcl_zero_em_ponto_da_curva(tc)
% Confere que um ponto (V, I) da curva resolvida pelo Newton zera a KCL do modulo.
p = parametros_painel('generico');
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;      % modulo inteiro como um unico grupo
% O bypass do grupo unico vaza I0bp = 1,4 uA em reversa, corrente que o
% kcl_modulo (sem bypass) nao tem. Zerar I0bp para comparar so o modulo.
q.I0bp = 0;
I = painel_sombreado(15, 1000, p.Tn, q);
F = kcl_modulo(15, I, 1000, p.Tn, p);
verifyEqual(tc, F, 0, 'AbsTol', 1e-6);
end

function test_derivada_analitica(tc)
% Confere dI/dV = -g/(1 + Rs*g) contra diferenca finita central da curva.
p = parametros_painel('generico');
q = p;  q.Nsub = 1;  q.Ncel = p.Ns;
V = 17;  h = 1e-4;
I  = painel_sombreado(V, 1000, p.Tn, q);
Ip = painel_sombreado(V + h, 1000, p.Tn, q);
Im = painel_sombreado(V - h, 1000, p.Tn, q);
[~, g] = kcl_modulo(V, I, 1000, p.Tn, p);
dIdV = -g / (1 + p.Ns * p.Rs * g);
verifyEqual(tc, dIdV, (Ip - Im) / (2 * h), 'RelTol', 1e-3);
end
