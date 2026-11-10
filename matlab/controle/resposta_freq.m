function H = resposta_freq(sys, w)
%RESPOSTA_FREQ Resposta em frequencia H(jw) de um sistema em espaco de estados.
%   H = resposta_freq(sys, w)
%
%   sys : struct com .A, .B, .C, .D (x' = A x + B u, y = C x + D u)
%   w   : vetor de frequencias angulares [rad/s]
%
%   Aplicando Laplace com condicao inicial nula: s X = A X + B U, logo
%   X = (sI - A)^-1 B U e Y/U = C (sI - A)^-1 B + D. A resposta em frequencia
%   e essa funcao avaliada em s = jw. Substitui bode/freqresp (Control System
%   Toolbox, nao disponivel). Usa "\" em vez de inv() por ser mais preciso.
H = zeros(size(w));
n = size(sys.A, 1);
for k = 1:numel(w)
    s = 1j * w(k);
    H(k) = sys.C * ((s * eye(n) - sys.A) \ sys.B) + sys.D;
end
end
