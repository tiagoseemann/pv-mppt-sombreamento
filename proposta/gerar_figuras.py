"""Figuras ilustrativas da proposta (parametros genericos, nao do ZTP-160M)."""
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "figs")
os.makedirs(OUT, exist_ok=True)

plt.rcParams.update({
    "font.size": 10,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "savefig.bbox": "tight",
})
C1, C2, C3, C4 = "#1f5fa8", "#d1495b", "#edae49", "#2e8b57"

# ---------------------------------------------------------------- painel
q, k = 1.602e-19, 1.381e-23
T0 = 298.15
N_CELL = 36
N_SUB = 3
ISC = 8.2
VOC_CELL = 0.61
A_ID = 1.2
RS_CELL = 0.004
VT_CELL = k * T0 / q
I0 = ISC / (np.exp(VOC_CELL / (A_ID * VT_CELL)) - 1)
V_BP = -0.5


def v_sub(i, g, n_cells):
    """Tensao de um submodulo (modelo simplificado, Rp infinito) com bypass."""
    ipv = ISC * g / 1000.0
    with np.errstate(invalid="ignore", divide="ignore"):
        v = n_cells * (A_ID * VT_CELL * np.log((ipv - i) / I0 + 1) - RS_CELL * i)
    v = np.where(i < ipv, v, -np.inf)
    return np.maximum(v, V_BP)


def curva_modulo(gs):
    imax = ISC * max(gs) / 1000
    i = np.unique(np.concatenate([np.linspace(0, imax, 4000),
                                  imax * (1 - np.logspace(-9, -1, 2000))]))
    i = np.concatenate([i, [g * ISC / 1000 * (1 - 1e-12) for g in gs]])
    i.sort()
    v = sum(v_sub(i, g, N_CELL // N_SUB) for g in gs)
    m = v > 0
    return v[m], i[m]


# Fig 1: I-V e P-V uniforme
fig, ax = plt.subplots(1, 2, figsize=(9, 3.3))
for g, c in [(1000, C1), (600, C4), (200, C3)]:
    v, i = curva_modulo([g] * N_SUB)
    p = v * i
    ax[0].plot(v, i, color=c, label=f"G = {g} W/m²")
    ax[1].plot(v, p, color=c, label=f"G = {g} W/m²")
    j = np.argmax(p)
    ax[1].plot(v[j], p[j], "o", color=c)
    ax[0].plot(v[j], i[j], "o", color=c)
ax[0].set(xlabel="Tensão V [V]", ylabel="Corrente I [A]", title="Curva I-V")
ax[1].set(xlabel="Tensão V [V]", ylabel="Potência P [W]", title="Curva P-V (● = MPP)")
ax[0].legend(fontsize=8)
for a in ax:
    a.set_xlim(0, 24)
    a.set_ylim(bottom=0)
fig.savefig(os.path.join(OUT, "fig_iv_pv.pdf"))
plt.close(fig)

# Fig 2: sombreamento parcial
fig, ax = plt.subplots(1, 2, figsize=(9, 3.3))
casos = [([1000, 1000, 1000], C1, "sem sombra"),
         ([1000, 1000, 350], C2, "1 submódulo a 350 W/m²")]
for gs, c, lab in casos:
    v, i = curva_modulo(gs)
    ax[0].plot(v, i, color=c, label=lab)
    ax[1].plot(v, v * i, color=c, label=lab)
v, i = curva_modulo([1000, 1000, 350])
p = v * i
dp = np.diff(p)
picos = [j for j in range(1, len(dp)) if dp[j - 1] > 0 and dp[j] <= 0]
jg = max(picos, key=lambda j: p[j])
jl = [j for j in picos if j != jg][0]
ax[1].annotate("máximo GLOBAL", xy=(v[jg], p[jg]), xytext=(v[jg] - 9, p[jg] + 25),
               arrowprops=dict(arrowstyle="->", color=C4), color=C4, fontweight="bold")
ax[1].annotate("máximo local\n(P&O pode parar aqui)", xy=(v[jl], p[jl]),
               xytext=(v[jl] - 1, p[jl] + 45),
               arrowprops=dict(arrowstyle="->", color=C2), color=C2)
ax[0].set(xlabel="Tensão V [V]", ylabel="Corrente I [A]", title="I-V: \"degraus\" do bypass")
ax[1].set(xlabel="Tensão V [V]", ylabel="Potência P [W]", title="P-V: múltiplos picos")
ax[0].legend(fontsize=8)
for a in ax:
    a.set_xlim(0, 24)
    a.set_ylim(bottom=0)
ax[1].set_ylim(0, 190)
fig.savefig(os.path.join(OUT, "fig_sombra.pdf"))
plt.close(fig)

# Fig 3: escalas de tempo
escalas = [
    ("Chaveamento PWM", 2e-5, 1e-4),
    ("Dinâmica LC do conversor", 1e-3, 1e-2),
    ("Período do MPPT", 1e-2, 1e-1),
    ("Nuvens e rampas de G", 1, 100),
    ("Inércia térmica do painel", 120, 900),
    ("Dia solar", 2e4, 5e4),
]
fig, ax = plt.subplots(figsize=(8, 2.8))
cores = [C2, C2, C3, C4, C1, "#555555"]
for n, (lab, a, b) in enumerate(escalas):
    ax.barh(n, b - a, left=a, color=cores[n], height=0.55)
    ax.text(b * 1.6, n, lab, va="center", fontsize=9)
ax.set_xscale("log")
ax.set_yticks([])
ax.set_xlim(1e-5, 1e7)
ax.set_xlabel("Tempo [s] (escala logarítmica)")
ax.set_title("Escalas de tempo do sistema: ~9 ordens de grandeza")
ax.grid(axis="y", visible=False)
ax.spines["left"].set_visible(False)
fig.savefig(os.path.join(OUT, "fig_escalas.pdf"))
plt.close(fig)

# Fig 4: modelo termico
area = 1.0
mcp = 11000 * area
alpha, eta = 0.9, 0.15
v_w = 1.5
h_c = 5.7 + 3.8 * v_w
h_r = 6.0
h_tot = (h_c + h_r) * 2 * area
t = np.arange(0, 3600, 1.0)
G = np.where(t < 300, 200.0, 900.0)
for t0 in (1500, 1560, 2400):
    G = np.where((t >= t0) & (t < t0 + 20), 300.0, G)
G = np.where((t >= 2900) & (t < 3300), 400.0, G)
T_amb = 25.0
T = np.empty_like(t)
T[0] = T_amb + (alpha * 200 * (1 - eta)) * area / h_tot
for n in range(1, len(t)):
    dT = (alpha * G[n - 1] * area - eta * G[n - 1] * area - h_tot * (T[n - 1] - T_amb)) / mcp
    T[n] = T[n - 1] + dT
T_qs = T_amb + (alpha - eta) * G * area / h_tot
tau = mcp / h_tot
fig, ax = plt.subplots(2, 1, figsize=(8, 4.2), sharex=True)
ax[0].plot(t / 60, G, color=C3)
ax[0].set(ylabel="G [W/m²]", title="Resposta térmica do módulo")
ax[1].plot(t / 60, T_qs, color="#999999", ls="--", label="sem inércia (T segue G na hora)")
ax[1].plot(t / 60, T, color=C2, label=f"com inércia (τ ≈ {tau / 60:.0f} min)")
ax[1].set(xlabel="Tempo [min]", ylabel="T do módulo [°C]")
ax[1].legend(fontsize=8, loc="lower right")
fig.savefig(os.path.join(OUT, "fig_termico.pdf"))
plt.close(fig)

# Fig 5: chaveado x medio (buck-boost alimentado pelo modulo)
L_, C_, fs = 330e-6, 470e-6, 20e3
VBAT = 12.0
v_mod, i_mod = curva_modulo([1000] * N_SUB)
order = np.argsort(v_mod)
vv, ii = v_mod[order], i_mod[order]


def ipv(v):
    return np.interp(v, vv, ii, left=ISC, right=0.0)


dt = 1 / fs / 200
tt = np.arange(0, 6e-3, dt)
d = np.where(tt < 1e-3, 0.40, 0.45)
v_eq = (1 - d[0]) * VBAT / d[0]
x_sw = np.array([v_eq, ipv(v_eq) / d[0]])
x_av = x_sw.copy()
sw = np.zeros((len(tt), 2))
av = np.zeros((len(tt), 2))
for n, tn in enumerate(tt):
    qn = 1.0 if (tn * fs) % 1.0 < d[n] else 0.0
    v, il = x_sw
    il_pos = max(il, 0.0)
    dv = (ipv(v) - qn * il_pos) / C_
    di = (qn * v - (1 - qn) * VBAT) / L_
    if qn == 0 and il <= 0 and di < 0:
        di = 0.0
    x_sw = np.array([v + dv * dt, max(il + di * dt, 0.0)])
    v, il = x_av
    dv = (ipv(v) - d[n] * il) / C_
    di = (d[n] * v - (1 - d[n]) * VBAT) / L_
    x_av = np.array([v + dv * dt, il + di * dt])
    sw[n], av[n] = x_sw, x_av
fig, ax = plt.subplots(2, 1, figsize=(8, 4.2), sharex=True)
ax[0].plot(tt * 1e3, sw[:, 0], color=C1, lw=0.8, label="chaveado")
ax[0].plot(tt * 1e3, av[:, 0], color=C2, lw=1.6, ls="--", label="médio")
ax[0].set(ylabel="v_pv [V]", title="Modelo chaveado × modelo médio (degrau em d: 0,40 → 0,45 em t = 1 ms)")
ax[0].legend(fontsize=8)
ax[1].plot(tt * 1e3, sw[:, 1], color=C1, lw=0.6, label="chaveado (com ripple)")
ax[1].plot(tt * 1e3, av[:, 1], color=C2, lw=1.6, ls="--", label="médio")
ax[1].set(xlabel="Tempo [ms]", ylabel="i_L [A]")
ax[1].legend(fontsize=8)
fig.savefig(os.path.join(OUT, "fig_chaveado_medio.pdf"))
plt.close(fig)

# Fig 6: Bode de G_vd para varios r_pv
D, IL, VSUM = 0.4, 19.0, 30.0
w = np.logspace(1, 5, 800)
s = 1j * w
fig, ax = plt.subplots(2, 1, figsize=(8, 4.4), sharex=True)
for r, c, lab in [(20.0, C1, "à esquerda do MPP (r_pv = 20 Ω)"),
                  (2.4, C4, "no MPP (r_pv = Vmp/Imp ≈ 2,4 Ω)"),
                  (0.5, C3, "à direita do MPP (r_pv = 0,5 Ω)")]:
    Gs = -(L_ * IL * s + D * VSUM) / (L_ * C_ * s ** 2 + (L_ / r) * s + D ** 2)
    ax[0].semilogx(w / (2 * np.pi), 20 * np.log10(np.abs(Gs)), color=c, label=lab)
    fase = np.unwrap(np.angle(Gs)) * 180 / np.pi
    fase -= 360 * np.round((fase[0] + 180) / 360)
    ax[1].semilogx(w / (2 * np.pi), fase, color=c)
ax[0].set(ylabel="|G_vd| [dB]", title="A planta muda com o ponto de operação")
ax[0].legend(fontsize=8)
ax[1].set(xlabel="Frequência [Hz]", ylabel="Fase [°]")
fig.savefig(os.path.join(OUT, "fig_bode.pdf"))
plt.close(fig)

print("ok:", sorted(os.listdir(OUT)))
