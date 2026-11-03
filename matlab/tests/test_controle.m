% Testes do controle: margens de estabilidade e projeto do PI de tensao do painel.
function tests = test_controle
tests = functiontests(localfunctions);
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

function test_pi_robusto(tc)
% O PI projetado tem MF >= 45 graus e MG >= 6 dB em todos os pontos em CCM e acomoda em menos de 20 ms.
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
[ctl, rel] = projeto_pi(p, pc);
verifyGreaterThanOrEqual(tc, rel.PMmin, 45);
verifyGreaterThanOrEqual(tc, rel.GMmin, 6);
verifyGreaterThan(tc, ctl.Kp, 0);
verifyLessThan(tc, ctl.ts, 0.02);
verifyGreaterThanOrEqual(tc, numel(rel.ops), 8);    % quase todos os pontos em CCM
end

function test_regra_antiga_falha(tc)
% A regra classica "zero em wc/5" (r = 0.2) nao atende as margens: a ressonancia LC pouco amortecida cruza 0 dB com pouca fase.
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
verifyError(tc, @() projeto_pi(p, pc, 0.2), 'projeto_pi:inviavel');
end
