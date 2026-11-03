function dx = conversor_medio_rhs(vpv, iL, ipv, d, pc)
%CONVERSOR_MEDIO_RHS Derivadas do modelo medio com perdas: [dv_pv/dt; di_L/dt].
%   O modelo medio e a media ponderada pelo tempo das duas topologias:
%     chave ligada  (fracao d):   L di/dt = v_pv - iL*(rL + Ron)
%     chave desligada (1-d):      L di/dt = -(Vbat + VF) - iL*(rL + RD)
%   Capacitor de entrada: C dv/dt = i_pv - d*iL (o indutor so puxa corrente
%   do capacitor enquanto a chave esta ligada).
dv = (ipv - d * iL) / pc.C;
di = (d * vpv - (1 - d) * (pc.Vbat + pc.VF) ...
      - iL * (pc.rL + d * pc.Ron + (1 - d) * pc.RD)) / pc.L;
dx = [dv; di];
end
