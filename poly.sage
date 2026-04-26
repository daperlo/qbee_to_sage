from collections.abc import Iterable
import pickle
from functools import cached_property
load("utils.sage")
load("sage_sympy_tools.sage")

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
        return [(x, f) for x, f in self._substitution_equations.items()]

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

    def add_new_var(self, substitution, new_var=None) -> None:
        """
        Добавляет new_var = substitution в систему.
        """
        if substitution in self._substitution_equations.values():
            return

        if new_var is None:
            new_var = self.variables.create()

        self._substitution_equations[new_var] = substitution
        self._equations[new_var] = self._calculate_Lie_derivative(substitution)

        self._fill_poly_system()

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
            self.variables.input.add(input_var_dot)
            result += diff(expr, input_var) * input_var_dot

        return result

    def _fill_poly_system(self):
        for x, fx in self._equations.items():
            if x not in self._poly_equations:
                self._poly_equations[x] = None

            if self._poly_equations[x] is None:
                self._poly_equations[x] = self._try_convert_to_polynomial(fx)

    def print(self, str_func=str_qbee, use_poly_equations=True, with_introduced_variables=True):
        if with_introduced_variables:
            self.print_substitutions(str_func)
            print()

        equations = self.polynomial_equations if use_poly_equations else self.equations
        print("\n".join([str_func(eq) for eq in equations]))

    def substitution_equations_str(self):
        return '\n'.join(map(str_qbee, self.introduced_variables))

    def print_substitutions(self, str_func=str_qbee):
        print("Introduced variables:")
        print('\n'.join([str_func(eq) for eq in self.introduced_variables]))

    def is_polynomial(self) -> bool:
        self._fill_poly_system()  # possible performance issue
        return all([x is not None for x in self._poly_equations.values()])
    def _try_convert_to_polynomial(self, expr):
        """
        Sage version of QBee polynomial conversion.
        Uses Sage SR + custom replace_pow tool.
        """

        try:
            # ----------------------------
            # 1. substitute introduced variables
            # ----------------------------
            replaced = expr

            for new_var, old_expr in self._substitution_equations.items():
                replaced = replaced.subs({old_expr: new_var})

            # ----------------------------
            # 2. handle powers (SymPy .replace(Pow, ...) replacement)
            # ----------------------------
            replaced = replace_pow(
                replaced,
                lambda base, exp: base^exp
            )

            # ----------------------------
            # 3. polynomial check (Sage native)
            # ----------------------------
            vars_list = list(self.variables.state) + list(self.variables.input)

            if replaced.is_polynomial(vars_list):
                return replaced

            return None

        except Exception:
            return None
    
    def to_poly_equations(self, inputs_ord: dict):

        # ----------------------------
        # 1. ensure polynomial system is filled
        # ----------------------------
        self._fill_poly_system()

        # ----------------------------
        # 2. build inputs (Sage variables)
        # ----------------------------
        inputs_ord_sym = {
            v: 0
            for v in self.variables.input
            if "'" not in str(v)   # remove derivatives
        }

        # add external inputs
        for k, v in inputs_ord.items():
            inputs_ord_sym[var(str_qbee(k))] = v

        # ----------------------------
        # 3. derivatives of inputs
        # ----------------------------
        d_inputs = generate_derivatives(inputs_ord_sym)

        # ----------------------------
        # 4. flatten unique variables (NO SymPy flatten/OrderedSet)
        # ----------------------------
        unique_flattened_inputs = []
        for item in d_inputs:
            for x in item:
                if isinstance(x, list):
                    unique_flattened_inputs.extend(flatten(x))
                else:
                    unique_flattened_inputs.append(x)

        unique_flattened_inputs = list(set(unique_flattened_inputs))

        # ----------------------------
        # 5. build polynomial ring (Sage replacement for sp.ring)
        # ----------------------------
        all_vars = list(self.variables.state) + unique_flattened_inputs
        R = PolynomialRing(QQ, all_vars)

        # ----------------------------
        # 6. build equations (Laurent-style builder must be Sage-compatible)
        # ----------------------------
        equations = make_laurent_poly(
            [eq[1] for eq in self.polynomial_equations],  # RHS only
            self.variables.state,
            unique_flattened_inputs,
            R
        )

        # ----------------------------
        # 7. add input derivative constraints
        # ----------------------------
        for v in inputs_ord_sym:

            # find derivative generators in ring
            for g in R.gens():
                if str(v) + "'" in str(g):
                    equations.append(g)

            # zero constraint
            equations.append(R(0))

        # ----------------------------
        # 8. build exclusion list
        # ----------------------------
        inputs_to_exclude = []

        for item in d_inputs:
            try:
                clean_item = []
                for x in item:
                    if isinstance(x, list):
                        clean_item.extend(flatten(x))
                    else:
                        clean_item.append(x)

                inputs_to_exclude.append(tuple(R(x) for x in clean_item))
            except Exception:
                pass

        # ----------------------------
        # 9. return
        # ----------------------------
        return equations, inputs_to_exclude, unique_flattened_inputs
    
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
    
    def _replace_negative_integer_pow(self, base, exp):

        # только целые отрицательные степени
        if exp in ZZ and exp < 0:

            inv_expr = 1 / base

            # подставляем уже введённые переменные
            inv_expr = inv_expr.subs(self._substitution_equations)

            new_var = key_from_value(self._substitution_equations, inv_expr)

            if new_var is not None:
                return new_var^(-exp)
        return base^exp


    def _replace_irrational_pow(self, base, exp):

        # вещественные (нецелые) степени
        if exp in RR:

            for k, v in self._substitution_equations.items():

                # v должно быть степенью
                if hasattr(v, "operator") and v.operator().__name__ == "pow":

                    b, e = v.operands()

                    # совпадает база + почти совпадает степень
                    if b == base and abs(float(e) - float(exp)) < 1e-9:
                        return k

        return base^exp

    def _replace_symbolic_pow(self, base, exp):

        # символические степени (не число)
        if exp not in ZZ and exp not in RR:

            for k, v in self._substitution_equations.items():

                if hasattr(v, "operator") and v.operator().__name__ == "pow":

                    b, e = v.operands()

                    if b == base:

                        ratio = exp / e

                        if ratio in ZZ:
                            return k^ratio

        return base^exp

    def __str__(self):
        equations = self.polynomial_equations if self.is_polynomial() else self.equations
        return '\n'.join([str_qbee(eq) for eq in equations])

    def __len__(self):
        return len(self._equations)
