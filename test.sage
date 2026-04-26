from sage.all import *

load("utils.sage")
load("poly.sage")
load("sage_sympy_tools.sage")

# ----------------------------
# variables
# ----------------------------
x, y, z = var("x y z")

# ----------------------------
# system (НЕ список списков)
# ----------------------------
system = [
    x^2 + y,
    x*y + z,
    -z^2 + x
]

print("\n=== ORIGINAL SYSTEM ===")
for eq in system:
    print(eq)

# ----------------------------
# derivatives
# ----------------------------
print("\n=== DERIVATIVES ===")
vars_list = [x, y, z]
derivs = generate_derivatives(vars_list)

for v, dv in derivs:
    print((v, dv))

# ----------------------------
# polynomial conversion
# ----------------------------
print("\n=== LAURENT POLY ===")

R = SR
poly = make_laurent_poly(system, [], vars_list, R)

for p in poly:
    print(p)

# ----------------------------
# pow test (SAFE)
# ----------------------------
print("\n=== POW TEST ===")
expr = (x^2 + y)^3
print("Original:", expr)
print("Replaced:", replace_pow(expr, lambda b, e: b^e))

# ----------------------------
# stress test (SAFE)
# ----------------------------
print("\n=== STRESS TEST ===")
expr2 = z^2 + sqrt(y) + 1/x
print(expr2)

print("\n=== TEST COMPLETE ===")