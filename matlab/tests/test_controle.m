% Testes do controle: margens de estabilidade, resposta ao degrau e projeto do PI de tensao do painel.
function tests = test_controle
tests = functiontests(localfunctions);
end

function setupOnce(tc)
% Uma unica execucao do projeto (generico) e reaproveitada pelos testes.
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
tc.TestData.p = p;  tc.TestData.pc = pc;
[tc.TestData.ctl, tc.TestData.rel] = projeto_pi(p, pc);
end

function test_margens_sistema_conhecido(tc)
% L(s) = 10/(s(s+1)(s+10)): wc e MF conferidos pela definicao; MG = 11 (w180 = sqrt(10)).
L = @(w) 10 ./ ((1j * w) .* (1j * w + 1) .* (1j * w + 10));
wg = logspace(-2, 3, 20000);
m = margens(wg, L(wg));
wc = fzero(@(w) abs(L(w)) - 1, [0.1 10]);
verifyEqual(tc, m.wc, wc, 'RelTol', 1e-3);
verifyEqual(tc, m.PM, 180 + rad2deg(angle(L(wc))), 'AbsTol', 0.1);
verifyEqual(tc, m.GM, 20 * log10(11), 'AbsTol', 0.05);   % w180 = sqrt(10), |L| = 1/11
end

function test_margens_ressonancia(tc)
% Integrador + ressonancia pouco amortecida + atraso: a MG e medida no cruzamento de -180 graus junto a ressonancia.
w0 = 1500;  Q = 3;  tau = 75e-6;  k = 50;            % wc ~ 50 rad/s << w0
L = @(w) k * exp(-1j * w * tau) ./ (((1j * w / w0).^2 + 1j * w / (Q * w0) + 1) .* (1j * w));
% fase continua escrita a mao: integrador (-90), 2a ordem (atan2) e atraso
fase = @(w) -pi / 2 - atan2(w / (Q * w0), 1 - (w / w0).^2) - w * tau;
w180 = fzero(@(w) fase(w) + pi, [0.5 * w0, 1.5 * w0]);
wg = logspace(0, log10(pi * 20e3), 3000);
m = margens(wg, L(wg));
verifyEqual(tc, m.w180, w180, 'RelTol', 1e-3);
verifyEqual(tc, m.GM, -20 * log10(abs(L(w180))), 'AbsTol', 0.05);
verifyLessThan(tc, m.wc, w0 / 10);
end

function test_degrau_primeira_ordem(tc)
% Planta de 1a ordem com o zero do PI cancelando o polo: malha fechada de 1a ordem, ts = ln(50)/(b*Kp).
a = 200;  b = 50;                         % planta -b/(s + a) (ganho negativo, como o conversor)
sys = struct('A', -a, 'B', -b, 'C', 1, 'D', 0);
ctl = struct('Kp', 2, 'Ti', 1 / a);       % L = b*Kp/s -> polo de malha fechada em -b*Kp
t_fim = 0.1;
[t, v, ts] = resposta_degrau_mf(sys, ctl, t_fim);
verifyEqual(tc, v, 1 - exp(-b * ctl.Kp * t), 'AbsTol', 1e-9);
verifyEqual(tc, ts, log(50) / (b * ctl.Kp), 'AbsTol', 2 * t_fim / 4000);
end

function test_pi_robusto(tc)
% O PI projetado tem MF >= 45 graus e MG >= 6 dB em todos os casos em CCM; Ta segue Femia no pior caso.
ctl = tc.TestData.ctl;  rel = tc.TestData.rel;
verifyGreaterThanOrEqual(tc, rel.PMmin, 45);
verifyGreaterThanOrEqual(tc, rel.GMmin, 6);
verifyGreaterThan(tc, ctl.Kp, 0);
verifyLessThan(tc, rel.ts_max, 0.05);              % limite de sanidade
verifyGreaterThanOrEqual(tc, numel(rel.ops), 8);    % quase todos os pontos em CCM
verifyGreaterThanOrEqual(tc, ctl.Ta, 1.5 * rel.ts_max - 1e-3);
end

function test_regra_antiga_falha(tc)
% A regra classica "zero em wc/5" (r = 0.2) nao atende as margens: a ressonancia LC pouco amortecida cruza 0 dB com pouca fase.
verifyError(tc, @() projeto_pi(tc.TestData.p, tc.TestData.pc, 0.2), 'projeto_pi:inviavel');
end
