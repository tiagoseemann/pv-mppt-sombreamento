%EXP07 Dia real em Florianopolis com sombras sinteticas: energia e ablacao.
% Clima: PVGIS horario (irradiancia no plano, temperatura e vento) do dia
% escolhido na Tarefa 12 (resultados/dia_escolhido.txt), em hora local.
% Os dados horarios nao tem nuvens rapidas nem sombras; os eventos abaixo
% sao SINTETICOS (declarados no relatorio e gravados em e7_eventos.csv):
%   - 10:30 e 11:15: nuvens rapidas, cobrem o modulo inteiro (sub = 0);
%   - 14:00-15:30: sombra de um poste andando sobre o modulo:
%       14:00-14:45 no submodulo N (fator 0,3),
%       14:45-15:00 no submodulo N-1 (fator 0,3),
%       15:00-15:30 de volta no submodulo N, mais fraca (fator 0,5).
%     Com um submodulo sombreado a curva P-V tem dois picos: e o trecho em
%     que P&O e InC podem ficar presos no pico local e o PSO deve ganhar.
%     Nas transicoes (rampas de 60 s) os dois eventos se sobrepoem.
%
% ABLACAO: o mesmo dia com tres variantes do modelo, para medir o efeito
% de cada parte da modelagem na energia:
%   - completo: termico (ao sol o modulo fica bem acima da temperatura do
%     ar e a potencia cai ~0,4 %/K) e perdas do conversor;
%   - sem termico: celulas a 25 C o dia todo (como no trabalho anterior);
%   - sem perdas: conversor ideal (toda a potencia do painel chega a bateria).
% Modelo quase-estatico, oraculo a cada 1 s (D16). Custo ~14 min de CPU por
% rodada (9 rodadas).
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
pasta_figs = fullfile(raiz_projeto(), 'relatorio', 'figs');
if ~isfolder(pasta_res), mkdir(pasta_res); end
if ~isfolder(pasta_figs), mkdir(pasta_figs); end

p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
ds = datasheet_painel('ztp160m');  pt = parametros_termicos(ds);
ctl = projeto_pi(p, pc);  cfg = config_mppt(p);
dia = datetime(strtrim(fileread(fullfile(pasta_res, 'dia_escolhido.txt'))));
cen = dia_florianopolis(fullfile(raiz_projeto(), 'data', 'clima', 'pvgis_floripa_2020.csv'), dia, p.Nsub);

% ---- Eventos de sombra (hora local, em segundos desde 00:00) ----
h = 3600;
N = p.Nsub;
ev = table([10.5; 11.25; 14.0; 14.75; 15.0] * h, [10.6; 11.27; 14.75; 15.0; 15.5] * h, ...
           [0; 0; N; N - 1; N], [0.4; 0.3; 0.3; 0.3; 0.5], [20; 10; 60; 60; 60], ...
           {'nuvem'; 'nuvem'; 'poste'; 'poste'; 'poste (mais fraca)'}, ...
           'VariableNames', {'t_ini', 't_fim', 'sub', 'fator', 'rampa_s', 'descricao'});
cen = aplicar_sombras(cen, ev);
% Tabela dos eventos com a hora legivel, para o relatorio
tab_ev = ev;
tab_ev.hora_ini = string(datetime(dia) + seconds(ev.t_ini), 'HH:mm:ss');
tab_ev.hora_fim = string(datetime(dia) + seconds(ev.t_fim), 'HH:mm:ss');
writetable(tab_ev, fullfile(pasta_res, 'e7_eventos.csv'));

% Simula so a janela de sol (G > 5 W/m^2)
cen.t_fim = cen.t_fim_dia;
fprintf('Dia %s: sol de %.2f h a %.2f h (hora local), Ta = %.1f ms\n', ...
    string(dia, 'yyyy-MM-dd'), cen.t_ini_dia / h, cen.t_fim_dia / h, 1e3 * ctl.Ta);

variantes = {struct('termico', true,  'perdas', true),  'completo'
             struct('termico', false, 'perdas', true),  'sem termico (T = 25 C)'
             struct('termico', true,  'perdas', false), 'sem perdas'};
algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
% Series no tempo: uma amostra a cada ~1 s (n_log periodos de Ta) basta
% para a figura; os totais de energia somam todos os periodos
n_log = round(1 / ctl.Ta);

linhas = {};
res = cell(size(algs, 1), 1);          % series da variante completa (figura)
for v = 1:size(variantes, 1)
    op = variantes{v, 1};
    op.dt_oraculo = 1;  op.t_ini = cen.t_ini_dia;  op.n_log = n_log;
    for a = 1:size(algs, 1)
        r = sim_quase_estatica(cen, algs{a, 1}, cfg, ctl, p, pc, pt, op);
        linhas(end + 1, :) = {variantes{v, 2}, algs{a, 2}, r.E / 3600, r.Eout / 3600, ...
            r.Eg / 3600, r.eta, r.eta_conv, r.fracDCM, r.nReinicios, ...
            max(r.T) - 273.15, r.tempo_cpu / 60}; %#ok<SAGROW>
        fprintf('%s, %s: eta = %.4f, E = %.1f Wh (%.1f min de CPU)\n', ...
            variantes{v, 2}, algs{a, 2}, r.eta, r.E / 3600, r.tempo_cpu / 60);
        if v == 1
            res{a} = struct('t', r.t, 'P', r.P, 'Pg', r.Pg);
        end
        % Grava a tabela a cada rodada (nao perde o que ja rodou)
        tab = cell2table(linhas, 'VariableNames', {'variante', 'algoritmo', 'E_pv_Wh', ...
            'E_bat_Wh', 'E_max_Wh', 'eta_MPPT', 'eta_conv', 'frac_DCM', 'n_reinicios', ...
            'T_max_C', 'cpu_min'});
        writetable(tab, fullfile(pasta_res, 'e7_dia.csv'));
    end
end
disp(tab);
% Series guardadas fora do repositorio: permitem refazer a figura sem
% rodar as simulacoes de novo
save(fullfile(tempdir, 'e7_series.mat'), 'res', 'cen', 'algs');

% ---- Figura: potencia maxima disponivel x extraida ----
% Em cima o dia inteiro; embaixo o zoom na sombra do poste.
% Media movel de ~10 s: a oscilacao de 3 niveis do P&O/InC a cada Ta
% viraria uma faixa grossa no grafico do dia inteiro.
janelas = {[cen.t_ini_dia, cen.t_fim_dia] / h, [13.8, 15.7]};
cores = lines(size(algs, 1));
nomes = [{'maximo global'}, algs(:, 2).'];
figure('Position', [100 100 1000 650], 'Theme', 'light');
for j = 1:2
    subplot(2, 1, j); hold on;
    hl = plot(res{1}.t / h, res{1}.Pg, 'k', 'LineWidth', 1.5);
    for a = 1:size(algs, 1)
        hl(a + 1) = plot(res{a}.t / h, movmean(res{a}.P, 10), 'Color', cores(a, :), ...
            'LineWidth', 1.0);
    end
    xlim(janelas{j}); grid on; ylabel('P [W]');
end
subplot(2, 1, 1); title(sprintf('%s, Florianopolis (modelo completo)', string(dia, 'dd/MM/yyyy')));
% Legenda com as curvas passadas explicitamente: montada a partir de
% 'DisplayName' o exportgraphics travava em modo batch
legend(hl, nomes, 'Location', 'northeast');
subplot(2, 1, 2); title('Sombra de poste (14:00-15:30)'); xlabel('hora local');
exportgraphics(gcf, fullfile(pasta_figs, 'e7_dia.pdf'));
