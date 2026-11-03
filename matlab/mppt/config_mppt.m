function cfg = config_mppt(p)
%CONFIG_MPPT Configuracao padrao comum aos algoritmos de MPPT.
%   cfg = config_mppt(p)   p: struct de parametros_painel()
%
%   Todas as tensoes sao escaladas pelo Voc do modulo sem sombra (STC),
%   entao a mesma configuracao serve para o painel generico e o ZTP-160M.

% Voc sem sombra: ultimo ponto da curva com corrente >= 0
c = curva_pv(1000 * ones(1, p.Nsub), p.Tn, p);
Voc = c.V(end);
cfg.Voc = Voc;

% Partida tipica: o conversor liga com o painel em aberto (perto de Voc)
cfg.Vref0 = 0.85 * Voc;
% Faixa permitida da referencia: abaixo de 10 % de Voc a potencia e quase
% nula; acima de 95 % o painel esta quase em aberto
cfg.Vmin = 0.10 * Voc;  cfg.Vmax = 0.95 * Voc;

% --- P&O e InC ---
cfg.delta = 0.01 * Voc;          % passo de tensao (ajustado no E6)
% Tolerancia do InC em |s|, s = dI/dV + I/V [S]. Um passo de tensao delta
% muda s de ~|ds/dV|*delta; o ponto da grade de tensoes mais proximo do MPP
% esta a no maximo delta/2 dele, entao |s| ali e no maximo metade desse
% salto. eps precisa ser pelo menos isso para o InC conseguir parar (com
% eps = 0,002 S isso nunca acontecia: o salto medido e ~0,09-0,10 S).
% ds/dV vem da curva sem sombra, por diferencas finitas em torno de Vmp.
dIdV = gradient(c.I, c.V);                % derivada numerica de I(V)
s = dIdV + c.I ./ c.V;                    % s(V); zero no MPP
dsdV = gradient(s, c.V);
[~, kmp] = max(c.P);
cfg.eps = 0.5 * abs(dsdV(kmp)) * cfg.delta;
cfg.epsI = 0.01;                 % tolerancia do InC em |dI| quando dV = 0 [A]

% --- PSO ---
cfg.w = 0.4;                     % inercia: quanto da velocidade anterior fica
cfg.c1 = 1.2;                    % atracao pela melhor posicao da propria particula
cfg.c2 = 2.0;                    % atracao pela melhor posicao do enxame
% Posicoes iniciais: com Nsub diodos de bypass, os maximos locais da curva
% P-V ficam perto de multiplos de Vmp/Nsub (cada submodulo ativo a mais
% soma ~uma tensao de MPP de submodulo; Patel e Agarwal 2008, Ishaque e
% Salam 2013). Uma particula em cada k*Vmp/Nsub (k = 1..Nsub) e mais uma
% em 0,9*Voc para cobrir o lado de alta tensao: N = Nsub + 1 particulas.
cfg.x0 = [(1:p.Nsub) * c.Vmp / p.Nsub, 0.90 * Voc].';
cfg.N = numel(cfg.x0);           % numero de particulas
cfg.tolV = 0.01 * Voc;           % convergiu quando todas estao a menos disso do gbest
cfg.maxIter = 15;                % limite de iteracoes (cada uma custa N periodos Ta)
cfg.limiarReinicio = 0.10;       % reinicia se a potencia mudar mais de 10 %
cfg.seed = 1;                    % semente do gerador aleatorio (reprodutibilidade)
end
