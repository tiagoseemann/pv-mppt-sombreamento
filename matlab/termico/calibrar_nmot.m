function pt = calibrar_nmot(pt, ds)
%CALIBRAR_NMOT Ajusta pt.kh para que o regime permanente reproduza o NMOT.
%   Condicao NMOT: G = 800 W/m^2, Tamb = 20 C, vento 1 m/s, modulo no MPP.
%   A potencia eletrica no MPP e estimada pelo datasheet (Pmax e gamaP).
T_alvo = ds.NMOT + 273.15;
Pel = ds.Pmax * 0.8 * (1 + ds.gamaP * (T_alvo - 298.15));

% No regime permanente dT/dt = 0. Procuramos o kh que zera dT/dt em T_alvo.
% Em MATLAB, struct passada por valor: copiamos pt e trocamos so o campo kh.
balanco = @(kh) balanco_com_kh(kh, pt, T_alvo, Pel);
pt.kh = fzero(balanco, [0.1 10]);
end

function dTdt = balanco_com_kh(kh, pt, T_alvo, Pel)
% dT/dt na condicao NMOT para um dado kh (usa uma copia de pt com esse kh).
pt.kh = kh;
dTdt = termico_dTdt(T_alvo, 800, 293.15, 1, Pel, pt);
end
