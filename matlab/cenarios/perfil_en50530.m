function cen = perfil_en50530(arq, Nsub, Tamb, vw)
%PERFIL_EN50530 Irradiancia uniforme G(t) dos ensaios dinamicos da EN 50530 (Anexo B).
%   Cada linha da tabela gera: espera em G_baixo e depois 'repeticoes' trapezios
%   (rampa de subida, patamar em G_alto, rampa de descida, patamar em G_baixo).
%   G(t) e montado como uma lista de pontos (tempo, irradiancia) interpolada
%   linearmente entre eles. A irradiancia e a mesma em todos os submodulos
%   (a norma testa o MPPT sem sombreamento parcial).
if nargin < 3, Tamb = 298.15; end
if nargin < 4, vw = 1; end
tab = readtable(arq, 'CommentStyle', '%', 'TextType', 'string');

t_pts = [];  G_pts = [];  t = 0;
for i = 1:height(tab)
    Gb = tab.G_baixo(i);  Ga = tab.G_alto(i);
    rampa = (Ga - Gb) / tab.inclinacao_Wm2s(i);      % duracao da rampa [s]
    patamar = tab.patamar_s(i);

    % Inicio da linha: degrau para G_baixo e espera (1 ms para o degrau ser vertical)
    t_pts(end + 1) = t + 1e-3;           G_pts(end + 1) = Gb;   %#ok<AGROW>
    t = t + tab.espera_s(i);
    t_pts(end + 1) = t;                  G_pts(end + 1) = Gb;   %#ok<AGROW>

    for rep = 1:tab.repeticoes(i)
        t = t + rampa;    t_pts(end + 1) = t;  G_pts(end + 1) = Ga;  %#ok<AGROW> sobe
        t = t + patamar;  t_pts(end + 1) = t;  G_pts(end + 1) = Ga;  %#ok<AGROW> fica no alto
        t = t + rampa;    t_pts(end + 1) = t;  G_pts(end + 1) = Gb;  %#ok<AGROW> desce
        t = t + patamar;  t_pts(end + 1) = t;  G_pts(end + 1) = Gb;  %#ok<AGROW> fica no baixo
    end
end
t_pts = [0, t_pts];  G_pts = [G_pts(1), G_pts];

interp_G = griddedInterpolant(t_pts, G_pts, 'linear', 'nearest');
cen.G = @(tq) interp_G(tq) * ones(1, Nsub);          % mesma irradiancia em todos
cen.Tamb = @(tq) Tamb;
cen.vw = @(tq) vw;
cen.t_fim = t;
end
