function [r, e] = rastrear_estatico(alg, cfg, Gfun, T, p, nPassos)
%RASTREAR_ESTATICO MPPT sobre o mapa estatico (tensao assentada a cada passo).
%   [r, e] = rastrear_estatico(alg, cfg, Gfun, T, p, nPassos)
%
%   alg     : handle do algoritmo, ex. @mppt_po
%   cfg     : struct de config_mppt()
%   Gfun    : @(k) irradiancia 1 x Nsub no passo k [W/m^2]
%   T       : temperatura das celulas [K]
%   p       : struct de parametros_painel()
%   nPassos : numero de periodos Ta simulados
%
%   r.V, r.P : tensao aplicada e potencia medida em cada passo
%   e        : estado final do algoritmo (para inspecao nos testes)
%
%   Hipotese: a malha de tensao assenta dentro de um periodo Ta (D13), entao
%   a tensao do painel e exatamente a referencia pedida no passo anterior
%   e a corrente vem direto da curva estatica I(V). Isola o algoritmo de
%   MPPT da dinamica do conversor.

e = [];
V = cfg.Vref0;
z = [];
r.V = zeros(nPassos, 1);
r.P = zeros(nPassos, 1);
for k = 1:nPassos
    [I, s] = painel_sombreado(V, Gfun(k), T, p, z);
    z = s.z;                             % warm start para o proximo passo
    r.V(k) = V;
    r.P(k) = V * I;
    [V, e] = alg(V, I, e, cfg);          % nova referencia para o proximo passo
end
end
