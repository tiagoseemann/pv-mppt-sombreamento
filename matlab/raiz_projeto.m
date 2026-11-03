% matlab/raiz_projeto.m
function r = raiz_projeto()
%RAIZ_PROJETO Pasta raiz do repositorio (pai de matlab/).
r = fileparts(fileparts(mfilename('fullpath')));
end
