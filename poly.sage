from collections.abc import Iterable
import pickle
from functools import cached_property
load("utils.sage")

class VariablesHolder:
    """
    Class that manages variable storage (Sage version).
    """

    def __init__(self, variables: Iterable,
                 parameter_variables=None,
                 input_variables=None,
                 new_var_base_name="w_",
                 start_new_vars_with=0):

        if parameter_variables is None:
            parameter_variables = set()
        if input_variables is None:
            input_variables = set()

        self._parameter_variables = set(parameter_variables)
        self._input_variables = set(input_variables)
        self._state_variables = list(variables)
        self._generated_variables = []
        self._base_name = new_var_base_name
        self._start_id = start_new_vars_with
        self.laurent = []

    @property
    def state(self):
        # State variables stored as list to preserve ordering
        return self._state_variables

    @property
    def parameter(self):
        return self._parameter_variables

    @property
    def input(self):
        return self._input_variables

    @property
    def generated(self):
        return self._generated_variables

    @property
    def base_var_name(self):
        return self._base_name

    @base_var_name.setter
    def base_var_name(self, value: str):
        self._base_name = value

    @property
    def start_new_vars_with(self):
        return self._start_id

    @start_new_vars_with.setter
    def start_new_vars_with(self, value):
        self._start_id = value

    def create(self):
        """
        Creates a new symbolic variable in Sage and stores it.

        Example:
            w_{0}, w_{1}, w_{2}, ...

        :return: created variable (Sage symbolic variable)
        """
        new_index = len(self._generated_variables) + self._start_id

        # Sage variable name
        name = f"{self._base_name}{new_index}"

        # create symbolic variable
        new_variable = var(name)

        self._state_variables.append(new_variable)
        self._generated_variables.append(new_variable)

        return new_variable


class EquationSystem:
    def __init__(self, equations: dict,
                 parameter_variables=None,
                 input_variables=None):

        self._equations = equations.copy()
        self._substitution_equations = dict()
        self._poly_equations = {k: None for k in equations.keys()}

        _parameter_vars = set(parameter_variables) if parameter_variables is not None else set()
        _input_vars = set(input_variables) if input_variables is not None else set()
        _variables = list(equations.keys())

        self.variables = VariablesHolder(_variables, _parameter_vars, _input_vars)

        self.expand()
        self._fill_poly_system()

    def __copy__(self):
        system = EquationSystem(self._equations)
        system._equations = {k: v for k, v in self._equations.items()}
        system._substitution_equations = {k: v for k, v in self._substitution_equations.items()}
        system._poly_equations = {k: v for k, v in self._poly_equations.items()}
        system.variables = pickle.loads(pickle.dumps(self.variables, -1))
        return system

    @property
    def equations(self):
        # возвращаем пары (lhs, rhs), Sage Eq не обязателен
        return [(make_derivative_symbol(dx), f) for dx, f in self._equations.items()]

    @property
    def introduced_variables(self):
        return self._substitution_equations.items()

    @property
    def polynomial_equations(self):
        return [(make_derivative_symbol(x), f if f is not None else 0)
                for x, f in self._poly_equations.items()]

    @cached_property
    def laurent_substitutions(self):
        return {k: v for k, v in self._substitution_equations.items()
                if (1 / v) in self.variables.laurent}

    def expand(self):
        """expand() для всех правых частей"""
        for x, fx in self._equations.items():
            try:
                self._equations[x] = fx.expand()
            except Exception:
                self._equations[x] = fx

    def add_new_var(self, substitution, new_var=None):
        if substitution in self._substitution_equations.values():
            return

        if new_var is None:
            new_var = self.variables.create()

        # 1. ПРАВИЛЬНАЯ подстановка
        self._equations = {
            k: v.subs({substitution: new_var})
            for k, v in self._equations.items()
        }

        # 2. сохранить
        self._substitution_equations[new_var] = substitution

        # 3. пересчитать производную
        self._equations[new_var] = self._calculate_Lie_derivative(substitution)

        # 4. ВАЖНО: сброс кэша полинома
        self._poly_equations = {k: None for k in self._equations.keys()}

        self._fill_poly_system()

    def _sanitize(self, expr):
        if isinstance(expr, (list, tuple)):
            return sum(self._sanitize(x) for x in expr)

        if hasattr(expr, "__iter__") and not hasattr(expr, "variables"):
            return sum(self._sanitize(x) for x in expr)

        return expr

    def _calculate_Lie_derivative(self, expr):
        """
        d/dt expr(x(t)) = sum(diff(expr, xi)*xi_dot)
        """
        result = 0
        expr_vars = set(expr.variables())

        state_vars = expr_vars.difference(self.variables.parameter).difference(self.variables.input)

        for var in state_vars:
            if var not in self._equations:
                continue
            var_diff = self._equations[var]
            result += diff(expr, var) * var_diff

        for input_var in expr_vars.intersection(self.variables.input):
            input_var_dot = make_derivative_symbol(input_var)
            self.variables._input_variables.add(input_var_dot)
            result += diff(expr, input_var) * input_var_dot

        return result

    def _fill_poly_system(self):
        for x, fx in self._equations.items():
            if x not in self._poly_equations:
                self._poly_equations[x] = None

            if self._poly_equations[x] is None:
                self._poly_equations[x] = self._try_convert_to_polynomial(fx)

    def print(self, use_poly_equations=True):
        if self._substitution_equations:
            self.print_substitutions()
            print()

        equations = self.polynomial_equations if use_poly_equations else self.equations

        for lhs, rhs in equations:
            print(f"{lhs} = {rhs}")

    def substitution_equations_str(self):
        return '\n'.join(map(str_qbee, self.introduced_variables))

    def print_substitutions(self, str_func=str_qbee):
        print("Introduced variables:")
        print('\n'.join([str_func(eq) for eq in self.introduced_variables]))

    def is_polynomial(self) -> bool:
        self._fill_poly_system()  # possible performance issue
        return all([x is not None for x in self._poly_equations.values()])
    def _try_convert_to_polynomial(self, expr):
        try:
            if isinstance(expr, (list, tuple)):
                return None

            replaced = expr

            for new_var, old_expr in self._substitution_equations.items():
                if isinstance(old_expr, (list, tuple)):
                    continue
                try:
                    replaced = replaced.subs(old_expr == new_var)
                except:
                    pass

            replaced = replaced.expand().simplify_full()

            vars_list = sorted(
                list(self.variables.state) + list(self.variables.input),
                key=str
            )

            clean_vars = [v for v in vars_list if "'" not in str(v)]

            R = PolynomialRing(QQ, clean_vars)

            R(replaced)   # <-- КЛЮЧЕВАЯ ПРОВЕРКА

            return replaced

        except:
            return None
    
    def to_poly_equations(self, inputs_ord: dict):
        self._fill_poly_system()

        inputs_ord_sym = {
            v: 0
            for v in self.variables.input
            if "'" not in str(v)
        }

        for k, v in inputs_ord.items():
            inputs_ord_sym[var(str(k))] = v

        d_inputs = generate_derivatives(inputs_ord_sym)

        # flatten (Sage-safe)
        def flatten_safe(x):
            if isinstance(x, (list, tuple, set)):
                out = []
                for i in x:
                    out.extend(flatten_safe(i))
                return out
            return [x]
        unique_inputs = set()
        for item in d_inputs:
            for x in item:
                if isinstance(x, (list, tuple, set)):
                    continue
                if hasattr(x, "variables") or hasattr(x, "operator"):
                    unique_inputs.add(x)

        all_vars = list(self.variables.state) + list(unique_inputs)
        all_vars = [var(str(v)) if not hasattr(v, "operator") else v for v in all_vars]

        R = PolynomialRing(QQ, all_vars)

        equations = [
            (eq[0], R(eq[1].expand()))
            for eq in self.polynomial_equations
        ]       

        for v in inputs_ord_sym:
            for g in R.gens():
                if str(v) + "'" in str(g):
                    equations.append(g)
            equations.append(R(0))

        inputs_to_exclude = []

        for item in d_inputs:
            try:
                inputs_to_exclude.append(tuple(R(x) for x in item))
            except:
                pass

        return equations, inputs_to_exclude, list(unique_inputs)
    def _is_expr_polynomial(self, expr):
        # ----------------------------
        # 1. fast path (pure polynomial)
        # ----------------------------
        if not self.variables.laurent:
            return expr.is_polynomial(
                *self.variables.state,
                *self.variables.input
            )

        # ----------------------------
        # 2. Laurent mode (QBee logic)
        # ----------------------------
        non_polynomials = find_nonpolynomial_terms(
            expr,
            set(self.variables.state) | set(self.variables.input)
        )

        return len(filter_laurent_monoms(self, non_polynomials)) == 0
    

    def __str__(self):
        equations = self.polynomial_equations if self.is_polynomial() else self.equations
        return '\n'.join([str_qbee(eq) for eq in equations])

    def __len__(self):
        return len(self._equations)
