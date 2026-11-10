function [x, info] = levenberg_marquardt(fun, x0, lb, ub, opts)
%LEVENBERG_MARQUARDT Minimiza ||fun(x)||^2 com limites lb <= x <= ub.
%   [x, info] = levenberg_marquardt(fun, x0, lb, ub)
%   [x, info] = levenberg_marquardt(fun, x0, lb, ub, opts)
%
%   fun  : funcao que devolve o vetor de residuos r(x) (coluna)
%   opts : struct opcional com campos
%          maxIt  numero maximo de iteracoes (padrao 500)
%          tol    para quando o custo ||r||^2 fica abaixo disso (padrao 1e-14)
%   info : struct com iter (iteracoes), residuo = ||r|| e r (residuos finais)
%
%   Substitui lsqnonlin (Optimization Toolbox ausente). Jacobiano por
%   diferencas centrais; os limites sao impostos projetando cada passo
%   de volta na caixa [lb, ub].

if nargin < 5, opts = struct(); end
maxIt = campo(opts, 'maxIt', 500);
tol   = campo(opts, 'tol', 1e-14);

lb = lb(:);  ub = ub(:);
x = min(max(x0(:), lb), ub);          % chute inicial dentro dos limites
r = fun(x);
custo = r.' * r;

% mu controla o passo: mu pequeno -> passo de Gauss-Newton (rapido perto
% da solucao); mu grande -> passo curto na direcao do gradiente (seguro).
mu = 1e-3;

it = 0;                               % definido mesmo se maxIt = 0
for it = 1:maxIt
    J = jacobiano_numerico(fun, x, r, lb, ub);
    A = J.' * J;                      % aproximacao de Gauss-Newton da Hessiana / 2
    b = J.' * r;                      % gradiente do custo / 2

    % Tenta passos com mu crescente ate o custo diminuir
    aceitou = false;
    while mu < 1e12
        % Equacao do LM: (A + mu*diag(A)) dx = -b. O termo diag(A) escala
        % o amortecimento por variavel.
        % As incognitas tem escalas muito diferentes (ex.: Rp ~ 1e2 ohm e
        % Eg ~ 1 eV), o que deixa A mal condicionada. Resolve-se a MESMA
        % equacao com as variaveis normalizadas por d = sqrt(diag(A)):
        %   (A./(d*d') + mu*I) y = -b./d,   dx = y./d
        % Matematicamente identico, mas com diagonal unitaria (bem condicionado).
        d = sqrt(diag(A)) + eps;
        y = -(A ./ (d * d.') + mu * eye(numel(x))) \ (b ./ d);
        dx = y ./ d;
        x_novo = min(max(x + dx, lb), ub);       % projeta nos limites
        r_novo = fun(x_novo);
        custo_novo = r_novo.' * r_novo;
        if custo_novo < custo
            passo = norm(x_novo - x);
            x = x_novo;  r = r_novo;  custo = custo_novo;
            mu = max(mu / 3, 1e-12);  % deu certo: confia mais em Gauss-Newton
            aceitou = true;
            break
        end
        mu = mu * 4;                  % piorou: passo mais curto e cauteloso
    end

    % Criterios de parada: nenhum passo melhora, custo ja e pequeno, ou o
    % passo ficou desprezivel frente ao tamanho de x.
    % Com limites ativos (x parado em lb ou ub) a parada costuma ser a de
    % "nenhum passo melhora": a projecao anula o passo naquela direcao.
    if ~aceitou
        break
    end
    if custo < tol || passo < 1e-12 * (1 + norm(x))
        break
    end
end

info = struct('iter', it, 'residuo', sqrt(custo), 'r', r);
end

function J = jacobiano_numerico(fun, x, r, lb, ub)
% Jacobiano dr/dx por diferencas centrais, sem sair dos limites
% (no limite a diferenca vira unilateral). r so e usado para o tamanho de J.
J = zeros(numel(r), numel(x));
for j = 1:numel(x)
    h = 1e-6 * max(1, abs(x(j)));
    x_mais  = x;  x_mais(j)  = min(x(j) + h, ub(j));
    x_menos = x;  x_menos(j) = max(x(j) - h, lb(j));
    J(:, j) = (fun(x_mais) - fun(x_menos)) / (x_mais(j) - x_menos(j));
end
end

function v = campo(s, nome, padrao)
% Le o campo opcional s.(nome); usa o valor padrao se nao existir.
if isfield(s, nome)
    v = s.(nome);
else
    v = padrao;
end
end
