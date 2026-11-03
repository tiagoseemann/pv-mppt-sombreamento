function pc = parametros_conversor(p, Vbat)
%PARAMETROS_CONVERSOR Buck-boost inversor dimensionado pelo ripple no MPP em STC.
%   Chave ligada (fracao d): o indutor ve v_pv. Chave desligada: o indutor
%   descarrega na bateria. No equilibrio de tensao do indutor (sem perdas),
%   d*Vmp = (1-d)*Vbat, logo d = Vbat/(Vbat+Vmp) e iL = Imp/d.
if nargin < 2, Vbat = 12; end
pc.Vbat = Vbat;
pc.fs = 20e3;  pc.Ts = 1 / pc.fs;

% Ponto de operacao de projeto: MPP em STC (G = 1000 em todos os submodulos)
c = curva_pv(1000 * ones(1, p.Nsub), p.Tn, p, 1000);
D = Vbat / (Vbat + c.Vmp);
IL = c.Imp / D;

% Indutor: com a chave ligada, di = v_pv*d*Ts/L. Impomos ripple de 30 % de iL.
pc.L = c.Vmp * D / (0.30 * IL * pc.fs);
% Capacitor de entrada: com a chave ligada o indutor puxa iL do capacitor, e a
% carga trocada por ciclo e IL*D*(1-D)*Ts (aprox.); ripple de tensao de 1 % de Vmp.
pc.C = IL * D * (1 - D) / (0.01 * c.Vmp * pc.fs);

% Perdas (valores tipicos de catalogo, ver decisao D4)
pc.rL = 0.020;                 % resistencia serie do indutor [ohm]
pc.Ron = 0.018;                % resistencia do MOSFET ligado [ohm]
pc.VF = 0.45;                  % queda direta do diodo Schottky [V]
pc.RD = 0.010;                 % resistencia dinamica do diodo [ohm]
pc.ttr = 100e-9;               % tempo de subida + descida da chave [s]
pc.Dmin = 0.02;  pc.Dmax = 0.95;
pc.atraso = 1.5 * pc.Ts;       % atraso do PWM digital
end
