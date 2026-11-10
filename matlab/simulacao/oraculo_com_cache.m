function [Pg, cache] = oraculo_com_cache(G, T, p, cache)
%ORACULO_COM_CACHE Potencia do oraculo com cache.
%   [Pg, cache] = oraculo_com_cache(G, T, p, cache)   G: 1 x Nsub [W/m^2], T [K]
%   cache: G, T e Pg da ultima chamada; comeca vazio com
%          struct('G', [], 'T', NaN, 'Pg', NaN)
%
%   oraculo_pmax so e recalculado se G ou T mudaram (0,01 K muda Pmp em
%   ~4e-5, desprezivel). Com G constante, a ponta final de um intervalo e a
%   inicial do seguinte caem no cache. Usada por sim_dinamica e
%   sim_quase_estatica.
if ~isequal(G, cache.G) || abs(T - cache.T) > 0.01
    cache.Pg = oraculo_pmax(G, T, p);
    cache.G = G;
    cache.T = T;
end
Pg = cache.Pg;
end
