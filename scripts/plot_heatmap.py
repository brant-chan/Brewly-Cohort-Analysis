"""
Optional: turn your cohort_retention table into a portfolio-ready heatmap.
Requires: pip install duckdb matplotlib
Run from the project root AFTER Step 5:  python scripts/plot_heatmap.py
"""
import duckdb, matplotlib.pyplot as plt, numpy as np

con = duckdb.connect("brewly.duckdb", read_only=True)
rows = con.execute("""
    SELECT strftime(cohort_month, '%Y-%m'), month_number, retention_pct
    FROM cohort_retention ORDER BY 1, 2
""").fetchall()

cohorts = sorted({r[0] for r in rows})
max_m = max(r[1] for r in rows)
grid = np.full((len(cohorts), max_m + 1), np.nan)
for c, m, pct in rows:
    grid[cohorts.index(c), m] = pct

fig, ax = plt.subplots(figsize=(12, 6))
im = ax.imshow(grid, cmap="YlGnBu", aspect="auto", vmin=0, vmax=100)
for i in range(grid.shape[0]):
    for j in range(grid.shape[1]):
        if not np.isnan(grid[i, j]):
            ax.text(j, i, f"{grid[i, j]:.0f}%", ha="center", va="center", fontsize=8,
                    color="white" if grid[i, j] > 55 else "black")
ax.set_xticks(range(max_m + 1), [f"M{m}" for m in range(max_m + 1)])
ax.set_yticks(range(len(cohorts)), cohorts)
ax.set_xlabel("Months since signup"); ax.set_ylabel("Signup cohort")
ax.set_title("Brewly — Customer Retention by Signup Cohort (2025)")
fig.colorbar(im, label="% of cohort with a completed order")
plt.tight_layout()
plt.savefig("retention_heatmap.png", dpi=160)
print("Saved retention_heatmap.png")
