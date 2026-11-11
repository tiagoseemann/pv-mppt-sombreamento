%EXP07 Dia real em Florianopolis com sombras sinteticas: energia e ablacao.
% Clima: PVGIS horario (irradiancia no plano, temperatura e vento) do dia
% escolhido na Tarefa 12 (resultados/dia_escolhido.txt), em hora local.
% Os dados horarios nao tem nuvens rapidas nem sombras; os eventos abaixo
% sao SINTETICOS (declarados no relatorio e gravados em e7_eventos.csv):
%   ("fator" multiplica a irradiancia; ele entra e sai em rampas lineares)
%   - nuvens rapidas, cobrem o modulo inteiro (sub = 0):
%       10:30:00-10:36:00 (6 min), fator 0,4, rampas de 20 s;
%       11:15:00-11:16:12 (72 s),  fator 0,3, rampas de 10 s;
%   - sombra de um poste andando sobre o modulo, rampas de 60 s:
%       14:00-14:45 (45 min) no submodulo N   (fator 0,3),
%       14:45-15:00 (15 min) no submodulo N-1 (fator 0,3),
%       15:00-15:30 (30 min) de volta no submodulo N, mais fraca (fator 0,5).
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
% Modelo quase-estatico, oraculo a cada 1 s (D16). Custo medido: 9 a 23 min
% de CPU por rodada (9 rodadas; varia com a carga da maquina).
%
% SERIES SALVAS: as series da variante completa (t, P, Pg, ~2 MB) ficam em
% resultados/e7_series.mat. Se esse arquivo existe, o script NAO roda as
% simulacoes: so carrega as series e refaz a figura (a tabela e7_dia.csv
% fica como esta). Para rodar tudo de novo, apague o arquivo.
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
pasta_figs = fullfile(raiz_projeto(), 'relatorio', 'figs');

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
tab_ev.hora_ini = string(dia + seconds(ev.t_ini), 'HH:mm:ss');
tab_ev.hora_fim = string(dia + seconds(ev.t_fim), 'HH:mm:ss');
writetable(tab_ev, fullfile(pasta_res, 'e7_eventos.csv'));

% Simula so a janela de sol (G > 5 W/m^2)
cen.t_fim = cen.t_fim_dia;
fprintf('Dia %s: sol de %.2f h a %.2f h (hora local), Ta = %.1f ms\n', ...
    string(dia, 'yyyy-MM-dd'), cen.t_ini_dia / h, cen.t_fim_dia / h, 1e3 * ctl.Ta);

algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
arq_series = fullfile(pasta_res, 'e7_series.mat');
if isfile(arq_series)
    load(arq_series, 'res');
    fprintf('Series carregadas de %s (simulacoes nao rodadas)\n', arq_series);
else
    variantes = {struct('termico', true,  'perdas', true),  'completo'
                 struct('termico', false, 'perdas', true),  'sem termico (T = 25 C)'
                 struct('termico', true,  'perdas', false), 'sem perdas'};
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
    save(arq_series, 'res');
end

% ---- Figura: potencia maxima disponivel x extraida ----
% Em cima o dia inteiro; embaixo o zoom na sombra do poste.
% Media movel de ~10 s: a oscilacao de 3 niveis do P&O/InC a cada Ta
% viraria uma faixa grossa no grafico do dia inteiro.
% Janela do zoom tirada da tabela de eventos: do inicio ao fim da sombra
% do poste (eventos com sub > 0), com 10 min de margem de cada lado
poste = ev.sub > 0;
t_sombra = [min(ev.t_ini(poste)), max(ev.t_fim(poste))];
janelas = {[cen.t_ini_dia, cen.t_fim_dia] / h, (t_sombra + [-600, 600]) / h};
marcas = {ceil(cen.t_ini_dia / h):floor(cen.t_fim_dia / h), ...   % horas inteiras
          ceil(2 * janelas{2}(1)) / 2:0.5:janelas{2}(2)};         % meias horas
cores = lines(size(algs, 1));
nomes = [{'máximo global'}, algs(:, 2).'];
figure('Position', [100 100 1000 650], 'Theme', 'light');
for j = 1:2
    subplot(2, 1, j); hold on;
    % Maximo global: potencia do oraculo (pico global da curva P-V com G e
    % T daquele instante), calculada uma vez por segundo (dt_oraculo). E a
    % referencia de eta_MPPT. Usa a temperatura da rodada do P&O: T muda um
    % pouco com a potencia extraida (energia eletrica nao vira calor), mas a
    % energia maxima E_max das tres rodadas difere menos de 0,1 %.
    hl = plot(res{1}.t / h, res{1}.Pg, 'k', 'LineWidth', 1.5);
    for a = 1:size(algs, 1)
        hl(a + 1) = plot(res{a}.t / h, movmean(res{a}.P, 10), 'Color', cores(a, :), ...
            'LineWidth', 1.0);
    end
    xlim(janelas{j}); xticks(marcas{j}); grid on;
    ylabel('P [W]'); xlabel('hora local [h]');
end
subplot(2, 1, 1); title(sprintf('%s, Florianópolis (modelo completo)', string(dia, 'dd/MM/yyyy')));
subplot(2, 1, 2);
title(sprintf('Sombra de poste (%s-%s)', string(dia + seconds(t_sombra(1)), 'HH:mm'), ...
    string(dia + seconds(t_sombra(2)), 'HH:mm')));
% Legenda com as curvas passadas explicitamente: montada a partir de
% 'DisplayName' o exportgraphics travava em modo batch
legend(hl, nomes, 'Location', 'northeast');
exportgraphics(gcf, fullfile(pasta_figs, 'e7_dia.pdf'));
