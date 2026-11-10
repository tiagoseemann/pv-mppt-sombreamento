%EXP02 Curvas I-V e P-V do ZTP-160M sob sombreamento parcial.
% Tres padroes de irradiancia por submodulo (25 C):
%   - sem sombra: um unico maximo (o MPP do datasheet, ~160 W em ~19,6 V)
%   - 1 submodulo a 40 %: o submodulo sombreado limita a corrente da serie.
%     Em tensao baixa a corrente pedida passa da que ele gera, o diodo de
%     bypass conduz e o submodulo sai do circuito: aparece um "degrau" na
%     I-V e um segundo maximo na P-V (dois picos, um local e um global).
%   - degrade (100/60/30 %): cada submodulo entra em bypass numa corrente
%     diferente, entao ate tres picos.
% A tabela guarda todos os maximos locais e marca qual e o global: e o que
% o MPPT precisa achar (P&O e InC podem parar no pico local).
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
pasta_figs = fullfile(raiz_projeto(), 'relatorio', 'figs');

p = parametros_painel('ztp160m');
% Fatores de irradiancia por submodulo (x 1000 W/m^2); mesmo degrade do E5
padroes = {ones(1, p.Nsub), [ones(1, p.Nsub - 1) 0.4], [1 0.6 0.3]};
nomes = {'sem sombra', '1 submodulo a 40 %', 'degrade 100/60/30 %'};   % para a tabela
% Texto da legenda (com acentos; a tabela fica com os nomes sem acento)
rotulos = {'sem sombra', '1 submódulo a 40 %', 'degradê 100/60/30 %'};
cores = lines(numel(padroes));
linhas = {};

figure('Position', [100 100 1000 420], 'Theme', 'light');
for n = 1:numel(padroes)
    % Grade fina (3000 pontos) para o valor dos picos sair preciso
    c = curva_pv(1000 * padroes{n}, p.Tn, p, 3000);
    cor = cores(n, :);

    subplot(1, 2, 1); hold on;
    plot(c.V, c.I, 'Color', cor, 'LineWidth', 1.5, 'DisplayName', rotulos{n});

    subplot(1, 2, 2); hold on;
    plot(c.V, c.P, 'Color', cor, 'LineWidth', 1.5, 'DisplayName', rotulos{n});
    % Maximo global marcado com um circulo cheio
    plot(c.Vmp, c.Pmp, 'o', 'Color', cor, 'MarkerFaceColor', cor, 'HandleVisibility', 'off');

    % Uma linha da tabela por maximo local; global = o de maior potencia
    for k = 1:height(c.picos)
        eh_global = c.picos.P(k) == c.Pmp;
        linhas(end + 1, :) = {nomes{n}, mat2str(padroes{n}), c.picos.V(k), ...
                              c.picos.I(k), c.picos.P(k), eh_global}; %#ok<SAGROW>
    end
    fprintf('%-22s: maximo global %.1f W em %.2f V (%d picos)\n', ...
        nomes{n}, c.Pmp, c.Vmp, height(c.picos));
end

subplot(1, 2, 1); grid on; xlabel('V [V]'); ylabel('I [A]'); title('Curva I-V');
legend('Location', 'southwest');
subplot(1, 2, 2); grid on; xlabel('V [V]'); ylabel('P [W]');
title('Curva P-V (o = máximo global)');
exportgraphics(gcf, fullfile(pasta_figs, 'e2_curvas_sombra.pdf'));

tab = cell2table(linhas, 'VariableNames', {'cenario', 'fatores', 'V', 'I', 'P', 'global'});
writetable(tab, fullfile(pasta_res, 'e2_picos.csv'));
disp(tab);
