function dTdt = termico_dTdt(T, G, Tamb, vw, Pel, pt)
%TERMICO_DTDT Balanco de energia do modulo como um unico corpo [K/s].
%   m*cp*dT/dt = sol absorvido - eletricidade - conveccao - radiacao
%   T, Tamb [K]; G [W/m^2] (media dos submodulos); vw = vento [m/s]; Pel [W].
sigma = 5.670374419e-8;               % constante de Stefan-Boltzmann [W/(m^2 K^4)]
At = 2 * pt.A;                        % area de conveccao: frente e verso
% Conveccao pura (Watmuff et al., 1977, via Duffie e Beckman): h = 2.8 + 3.0*vw.
% Nao usamos h = 5.7 + 3.8*vw (McAdams) porque esse valor e um coeficiente
% COMBINADO que ja inclui a radiacao; como calculamos a radiacao a parte
% (Q_rad), usa-lo contaria a radiacao duas vezes. kh e o fator calibrado.
hc = pt.kh * (2.8 + 3.0 * vw);        % coeficiente de conveccao [W/(m^2 K)]
Tceu = 0.0552 * Tamb^1.5;             % temperatura efetiva do ceu (Swinbank) [K]

Q_sol  = pt.alpha * pt.A * G;                      % radiacao solar absorvida [W]
Q_conv = hc * At * (T - Tamb);                     % calor levado pelo ar [W]
% Radiacao de onda longa (hipotese usual de modulo concentrado, ver Duffie e
% Beckman; Jones e Underwood, 2001): a face da frente enxerga o ceu (Tceu) e a
% face de tras, num modulo em estrutura, enxerga o solo, que esta perto de Tamb.
Q_rad_frente = pt.eps * sigma * pt.A * (T^4 - Tceu^4);   % frente -> ceu [W]
Q_rad_tras   = pt.eps * sigma * pt.A * (T^4 - Tamb^4);   % verso -> solo [W]
Q_rad = Q_rad_frente + Q_rad_tras;                       % radiacao total perdida [W]

% O que sobra do balanco aquece o modulo; dividir pela capacidade termica total [J/K]
dTdt = (Q_sol - Pel - Q_conv - Q_rad) / (pt.mcp_area * pt.A);
end
