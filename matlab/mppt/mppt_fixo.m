function [Vref, e] = mppt_fixo(~, ~, e, cfg)
%MPPT_FIXO Referencia constante (testes da malha de tensao e oraculo).
%   [Vref, e] = mppt_fixo(V, I, e, cfg)   (mesma interface de mppt_po)
%   Ignora as medicoes e devolve sempre cfg.Vref0.
Vref = cfg.Vref0;
end
