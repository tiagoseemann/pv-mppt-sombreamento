function dTdt = termico_dTdt(T, G, Tamb, vw, Pel, pt)
%TERMICO_DTDT Balanco de energia do modulo como um unico corpo [K/s].
%   m*cp*dT/dt = sol absorvido - eletricidade - conveccao - radiacao
%   T, Tamb [K]; G [W/m^2] (media dos submodulos); vw = vento [m/s]; Pel [W].
sigma = 5.670374419e-8;               % constante de Stefan-Boltzmann [W/(m^2 K^4)]
At = 2 * pt.A;                        % troca calor pela frente e pelo verso
hc = pt.kh * (5.7 + 3.8 * vw);        % coeficiente de conveccao forcada (McAdams) [W/(m^2 K)], com fator calibrado
Tceu = 0.0552 * Tamb^1.5;             % temperatura efetiva do ceu (Swinbank) [K]

Q_sol  = pt.alpha * pt.A * G;                      % radiacao solar absorvida [W]
Q_conv = hc * At * (T - Tamb);                     % calor levado pelo ar [W]
Q_rad  = pt.eps * sigma * At * (T^4 - Tceu^4);     % radiacao de onda longa trocada com o ceu [W]

% O que sobra do balanco aquece o modulo; dividir pela capacidade termica total [J/K]
dTdt = (Q_sol - Pel - Q_conv - Q_rad) / (pt.mcp_area * pt.A);
end
