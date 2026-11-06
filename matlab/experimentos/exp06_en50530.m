%EXP06 Eficiencia dinamica de rastreamento (perfil EN 50530) de P&O, InC e PSO.
% O perfil da EN 50530 (Anexo B) e uma sequencia de rampas trapezoidais de
% irradiancia UNIFORME (sem sombra), de lentas (~0,5 W/m^2/s) a rapidas
% (100 W/m^2/s), com ~7 h no total. A norma mede quanto da energia maxima
% disponivel o MPPT consegue tirar enquanto a irradiancia muda:
%   eta = E / Eg,  E = energia tirada do painel, Eg = energia no maximo global.
% Modelo quase-estatico (decisao D16), com o oraculo a cada 1 s.
% Temperatura fixa em 25 C: a norma separa o MPPT do efeito termico.
%
% Ajuste do passo delta do P&O e do InC: delta e o compromisso classico
%   - delta grande: segue rampas rapidas, mas oscila mais em torno do MPP;
%   - delta pequeno: oscila pouco, mas fica para tras nas rampas.
% Varremos delta = 0,5 %, 1 % e 2 % de Voc. A tolerancia do InC (eps)
% e proporcional a delta (decisao D14: eps = 1/2 |ds/dV| delta), entao ela
% e reescalada junto. O PSO nao usa delta: roda uma vez.
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
if ~isfolder(pasta_res), mkdir(pasta_res); end
arq_saida = fullfile(pasta_res, 'e6_en50530.csv');

p = parametros_painel('ztp160m');  pc = parametros_conversor(p, 12);
ds = datasheet_painel('ztp160m');  pt = parametros_termicos(ds);
ctl = projeto_pi(p, pc);  cfg0 = config_mppt(p);
cen = perfil_en50530(fullfile(raiz_projeto(), 'data', 'en50530_rampas.csv'), p.Nsub);
fprintf('Perfil EN 50530: %.2f h, Ta = %.1f ms\n', cen.t_fim / 3600, 1e3 * ctl.Ta);

% Sem series no tempo (so os totais): n_log grande economiza memoria
op = struct('termico', false, 'perdas', true, 'dt_oraculo', 1, 'n_log', 1000);

algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
deltas = [0.005 0.01 0.02];             % passo relativo a Voc
linhas = {};
for a = 1:size(algs, 1)
    if strcmp(algs{a, 2}, 'PSO')
        lista = NaN;                    % delta nao se aplica ao PSO
    else
        lista = deltas;
    end
    for dlt = lista
        cfg = cfg0;
        if ~isnan(dlt)
            cfg.delta = dlt * cfg0.Voc;
            cfg.eps = cfg0.eps * cfg.delta / cfg0.delta;   % eps proporcional a delta (D14)
        end
        r = sim_quase_estatica(cen, algs{a, 1}, cfg, ctl, p, pc, pt, op);
        linhas(end + 1, :) = {algs{a, 2}, 100 * dlt, r.eta, r.E / 3600, r.Eg / 3600, ...
            r.Eout / 3600, r.nReinicios, r.fracDCM, r.tempo_cpu / 60}; %#ok<SAGROW>
        fprintf('%s, delta = %.1f %% Voc: eta = %.4f (%.1f min de CPU)\n', ...
            algs{a, 2}, 100 * dlt, r.eta, r.tempo_cpu / 60);
        % Grava a tabela a cada rodada: se algo falhar depois, o que ja
        % rodou (minutos de CPU cada) nao se perde
        tab = cell2table(linhas, 'VariableNames', {'algoritmo', 'delta_pct_Voc', 'eta', ...
            'E_pv_Wh', 'E_max_Wh', 'E_bat_Wh', 'n_reinicios', 'frac_DCM', 'cpu_min'});
        writetable(tab, arq_saida);
    end
end
disp(tab);

% Melhor delta de cada algoritmo (maior eta)
for a = 1:size(algs, 1)
    sel = find(strcmp(tab.algoritmo, algs{a, 2}));
    [~, i] = max(tab.eta(sel));
    fprintf('Melhor %s: delta = %.1f %% Voc, eta = %.4f\n', ...
        algs{a, 2}, tab.delta_pct_Voc(sel(i)), tab.eta(sel(i)));
end
