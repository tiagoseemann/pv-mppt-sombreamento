%EXP01 Validacao do ZTP-160M: pontos de STC, coeficiente de Pmax e baixa irradiancia.
% O datasheet nao traz curvas I-V; a validacao usa o que ele publica:
%   (a) pontos de STC (impostos no ajuste: confirmam que a extracao fechou)
%   (b) coeficiente termico de Pmax, que NAO entra no ajuste (teste independente)
%   (c) identificabilidade do 2o diodo: a razao I02/I01 que o datasheet nao fixa
setup_path();
ds = datasheet_painel('ztp160m');
v = validar_painel('ztp160m');

% ---- Tabela de validacao (1 diodo x 2 diodos) ----
modelo = {'1 diodo'; '2 diodos'};
tab = table(modelo, 100 * v.erroPmax_STC(:), 100 * v.erroVoc_STC(:), ...
    100 * v.gamaP_modelo(:), 100 * ds.gamaP * [1; 1], ...
    'VariableNames', {'modelo', 'erroPmax_pct', 'erroVoc_pct', ...
                      'gamaP_modelo_pct_K', 'gamaP_datasheet_pct_K'});
disp(tab);
writetable(tab, fullfile(raiz_projeto(), 'resultados', 'e1_validacao_painel.csv'));

% ---- Eficiencia relativa: eta(G)/eta(1000) = (Pmax(G)/G) / (Pmax(1000)/1000) ----
% Sem dado medido em baixa irradiancia, a figura mostra a DIFERENCA entre
% os modelos, nao qual deles acerta.
eta_rel = (v.Pmax_G ./ v.G) ./ (v.Pmax_G(:, 1) / 1000);
disp(array2table(100 * eta_rel, 'VariableNames', compose('G%d', v.G), ...
    'RowNames', modelo));
% Tema claro: a figura vai para o relatorio impresso (o MATLAB pode estar no escuro)
figure('Position', [100 100 600 400], 'Theme', 'light');
plot(v.G, 100 * eta_rel(1, :), 'o--', v.G, 100 * eta_rel(2, :), 's-', 'LineWidth', 1.3);
grid on; xlabel('G [W/m^2]'); ylabel('\eta(G) / \eta(STC) [%]');
legend(modelo, 'Location', 'southeast');
title('ZTP-160M: eficiencia relativa em baixa irradiancia');
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e1_eficiencia_relativa.pdf'));

% ---- Identificabilidade do 2o diodo (decisao D9) ----
% Cada linha e um modelo de 2 diodos que satisfaz as 5 condicoes do
% datasheet (residuo ~0). A faixa de eta200_rel e a incerteza que o
% datasheet deixa na previsao em baixa irradiancia.
tab_id = identificabilidade_2d('ztp160m');
disp(tab_id);
writetable(tab_id, fullfile(raiz_projeto(), 'resultados', 'e1_identificabilidade.csv'));

figure('Position', [100 100 600 400], 'Theme', 'light');
semilogx(tab_id.razao_I02_I01, 100 * tab_id.eta200_rel, 's-', 'LineWidth', 1.3);
grid on; xlabel('I_{02} / I_{01}'); ylabel('\eta(200) / \eta(STC) [%]');
title('ZTP-160M: eficiencia relativa em 200 W/m^2 x razao I_{02}/I_{01}');
exportgraphics(gcf, fullfile(raiz_projeto(), 'relatorio', 'figs', 'e1_identificabilidade.pdf'));
