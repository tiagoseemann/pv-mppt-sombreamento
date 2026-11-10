function [F, g, dIdV] = kcl_modulo(V, I, G, T, p)
%KCL_MODULO Residuo explicito da equacao do modulo inteiro (sem sombra) em (V, I).
%   V, I, G, T sao escalares (G = irradiancia uniforme do modulo).
%   F = 0 quando (V, I) esta sobre a curva. g = -dIc/dVd.
%   dIdV = inclinacao dI/dV da curva I-V no ponto (V, I).

% Modulo inteiro tratado como um unico grupo de Ns celulas em serie
q = p;  q.Ncel = p.Ns;
c = celula_params(G, T, q);

% Tensao na juncao dos diodos = tensao do terminal + queda na resistencia serie
Vd = V + c.Rs_s * I;
e1 = exp(Vd / (p.a1 * c.Vt_s));
e2 = exp(Vd / (p.a2 * c.Vt_s));

% G e escalar aqui, entao c.Rp_s tambem e (Rp(G) de De Soto, ver celula_params);
% ./ por coerencia com residuo_painel.
% KCL: fotocorrente - diodo 1 - diodo 2 - corrente em Rp - corrente de saida = 0
F = c.Ipv - c.I01 * (e1 - 1) - c.I02 * (e2 - 1) - Vd ./ c.Rp_s - I;

% g = -dIc/dVd: derivada dos diodos mais condutancia de Rp
g = c.I01 * e1 / (p.a1 * c.Vt_s) + c.I02 * e2 / (p.a2 * c.Vt_s) + 1 ./ c.Rp_s;

% Derivacao implicita de F(V, I) = 0: dI/dV = -(dF/dV)/(dF/dI)
% com dF/dV = -g e dF/dI = -(1 + Rs_s*g), logo dI/dV = -g / (1 + Rs_s*g)
dIdV = -g / (1 + c.Rs_s * g);
end
