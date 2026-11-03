function [I, sol] = painel_sombreado(Vpv, G, T, p, z0)
%PAINEL_SOMBREADO Corrente do modulo FV sob sombreamento parcial.
%   [I, sol] = painel_sombreado(Vpv, G, T, p)
%   [I, sol] = painel_sombreado(Vpv, G, T, p, z0)
%
%   Vpv : tensao imposta nos terminais do modulo [V] (vem do conversor)
%   G   : vetor 1 x Nsub com a irradiancia de cada submodulo [W/m^2]
%   T   : temperatura das celulas [K]
%   p   : struct de parametros_painel()
%   z0  : chute inicial [I; Vd_1..Vd_Nsub] (warm start), opcional
%
%   Resolve residuo_painel(z) = 0 por Newton-Raphson com passo limitado.

N = p.Nsub;
Vt_s = p.Ncel * p.k * T / p.q;

if nargin < 5 || isempty(z0)
    z0 = [p.Ipv_n * min(G) / p.Gn; repmat(max(Vpv, 0) / N, N, 1) + 0.5 * Vt_s];
end
z = z0(:);

tol = 1e-9;
for it = 1:60
    [R, J] = residuo_painel(z, Vpv, G, T, p);
    if norm(R, inf) < tol
        break
    end
    dz = -J \ R;
    % limita o passo: evita overflow das exponenciais longe da solucao
    dz(1)     = max(min(dz(1), 2), -2);
    dz(2:end) = max(min(dz(2:end), 2 * Vt_s), -2 * Vt_s);
    z = z + dz;
end

[R, ~, Vj, Ic, Ibp] = residuo_painel(z, Vpv, G, T, p);
I = z(1);
sol.z = z;  sol.Vj = Vj;  sol.Ic = Ic;  sol.Ibp = Ibp;
sol.iter = it;  sol.res = norm(R, inf);
end
