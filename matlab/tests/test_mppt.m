% Testes dos algoritmos de MPPT sobre o mapa estatico do painel.
% Painel generico a 25 C. Picos de referencia (test_sombreamento):
%   [1000 1000 1000]: um pico, 138,2 W
%   [1000 1000  400]: global 89,2 W em 11,6 V; local ~62 W perto de 19,6 V
%   [1000  600  300]: tres picos, global 58,0 W
function tests = test_mppt
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
tc.TestData.p = p;
tc.TestData.cfg = config_mppt(p);
end

function test_po_uniforme_converge(tc)
% Sem sombra a curva P-V tem um pico so: o P&O deve chegar a ele.
p = tc.TestData.p;  G = [1000 1000 1000];
r = rastrear_estatico(@mppt_po, tc.TestData.cfg, @(k) G, p.Tn, p, 150);
Pmp = curva_pv(G, p.Tn, p).Pmp;
verifyGreaterThan(tc, mean(r.P(end - 20:end)), 0.98 * Pmp);
end

function test_po_preso_no_maximo_local(tc)
% Caracteriza a falha que o trabalho investiga: partindo perto de Voc, o P&O para no pico local.
p = tc.TestData.p;  G = [1000 1000 400];
r = rastrear_estatico(@mppt_po, tc.TestData.cfg, @(k) G, p.Tn, p, 150);
Pg = curva_pv(G, p.Tn, p).Pmp;
verifyLessThan(tc, mean(r.P(end - 20:end)), 0.75 * Pg);
end

function test_inc_para_no_mpp(tc)
% O InC deve parar (tensao constante) no MPP de uma curva sem sombra.
p = tc.TestData.p;  G = [1000 1000 1000];
r = rastrear_estatico(@mppt_inc, tc.TestData.cfg, @(k) G, p.Tn, p, 150);
verifyLessThan(tc, std(r.V(end - 10:end)), 1e-9);
verifyGreaterThan(tc, r.P(end), 0.98 * curva_pv(G, p.Tn, p).Pmp);
end

function test_pso_acha_global(tc)
% O PSO deve achar o pico global em 3 padroes de sombra e 5 sementes.
p = tc.TestData.p;
for G = {[1000 1000 400], [1000 600 300], [1000 1000 1000]}
    for seed = 1:5
        cfg = tc.TestData.cfg;  cfg.seed = seed;
        r = rastrear_estatico(@mppt_pso, cfg, @(k) G{1}, p.Tn, p, 120);
        verifyGreaterThan(tc, r.P(end), 0.98 * curva_pv(G{1}, p.Tn, p).Pmp, ...
            sprintf('G = %s, semente %d', mat2str(G{1}), seed));
    end
end
end

function test_pso_reinicia_quando_sombra_muda(tc)
% Quando a sombra muda (138 -> 58 W), o PSO deve reiniciar a busca e achar o novo global.
p = tc.TestData.p;
Gf = @(k) [1000 1000 1000] .* (k <= 80) + [1000 600 300] .* (k > 80);
[r, e] = rastrear_estatico(@mppt_pso, tc.TestData.cfg, Gf, p.Tn, p, 200);
verifyGreaterThan(tc, r.P(end), 0.98 * curva_pv([1000 600 300], p.Tn, p).Pmp);
verifyGreaterThanOrEqual(tc, e.nReinicios, 1);
end

function test_inc_ramo_manter(tc)
% Com a referencia mantida no MPP, uma queda de irradiancia (1000 -> 800) deve mover Vref de sign(dI)*delta.
p = tc.TestData.p;  cfg = tc.TestData.cfg;  G = [1000 1000 1000];
[~, e] = rastrear_estatico(@mppt_inc, cfg, @(k) G, p.Tn, p, 150);
verifyEqual(tc, e.dVref, 0);             % esta parado no MPP
V = e.Vref;                              % tensao mantida
I = painel_sombreado(V, 0.8 * G, p.Tn, p);
[Vnovo, ~] = mppt_inc(V, I, e, cfg);
verifyEqual(tc, Vnovo, V + sign(I - e.Iant) * cfg.delta, 'AbsTol', 1e-12);
verifyLessThan(tc, Vnovo, V);            % menos luz: o MPP vai para a esquerda
end

function test_limites_respeitados(tc)
% Os tres algoritmos mantem Vref em [Vmin, Vmax] partindo perto de cada limite.
p = tc.TestData.p;  G = [1000 1000 400];
algs = {@mppt_po, @mppt_inc, @mppt_pso};
for a = 1:numel(algs)
    for partida = {'baixo', 'alto'}
        cfg = tc.TestData.cfg;
        if strcmp(partida{1}, 'baixo')
            cfg.Vref0 = cfg.Vmin + 0.5 * cfg.delta;
        else
            cfg.Vref0 = cfg.Vmax - 0.5 * cfg.delta;
        end
        r = rastrear_estatico(algs{a}, cfg, @(k) G, p.Tn, p, 100);
        msg = sprintf('%s, partida %s', func2str(algs{a}), partida{1});
        verifyGreaterThanOrEqual(tc, min(r.V), cfg.Vmin - 1e-12, msg);
        verifyLessThanOrEqual(tc, max(r.V), cfg.Vmax + 1e-12, msg);
    end
end
end
