function [Vref, e] = mppt_pso(V, I, e, cfg)
%MPPT_PSO Enxame de particulas com avaliacao sequencial (uma particula por Ta).
%   [Vref, e] = mppt_pso(V, I, e, cfg)   (mesma interface de mppt_po)
%
%   Cada particula e uma tensao candidata x. O conversor so consegue impor
%   UMA tensao por vez, entao as particulas sao avaliadas uma por periodo
%   Ta: cada chamada recebe a medicao da particula aplicada na chamada
%   anterior. Depois que as N particulas foram medidas, o enxame se move:
%       v = w*v + c1*r1*(pbest - x) + c2*r2*(gbest - x)
%       x = x + v
%   - w*v       : inercia (continua andando no sentido em que ia)
%   - pbest - x : memoria propria (volta para o melhor ponto que ESTA
%                 particula ja achou)
%   - gbest - x : memoria do enxame (vai para o melhor ponto que QUALQUER
%                 particula ja achou)
%   r1, r2 sao sorteios em [0, 1]. Como as particulas comecam espalhadas
%   por toda a faixa de tensao, o enxame "ve" todos os picos da curva P-V e
%   tende a convergir para o global, ao contrario de P&O e InC.
%
%   Convergencia: quando todas as particulas estao a menos de tolV do
%   gbest (ou estourou maxIter), fixa a referencia no gbest.
%   Reinicio: convergido, monitora a potencia; se ela muda mais que
%   limiarReinicio (a sombra ou a irradiancia mudou), a curva P-V mudou e
%   a busca recomeca do zero.

P = V * I;
if isempty(e)
    e = iniciar(cfg);
    Vref = e.x(1);                       % aplica a primeira particula
    return
end

if e.convergido
    if abs(P - e.Pconv) > cfg.limiarReinicio * max(e.Pconv, 1)
        e = iniciar(cfg);                % a curva mudou: nova busca
        Vref = e.x(1);
        return
    end
    Vref = e.gbest;                      % fica parado no melhor ponto
    return
end

% P e a potencia da particula k (aplicada no periodo anterior):
% atualiza a memoria propria e a do enxame
k = e.k;
if P > e.pbestP(k)
    e.pbestP(k) = P;  e.pbest(k) = e.x(k);
end
if P > e.gbestP
    e.gbestP = P;  e.gbest = e.x(k);
end

e.k = k + 1;
if e.k > cfg.N
    % Todas as particulas foram medidas: move o enxame
    e.k = 1;  e.iter = e.iter + 1;
    r1 = rand(e.rs, cfg.N, 1);
    r2 = rand(e.rs, cfg.N, 1);
    e.v = cfg.w * e.v + cfg.c1 * r1 .* (e.pbest - e.x) + cfg.c2 * r2 .* (e.gbest - e.x);
    e.x = min(max(e.x + e.v, cfg.Vmin), cfg.Vmax);
    if max(abs(e.x - e.gbest)) < cfg.tolV || e.iter >= cfg.maxIter
        e.convergido = true;
        e.Pconv = e.gbestP;              % potencia de referencia para o reinicio
        Vref = e.gbest;
        return
    end
end
Vref = e.x(e.k);                         % aplica a proxima particula
end

function e = iniciar(cfg)
% Estado inicial do enxame: particulas em cfg.x0, paradas, sem memoria.
% O gerador aleatorio e proprio (RandStream) para o resultado depender so
% de cfg.seed e nao do estado global do rand.
e.rs = RandStream('mt19937ar', 'Seed', cfg.seed);
e.x = cfg.x0(:);
e.v = zeros(cfg.N, 1);
e.pbest = e.x;  e.pbestP = -inf(cfg.N, 1);
e.gbest = e.x(1);  e.gbestP = -inf;
e.k = 1;  e.iter = 0;
e.convergido = false;  e.Pconv = 0;
end
