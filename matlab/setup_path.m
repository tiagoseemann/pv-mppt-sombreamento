% matlab/setup_path.m
function setup_path()
%SETUP_PATH Adiciona as pastas do projeto ao path.
raiz = fileparts(mfilename('fullpath'));
pastas = {'numerico', 'painel', 'termico', 'conversor', 'controle', ...
          'mppt', 'simulacao', 'cenarios', 'experimentos'};
addpath(raiz);
for k = 1:numel(pastas)
    addpath(fullfile(raiz, pastas{k}));
end
end
