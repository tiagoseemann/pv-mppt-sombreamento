%EXEMPLO_DAE_CONVERSOR Painel sombreado acoplado ao buck-boost (modelo medio).
%   Formulacao DAE resolvida pelo ode15s com matriz de massa singular:
%
%       x = [v_pv; i_L; I; Vd_1..Vd_N]
%
%       C * dv_pv/dt = I - d*i_L                  (diferencial)
%       L * di_L/dt  = d*v_pv - (1-d)*Vbat        (diferencial)
%       0            = residuo_painel(z, v_pv)    (algebrica, N+1 linhas)
%
%   Malha aberta (d imposto), sem perdas. Eventos:
%     t = 20 ms : sombra no submodulo 3 (1000 -> 400 W/m^2)
%     t = 50 ms : d de 0,40 -> 0,55 (tensao cai; submodulo 3 e bypassado)
clear; clc;

p = parametros_painel();
T = 298.15;
N = p.Nsub;

C = 470e-6;  L = 330e-6;  Vbat = 12;

% Entradas suavizadas (degraus de ~1 ms) para nao travar o integrador
suave = @(t, t0) 0.5 * (1 + tanh((t - t0) / 2e-4));
Gt = @(t) [1000, 1000, 1000 - 600 * suave(t, 0.020)];
dt = @(t) 0.40 + 0.15 * suave(t, 0.050);

% Condicao inicial consistente: equilibrio com d = 0,40 e sem sombra
v0 = (1 - dt(0)) * Vbat / dt(0);
[I0, s0] = painel_sombreado(v0, Gt(0), T, p);
x0 = [v0; I0 / dt(0); s0.z];

M = blkdiag(C, L, zeros(N + 1));
f   = @(t, x) [ x(3) - dt(t) * x(2)
                dt(t) * x(1) - (1 - dt(t)) * Vbat
                residuo_painel(x(3:end), x(1), Gt(t), T, p) ];
jac = @(t, x) jacobiano_dae(x, dt(t), Gt(t), T, p);

% Jacobiano analitico: o de diferencas finitas falha na exponencial do bypass
opts = odeset('Mass', M, 'MassSingular', 'yes', 'Jacobian', jac, ...
              'RelTol', 1e-6, 'AbsTol', 1e-8, 'MaxStep', 1e-4);
[t, x] = ode15s(f, [0 0.08], x0, opts);

% Pos-processamento: tensao de cada submodulo
Vj = zeros(numel(t), N);
for n = 1:numel(t)
    [~, ~, vj] = residuo_painel(x(n, 3:end).', x(n, 1), Gt(t(n)), T, p);
    Vj(n, :) = vj.';
end
P = x(:, 1) .* x(:, 3);

figure('Name', 'DAE painel + conversor', 'Position', [100 100 900 700]);
subplot(4, 1, 1); plot(t * 1e3, x(:, 1), 'LineWidth', 1.3); grid on;
ylabel('v_{pv} [V]'); title('Painel sombreado + buck-boost (malha aberta)');
subplot(4, 1, 2); plot(t * 1e3, x(:, 2), 'LineWidth', 1.3); grid on;
ylabel('i_L [A]');
subplot(4, 1, 3); plot(t * 1e3, P, 'LineWidth', 1.3); grid on;
ylabel('P_{pv} [W]');
subplot(4, 1, 4); plot(t * 1e3, Vj, 'LineWidth', 1.3); grid on;
ylabel('V_j [V]'); xlabel('t [ms]');
legend(compose('sub. %d', 1:N), 'Location', 'west');

fprintf('Antes da sombra  (t=19 ms): P = %.1f W\n', interp1(t, P, 0.019));
fprintf('Depois da sombra (t=49 ms): P = %.1f W\n', interp1(t, P, 0.049));
fprintf('Apos mudar d     (t=80 ms): P = %.1f W, V_sub3 = %.2f V (bypass)\n', ...
    P(end), Vj(end, 3));

function Jf = jacobiano_dae(x, d, G, T, p)
%JACOBIANO_DAE dF/dx do sistema [v_pv; i_L; z].
N = p.Nsub;
[~, Jz] = residuo_painel(x(3:end), x(1), G, T, p);
Jf = zeros(N + 3);
Jf(1, 2:3) = [-d, 1];              % C dv/dt = I - d*iL
Jf(2, 1)   = d;                    % L di/dt = d*v - (1-d)*Vbat
Jf(3:end, 1)     = [zeros(N, 1); -1];   % dR/dv_pv (so a linha da soma)
Jf(3:end, 3:end) = Jz;
end
