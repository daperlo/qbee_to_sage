from sage.all import *

# ============================================================
# POW REPLACEMENT
# ============================================================

def replace_pow(expr, handler):

    if not hasattr(expr, "operands"):
        return expr

    try:
        ops = expr.operands()
    except:
        return expr

    if hasattr(expr, "operator") and expr.operator() == pow:
        base, exp = ops
        return handler(base, exp)

    new_ops = tuple(replace_pow(op, handler) for op in ops)

    op = expr.operator()
    if op is None:
        return expr

    return op(*new_ops)