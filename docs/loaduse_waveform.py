# renders load-use stall waveform svg
import csv
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

rows = list(csv.DictReader(open('loaduse_wave.csv')))[8:]
def col(n): return [int(r[n]) for r in rows]
pc = col('pc')
stall = col('stall')
fwd = col('forward_a')
x1, x2 = col('x1'), col('x2')
N = len(rows)

DEC = lambda v: f'{v}'
lanes = [('pc', 'bus', pc, DEC),
         ('stall', 'bit', stall, None),
         ('forward_a', 'bus', fwd, DEC),
         ('x1', 'bus', x1, DEC), ('x2', 'bus', x2, DEC)]
nlanes = len(lanes)
lane_h, gap = 0.72, 0.55
pitch = lane_h + gap

fig, ax = plt.subplots(figsize=(13, 0.62 * nlanes + 1.4))
SIG, GREY = '#08306b', '#dfe6ee'
LABEL_X = -1.6

def base_of(k): return (nlanes - 1 - k) * pitch

def name_label(base, name):
    ax.text(LABEL_X, base + lane_h / 2, name, ha='center', va='center',
            fontsize=11, family='monospace')

def draw_bus(base, vals, fmt):
    top, bot = base + lane_h, base
    s = 0
    for i in range(1, N + 1):
        if i == N or vals[i] != vals[i - 1]:
            v = vals[s]
            ax.plot([s, i], [top, top], color=SIG, lw=1.7, zorder=3)
            ax.plot([s, i], [bot, bot], color=SIG, lw=1.7, zorder=3)
            ax.plot([s, s], [bot, top], color=SIG, lw=1.2, zorder=3)
            ax.plot([i, i], [bot, top], color=SIG, lw=1.2, zorder=3)
            ax.text((s + i) / 2, base + lane_h / 2, fmt(v), ha='center', va='center',
                    fontsize=9.0, family='monospace', color=SIG)
            s = i

for k, (name, kind, vals, fmt) in enumerate(lanes):
    base = base_of(k)
    name_label(base, name)
    if kind == 'bus':
        draw_bus(base, vals, fmt)
    else:
        ax.plot([0, N], [base, base], color=GREY, lw=0.8, zorder=0)
        seg = vals + [vals[-1]]
        ax.step(range(N + 1), [base + max(v, 0) * lane_h for v in seg], where='post',
                color=SIG, lw=1.8, zorder=3)

ax.set_xlim(-3.4, N)
ax.set_ylim(-0.4, base_of(0) + lane_h + 0.4)
ax.set_yticks([])
ax.set_xlabel('clock cycles', fontsize=10)
xt = list(range(0, N, 4))
ax.set_xticks([t + 0.5 for t in xt])
ax.set_xticklabels([str(t) for t in xt], fontsize=9)
for sp in ('top', 'right', 'left'):
    ax.spines[sp].set_visible(False)
ax.spines['bottom'].set_bounds(0, N)
ax.set_title('Load-Use Stall', fontsize=13, pad=16)
plt.tight_layout()
plt.savefig('loaduse_waveform.svg', bbox_inches='tight', facecolor='white')
print('wrote loaduse_waveform.svg; rows', N)
