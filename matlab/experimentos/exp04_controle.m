%EXP04 Bode da planta nos pontos de robustez, margens do PI e degrau linear x nao linear.
% O PI de tensao (projeto_pi) foi projetado para valer em TODOS os casos de
% robustez em conducao continua: pontos de operacao (1000/600/200 W/m^2 no
% MPP e em 0,8 e 1,1 Vmp, os dois picos com sombra e o modulo a 60 C) vezes
% os cantos de tolerancia de L e C (+-20 %), decisao D13.
% Este script:
%   1) desenha o Bode da planta -G_vd e do ganho de malha L = C*(-G_vd)*atraso
%      em todos esses casos (o nominal em preto, o que limita a MG em vermelho);
%   2) grava as margens de cada caso em resultados/e4_margens.csv (os casos
%      em DCM entram com margens NaN: ali o modelo linear de CCM nao vale);
%   3) compara a resposta ao degrau de V_ref do modelo LINEAR (usado no
%      projeto) com o modelo medio NAO LINEAR (painel resolvido por Newton,
%      PI com saturacao), no ponto nominal e no caso mais lento.
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
pasta_figs = fullfile(raiz_projeto(), 'relatorio', 'figs');

p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
cfg = config_mppt(p);
[ctl, rel] = projeto_pi(p, pc);

fprintf('PI: Kp = %.4g, Ti = %.3g ms, fc = %.1f Hz, r = wz/wc = %g\n', ...
    ctl.Kp, 1e3 * ctl.Ti, ctl.fc, ctl.r);
fprintf('Piores margens (CCM): MF = %.1f graus, MG = %.1f dB\n', rel.PMmin, rel.GMmin);
fprintf('Pior ts = %.1f ms -> Ta = 1,5 ts = %.1f ms\n', 1e3 * ctl.ts, 1e3 * ctl.Ta);
fprintf('Casos verificados (CCM): %d; excluidos por DCM: %d\n', ...
    numel(rel.ops), numel(rel.ops_dcm));

% ---- 1) Bode em todos os casos em CCM ----
% Mesma grade e mesmo atraso do PWM usados em projeto_pi
w = logspace(0, log10(pi * pc.fs), 3000);
f = w / (2 * pi);
atraso = exp(-1j * w * pc.atraso);
Cw = ctl.Kp * (1 + 1 ./ (1j * w * ctl.Ti));      % PI na grade de frequencias
[~, k_lim] = min(rel.GM);                          % caso que limita a banda

figure('Position', [100 100 1000 620], 'Theme', 'light');
PM = zeros(numel(rel.ops), 1);  GM = PM;
h_leg = gobjects(3, 1);                            % curvas que entram na legenda
% Ordem do desenho: demais casos, o limitante e o nominal por ultimo (por cima)
ordem = [setdiff(2:numel(rel.ops), k_lim), k_lim, 1];
for k = ordem
    op = rel.ops(k);
    pcx = pc;  pcx.L = pc.L * op.fL;  pcx.C = pc.C * op.fC;
    sys = linearizar_planta(op, p, pcx);
    % Sinal "-": a planta tem ganho negativo (mais d -> menor v_pv)
    Gp = -resposta_freq(sys, w) .* atraso;
    L = Cw .* Gp;
    m = margens(w, L);
    PM(k) = m.PM;  GM(k) = m.GM;

    if k == 1
        estilo = {'k', 'LineWidth', 2};  i_leg = 1;
    elseif k == k_lim
        estilo = {'r', 'LineWidth', 1.5};  i_leg = 2;
    else
        estilo = {'Color', [0.7 0.7 0.7], 'LineWidth', 0.5};  i_leg = 3;
    end
    subplot(2, 2, 1); h = semilogx(f, 20 * log10(abs(Gp)), estilo{:}); hold on;
    h_leg(i_leg) = h;
    subplot(2, 2, 3); semilogx(f, unwrap(angle(Gp)) * 180 / pi, estilo{:}); hold on;
    subplot(2, 2, 2); semilogx(f, 20 * log10(abs(L)), estilo{:}); hold on;
    subplot(2, 2, 4); semilogx(f, unwrap(angle(L)) * 180 / pi, estilo{:}); hold on;
end
% Conferencia: as margens recalculadas aqui sao as de projeto_pi
assert(max(abs(PM - rel.PM)) < 1e-6 && max(abs(GM - rel.GM)) < 1e-6, ...
    'exp04: margens diferentes das de projeto_pi');

lim = rel.ops(k_lim);
% Rotulo do caso limitante: diz quais componentes estao fora do nominal
if lim.fL == lim.fC
    fator = sprintf('L e C \\times%s', strrep(sprintf('%.1f', lim.fL), '.', ','));
else
    fator = sprintf('L \\times%s, C \\times%s', strrep(sprintf('%.1f', lim.fL), '.', ','), ...
        strrep(sprintf('%.1f', lim.fC), '.', ','));
end
rotulo_lim = sprintf('limita a MG (G = %s, %.1f V, %s)', mat2str(lim.G), lim.vpv, fator);
subplot(2, 2, 1); grid on; ylabel('|-G_{vd}| [dB]'); title('Planta (com atraso do PWM)');
legend(h_leg, {'nominal (STC, MPP)', ...
    rotulo_lim, ...
    'demais casos'}, 'Location', 'southwest');
subplot(2, 2, 3); grid on; ylabel('fase [°]'); xlabel('f [Hz]');
subplot(2, 2, 2); grid on; ylabel('|L| [dB]'); yline(0, 'k:');
title(sprintf('Malha com PI: f_c = %.0f Hz, MF_{mín} = %.0f°, MG_{mín} = %.1f dB', ...
    ctl.fc, rel.PMmin, rel.GMmin));
subplot(2, 2, 4); grid on; ylabel('fase [°]'); xlabel('f [Hz]'); yline(-180, 'k:');
exportgraphics(gcf, fullfile(pasta_figs, 'e4_bode.pdf'));

% ---- 2) Tabela de margens: casos em CCM e casos excluidos (DCM) ----
nC = numel(rel.ops);  nD = numel(rel.ops_dcm);
casos = [rel.ops, rel.ops_dcm];
G_txt = cell(nC + nD, 1);
for k = 1:nC + nD
    G_txt{k} = mat2str(casos(k).G);
end
tab = table([casos.vpv].', G_txt, [casos.T].' - 273.15, [casos.fL].', [casos.fC].', ...
    [true(nC, 1); false(nD, 1)], [rel.PM; NaN(nD, 1)], [rel.GM; NaN(nD, 1)], ...
    1e3 * [rel.ts; NaN(nD, 1)], ...
    'VariableNames', {'vpv', 'G', 'T_C', 'fL', 'fC', 'ccm', 'MF_graus', 'MG_dB', 'ts_ms'});
writetable(tab, fullfile(pasta_res, 'e4_margens.csv'));
disp(tab);

% ---- 3) Degrau de V_ref: linear x nao linear ----
% Degrau do tamanho do passo do P&O (1 % de Voc). O modelo linear da a
% resposta a um degrau unitario; a resposta a um degrau de dV e dV vezes ela.
% O modelo nao linear integra o modelo medio com o painel resolvido por
% Newton e o PI com saturacao (lei_pi), partindo do equilibrio no ponto.
dV = cfg.delta;
t_fim = 0.05;
k_lento = rel.k_ts_max;                             % caso com o pior ts
casos_degrau = [1, k_lento];
titulos = {'nominal (STC, MPP)', 'caso mais lento'};

figure('Position', [100 100 1000 380], 'Theme', 'light');
for j = 1:2
    op = rel.ops(casos_degrau(j));
    pcx = pc;  pcx.L = pc.L * op.fL;  pcx.C = pc.C * op.fC;
    sys = linearizar_planta(op, p, pcx);

    % Linear
    [tl, vl] = resposta_degrau_mf(sys, ctl, t_fim);

    % Nao linear: estado [v_pv; i_L; xi]. No equilibrio o erro e zero, entao
    % d0 = Kp*xi0/Ti, ou seja, xi0 = Ti*d0/Kp.
    x0 = [sys.x0(1); sys.x0(2); ctl.Ti * sys.d0 / ctl.Kp];
    Vref = op.vpv + dV;
    rhs = @(t, x) modelo_nao_linear(x, Vref, op, ctl, p, pcx);
    [tn, xn] = ode15s(rhs, [0 t_fim], x0, odeset('RelTol', 1e-6, 'AbsTol', 1e-8));

    subplot(1, 2, j);
    plot(1e3 * tl, op.vpv + dV * vl, 'LineWidth', 1.5); hold on;
    plot(1e3 * tn, xn(:, 1), '--', 'LineWidth', 1.5);
    grid on; xlabel('t [ms]'); ylabel('v_{pv} [V]');
    title(sprintf('%s: G = %s, %.1f V, L \\times %.1f, C \\times %.1f (t_s = %.1f ms)', titulos{j}, ...
        mat2str(op.G), op.vpv, op.fL, op.fC, 1e3 * rel.ts(casos_degrau(j))), 'FontSize', 9);
    legend('linear', 'não linear (modelo médio)', 'Location', 'southeast');
    % Diferenca maxima entre os dois, relativa ao degrau
    vl_n = interp1(tl, op.vpv + dV * vl, tn);
    fprintf('Degrau de %.2f V, %s: max |linear - nao linear| = %.1f %% do degrau\n', ...
        dV, titulos{j}, 100 * max(abs(vl_n - xn(:, 1))) / dV);
end
exportgraphics(gcf, fullfile(pasta_figs, 'e4_degrau.pdf'));


function dx = modelo_nao_linear(x, Vref, op, ctl, p, pc)
% Modelo medio do conversor em malha fechada com o PI (sem termico: T fixa)
v = x(1);  iL = x(2);  xi = x(3);
I = painel_sombreado(v, op.G, op.T, p);        % corrente do painel em v
[d, dxi] = lei_pi(v, xi, Vref, ctl, pc);       % PI com saturacao e anti-windup
dx = [conversor_medio_rhs(v, iL, I, d, pc); dxi];
end
