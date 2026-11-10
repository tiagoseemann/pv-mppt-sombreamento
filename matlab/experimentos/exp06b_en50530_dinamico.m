%EXP06B Trecho do perfil EN 50530 no modelo DINAMICO: figura de P&O, InC e PSO.
% O E6 roda o perfil inteiro (~7 h) no modelo quase-estatico. Aqui um trecho
% curto roda no modelo dinamico completo (sim_dinamica, EDO de 4 estados,
% decisao D15), para mostrar na figura como cada algoritmo segue as rampas:
%   uma linha da sequencia B.3: G entre 300 e 1000 W/m^2, inclinacao de
%   50 W/m^2/s (rampas de 14 s), patamares de 10 s, 2 trapezios.
%   A espera inicial em 300 W/m^2 foi encurtada de 300 s (norma) para 10 s,
%   so para os algoritmos sairem da partida (0,85 Voc) e acharem o MPP.
% Temperatura fixa em 25 C, como no E6. Duracao: 10 + 2*(2*14 + 2*10) = 106 s.
% Custo medido: 72 a 164 s de CPU por algoritmo (~0,7 a 1,6 s por s simulado).
% Na figura, os "dentes" do PSO nas rampas sao as buscas: a cada variacao
% de mais de 10 % na potencia ele reinicia e testa as particulas de novo.
% Para comparar, o mesmo trecho tambem roda no quase-estatico (com o oraculo
% a cada Ta, como no teste do D16): as eficiencias devem ficar proximas.
% Tabela: resultados/e6_dinamico.csv (eta nos dois modelos e reinicios do PSO).
clear; clc; close all;
setup_path();

pasta_figs = fullfile(raiz_projeto(), 'relatorio', 'figs');
pasta_res = fullfile(raiz_projeto(), 'resultados');

p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
ds = datasheet_painel('ztp160m');  pt = parametros_termicos(ds);
ctl = projeto_pi(p, pc);  cfg = config_mppt(p);

% Cenario: uma linha no formato de data/en50530_rampas.csv, num arquivo
% temporario, montada pela mesma funcao do perfil completo
arq = [tempname '.csv'];
writelines(["sequencia,G_baixo,G_alto,inclinacao_Wm2s,patamar_s,repeticoes,espera_s"
             "B3,300,1000,50,10,2,10"], arq);
cen = perfil_en50530(arq, p.Nsub);
delete(arq);
fprintf('Trecho: %.0f s simulados, Ta = %.1f ms\n', cen.t_fim, 1e3 * ctl.Ta);

algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
op = struct('termico', false);
res = cell(size(algs, 1), 1);
linhas = {};
for a = 1:size(algs, 1)
    res{a} = sim_dinamica(cen, algs{a, 1}, cfg, ctl, p, pc, pt, op);
    rq = sim_quase_estatica(cen, algs{a, 1}, cfg, ctl, p, pc, pt, op);
    fprintf('%s: eta dinamico = %.4f, quase-estatico = %.4f (%.0f s de CPU no dinamico)\n', ...
        algs{a, 2}, res{a}.eta, rq.eta, res{a}.tempo_cpu);
    % Uma linha por algoritmo: eta nos dois modelos e reinicios do PSO
    % (NaN para P&O e InC, que nao reiniciam)
    linhas(end + 1, :) = {algs{a, 2}, res{a}.eta, rq.eta, res{a}.nReinicios, ...
                          rq.nReinicios, res{a}.tempo_cpu / 60}; %#ok<SAGROW>
end
tab = cell2table(linhas, 'VariableNames', {'algoritmo', 'eta_dinamico', ...
    'eta_quase_estatico', 'n_reinicios_dinamico', 'n_reinicios_quase_estatico', 'cpu_min_dinamico'});
writetable(tab, fullfile(pasta_res, 'e6_dinamico.csv'));
disp(tab);

% ---- Figura: irradiancia em cima, potencia embaixo ----
% r.P e o produto das medias de v e I na janela de medida de cada Ta (o
% que o MPPT ve); r.Pg e o oraculo (pico global, media das duas pontas).
cores = lines(size(algs, 1));
figure('Position', [100 100 1000 600], 'Theme', 'light');
subplot(3, 1, 1);
tt = linspace(0, cen.t_fim, 2000);
Gt = zeros(size(tt));
for k = 1:numel(tt)
    Gk = cen.G(tt(k));
    Gt(k) = Gk(1);                      % irradiancia uniforme: igual nos submodulos
end
plot(tt, Gt, 'k', 'LineWidth', 1.2); grid on;
ylabel('G [W/m^2]'); xlim([0 cen.t_fim]);
title('EN 50530, B.3: 300 \leftrightarrow 1000 W/m^2 a 50 W/m^2/s (modelo dinâmico, 25 °C)');
subplot(3, 1, [2 3]); hold on;
hl = plot(res{1}.t, res{1}.Pg, 'k', 'LineWidth', 1.5);
for a = 1:size(algs, 1)
    hl(a + 1) = plot(res{a}.t, res{a}.P, 'Color', cores(a, :), 'LineWidth', 1.0);
end
grid on; xlim([0 cen.t_fim]); xlabel('t [s]'); ylabel('P_{pv} [W]');
nomes = cell(1, size(algs, 1) + 1);
nomes{1} = 'máximo global';
for a = 1:size(algs, 1)
    nomes{a + 1} = sprintf('%s (\\eta = %.3f)', algs{a, 2}, res{a}.eta);
end
% Legenda com as curvas explicitas (com 'DisplayName' o exportgraphics trava em batch)
legend(hl, nomes, 'Location', 'southeast');
exportgraphics(gcf, fullfile(pasta_figs, 'e6_dinamico.pdf'));
