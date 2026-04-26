load("poly.sage")
load("quadro.sage")

# -----------------------------
# ТЕСТОВАЯ СИСТЕМА
# -----------------------------
x, y = var('x y')

eqs = [
    (x, x^2 + y^2),
    (y, x^3 + y)
]

print("INPUT SYSTEM:")
print(eqs)

res = quadratize_poly(eqs)

res.print()