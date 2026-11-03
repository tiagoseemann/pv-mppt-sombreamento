function [ctl, rel] = projeto_pi(p, pc, razoes_zero)
%PROJETO_PI PI de tensao do painel com a maior banda que mantem MF >= 45 graus
%   e MG >= 6 dB em todos os pontos de operacao de robustez em CCM, e tempo
%   de acomodacao < 20 ms.
%   [ctl, rel] = projeto_pi(p, pc)
%   [ctl, rel] = projeto_pi(p, pc, razoes_zero)
%
%   p : parametros_painel();  pc : parametros_conversor()
%   razoes_zero : posicoes do zero do PI testadas, r = wz/wc
%                 (padrao [0.2 0.5 1 2 5]; r = 0.2 e a regra antiga "zero em wc/5")
%
%   ctl.Kp, ctl.Ti [s], ctl.fc [Hz], ctl.r : PI escolhido
%   ctl.ts [s] : tempo de acomodacao (2 %) ao degrau de V_ref, ponto nominal
%   ctl.Ta [s] : periodo minimo do MPPT (criterio de Femia)
%   rel.PMmin, rel.GMmin : piores margens entre os pontos em CCM
%   rel.PM, rel.GM       : margens em cada ponto de rel.ops
%   rel.ops, rel.ops_dcm : pontos verificados (CCM) e excluidos (DCM)
%   rel.tabela           : todos os candidatos (fc, r, pior MF, pior MG, ts)
%
%   Malha de tensao: L(s) = C(s) * (-G_vd(s)) * exp(-s*atraso), com
%   C(s) = Kp (1 + 1/(s Ti)). O sinal "-" vem da convencao d~ = Kp*(e + xi/Ti)
%   com e = v~ - r: a planta G_vd tem ganho negativo (mais d -> menor vpv),
%   e inverter o erro torna o ganho de malha positivo. O atraso exp(-s*atraso)
%   e o do PWM digital (amostragem + atualizacao do comparador).
%
%   Regras do projeto:
%   - Duas coisas sao varridas: a banda fc (cruzamento de ganho wc = 2*pi*fc)
%     e a posicao do zero do PI, wz = r*wc (Ti = 1/wz).
%   - Kp da |L(j wc)| = 1 no ponto nominal (MPP em STC).
%   - Por que a regra classica "zero em wc/5" (r = 0.2) falha aqui:
%     a planta -G_vd e plana (~40 a 85 V por unidade de d) ate a ressonancia
%     LC (~240 Hz), que e pouco amortecida (Q ~ 3 nos pontos de r_pv alto).
%     Com o zero abaixo de wc, acima de wc o PI e praticamente so o ganho Kp,
%     entao |L| = Kp*|G| fica ~1 desde wc ate a ressonancia; o pico da
%     ressonancia passa de novo por 0 dB com fase ~ -150 graus e a MF cai
%     para 25 a 40 graus. Subir fc acima da ressonancia tambem nao adianta:
%     ali a fase da planta ja esta perto de -180 graus.
%   - O que funciona: zero ACIMA do cruzamento (r > 1). Abaixo do zero o PI
%     age como integrador puro, |L| ~ Kp*|G|/(w*Ti) cai 20 dB/decada, e o
%     cruzamento fica bem abaixo da ressonancia com |L| << 1 no pico LC.
%     A fase em wc e ~ -90 graus (integrador), dai MF alta. E a escolha
%     padrao para uma planta LC pouco amortecida.
%   - A varredura inclui r = 0.2 para comparacao (aparece em rel.tabela).
%   - Entre os candidatos que passam, fica o de MAIOR fc (empate: maior MF):
%     banda maior = malha mais rapida, o que deixa o MPPT dar passos mais
%     curtos; mas o ganho da planta muda muito com G e vpv (r_pv do painel),
%     entao a banda tem de valer em todos os pontos, nao so no nominal.
%   - Pontos em DCM ficam fora da verificacao: o modelo linear vem do
%     modelo medio em conducao continua; em DCM a dinamica e outra (o polo
%     duplo LC some) e as margens calculadas nao teriam significado.
%     Eles sao listados em rel.ops_dcm.
if nargin < 3
    razoes_zero = [0.2 0.5 1 2 5];
end
ts_max = 0.02;                                % acomodacao maxima aceita [s]
ops = pontos_robustez(p);
w = logspace(0, log10(pi * pc.fs), 3000);     % ate a frequencia de Nyquist do PWM
atraso = exp(-1j * w * pc.atraso);            % atraso do PWM digital

% A resposta da planta nao depende do PI: calcula uma vez por ponto.
sysn = linearizar_planta(ops(1), p, pc);      % ponto nominal (MPP em STC)
Gplanta = {};  ops_ccm = ops([]);  ops_dcm = ops([]);
for k = 1:numel(ops)
    sys = linearizar_planta(ops(k), p, pc);
    if sys.ccm
        % sinal invertido: -G_vd (ver convencao acima)
        Gplanta{end + 1} = -resposta_freq(sys, w) .* atraso; %#ok<AGROW>
        ops_ccm(end + 1) = ops(k); %#ok<AGROW>
    else
        ops_dcm(end + 1) = ops(k); %#ok<AGROW>
    end
end

ctl = [];
fcs = logspace(log10(5), log10(pc.fs / 10), 80);    % bandas candidatas [Hz]
tabela = zeros(numel(fcs) * numel(razoes_zero), 5);
linha = 0;
for i = 1:numel(fcs)
    for r = razoes_zero
        fc = fcs(i);
        wc = 2 * pi * fc;  Ti = 1 / (r * wc);         % zero do PI em wz = r*wc
        % Kp: ganho de malha unitario em wc no ponto nominal
        Gwc = -resposta_freq(sysn, wc) * exp(-1j * wc * pc.atraso);
        Kp = 1 / abs(Gwc * (1 + 1 / (1j * wc * Ti)));
        Cw = Kp * (1 + 1 ./ (1j * w * Ti));           % PI na grade de frequencias
        PM = zeros(numel(Gplanta), 1);  GM = PM;
        for k = 1:numel(Gplanta)
            m = margens(w, Cw .* Gplanta{k});
            PM(k) = m.PM;  GM(k) = m.GM;
        end
        cand = struct('Kp', Kp, 'Ti', Ti, 'fc', fc, 'r', r);
        [~, ~, ts] = resposta_degrau_mf(sysn, cand, 0.05);
        linha = linha + 1;
        tabela(linha, :) = [fc, r, min(PM), min(GM), ts];

        passa = all(PM >= 45) && all(GM >= 6) && ts < ts_max;
        % fcs e crescente: um candidato que passa substitui o anterior se
        % tiver fc maior, ou mesma fc e MF maior
        if passa && (isempty(ctl) || fc > ctl.fc || min(PM) > rel.PMmin)
            ctl = cand;  ctl.ts = ts;
            rel = struct('PMmin', min(PM), 'GMmin', min(GM), 'PM', PM, 'GM', GM);
        end
    end
end
rel_tabela = array2table(tabela, 'VariableNames', {'fc_Hz', 'r', 'PMmin', 'GMmin', 'ts'});
if isempty(ctl)
    error('projeto_pi:inviavel', ...
        'Nenhum par (fc, r) atende MF >= 45, MG >= 6 dB e ts < %g s.', ts_max);
end

% Criterio de Femia: o P&O compara a potencia antes e depois de cada passo
% de V_ref. Se o periodo Ta for menor que o tempo de acomodacao da malha de
% tensao, a potencia medida ainda inclui o transitorio do conversor e o P&O
% confunde esse transitorio com uma mudanca real de potencia (pode andar
% para o lado errado). Por isso Ta > ts; usamos 1,5 ts arredondado para cima
% em ms.
ctl.Ta = 1e-3 * ceil(1.5 * ctl.ts / 1e-3);
rel.ops = ops_ccm;  rel.ops_dcm = ops_dcm;
rel.tabela = rel_tabela;
end


function ops = pontos_robustez(p)
% Pontos de operacao para a verificacao de robustez. Primeiro = nominal.
% Uniforme em 1000, 600 e 200 W/m^2, cada um no MPP e em 0,8 e 1,1 Vmp
% (o MPPT passeia em torno do MPP e o ganho da planta muda com r_pv).
% Mais os dois picos da curva com um submodulo sombreado (400 W/m^2).
ops = struct('vpv', {}, 'G', {}, 'T', {});
for G = [1000 600 200]
    Gv = G * ones(1, p.Nsub);
    c = curva_pv(Gv, p.Tn, p);
    for f = [1.0 0.8 1.1]
        ops(end + 1) = struct('vpv', f * c.Vmp, 'G', Gv, 'T', p.Tn); %#ok<AGROW>
    end
end
Gs = [1000 * ones(1, p.Nsub - 1), 400];             % sombra: os dois picos
c = curva_pv(Gs, p.Tn, p);
for k = 1:height(c.picos)
    ops(end + 1) = struct('vpv', c.picos.V(k), 'G', Gs, 'T', p.Tn); %#ok<AGROW>
end
end
