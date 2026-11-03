function [t, v, ts] = resposta_degrau_mf(sys, ctl, t_fim)
%RESPOSTA_DEGRAU_MF Degrau unitario em V_ref na malha fechada linear.
%   [t, v, ts] = resposta_degrau_mf(sys, ctl, t_fim)
%
%   sys   : planta linearizada (linearizar_planta), x' = A x + B d~, v~ = C x
%   ctl   : PI com .Kp e .Ti (projeto_pi)
%   t_fim : duracao da simulacao [s]
%   t, v  : tempo [s] e tensao v~ do painel (resposta ao degrau unitario)
%   ts    : tempo de acomodacao (faixa de 2 %) [s]; Inf se nao acomoda
%
%   Lei de controle: d~ = Kp*(e + xi/Ti), com e = v~ - r e xi' = e.
%   O erro e "v - r" (e nao "r - v") porque a planta tem ganho negativo:
%   aumentar d tira mais corrente do painel e a tensao dele cai. Se v esta
%   acima da referencia, o controle precisa AUMENTAR d.
%
%   Malha fechada com estado aumentado z = [x; xi]:
%       x'  = A x + B Kp (C x - r) + B Kp/Ti xi
%       xi' = C x - r
%   O atraso do PWM digital (pc.atraso, ~75 us) nao entra aqui: ele ja foi
%   considerado nas margens e e muito menor que o tempo de acomodacao.
A = sys.A;  B = sys.B;  C = sys.C;  Kp = ctl.Kp;  Ti = ctl.Ti;
Acl = [A + B * Kp * C, B * Kp / Ti; C, 0];
Bcl = [-B * Kp; -1];

% Discretizacao exata para entrada constante (r = 1 em todo o intervalo):
% z(k+1) = Ad z(k) + Bd, com Ad = e^(Acl dt) e Bd = Acl^-1 (Ad - I) Bcl
nPassos = 4000;
dt = t_fim / nPassos;
Ad = expm(Acl * dt);
Bd = Acl \ ((Ad - eye(3)) * Bcl);
z = zeros(3, 1);  t = (0:nPassos).' * dt;  v = zeros(size(t));
for k = 2:numel(t)
    z = Ad * z + Bd;
    v(k) = C * z(1:2);
end

% Tempo de acomodacao: ultimo instante fora da faixa de +-2 % do valor final
fora = abs(v - 1) > 0.02;
ultimo = find(fora, 1, 'last');
if isempty(ultimo)
    ts = 0;
elseif ultimo == numel(t)
    ts = Inf;          % ainda fora da faixa no fim: nao acomodou em t_fim
else
    ts = t(ultimo + 1);
end
end
