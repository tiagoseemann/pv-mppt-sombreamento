function [R, J, Vj, Ic, Ibp] = residuo_painel(z, Vpv, G, T, p)
%RESIDUO_PAINEL Equacoes algebricas do modulo com submodulos e bypass.
%   z = [I; Vd_1; ...; Vd_N], com Vd_j = tensao de juncao do submodulo j.
%   Com Vd_j conhecido, tudo no submodulo e explicito:
%       Ic_j  = Ipv_j - I01(e1-1) - I02(e2-1) - Vd_j/Rp_j   (celulas)
%       V_j   = Vd_j - Rs*Ic_j                              (terminais)
%       Ibp_j = I0bp*(exp(-V_j/(nbp*Vt)) - 1)               (bypass)
%   Equacoes (N+1):
%       R_j     = Ic_j + Ibp_j - I = 0      (KCL em cada submodulo)
%       R_{N+1} = sum(V_j) - Vpv   = 0      (KVL na serie)
%   J = dR/dz (jacobiano analitico).

N = p.Nsub;
G = G(:);

% Parametros do submodulo (dependentes de G e T), calculados em celula_params
c = celula_params(G, T, p);
Vt_s = c.Vt_s;  Rs_s = c.Rs_s;
Rp_s = c.Rp_s;                % vetor N x 1: Rp depende da G de cada submodulo
Ipv = c.Ipv;  I01 = c.I01;  I02 = c.I02;
Vt_bp = p.nbp * c.Vt;                       % tensao termica do diodo de bypass

I  = z(1);
Vd = z(2:end);
e1  = exp(Vd / (p.a1 * Vt_s));
e2  = exp(Vd / (p.a2 * Vt_s));
Ic  = Ipv - I01 * (e1 - 1) - I02 * (e2 - 1) - Vd ./ Rp_s;   % ./ : um Rp por submodulo
g   = I01 * e1 / (p.a1 * Vt_s) + I02 * e2 / (p.a2 * Vt_s) + 1 ./ Rp_s; % -dIc/dVd
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
