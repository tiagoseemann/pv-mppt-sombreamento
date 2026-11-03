function eq = equilibrio_conversor(vpv, ipv, pc)
%EQUILIBRIO_CONVERSOR Regime permanente do modelo medio para (vpv, ipv) impostos.
%   Em regime, dv/dt = 0 da iL = ipv/d, e di/dt = 0 da
%     d*vpv = (1-d)*(Vbat+VF) + iL*(rL + d*Ron + (1-d)*RD)
%   que resolvemos para d com fzero (iL depende de d).
if ipv <= 0
    eq = struct('d', NaN, 'iL', 0, 'Pcond', 0, 'Psw', 0, 'Pout', 0, 'eta', 0);
    return
end
f = @(d) d * vpv - (1 - d) * (pc.Vbat + pc.VF) ...
         - (ipv / d) * (pc.rL + d * pc.Ron + (1 - d) * pc.RD);
eq.d = fzero(f, [1e-3, 0.999]);
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
