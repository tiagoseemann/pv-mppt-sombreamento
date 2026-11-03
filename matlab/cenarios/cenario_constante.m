function cen = cenario_constante(G, Tamb, vw, t_fim)
%CENARIO_CONSTANTE Cenario com irradiancia, temperatura ambiente e vento constantes.
%   cen = cenario_constante(G, Tamb, vw, t_fim)
%   G    : 1 x Nsub, irradiancia de cada submodulo [W/m^2]
%   Tamb : temperatura ambiente [K];  vw : vento [m/s];  t_fim : duracao [s]
%   Os campos G, Tamb e vw sao funcoes de t (mesma interface dos cenarios
%   que variam no tempo), aqui devolvendo sempre o mesmo valor.
cen.G = @(t) G;
cen.Tamb = @(t) Tamb;
cen.vw = @(t) vw;
cen.t_fim = t_fim;
end
