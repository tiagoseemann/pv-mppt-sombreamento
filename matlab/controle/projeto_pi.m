function [ctl, rel] = projeto_pi(p, pc, razoes_zero)
%PROJETO_PI PI de tensao do painel com a maior banda que mantem MF >= 45 graus
%   e MG >= 6 dB em todos os casos de robustez em CCM (ponto de operacao x
%   tolerancia de L e C). O periodo do MPPT sai do pior tempo de acomodacao.
%   [ctl, rel] = projeto_pi(p, pc)
%   [ctl, rel] = projeto_pi(p, pc, razoes_zero)
%
%   p : parametros_painel();  pc : parametros_conversor()
%   razoes_zero : posicoes do zero do PI testadas, r = wz/wc
%                 (padrao [0.2 0.5 1 2 5]; r = 0.2 e a regra antiga "zero em wc/5")
%
%   ctl.Kp, ctl.Ti [s], ctl.fc [Hz], ctl.r : PI escolhido
%   ctl.ts [s] : pior tempo de acomodacao (2 %) ao degrau de V_ref
%   ctl.Ta [s] : periodo minimo do MPPT (criterio de Femia)
%   rel.PMmin, rel.GMmin : piores margens entre os casos em CCM
%   rel.PM, rel.GM, rel.ts : margens e acomodacao em cada caso de rel.ops
%   rel.ts_max, rel.k_ts_max : pior acomodacao e o indice do caso em rel.ops
%   rel.ops, rel.ops_dcm : casos verificados (CCM) e excluidos (DCM), com
%                          campos vpv, G, T, fL, fC (fatores de L e C)
%   rel.tabela : todos os candidatos (fc, r, pior MF, pior MG, ts no ponto
%                nominal, pior ts; o pior ts so e calculado quando as
%                margens passam, senao NaN)
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
%   - Kp da |L(j wc)| = 1 no ponto nominal (MPP em STC, L e C nominais).
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
%     entao a banda tem de valer em todos os casos, nao so no nominal.
%   - Robustez a tolerancia dos componentes: indutores e capacitores
%     eletroliticos tem tolerancia tipica de +-20 %. Cada ponto de operacao
%     e verificado com L e C nominais e nos cantos [fL fC] = [1.2 1],
%     [1 1.2], [1.2 1.2] e [0.8 0.8]. L +20 % e o caso que limita: o PI
%     projetado so com L e C nominais tinha MG de 4,6 dB com L +20 %.
%   - Pontos em DCM ficam fora da verificacao: o modelo linear vem do
%     modelo medio em conducao continua; em DCM a dinamica e outra (o polo
%     duplo LC some) e as margens calculadas nao teriam significado.
%     Eles sao listados em rel.ops_dcm e sao conferidos na simulacao nao
%     linear (Tarefa 10).
%   - Velocidade da malha: nao ha especificacao fisica de tempo de
%     acomodacao. O que importa e o criterio de Femia (Ta > ts no pior
%     caso), garantido pela escolha Ta = 1,5 ts_max. O limite ts_max < 50 ms
%     so descarta malhas absurdamente lentas.
%
%   Resultado (generico e ZTP-160M): com os cantos de tolerancia, a MG
%   limita a banda (fc ~ 49 a 57 Hz, caso critico 200 W/m^2 com L +20 %).
%   O caso mais lento e o pico de baixa tensao com sombra: ali o ganho DC
%   da planta e ~0,6 do nominal e, como Kp e fixado no nominal, o
%   cruzamento cai na mesma proporcao. Resulta ts_max ~ 20 a 23 ms e
%   Ta ~ 31 a 35 ms. Escalonar o ganho (Kp por ponto de operacao) tiraria
%   essa limitacao, mas esta fora do escopo.
if nargin < 3
    razoes_zero = [0.2 0.5 1 2 5];
end
% Limite de sanidade para o pior ts (nao e especificacao fisica: Femia so
% exige Ta > ts, o que e imposto via Ta; isto so rejeita malhas absurdas).
ts_max_limite = 0.05;                         % [s]
t_fim = 0.05;                                 % janela da resposta ao degrau [s]
                                              % (ts = Inf se nao acomodar nela)
ops = pontos_robustez(p);
cantos = [1 1; 1.2 1; 1 1.2; 1.2 1.2; 0.8 0.8];   % fatores [fL fC]
w = logspace(0, log10(pi * pc.fs), 3000);     % ate a frequencia de Nyquist do PWM
atraso = exp(-1j * w * pc.atraso);            % atraso do PWM digital

% A resposta da planta nao depende do PI: linearizacao e resposta em
% frequencia uma vez por caso (ponto x canto). O primeiro caso e o nominal.
Gplanta = {};  sys_ccm = {};
casos = struct('vpv', {}, 'G', {}, 'T', {}, 'fL', {}, 'fC', {});
ops_ccm = casos;  ops_dcm = casos;
for k = 1:numel(ops)
    for c = 1:size(cantos, 1)
        pcx = pc;                             % copia com L e C fora do nominal
        pcx.L = pc.L * cantos(c, 1);
        pcx.C = pc.C * cantos(c, 2);
        caso = struct('vpv', ops(k).vpv, 'G', ops(k).G, 'T', ops(k).T, ...
            'fL', cantos(c, 1), 'fC', cantos(c, 2));
        sys = linearizar_planta(ops(k), p, pcx);
        if sys.ccm
            % sinal invertido: -G_vd (ver convencao acima)
            Gplanta{end + 1} = -resposta_freq(sys, w) .* atraso; %#ok<AGROW>
            sys_ccm{end + 1} = sys; %#ok<AGROW>
            ops_ccm(end + 1) = caso; %#ok<AGROW>
        else
            ops_dcm(end + 1) = caso; %#ok<AGROW>
        end
    end
end
% Ponto nominal com L e C nominais (primeiro caso). O nominal esta em CCM
% por construcao: o conversor foi dimensionado nele (ripple de 30 %).
assert(~isempty(ops_ccm) && ops_ccm(1).vpv == ops(1).vpv && ops_ccm(1).fL == 1 ...
    && ops_ccm(1).fC == 1, 'projeto_pi: ponto nominal fora de CCM');
sysn = sys_ccm{1};

ctl = [];
fcs = logspace(log10(5), log10(pc.fs / 10), 80);    % bandas candidatas [Hz]
tabela = zeros(numel(fcs) * numel(razoes_zero), 6);
linha = 0;
for i = 1:numel(fcs)
    fc = fcs(i);
    wc = 2 * pi * fc;
    % planta nominal em wc (nao depende de r)
    Gwc = -resposta_freq(sysn, wc) * exp(-1j * wc * pc.atraso);
    for r = razoes_zero
        Ti = 1 / (r * wc);                            % zero do PI em wz = r*wc
        % Kp: ganho de malha unitario em wc no ponto nominal
        Kp = 1 / abs(Gwc * (1 + 1 / (1j * wc * Ti)));
        Cw = Kp * (1 + 1 ./ (1j * w * Ti));           % PI na grade de frequencias
        PM = zeros(numel(Gplanta), 1);  GM = PM;
        for k = 1:numel(Gplanta)
            m = margens(w, Cw .* Gplanta{k});
            PM(k) = m.PM;  GM(k) = m.GM;
        end
        cand = struct('Kp', Kp, 'Ti', Ti, 'fc', fc, 'r', r);
        [~, ~, ts_nom] = resposta_degrau_mf(sysn, cand, t_fim);

        % Acomodacao em todos os casos (so se as margens passaram: e o
        % calculo mais caro). Femia vale no PIOR caso: o P&O e o PSO operam
        % justamente em baixa irradiancia e nos picos com sombra, onde a
        % malha e mais lenta.
        margens_ok = all(PM >= 45) && all(GM >= 6);
        ts = NaN(numel(sys_ccm), 1);
        ts_pior = NaN;
        if margens_ok
            for k = 1:numel(sys_ccm)
                [~, ~, ts(k)] = resposta_degrau_mf(sys_ccm{k}, cand, t_fim);
            end
            ts_pior = max(ts);
        end
        linha = linha + 1;
        tabela(linha, :) = [fc, r, min(PM), min(GM), ts_nom, ts_pior];

        passa = margens_ok && ts_pior < ts_max_limite;
        % fcs e crescente: substitui o escolhido se a banda for maior, ou se
        % for a mesma banda com MF maior
        if passa && (isempty(ctl) || fc > ctl.fc || (fc == ctl.fc && min(PM) > rel.PMmin))
            ctl = cand;  ctl.ts = ts_pior;
            [~, k_pior] = max(ts);
            rel = struct('PMmin', min(PM), 'GMmin', min(GM), 'PM', PM, 'GM', GM, ...
                'ts', ts, 'ts_max', ts_pior, 'k_ts_max', k_pior);
        end
    end
end
rel_tabela = array2table(tabela, 'VariableNames', ...
    {'fc_Hz', 'r', 'PMmin', 'GMmin', 'ts_nominal', 'ts_max'});
if isempty(ctl)
    error('projeto_pi:inviavel', ...
        'Nenhum par (fc, r) atende MF >= 45, MG >= 6 dB e ts < %g s.', ts_max_limite);
end

% Criterio de Femia: o P&O compara a potencia antes e depois de cada passo
% de V_ref. Se o periodo Ta for menor que o tempo de acomodacao da malha de
% tensao, a potencia medida ainda inclui o transitorio do conversor e o P&O
% confunde essa dinamica com uma mudanca real de potencia (pode andar para o
% lado errado). Por isso Ta > ts no pior caso; usamos 1,5 ts_max
% arredondado para cima em ms.
ctl.Ta = 1e-3 * ceil(1.5 * rel.ts_max / 1e-3);
rel.ops = ops_ccm;  rel.ops_dcm = ops_dcm;
rel.tabela = rel_tabela;
end


function ops = pontos_robustez(p)
% Pontos de operacao para a verificacao de robustez. Primeiro = nominal.
% Uniforme em 1000, 600 e 200 W/m^2, cada um no MPP e em 0,8 e 1,1 Vmp
% (o MPPT passeia em torno do MPP e o ganho da planta muda com r_pv).
% Mais os dois picos da curva com um submodulo sombreado (400 W/m^2).
% Mais o modulo quente (60 C, 1000 W/m^2) no seu MPP: com a temperatura
% Vmp cai e r_pv muda, entao a planta muda.
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
Gq = 1000 * ones(1, p.Nsub);                         % modulo quente
Tq = p.Tn + 35;
c = curva_pv(Gq, Tq, p);
ops(end + 1) = struct('vpv', c.Vmp, 'G', Gq, 'T', Tq);
end
