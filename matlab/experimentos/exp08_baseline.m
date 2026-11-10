%EXP08 Modelo do trabalho anterior x modelo completo no mesmo dia (sem sombra).
% Responde "quanto as simplificacoes do trabalho anterior erravam" na
% energia de um dia real (mesmo dia do E7, mas sem os eventos de sombra).
%   - anterior: modelo de 1 diodo, conversor ideal (sem perdas) e celulas a
%     25 C o dia todo (sem modelo termico);
%   - completo: modelo de 2 diodos, conversor com perdas e modelo termico.
% Os dois com P&O (delta padrao) e o mesmo PI. A comparacao e pela energia
% que chega a bateria, que e o que interessa ao usuario do sistema.
% Sinal esperado: o anterior SUPERESTIMA a energia (ignora o aquecimento do
% modulo, que derruba a potencia em ~0,4 %/K, e as perdas do conversor).
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
if ~isfolder(pasta_res), mkdir(pasta_res); end

ds = datasheet_painel('ztp160m');
p2 = parametros_painel('ztp160m');           % 2 diodos (modelo deste trabalho)
p1 = extrair_parametros(ds, '1d');           % 1 diodo (trabalho anterior)
pc = parametros_conversor(p2, 12);  pt = parametros_termicos(ds);
ctl = projeto_pi(p2, pc);
dia = datetime(strtrim(fileread(fullfile(pasta_res, 'dia_escolhido.txt'))));
cen = dia_florianopolis(fullfile(raiz_projeto(), 'data', 'clima', 'pvgis_floripa_2020.csv'), dia, p2.Nsub);
cen.t_fim = cen.t_fim_dia;                   % so a janela de sol

% Series a cada ~1 s (so para a temperatura maxima); totais somam tudo
n_log = round(1 / ctl.Ta);
opA = struct('termico', false, 'perdas', false, 'dt_oraculo', 1, 't_ini', cen.t_ini_dia, 'n_log', n_log);
opB = struct('termico', true,  'perdas', true,  'dt_oraculo', 1, 't_ini', cen.t_ini_dia, 'n_log', n_log);
rA = sim_quase_estatica(cen, @mppt_po, config_mppt(p1), ctl, p1, conversor_ideal(pc), pt, opA);
fprintf('anterior: %.1f Wh na bateria (%.1f min de CPU)\n', rA.Eout / 3600, rA.tempo_cpu / 60);
rB = sim_quase_estatica(cen, @mppt_po, config_mppt(p2), ctl, p2, pc, pt, opB);
fprintf('completo: %.1f Wh na bateria (%.1f min de CPU)\n', rB.Eout / 3600, rB.tempo_cpu / 60);

tab = table({'anterior (1d, ideal, T = 25 C)'; 'completo (2d, perdas, termico)'}, ...
    [rA.E; rB.E] / 3600, [rA.Eout; rB.Eout] / 3600, [rA.eta; rB.eta], ...
    [max(rA.T); max(rB.T)] - 273.15, ...
    'VariableNames', {'modelo', 'E_pv_Wh', 'E_bat_Wh', 'eta_MPPT', 'T_max_C'});
% Diferenca relativa ao modelo completo (positivo = o anterior superestima)
tab.dif_vs_completo_pct = 100 * (tab.E_bat_Wh - tab.E_bat_Wh(2)) / tab.E_bat_Wh(2);
writetable(tab, fullfile(pasta_res, 'e8_baseline.csv'));
disp(tab);
