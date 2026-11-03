%EXP05 Eficiencia de P&O, InC e PSO em padroes de sombra estaticos.
% Para cada padrao de sombra (irradiancia fixa) roda cada algoritmo por 200
% periodos Ta sobre o mapa estatico do painel (rastrear_estatico) e mede:
%   eta         : potencia media nos ultimos 21 passos / Pmp global da curva
%   passos_conv : primeiro passo a partir do qual a potencia fica a menos de
%                 1 % de Pmp do valor final (o P&O, que oscila em 3 niveis
%                 com amplitude menor que isso, tambem "converge").
%                 Cuidado ao ler: a oscilacao do P&O/InC pode ficar toda
%                 dentro dessa faixa de 1 %, entao "1 passo" significa que a
%                 partida (0,85*Voc) ja estava perto do pico em que ele parou,
%                 nao que o algoritmo seja instantaneo.
% O PSO e aleatorio: roda com 10 sementes. P&O e InC sao deterministicos.
clear; clc; close all;
setup_path();

pasta_res = fullfile(raiz_projeto(), 'resultados');
if ~isfolder(pasta_res), mkdir(pasta_res); end

p = parametros_painel('ztp160m');  cfg = config_mppt(p);
padroes = {[1 1 1], [1 1 0.4], [1 0.6 0.3], [1 0.3 0.3], [0.8 0.8 0.2], [1 0.5 0.5]};
algs = {@mppt_po, 'P&O'; @mppt_inc, 'InC'; @mppt_pso, 'PSO'};
nPassos = 200;

linhas = {};
for g = 1:numel(padroes)
    G = 1000 * padroes{g}(1:p.Nsub);
    Pg = curva_pv(G, p.Tn, p).Pmp;          % pico global (referencia de eficiencia)
    for a = 1:size(algs, 1)
        if strcmp(algs{a, 2}, 'PSO')
            nSeeds = 10;
        else
            nSeeds = 1;
        end
        for seed = 1:nSeeds
            c = cfg;  c.seed = seed;
            r = rastrear_estatico(algs{a, 1}, c, @(k) G, p.Tn, p, nPassos);
            eta = mean(r.P(end - 20:end)) / Pg;
            % ultimo passo em que a potencia ainda estava longe do valor final
            kFora = find(abs(r.P - r.P(end)) > 0.01 * Pg, 1, 'last');
            if isempty(kFora)
                conv = 1;                    % ja comecou no valor final
            else
                conv = kFora + 1;
            end
            linhas(end + 1, :) = {mat2str(padroes{g}), algs{a, 2}, seed, eta, conv}; %#ok<SAGROW>
        end
    end
end

tab = cell2table(linhas, 'VariableNames', {'sombra', 'algoritmo', 'semente', 'eta', 'passos_conv'});
writetable(tab, fullfile(pasta_res, 'e5_mppt_estatico.csv'));
disp(groupsummary(tab, {'sombra', 'algoritmo'}, {'mean', 'min'}, {'eta', 'passos_conv'}));
