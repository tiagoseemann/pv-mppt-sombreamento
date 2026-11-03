function [Vref, e] = mppt_po(V, I, e, cfg)
%MPPT_PO Perturba e Observa: se a potencia caiu, inverte a direcao.
%   [Vref, e] = mppt_po(V, I, e, cfg)
%
%   V, I : media medida da tensao e corrente do painel no ultimo periodo Ta
%   e    : estado do algoritmo ([] na primeira chamada)
%   cfg  : struct de config_mppt()
%
%   E uma "subida de encosta" (hill climbing) na curva P(V): a cada periodo
%   a referencia anda um passo delta; se a potencia subiu, continua no mesmo
%   sentido, se caiu, volta. Consequencias:
%   - Nunca para: perto do MPP fica oscilando em 3 niveis de tensao
%     (Vmp - delta, Vmp, Vmp + delta), o que custa um pouco de energia.
%   - So enxerga a inclinacao local: sob sombra parcial a curva P-V tem
%     varios picos, e o P&O para no primeiro que encontra (partindo de perto
%     de Voc, o pico de tensao mais alta), mesmo que nao seja o global.

P = V * I;
if isempty(e)
    % Primeira chamada: nao ha potencia anterior para comparar. Comeca
    % descendo a tensao (partida perto de Voc, o MPP esta a esquerda).
    e = struct('Vref', cfg.Vref0, 'Pant', P, 'dir', -1);
else
    % A potencia caiu: o ultimo passo foi no sentido errado, inverte
    if P < e.Pant
        e.dir = -e.dir;
    end
    e.Pant = P;
end

% Da o passo e limita a faixa permitida
e.Vref = min(max(e.Vref + e.dir * cfg.delta, cfg.Vmin), cfg.Vmax);
Vref = e.Vref;
end
