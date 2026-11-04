% Testes da simulacao dinamica em malha fechada (EDO reduzida, decisao D15:
% conversor medio + PI + MPPT + painel resolvido a cada avaliacao + termico)
% e do oraculo de potencia maxima global.
function tests = test_sim_dinamica
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
pc = parametros_conversor(p, 12);
[ctl, ~] = projeto_pi(p, pc);
tc.TestData = struct('p', p, 'pc', pc, 'ctl', ctl, ...
    'pt', parametros_termicos(datasheet_painel('ztp160m')), 'cfg', config_mppt(p));
end

function test_oraculo_pico_global(tc)
% O oraculo acha o pico GLOBAL (nao o local perto de Voc) e refina a grade grossa.
p = tc.TestData.p;  G = [1000 1000 400];
[Pg, Vg] = oraculo_pmax(G, p.Tn, p);
c = curva_pv(G, p.Tn, p, 3000);
verifyGreaterThanOrEqual(tc, Pg, c.Pmp - 1e-6);
verifyEqual(tc, Pg, c.Pmp, 'RelTol', 1e-4);
verifyEqual(tc, Vg, c.Vmp, 'AbsTol', 0.05);
end

function test_pi_segue_referencia(tc)
% Partindo da tensao de partida (0,85 Voc), o PI leva o painel ao degrau V_ref = 16 V.
d = tc.TestData;  cfg = d.cfg;  cfg.Vref0 = 16;
cen = cenario_constante([1000 1000 1000], 298.15, 1, 20 * d.ctl.Ta);
op = struct('termico', false, 'V0', d.cfg.Vref0);
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, op);
verifyEqual(tc, r.V(end), 16, 'RelTol', 0.005);
verifyEqual(tc, r.V(1), 16, 'RelTol', 0.02);     % ja acomodou no 1o Ta (Femia)
end

function test_oraculo_eficiencia_unitaria(tc)
% Parado no Vmp global, a energia integrada bate com a do oraculo (eta ~ 1).
d = tc.TestData;  G = [1000 1000 400];
c = curva_pv(G, d.p.Tn, d.p);
cfg = d.cfg;  cfg.Vref0 = c.Vmp;
cen = cenario_constante(G, 298.15, 1, 30 * d.ctl.Ta);
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', false));
verifyGreaterThan(tc, r.eta, 0.99);
verifyLessThanOrEqual(tc, r.eta, 1 + 1e-6);
end

function test_termico_balanco(tc)
% O modulo parte do equilibrio termico em aberto (quente) e esfria a taxa Pel/(m*cp).
d = tc.TestData;  cfg = d.cfg;  cfg.Vref0 = 17;
cen = cenario_constante([1000 1000 1000], 298.15, 1, 20 * d.ctl.Ta);
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', true));
verifyGreaterThan(tc, r.T(end), 298.15 + 10);
% Em T0 o balanco sem eletricidade e nulo; extraindo Pel o modulo esfria a
% dT/dt ~ -Pel/(m*cp) (a conveccao e a radiacao quase nao mudam em < 1 s)
queda = r.T0 - r.T(end);
queda_esperada = r.E / (d.pt.mcp_area * d.pt.A);
verifyEqual(tc, queda, queda_esperada, 'RelTol', 0.05);
end

function test_oraculo_noite(tc)
% Sem irradiancia nao ha potencia a rastrear: o oraculo devolve zero sem otimizar.
p = tc.TestData.p;
[Pg, Vg] = oraculo_pmax([0 0 0], p.Tn, p);
verifyEqual(tc, [Pg, Vg], [0, 0]);
end

function test_baixa_irradiancia_diodo_bloqueia(tc)
% Em 20 W/m^2 que caem a zero (anoitecer), i_L nunca fica negativa (diodo) e E >= 0.
d = tc.TestData;  G = [20 20 20];
c = curva_pv(G, d.p.Tn, d.p);
cfg = d.cfg;  cfg.Vref0 = c.Vmp;
op = struct('termico', false, 'V0', 0.95 * c.V(end));
cen = cenario_constante(G, 298.15, 1, 20 * d.ctl.Ta);
cen.G = @(t) G * (t < 10 * d.ctl.Ta);       % G vai a zero na metade
r = sim_dinamica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, op);
% i_L >= 0 a menos do erro do integrador (AbsTol = 1e-7 A; medido ~ -1,4e-7):
% (sem o bloqueio do diodo, i_L chega a -0,31 A neste mesmo caso)
verifyGreaterThan(tc, r.iLmin, -1e-6);
verifyGreaterThanOrEqual(tc, r.E, 0);
verifyTrue(tc, all(isfinite(r.V)) && all(isfinite(r.I)));
verifyEqual(tc, r.Pg(end), 0);              % noite: oraculo zerado
end

function test_pso_conta_reinicios(tc)
% Com o PSO, o registro guarda o numero de reinicios do enxame; com o P&O fica NaN.
d = tc.TestData;  G = [1000 1000 400];
cen = cenario_constante(G, 298.15, 1, 10 * d.ctl.Ta);
op = struct('termico', false);
r = sim_dinamica(cen, @mppt_pso, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
verifyEqual(tc, r.nReinicios, 0);
verifyTrue(tc, all(isfinite(r.V)));
r = sim_dinamica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
verifyTrue(tc, isnan(r.nReinicios));
end

function test_ponto_dcm_estavel(tc)
% ZTP-160M a 200 W/m^2 e 1,1 Vmp (ponto excluido do projeto do PI por DCM): a malha fica estavel.
p = parametros_painel('ztp160m');
pc = parametros_conversor(p, 12);
[ctl, ~] = projeto_pi(p, pc);
pt = parametros_termicos(datasheet_painel('ztp160m'));
G = [200 200 200];
c = curva_pv(G, p.Tn, p);
cfg = config_mppt(p);  cfg.Vref0 = 1.1 * c.Vmp;
% Parte do Vmp (fora do ponto) para que haja um transitorio de verdade
op = struct('termico', false, 'T', p.Tn, 'V0', c.Vmp);
cen = cenario_constante(G, 298.15, 1, 30 * ctl.Ta);
r = sim_dinamica(cen, @mppt_fixo, cfg, ctl, p, pc, pt, op);
verifyTrue(tc, all(isfinite(r.V)) && all(isfinite(r.I)));
verifyLessThan(tc, max(abs(r.V(end - 4:end) - cfg.Vref0)) / cfg.Vref0, 0.02);
% Confere que o ponto testado e mesmo DCM (senao o teste nao testa nada)
verifyGreaterThan(tc, r.fracDCM, 0.5);
end
