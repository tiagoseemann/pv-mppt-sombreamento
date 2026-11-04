% Testes da simulacao quase-estatica (conversor + PI assentados a cada Ta,
% termico por Euler), validada contra a simulacao dinamica (sim_dinamica).
function tests = test_quase_estatica
tests = functiontests(localfunctions);
end

function setupOnce(tc)
p = parametros_painel('generico');
pc = parametros_conversor(p, 12);
[ctl, ~] = projeto_pi(p, pc);
% Cenario da validacao: 4 s, sombra de 60 % no 3o submodulo a partir de ~2 s.
% O degrau cai EXATAMENTE numa fronteira de periodo Ta: assim o trapezio nas
% pontas nao soma o vies de "meio degrau" (um degrau dentro de um periodo
% conta pela metade; com o degrau em 2,000 s isso somava ~+0,25 %) e a
% diferenca medida e so a da hipotese quase-estatica.
tDegrau = round(2 / ctl.Ta) * ctl.Ta;
cen.G = @(t) [1000 1000 1000 - 600 * (t >= tDegrau)];
cen.Tamb = @(t) 298.15;  cen.vw = @(t) 1;  cen.t_fim = 4;
tc.TestData = struct('p', p, 'pc', pc, 'ctl', ctl, 'cen', cen, ...
    'pt', parametros_termicos(datasheet_painel('ztp160m')), 'cfg', config_mppt(p));
% Painel real (ZTP-160M) para a janela representativa
pz = parametros_painel('ztp160m');
pcz = parametros_conversor(pz, 12);
[ctlz, ~] = projeto_pi(pz, pcz);
tc.TestData.ztp = struct('p', pz, 'pc', pcz, 'ctl', ctlz, 'cfg', config_mppt(pz));
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
% P&O: energia do quase-estatico a menos de 1 % da dinamica (degrau de sombra em ~2 s).
% Medido: +0,13 %.
[rq, rd] = compara(tc, @mppt_po);
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
verifyEqual(tc, rq.nAvisosNewton, 0);
end

function test_energia_igual_a_dinamica_inc(tc)
% InC: energia do quase-estatico a menos de 1 % da dinamica.
% Medido: +0,14 %.
[rq, rd] = compara(tc, @mppt_inc);
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
end

function test_energia_igual_a_dinamica_pso(tc)
% PSO buscando quase o tempo todo: o quase-estatico fica na faixa da D16 (-1,5 % a 0).
% A D16 aceita este vies CONSERVADOR (~-1,1 %) da busca continua: nos
% degraus grandes o transitorio do PI passa por tensoes entre as
% particulas (perto do pico), com mais potencia que nas pontas, e o
% quase-estatico so conta a potencia em V_ref. Medido: -1,12 %.
[rq, rd] = compara(tc, @mppt_pso);
dif = rq.E / rd.E - 1;
verifyGreaterThan(tc, dif, -0.015);
verifyLessThan(tc, dif, 0);
verifyEqual(tc, rq.nReinicios, rd.nReinicios);
verifyEqual(tc, rq.Eg, rd.Eg, 'RelTol', 1e-3);
end

function test_energia_pso_janela_representativa(tc)
% PSO numa janela tipica de 20 s (busca de ~1-2 s e depois segura o gbest): energia a menos de 1 %.
% ZTP-160M, 1000 W/m^2 uniforme ate ~5 s, depois [1000 1000 400]; degrau
% numa fronteira de periodo Ta (mesmo motivo do cenario de 4 s).
% Medido: -0,32 % (E din = 1956,8 J, E qe = 1950,6 J; eta 0,976 x 0,973).
d = tc.TestData;  z = d.ztp;
tDegrau = round(5 / z.ctl.Ta) * z.ctl.Ta;
cen.G = @(t) [1000 1000 1000 - 600 * (t >= tDegrau)];
cen.Tamb = @(t) 298.15;  cen.vw = @(t) 1;  cen.t_fim = 20;
cfg = z.cfg;  cfg.seed = 1;
op = struct('termico', true, 'perdas', false);
rd = sim_dinamica(cen, @mppt_pso, cfg, z.ctl, z.p, z.pc, d.pt, op);
rq = sim_quase_estatica(cen, @mppt_pso, cfg, z.ctl, z.p, z.pc, d.pt, op);
fprintf('janela 20 s, PSO: E din = %.3f J, E qe = %.3f J, dif = %+.3f %%\n', ...
    rd.E, rq.E, 100 * (rq.E / rd.E - 1));
verifyEqual(tc, rq.E, rd.E, 'RelTol', 0.01);
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

function test_oraculo_segurado_rampa(tc)
% Rampa de G com o oraculo no ponto medio de blocos de 7 Ta (52 periodos, ultimo bloco de 3): erro de 2a ordem.
% Derivacao do limite: num bloco de duracao h, a regra do ponto medio erra
% |integral(Pg) - h*Pg(meio)| <= h^3/24 * max|Pg''|. Somando os blocos
% (soma dos h = t_fim, h <= hMax): erro <= t_fim * hMax^2/24 * max|Pg''|.
% A referencia (dt_oraculo = Ta, trapezio por periodo) tambem erra, ate
% t_fim * Ta^2/12 * max|Pg''|. Limite = soma dos dois, com Pg'' estimada
% por segundas diferencas do oraculo ao longo da rampa (folga de 2x).
% Para comparar: segurar o valor do INICIO do bloco erraria ~ |Pg'|*h/2*t_fim.
d = tc.TestData;  Ta = d.ctl.Ta;  p = d.p;
tFim = 52 * Ta;
g = @(t) 200 + 600 * t / tFim;                  % rampa de ~330 W/m^2/s
cen = cenario_constante([0 0 0], 298.15, 1, tFim);
cen.G = @(t) g(t) * [1 1 0.5];
op = struct('termico', false);
rRef = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, p, d.pc, d.pt, op);
op.dt_oraculo = 7 * Ta;
r7 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, p, d.pc, d.pt, op);
% Pg'' por segundas diferencas em 9 pontos da rampa
ts = linspace(0, tFim, 9);  H = ts(2) - ts(1);
Pg = zeros(1, 9);
for i = 1:9
    Pg(i) = oraculo_pmax(cen.G(ts(i)), 298.15, p);
end
d2 = max(abs(Pg(1:7) - 2 * Pg(2:8) + Pg(3:9))) / H^2;
hMax = 7 * Ta;
limite = 2 * tFim * (hMax^2 / 24 + Ta^2 / 12) * d2;
dPg = max(abs(diff(Pg))) / H;
fprintf('rampa: |Eg7 - Egref| = %.4f J, limite = %.4f J (atraso do inicio do bloco ~ %.3f J)\n', ...
    abs(r7.Eg - rRef.Eg), limite, dPg * hMax / 2 * tFim);
verifyLessThan(tc, abs(r7.Eg - rRef.Eg), limite);
end

function test_amanhecer(tc)
% Amanhecer (G de 0 a 200 W/m^2 em 50 periodos): InC e PSO rodam sem erro, saidas finitas, PSO reinicia.
d = tc.TestData;  Ta = d.ctl.Ta;
cen = cenario_constante([0 0 0], 290, 1, 50 * Ta);
cen.G = @(t) 200 * t / (50 * Ta) * [1 1 1];
op = struct('termico', true);
algs = {@mppt_inc, @mppt_pso};
for i = 1:2
    r = sim_quase_estatica(cen, algs{i}, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
    verifyTrue(tc, all(isfinite([r.V; r.P; r.T; r.Pg])));
    verifyTrue(tc, isfinite(r.E) && r.E > 0 && isfinite(r.eta));
    verifyEqual(tc, r.nAvisosNewton, 0);
end
fprintf('amanhecer: PSO nReinicios = %d\n', r.nReinicios);
verifyGreaterThanOrEqual(tc, r.nReinicios, 1);
end

function test_dcm_contado(tc)
% Em 50 W/m^2 a corrente e pequena perto do ripple do indutor: a maior parte dos periodos e DCM.
d = tc.TestData;
cen = cenario_constante([50 50 50], 298.15, 1, 20 * d.ctl.Ta);
r = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', false));
verifyGreaterThan(tc, r.fracDCM, 0.5);
verifyEqual(tc, r.fracTransferencia, 1);
end

function test_noite(tc)
% Sem irradiancia: E = Eg = 0, eta indefinida (NaN) e nenhum periodo com transferencia, DCM ou inviavel.
d = tc.TestData;
cen = cenario_constante([0 0 0], 290, 1, 10 * d.ctl.Ta);
r = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, struct('termico', true));
verifyEqual(tc, [r.E, r.Eg, r.Eout], [0 0 0]);
verifyTrue(tc, isnan(r.eta) && isnan(r.eta_conv));
verifyEqual(tc, [r.fracTransferencia, r.fracDCM, r.fracInviavel], [0 0 0]);
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
    struct('termico', false, 't_ini', 100 - 10 * Ta));
verifyEqual(tc, numel(r.t), 10);       % nK com folga de arredondamento (+1e-9)
verifyEqual(tc, r.t(1), 100 - 9 * Ta, 'AbsTol', 1e-9);
end

function test_n_log(tc)
% n_log = 5 guarda 1 amostra a cada 5 periodos, sem mudar os totais.
d = tc.TestData;
cen = cenario_constante([1000 1000 400], 298.15, 1, 22 * d.ctl.Ta);
op = struct('termico', true);
r1 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
op.n_log = 5;
r5 = sim_quase_estatica(cen, @mppt_po, d.cfg, d.ctl, d.p, d.pc, d.pt, op);
verifyEqual(tc, numel(r5.t), 4);
verifyEqual(tc, r5.t, r1.t(5:5:20));
verifyEqual(tc, r5.P, r1.P(5:5:20));
verifyEqual(tc, r5.V, r5.Vref);
verifyEqual(tc, [r5.E, r5.Eg, r5.Eout], [r1.E, r1.Eg, r1.Eout]);
end
