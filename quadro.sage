from functools import partial
from itertools import combinations
load("poly.sage")
# -----------------------------
# GENERATION (Sage version)
# -----------------------------
def default_generation(system, beam_size=20, max_degree=3):
    """
    Sage-safe generation (no tuple monomials, only expressions)
    """

    active = list(system.variables.state)

    if not active:
        return []

    # -----------------------------
    # сортировка по степени выражения
    # -----------------------------
    def expr_size(v):
        try:
            return v.degree()  # если polynomial-like
        except:
            return len(str(v))  # fallback

    active.sort(key=expr_size)
    active = active[:beam_size]

    candidates = []

    # -----------------------------
    # квадраты
    # -----------------------------
    for v in active:
        try:
            candidates.append((v * v,))
        except:
            pass

    # -----------------------------
    # локальные произведения
    # -----------------------------
    for i in range(len(active)):
        vi = active[i]

        for j in range(i + 1, min(i + 5, len(active))):
            vj = active[j]

            try:
                m = vi * vj
                candidates.append((m,))
            except:
                pass

    return candidates


# -----------------------------
# SCORING
# -----------------------------
def default_scoring(system):
    return system.variables.generated.__len__()


# -----------------------------
# PRUNING
# -----------------------------
def pruning_by_too_many_vars(algo, system, *args, nvars=10):
    return len(system.variables.generated) >= nvars


def default_pruning_rules():
    return [pruning_by_too_many_vars]


# -----------------------------
# MAIN QUADRATIZATION
# -----------------------------
def quadratize_poly(polynomials,
                    max_vars=10,
                    generation_strategy=default_generation,
                    scoring=default_scoring,
                    pruning_functions=None):

    if pruning_functions is None:
        pruning_functions = default_pruning_rules()

    # -----------------------------
    # 1. создаём систему
    # -----------------------------
    system = EquationSystem(dict(polynomials))

    introduced = []

    # -----------------------------
    # 2. greedy + pruning loop (qbee-style simplified)
    # -----------------------------
    while len(system.variables.generated) < max_vars:

        candidates = generation_strategy(system)

        if not candidates:
            break

        best = None

        # -----------------------------
        # 3. выбор лучшего кандидата
        # -----------------------------
        for cand in candidates:
            expr = cand[0]

            try:
                new_var = system.variables.create()
                system.add_new_var(expr, new_var)
                introduced.append((new_var, expr))

                best = (new_var, expr)
                break

            except:
                continue

        if best is None:
            break

    # -----------------------------
    # 4. финальные уравнения
    # -----------------------------
    quad_eqs, eq_vars, quad_vars = system.to_poly_equations({})

    return QuadratizationResult(
        quad_eqs,
        eq_vars,
        quad_vars,
        None
    )

class QuadratizationResult:
    def __init__(self, equations, variables, quad_variables, algo):
        self.equations = equations
        self.variables = variables
        self.quad_variables = quad_variables
        self.algo = algo
        self._introduced = []

    @property
    def introduced_variables(self):
        return self._introduced

    def print(self):
        print("Introduced variables:")
        for v in self._introduced:
            print(v)

        print("\nEquations:")
        for e in self.equations:
            print(e)