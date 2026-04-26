from sage.all import *

# ============================================================
# POW REPLACEMENT
# ============================================================

def replace_pow(expr, handler):

    # атомарные
    if not hasattr(expr, "operands"):
        return expr

    try:
        op = expr.operator()
        args = expr.operands()
    except Exception:
        return expr

    # ⭐ правильный детект степени в Sage
    if len(args) == 2 and expr.nops() == 2 and "^" in str(expr):
        base, exp = args
        return handler(base, exp)

    new_args = [replace_pow(a, handler) for a in args]

    if op is None:
        return expr

    return op(*new_args)