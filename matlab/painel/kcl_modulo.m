function [F, g] = kcl_modulo(V, I, G, T, p)
%KCL_MODULO Residuo explicito da equacao do modulo inteiro (sem sombra) em (V, I).
%   F = 0 quando (V, I) esta sobre a curva. g = -dIc/dVd, usado em
%   dI/dV = -g / (1 + Rs_modulo * g).

% Modulo inteiro tratado como um unico grupo de Ns celulas em serie
q = p;  q.Ncel = p.Ns;
c = celula_params(G, T, q);

% Tensao na juncao dos diodos = tensao do terminal + queda na resistencia serie
Vd = V + c.Rs_s * I;
e1 = exp(Vd / (p.a1 * c.Vt_s));
e2 = exp(Vd / (p.a2 * c.Vt_s));

% KCL: fotocorrente - diodo 1 - diodo 2 - corrente em Rp - corrente de saida = 0
F = c.Ipv - c.I01 * (e1 - 1) - c.I02 * (e2 - 1) - Vd / c.Rp_s - I;

% g = -dIc/dVd: derivada dos diodos mais condutancia de Rp
g = c.I01 * e1 / (p.a1 * c.Vt_s) + c.I02 * e2 / (p.a2 * c.Vt_s) + 1 / c.Rp_s;
end
