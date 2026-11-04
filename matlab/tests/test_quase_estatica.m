% Testes da simulacao quase-estatica (conversor + PI assentados a cada Ta,
% termico por Euler), validada contra a simulacao dinamica (sim_dinamica).
function tests = test_quase_estatica
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
pc = parametros_conversor(p, 12);
[ctl, ~] = projeto_pi(p, pc);
% Cenario da validacao: 4 s, sombra de 60 % no 3o submodulo a partir de t = 2 s
cen.G = @(t) [1000 1000 1000 - 600 * (t > 2)];
cen.Tamb = @(t) 298.15;  cen.vw = @(t) 1;  cen.t_fim = 4;
tc.TestData = struct('p', p, 'pc', pc, 'ctl', ctl, 'cen', cen, ...
    'pt', parametros_termicos(datasheet_painel('ztp160m')), 'cfg', config_mppt(p));
end

function [rq, rd] = compara(tc, alg)
% Roda as duas simulacoes no cenario da validacao e mostra a diferenca de energia.
d = tc.TestData;
op = struct('termico', true, 'perdas', false);
rd = sim_dinamica(d.cen, alg, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
rq = sim_quase_estatica(d.cen, alg, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
fprintf('%s: E din = %.3f J, E qe = %.3f J, dif = %+.3f %%; eta din = %.4f, eta qe = %.4f\n', ...
    func2str(alg), rd.E, rq.E, 100 * (rq.E / rd.E - 1), rd.eta, rq.eta);
end

function test_energia_igual_a_dinamica_po(tc)
% P&O: energia do quase-estatico a menos de 1 % da dinamica (degrau de sombra em 2 s).
[rq, rd] = compara(tc, @mppt_po);
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
end

function test_energia_igual_a_dinamica_inc(tc)
% InC: energia do quase-estatico a menos de 1 % da dinamica.
[rq, rd] = compara(tc, @mppt_inc);
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
end

function test_energia_igual_a_dinamica_pso(tc)
% PSO (degraus grandes de referencia, o pior caso da hipotese quase-estatica): energia a menos de 1 %.
% Medido: -0,89 %. ATENCAO, margem pequena: com o degrau de sombra numa
% fronteira de periodo (57 Ta) a diferenca e -1,12 %. Nos degraus grandes o
% transitorio do PI passa por tensoes entre as particulas (perto do pico),
% com mais potencia que nas pontas: o quase-estatico subestima o PSO.
% Aqui o degrau em 2 s cai dentro de um periodo e o trapezio soma ~+0,25 %.
[rq, rd] = compara(tc, @mppt_pso);
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
verifyEqual(tc, rq.nReinicios, rd.nReinicios);
verifyEqual(tc, rq.Eg, rd.Eg, 'RelTol', 1e-3);
end

function test_oraculo_eficiencia_unitaria(tc)
% Parado no Vmp global com G e T constantes, eta = 1 (mesma conta de E e Eg).
d = tc.TestData;  G = [1000 1000 400];
c = curva_pv(G, d.p.Tn, d.p);
[~, Vg] = oraculo_pmax(G, d.p.Tn, d.p);
cfg = d.cfg;  cfg.Vref0 = Vg;
cen = cenario_constante(G, 298.15, 1, 30 * d.ctl.Ta);
r = sim_quase_estatica(cen, @mppt_fixo, cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', false));
verifyEqual(tc, r.eta, 1, 'AbsTol', 1e-6);
verifyEqual(tc, r.P(end), c.Pmp, 'RelTol', 1e-3);
verifyTrue(tc, isnan(r.nReinicios));
end

function test_oraculo_segurado(tc)
% Com dt_oraculo > Ta e G, T constantes, segurar o oraculo nao muda Eg.
d = tc.TestData;
cen = cenario_constante([1000 800 300], 298.15, 1, 40 * d.ctl.Ta);
op = struct('termico', false);
r1 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
op.dt_oraculo = 10 * d.ctl.Ta;
r2 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
verifyEqual(tc, r2.Eg, r1.Eg, 'RelTol', 1e-9);
verifyEqual(tc, r2.E, r1.E, 'RelTol', 1e-9);
end

function test_noite(tc)
% Sem irradiancia: E = Eg = 0, eta indefinida (NaN) e nenhum ponto inviavel.
d = tc.TestData;
cen = cenario_constante([0 0 0], 290, 1, 10 * d.ctl.Ta);
r = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', true));
verifyEqual(tc, [r.E, r.Eg, r.Eout], [0 0 0]);
verifyTrue(tc, isnan(r.eta) && isnan(r.eta_conv));
verifyEqual(tc, r.fracInviavel, 0);
end

function test_perdas_conversor(tc)
% Com perdas o conversor entrega menos que o painel (eta_conv < 1); sem perdas, eta_conv = 1.
d = tc.TestData;
cen = cenario_constante([1000 1000 1000], 298.15, 1, 20 * d.ctl.Ta);
r1 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', false));
r0 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, ...
    struct('termico', false, 'perdas', false));
% ~160 W: no buck-boost i_L = I/d ~ 20 A, perdas ~ 19 W (eta ~ 0,885)
verifyGreaterThan(tc, r1.eta_conv, 0.8);
verifyLessThan(tc, r1.eta_conv, 1);
verifyEqual(tc, r0.eta_conv, 1, 'AbsTol', 1e-12);
verifyEqual(tc, r1.E, r0.E, 'RelTol', 1e-12);     % perdas nao mudam o que sai do painel
end

function test_t_ini(tc)
% t_ini desloca a janela simulada: r.t comeca em t_ini + Ta e o numero de periodos segue a duracao.
d = tc.TestData;  Ta = d.ctl.Ta;
cen = cenario_constante([1000 1000 1000], 298.15, 1, 100);
r = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, ...
    struct('termico', false, 't_ini', 100 - 10.5 * Ta));
verifyEqual(tc, numel(r.t), 10);
verifyEqual(tc, r.t(1), 100 - 9.5 * Ta, 'AbsTol', 1e-9);
end
