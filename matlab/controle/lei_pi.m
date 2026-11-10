function [d, dxi, modo] = lei_pi(v, xi, Vref, ctl, pc, modo)
%LEI_PI Lei do PI de tensao com saturacao e anti-windup (modelo medio).
%   [d, dxi, modo] = lei_pi(v, xi, Vref, ctl, pc)
%   [d, dxi]       = lei_pi(v, xi, Vref, ctl, pc, modo)
%
%   Fica num arquivo proprio para que a simulacao dinamica (sim_dinamica) e
%   a quase-estatica usem exatamente a mesma lei de controle.
%
%   d = Kp*(e + xi/Ti), e = v - Vref (sinal invertido: mais d tira mais
%   corrente do painel e a tensao dele cai), saturado em [Dmin, Dmax].
%   dxi = derivada do integrador: e, ou 0 com o integrador congelado.
%   modo = [lado, integra]: lado = +1 (d em Dmax), -1 (d em Dmin) ou 0
%   (linear); integra = 1 se o integrador esta ativo, 0 se congelado.
%   Sem o argumento modo, ele e decidido pelo estado atual. Passar modo
%   congela a logica de saturacao (usado nos jacobianos por diferencas
%   finitas, para o passo de diferenca nao atravessar a descontinuidade).
err = v - Vref;
du = ctl.Kp * (err + xi / ctl.Ti);        % comando antes da saturacao
if nargin < 6
    lado = 0;
    if du > pc.Dmax
        lado = 1;
    elseif du < pc.Dmin
        lado = -1;
    end
    % Anti-windup: com d saturado, para de integrar se o erro empurraria
    % du ainda mais para fora da faixa (err > 0 aumenta du). Sem isso xi
    % cresceria sem limite e a malha demoraria a sair da saturacao.
    integra = ~((lado == 1 && err > 0) || (lado == -1 && err < 0));
    modo = [lado, integra];
end
if modo(1) == 1
    d = pc.Dmax;
elseif modo(1) == -1
    d = pc.Dmin;
else
    d = du;
end
dxi = modo(2) * err;
end
