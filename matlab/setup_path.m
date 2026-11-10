function setup_path()
%SETUP_PATH Adiciona as pastas do projeto ao path.
% Obs: os scripts de experimentos comecam com 'clear'; rode-os apenas no
% nivel principal (nunca dentro de uma funcao).
raiz = fileparts(mfilename('fullpath'));
pastas = {'numerico', 'painel', 'termico', 'conversor', 'controle', ...
          'mppt', 'simulacao', 'cenarios', 'experimentos'};
addpath(raiz);
for k = 1:numel(pastas)
    addpath(fullfile(raiz, pastas{k}));
end
end
