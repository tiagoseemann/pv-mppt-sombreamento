function [Vref, e] = mppt_inc(V, I, e, cfg)
%MPPT_INC Condutancia incremental: dI/dV = -I/V no MPP.
%   [Vref, e] = mppt_inc(V, I, e, cfg)   (mesma interface de mppt_po)
%
%   No MPP dP/dV = 0. Como P = V*I:
%       dP/dV = I + V*dI/dV = 0   =>   dI/dV = -I/V
%   Definindo s = dI/dV + I/V (= (dP/dV)/V):
%       s > 0 : a esquerda do MPP, aumenta a tensao
%       s < 0 : a direita do MPP, diminui a tensao
%       |s| < eps : esta no MPP, mantem a referencia (nao oscila, ao
%                   contrario do P&O)
%   Como o P&O, so enxerga a inclinacao local: tambem para num pico local
%   sob sombra parcial.

if isempty(e)
    % Primeira chamada: da um passo para ter dois pontos e calcular dI/dV
    e = struct('Vref', cfg.Vref0, 'Vant', V, 'Iant', I);
    Vref = e.Vref - cfg.delta;
    e.Vref = Vref;
    return
end

dV = V - e.Vant;
dI = I - e.Iant;
if abs(dV) < 1e-6
    % A tensao nao mudou (referencia mantida): se a corrente mudou, foi a
    % irradiancia que mudou. Mais luz (dI > 0) desloca o MPP para a
    % direita, entao sobe a tensao; menos luz, desce.
    if abs(dI) > cfg.epsI
        e.Vref = e.Vref + sign(dI) * cfg.delta;
    end
else
    s = dI / dV + I / V;                 % = (dP/dV) / V
    if abs(s) > cfg.eps
        e.Vref = e.Vref + sign(s) * cfg.delta;
    end
end

e.Vref = min(max(e.Vref, cfg.Vmin), cfg.Vmax);
e.Vant = V;  e.Iant = I;
Vref = e.Vref;
end
