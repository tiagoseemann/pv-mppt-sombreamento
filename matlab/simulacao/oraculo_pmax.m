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
%   Noite (todas as G < 1 W/m^2) ou curva sem potencia positiva: Pg = 0,
%   Vg = 0 (nao ha o que rastrear).
if max(G) < 1
    Pg = 0;  Vg = 0;
    return
end
c = curva_pv(G, T, p, 150);
[Pk, k] = max(c.P);
if isempty(Pk) || Pk <= 0
    Pg = 0;  Vg = 0;
    return
end
a = c.V(max(k - 1, 1));
b = c.V(min(k + 1, numel(c.V)));
if a >= b
    % Curva com um ponto so: nao ha intervalo para refinar
    Pg = Pk;  Vg = c.V(k);
    return
end
menosP = @(v) -v * painel_sombreado(v, G, T, p);
[Vg, nP] = fminbnd(menosP, a, b, optimset('TolX', 1e-6));
Pg = -nP;
% Garantia: o refinamento nunca devolve menos que o melhor ponto da grade
if Pk > Pg
    Pg = Pk;  Vg = c.V(k);
end
end
