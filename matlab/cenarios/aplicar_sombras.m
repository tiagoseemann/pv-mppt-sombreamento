function cen = aplicar_sombras(cen, ev)
%APLICAR_SOMBRAS Multiplica G por 'fator' entre t_ini e t_fim (rampas de rampa_s).
%   ev e uma tabela com colunas t_ini, t_fim, sub, fator, rampa_s.
%   ev.sub = 0 -> todos os submodulos (nuvem); sub = j -> so o submodulo j (sombra
%   de poste, folha etc.). O fator entra e sai linearmente em rampa_s segundos.
%   As funcoes do cenario aceitam t escalar (como os simuladores chamam).
%   Os dados horarios do PVGIS nao tem sombras nem nuvens rapidas; por isso estes
%   eventos sao SINTETICOS e devem ser declarados como tais no relatorio.
Gbase = cen.G;
cen.G = @(t) G_com_sombras(t);
    function G = G_com_sombras(t)
        G = Gbase(t);                    % Gbase e avaliada uma unica vez
        f = ones(size(G));
        for i = 1:height(ev)
            % a: (subida) - (descida). A subida vai de 0 a 1 em rampa_s a partir de
            % t_ini; a descida so comeca em t_fim e anula a subida: o resultado e um
            % trapezio no tempo (0 antes, rampa, 1 no patamar, rampa, 0 depois).
            a = min(max((t - ev.t_ini(i)) / ev.rampa_s(i), 0), 1) ...
              - min(max((t - ev.t_fim(i)) / ev.rampa_s(i), 0), 1);
            fi = 1 - (1 - ev.fator(i)) * a;
            if ev.sub(i) == 0
                f = f * fi;
            else
                f(ev.sub(i)) = f(ev.sub(i)) * fi;
            end
        end
        G = G .* f;
    end
end
