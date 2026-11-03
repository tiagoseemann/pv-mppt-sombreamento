function [Pg, Vg] = oraculo_pmax(G, T, p)
%ORACULO_PMAX Potencia maxima GLOBAL do painel (referencia da eficiencia do MPPT).
%   [Pg, Vg] = oraculo_pmax(G, T, p)   G: 1 x Nsub [W/m^2], T [K]
%
%   Com sombra a curva P-V tem varios maximos locais. A eficiencia de
%   rastreamento compara a energia obtida com a do pico GLOBAL: um MPPT
%   preso num pico local deve aparecer com eficiencia < 1.
%   1) Varredura grossa da curva (150 pontos): acha em qual pico esta o
%      maximo global (um otimizador local sozinho poderia parar no outro).
%   2) Refinamento com fminbnd entre os vizinhos do melhor ponto da grade:
%      dentro desse intervalo P(V) tem um maximo so.
c = curva_pv(G, T, p, 150);
[~, k] = max(c.P);
a = c.V(max(k - 1, 1));
b = c.V(min(k + 1, numel(c.V)));
menosP = @(v) -v * painel_sombreado(v, G, T, p);
[Vg, nP] = fminbnd(menosP, a, b, optimset('TolX', 1e-6));
Pg = -nP;
% Garantia: o refinamento nunca devolve menos que o melhor ponto da grade
if c.P(k) > Pg
    Pg = c.P(k);  Vg = c.V(k);
end
end
