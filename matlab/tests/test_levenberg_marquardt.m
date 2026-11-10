% Testes do otimizador de minimos quadrados levenberg_marquardt.
function tests = test_levenberg_marquardt
tests = functiontests(localfunctions);
end

function test_rosenbrock(tc)
% Confere que o LM acha o minimo (1, 1) do vale curvo de Rosenbrock.
f = @(x) [10 * (x(2) - x(1)^2); 1 - x(1)];
x = levenberg_marquardt(f, [-1.2; 1], [-5; -5], [5; 5]);
verifyEqual(tc, x, [1; 1], 'AbsTol', 1e-6);
end

function test_respeita_limites(tc)
% Confere que a solucao para no limite superior quando o minimo esta fora dele.
f = @(x) x - 3;                       % minimo irrestrito em 3
x = levenberg_marquardt(f, 0, -1, 2);
verifyEqual(tc, x, 2, 'AbsTol', 1e-9);
end
