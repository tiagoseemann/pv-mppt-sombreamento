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
    e = struct('Vref', cfg.Vref0 - cfg.delta, 'dVref', -cfg.delta, 'Vant', V, 'Iant', I);
    e.Vref = min(max(e.Vref, cfg.Vmin), cfg.Vmax);
    Vref = e.Vref;
    return
end

dV = V - e.Vant;
dI = I - e.Iant;
VrefAnt = e.Vref;

% O ramo e escolhido pelo passo COMANDADO (e.dVref), nao pelo dV medido:
% em simulacao dinamica (ou com ruido), uma referencia mantida ainda gera
% dV de ~1e-5 a 1e-3 V; dividir dI por um dV tao pequeno da um s enorme e
% de sinal aleatorio, e o InC passaria a oscilar como o P&O.
if V <= 0
    % Capacitor de entrada descarregado na partida: I/V nao existe; sobe a tensao
    e.Vref = e.Vref + cfg.delta;
elseif e.dVref == 0 || dV == 0
    % Referencia mantida (ou a tensao ainda nao respondeu ao passo): se a
    % corrente mudou, foi a irradiancia que mudou. Mais luz (dI > 0)
    % desloca o MPP para a direita, entao sobe a tensao; menos luz, desce.
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
e.dVref = e.Vref - VrefAnt;              % passo efetivamente comandado
e.Vant = V;  e.Iant = I;
Vref = e.Vref;
end
