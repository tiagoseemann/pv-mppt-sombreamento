function H = gvd_analitico(sys, pc, w)
%GVD_ANALITICO G_vd(jw) = v~_pv / d~ do buck-boost SEM perdas (expressao da proposta).
%   H = gvd_analitico(sys, pc, w)
%
%   sys : saida de linearizar_planta (usa d0, x0 = [Vpv; IL] e rpv)
%   pc  : parametros do conversor (L, C, Vbat)
%   w   : frequencias angulares [rad/s]
%
%   Derivacao (sem perdas: rL = Ron = RD = VF = 0):
%   1) Equacoes de estado do modelo medio:
%        C dv/dt = i_pv(v) - d*iL
%        L di/dt = d*v - (1-d)*Vbat
%   2) Pequenos sinais em torno de (V, IL, D). O painel vira um resistor:
%      i~_pv = -v~/r_pv. Os produtos d*iL e d*v dao dois termos cada:
%        C dv~/dt = -v~/r_pv - D*i~L - IL*d~
%        L di~/dt =  D*v~ + (V + Vbat)*d~
%   3) Laplace (condicao inicial nula):
%        C s v~ = -v~/r_pv - D i~L - IL d~
%        L s i~L = D v~ + (V + Vbat) d~   ->   i~L = (D v~ + (V+Vbat) d~)/(L s)
%   4) Eliminando i~L na primeira e multiplicando tudo por L s:
%        (L C s^2 + (L/r_pv) s + D^2) v~ = -(L IL s + D (V + Vbat)) d~
%      portanto
%        G_vd(s) = -(L IL s + D (V+Vbat)) / (L C s^2 + (L/r_pv) s + D^2)
%
%   Sinal negativo: aumentar d deixa a chave mais tempo ligada, o indutor
%   puxa mais corrente do capacitor de entrada e v_pv cai.
%   Polos: w0 = D/sqrt(L C) e amortecimento zeta = sqrt(L/C) / (2 D r_pv)
%   (o unico "resistor" sem perdas e o proprio painel).
s = 1j * w;
D = sys.d0;
IL = sys.x0(2);
Vsum = sys.x0(1) + pc.Vbat;
H = -(pc.L * IL * s + D * Vsum) ./ (pc.L * pc.C * s.^2 + (pc.L / sys.rpv) * s + D^2);
end
