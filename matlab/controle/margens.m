function m = margens(w, L)
%MARGENS Margens de fase e de ganho a partir de L(jw) amostrado em w.
%   m = margens(w, L)
%
%   w : vetor de frequencias angulares [rad/s], crescente
%   L : vetor com o ganho de malha L(jw) nessas frequencias
%
%   Substitui margin(), que e da Control System Toolbox (nao disponivel).
%
%   O que as margens significam (criterio de Nyquist simplificado):
%   - Margem de fase (MF): na frequencia de cruzamento de ganho wc, onde
%     |L| = 1, quanto falta para a fase chegar a -180 graus. Se a fase
%     chegasse a -180 com |L| = 1, L = -1 e 1 + L = 0: polo em malha fechada
%     sobre o eixo imaginario (oscilacao sustentada). MF = 180 + fase(wc).
%     MF baixa = resposta muito oscilatoria; MF >= 45 graus e o usual.
%   - Margem de ganho (MG): na frequencia w180, onde a fase vale -180 graus,
%     quanto o ganho poderia crescer ate |L| = 1. MG = -20 log10|L(w180)| dB.
%     MG >= 6 dB: o ganho da planta pode dobrar sem instabilizar.
%
%   m.wc, m.PM   : primeiro cruzamento de ganho [rad/s] e a menor MF [graus]
%                  entre todos os cruzamentos de ganho
%   m.w180, m.GM : primeiro cruzamento de fase [rad/s] e a menor MG [dB]
%                  entre todos os cruzamentos de fase
%   Quando o cruzamento nao existe na faixa de w: wc (ou w180) = NaN e a
%   margem correspondente = Inf.
%
%   Por que olhar todos os cruzamentos: a ressonancia LC do conversor pode
%   fazer |L| voltar a passar de 1 depois do primeiro cruzamento. A margem
%   que vale e a pior delas.
magn = abs(L);
fase = unwrap(angle(L)) * 180 / pi;   % unwrap: fase continua, sem saltos de 360

% Cruzamento de ganho: |L| passa de >= 1 para < 1 (ou volta de < 1 para >= 1)
m.wc = NaN;  m.PM = Inf;
for k = 1:numel(w) - 1
    if (magn(k) >= 1) ~= (magn(k + 1) >= 1)
        % interpola em log|L|: no Bode |L| varia como potencia de w
        wck = interp1(log(magn(k:k + 1)), w(k:k + 1), 0);
        fase_wc = interp1(w(k:k + 1), fase(k:k + 1), wck);
        PMk = mod(180 + fase_wc + 180, 360) - 180;    % leva para [-180, 180)
        if isnan(m.wc), m.wc = wck; end
        m.PM = min(m.PM, PMk);
    end
end

% Cruzamento de fase: (fase + 180), levada para [-180, 180), muda de sinal.
% O teste abs(diff) < 180 descarta o salto artificial de +-180 da funcao mod.
fr = mod(fase + 180 + 180, 360) - 180;
m.w180 = NaN;  m.GM = Inf;
for j = 1:numel(w) - 1
    if fr(j) * fr(j + 1) < 0 && abs(fr(j + 1) - fr(j)) < 180
        w180j = interp1(fr(j:j + 1), w(j:j + 1), 0);
        magn180 = exp(interp1(w(j:j + 1), log(magn(j:j + 1)), w180j));
        GMj = -20 * log10(magn180);
        if isnan(m.w180), m.w180 = w180j; end
        m.GM = min(m.GM, GMj);
    end
end
end
