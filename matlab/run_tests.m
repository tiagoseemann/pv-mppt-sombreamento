% matlab/run_tests.m
function run_tests()
%RUN_TESTS Roda todos os testes de matlab/tests e falha se algum falhar.
setup_path();
r = runtests(fullfile(fileparts(mfilename('fullpath')), 'tests'));
disp(table(r));
assert(all([r.Passed]), '%d teste(s) falhando', sum(~[r.Passed]));
end
