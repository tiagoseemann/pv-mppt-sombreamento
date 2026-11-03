% Testes do modelo chaveado contra o modelo medio (DAE) do buck-boost com o painel.
function tests = test_chaveado_medio
tests = functiontests(localfunctions);
end

function test_media_do_chaveado_igual_ao_medio(tc)
% Em CCM, a media movel de um periodo do chaveado segue o modelo medio (degrau de d em 2 ms).
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
G = [1000 1000 1000];  T = p.Tn;
v0 = 18;  I0 = painel_sombreado(v0, G, T, p);
eq = equilibrio_conversor(v0, I0, pc);
dfun = @(t) eq.d + 0.02 * (t >= 2e-3);
x0 = [v0; eq.iL];
rs = sim_chaveado(6e-3, dfun, G, T, p, pc, x0);
rm = sim_medio_aberta(6e-3, dfun, G, T, p, pc, x0);
nper = round(pc.Ts / (rs.t(2) - rs.t(1)));
vbar = movmean(rs.v, nper);  ibar = movmean(rs.iL, nper);
vm = interp1(rm.t, rm.v, rs.t);  im = interp1(rm.t, rm.iL, rs.t);
k = rs.t > pc.Ts;                                  % ignora o primeiro periodo
verifyLessThan(tc, max(abs(vbar(k) - vm(k))) / v0, 0.01);
verifyLessThan(tc, max(abs(ibar(k) - im(k))) / eq.iL, 0.03);
end

function test_ripple_analitico(tc)
% O ripple pico a pico de i_L no chaveado bate com v*d/(L*fs).
p = parametros_painel('generico');  pc = parametros_conversor(p, 12);
G = [1000 1000 1000];  T = p.Tn;
v0 = 18;  I0 = painel_sombreado(v0, G, T, p);
eq = equilibrio_conversor(v0, I0, pc);
rs = sim_chaveado(2e-3, @(t) eq.d, G, T, p, pc, [v0; eq.iL]);
k = rs.t > rs.t(end) - pc.Ts;
verifyEqual(tc, max(rs.iL(k)) - min(rs.iL(k)), v0 * eq.d / (pc.L * pc.fs), 'RelTol', 0.15);
end
