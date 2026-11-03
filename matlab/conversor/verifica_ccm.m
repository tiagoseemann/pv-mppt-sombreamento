function ccm = verifica_ccm(vpv, d, iL, pc)
%VERIFICA_CCM true se a corrente no indutor nao zera (conducao continua).
%   O ripple pico a pico e vpv*d/(L*fs); a corrente minima e iL - ripple/2.
%   Conducao continua exige iL > ripple/2.
%   O ripple usa a inclinacao ideal vpv/L da chave ligada (ignora as quedas
%   resistivas), o que e levemente conservador.
ccm = iL > vpv * d / (pc.L * pc.fs) / 2;
end
