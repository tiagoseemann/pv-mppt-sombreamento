function [R, J, Vj, Ic, Ibp] = residuo_painel(z, Vpv, G, T, p)
%RESIDUO_PAINEL Equacoes algebricas do modulo com submodulos e bypass.
%   z = [I; Vd_1; ...; Vd_N], com Vd_j = tensao de juncao do submodulo j.
%   Com Vd_j conhecido, tudo no submodulo e explicito:
%       Ic_j  = Ipv_j - I01(e1-1) - I02(e2-1) - Vd_j/Rp     (celulas)
%       V_j   = Vd_j - Rs*Ic_j                              (terminais)
%       Ibp_j = I0bp*(exp(-V_j/(nbp*Vt)) - 1)               (bypass)
%   Equacoes (N+1):
%       R_j     = Ic_j + Ibp_j - I = 0      (KCL em cada submodulo)
%       R_{N+1} = sum(V_j) - Vpv   = 0      (KVL na serie)
%   J = dR/dz (jacobiano analitico).

N = p.Nsub;
G = G(:);

% Parametros do submodulo (Ncel celulas em serie agrupadas)
Vt    = p.k * T / p.q;
Vt_s  = p.Ncel * Vt;
Rs_s  = p.Ncel * p.Rs;
Rp_s  = p.Ncel * p.Rp;
Vt_bp = p.nbp * Vt;

Ipv = (G / p.Gn) * (p.Ipv_n + p.Ki * (T - p.Tn));
fT  = @(a, gam) (T / p.Tn)^gam * exp(p.q * p.Eg / (a * p.k) * (1 / p.Tn - 1 / T));
I01 = p.I01_n * fT(p.a1, 3);
I02 = p.I02_n * fT(p.a2, 1.5);

I  = z(1);
Vd = z(2:end);
e1  = exp(Vd / (p.a1 * Vt_s));
e2  = exp(Vd / (p.a2 * Vt_s));
Ic  = Ipv - I01 * (e1 - 1) - I02 * (e2 - 1) - Vd / Rp_s;
g   = I01 * e1 / (p.a1 * Vt_s) + I02 * e2 / (p.a2 * Vt_s) + 1 / Rp_s;  % -dIc/dVd
Vj  = Vd - Rs_s * Ic;
dVj = 1 + Rs_s * g;                                                    % dVj/dVd
ebp = exp(-Vj / Vt_bp);
Ibp = p.I0bp * (ebp - 1);
h   = p.I0bp * ebp / Vt_bp;                                            % -dIbp/dVj

R = [Ic + Ibp - I; sum(Vj) - Vpv];

J = zeros(N + 1);
J(1:N, 1)       = -1;
J(1:N, 2:end)   = diag(-g - h .* dVj);
J(N + 1, 2:end) = dVj.';
end
