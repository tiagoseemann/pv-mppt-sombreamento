function eq = equilibrio_conversor(vpv, ipv, pc)
%EQUILIBRIO_CONVERSOR Regime permanente do modelo medio para (vpv, ipv) impostos.
%   Campos de saida: d, iL, Pcond, Psw, Pout, eta, viavel.
%
%   d = NaN e viavel = false significam "sem transferencia de potencia neste
%   ponto" (ipv <= 0, ou o controlador nao alcanca o ponto: d fora de
%   [Dmin, Dmax], por exemplo com vpv muito baixo).
%
%   ATENCAO: so vale em conducao continua (CCM). Use verifica_ccm para
%   sinalizar DCM. Em DCM as equacoes de CCM subestimam as perdas de conducao
%   (corrente de pico/RMS bem maior que a media), entao eta em DCM e otimista.
%
%   Psw entra apenas no balanco de potencia (e descontada de Pout); nao entra
%   no modelo medio / EDO (e pequena, < 1 % em STC).
%
%   Derivacao de d (regime: dv/dt = 0 e di/dt = 0):
%   1) dv/dt = 0  ->  ipv - d*iL = 0  ->  iL = ipv/d
%   2) di/dt = 0  ->  d*vpv - (1-d)*Vt - iL*(rL + d*Ron + (1-d)*RD) = 0,
%      com Vt = Vbat + VF.  Trocando iL por ipv/d:
%        d*vpv - (1-d)*Vt - (ipv/d)*(rL + d*Ron + (1-d)*RD) = 0
%   3) Multiplicando tudo por d (d > 0):
%        d^2*vpv - d*(1-d)*Vt - ipv*(rL + d*Ron + RD - d*RD) = 0
%   4) Abrindo os produtos e juntando as potencias de d:
%        d^2*vpv + d^2*Vt - d*Vt - ipv*d*(Ron - RD) - ipv*(rL + RD) = 0
%        (vpv + Vt)*d^2 - (Vt + ipv*(Ron - RD))*d - ipv*(rL + RD) = 0
%   5) E uma equacao do 2o grau a*d^2 + b*d + c = 0 com
%        a = vpv + Vt  (> 0),  b = -(Vt + ipv*(Ron - RD)),  c = -ipv*(rL + RD) (< 0)
%      Como a > 0 e c < 0, o produto das raizes c/a e negativo: ha exatamente
%      uma raiz positiva, d = (-b + sqrt(b^2 - 4*a*c)) / (2*a).
semtransf = struct('d', NaN, 'iL', 0, 'Pcond', 0, 'Psw', 0, 'Pout', 0, ...
                   'eta', 0, 'viavel', false);
if ipv <= 0
    eq = semtransf;
    return
end
Vt = pc.Vbat + pc.VF;
a = vpv + Vt;
b = -(Vt + ipv * (pc.Ron - pc.RD));
c = -ipv * (pc.rL + pc.RD);
d = (-b + sqrt(b^2 - 4 * a * c)) / (2 * a);

% Se o ponto exige d fora da faixa do PWM, o controlador nao o alcanca:
% nao ha transferencia de potencia util, entao devolvemos tudo zerado.
if d > pc.Dmax || d < pc.Dmin
    eq = semtransf;
    return
end

eq.d = d;
eq.viavel = true;
eq.iL = ipv / eq.d;
% Perda de conducao: I^2*R nas resistencias + queda fixa do diodo (so quando conduz)
eq.Pcond = eq.iL^2 * (pc.rL + eq.d * pc.Ron + (1 - eq.d) * pc.RD) ...
           + (1 - eq.d) * eq.iL * pc.VF;
% Perda de chaveamento: sobreposicao tensao x corrente nas transicoes
eq.Psw = 0.5 * (vpv + pc.Vbat) * eq.iL * pc.ttr * pc.fs;
% Potencia entregue a bateria = media da corrente de saida x Vbat, menos chaveamento
eq.Pout = (1 - eq.d) * eq.iL * pc.Vbat - eq.Psw;
eq.eta = eq.Pout / (vpv * ipv);
end
