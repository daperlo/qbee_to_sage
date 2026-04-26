from sage.all import *

# ----------------------------
# safe stringify
# ----------------------------
def str_qbee(x):
    return str(x)


# ----------------------------
# derivative symbol (SAGE ONLY)
# ----------------------------
def make_derivative_symbol(x):
    return var(str(x) + "_prime")


# ----------------------------
# FLATTEN (SAFE)
# ----------------------------
def flatten(x):
    if isinstance(x, (list, tuple, set)):
        res = []
        for i in x:
            res.extend(flatten(i))
        return res
    return [x]


# ----------------------------
# SAFE laurent stub
# ----------------------------
def make_laurent_poly(exprs, state_vars, input_vars, R):
    polys = []

    for e in exprs:
        try:
            if isinstance(e, (list, tuple)):
                e = sum(e)   # или просто взять e[0], зависит от логики

            polys.append(R(e))

        except Exception:
            polys.append(R(0))

    return polys

def generate_derivatives(inputs):
    result = []

    for v in inputs:
        dv = make_derivative_symbol(v)
        result.append((v, dv))   # OK tuple

    return result