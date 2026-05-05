Nubmer tasks in work:
Daniil: 
Vlada:
Ekaterina: 


Number tasks ready to work:
nums: 



1) VariablesHolder.start_new_vars_with

Расположение: poly.sage -> class VariablesHolder -> @property start_new_vars_with
Назначение: возвращает начальный индекс, с которого будут создаваться новые переменные (w_5 вместо w_0).

2) VariablesHolder.start_new_vars_with(value)

Расположение: poly.sage -> class VariablesHolder -> @start_new_vars_with.setter
Назначение: задаёт начальный индекс генерации новых переменных.

3) VariablesHolder.create()

Расположение: poly.sage -> class VariablesHolder -> create()
Назначение: создаёт новую символическую переменную Sage (var("w_0"), var("w_1") и т.д.), добавляет её в state и в generated.
Зачем нужно: используется в квадратизации/заменах, когда нужно автоматически вводить новые переменные.


4) EquationSystem.polynomial_equations

Расположение: poly.sage -> class EquationSystem -> @property polynomial_equations
Назначение: возвращает уравнения системы в полиномиальной форме.
Если RHS не удалось преобразовать в полином → подставляется 0.

5) EquationSystem.laurent_substitutions

Расположение: poly.sage -> class EquationSystem -> @cached_property laurent_substitutions
Назначение: возвращает подстановки, относящиеся к Лорановым мономам (если (1/v) лежит в variables.laurent).
Зачем нужно: режим обработки систем, допускающих дробные мономы (Laurent-polynomial logic).

6) EquationSystem.expand()

Расположение: poly.sage -> class EquationSystem -> expand()
Назначение: выполняет expand() для всех правых частей уравнений системы.
Зачем нужно: приводит выражения к развёрнутому виду перед дальнейшим анализом.

7) EquationSystem.add_new_var(substitution, new_var=None)

Расположение: poly.sage -> class EquationSystem -> add_new_var()
Назначение: добавляет новую переменную для замены выражения substitution.
Алгоритм:

1. создаёт новую переменную (если не передана)
2. делает подстановку во всей системе
3. сохраняет замену в _substitution_equations
4. добавляет уравнение для производной новой переменной через Lie-derivative
5. пересчитывает полиномиальную систему

Зачем нужно: основная операция квадратизации/упрощения системы.

8) EquationSystem._sanitize(expr)

Расположение: poly.sage -> class EquationSystem -> _sanitize()
Назначение: рекурсивно приводит выражение к сумме, если оно приходит как список/кортеж/итерируемая структура.
Зачем нужно: защита от нестандартного формата выражений (когда RHS не одно выражение, а коллекция).

9) EquationSystem._calculate_Lie_derivative(expr)

Расположение: poly.sage -> class EquationSystem -> _calculate_Lie_derivative()
Назначение: вычисляет производную выражения по времени через формулу Ли

Также учитывает входные переменные (input), добавляя их производные в систему (u').
Зачем нужно: чтобы корректно добавлять уравнение для новой введённой переменной.

10) EquationSystem.is_polynomial()

Расположение: poly.sage -> class EquationSystem -> is_polynomial()
Назначение: проверяет, удалось ли представить RHS каждого уравнения как полином.
Возвращает True, если все элементы _poly_equations не равны None.

11) EquationSystem._try_convert_to_polynomial(expr)

Расположение: poly.sage -> class EquationSystem -> _try_convert_to_polynomial()
Назначение: пытается проверить, можно ли считать выражение полиномом относительно текущих переменных.
Логика:

1. подставляет новые переменные вместо введённых substitutions
2. делает expand() и simplify_full()
3. создаёт PolynomialRing(QQ, vars)
4. пытается привести выражение к полиному R(replaced)
5. Если не получается → возвращает None.

Зачем нужно: ключевой фильтр: полином / не полином.

12) EquationSystem.to_poly_equations(inputs_ord: dict)

Расположение: poly.sage -> class EquationSystem -> to_poly_equations()
Назначение: преобразует систему в объект полиномиального кольца Sage и возвращает данные для дальнейшей обработки.

Возвращает:

equations — список уравнений в виде (lhs, rhs) внутри PolynomialRing
inputs_to_exclude — список наборов производных входов, которые нужно исключить (ограничения)
unique_inputs — список всех входных переменных и их производных

Зачем нужно: подготовка системы к алгоритмам, которые требуют строгого полиномиального представления.

13) EquationSystem._is_expr_polynomial(expr)

Расположение: poly.sage -> class EquationSystem -> _is_expr_polynomial()
Назначение: проверяет является ли выражение полиномом:

обычный режим: expr.is_polynomial(...)
режим Laurent: ищет неполиномиальные члены и фильтрует допустимые Лорановы мономы

Зачем нужно: реализация логики QBee для обработки дробных мономов.

14) flatten(x)

Расположение: utils.sage -> flatten(x)
Назначение: рекурсивно разворачивает вложенные структуры (list, tuple, set) в один плоский список.
Зачем нужно: используется для безопасной обработки выражений и списков производных, чтобы не ломаться на вложенных структурах.

15) make_laurent_poly(exprs, state_vars, input_vars, R)

Расположение: utils.sage -> make_laurent_poly(exprs, state_vars, input_vars, R)
Назначение: попытка привести набор выражений к элементам полиномиального кольца R.
Если выражение не приводится — вместо него подставляется R(0).
Зачем нужно: заглушка/упрощённая реализация для поддержки Laurent-полиномов или "почти полиномиальных" выражений при преобразованиях системы.

16) generate_derivatives(inputs)

Расположение: utils.sage -> generate_derivatives(inputs)
Назначение: генерирует список пар (v, v_prime) для входных переменных системы.
Пример: u -> (u, u_prime).
Зачем нужно: используется при построении расширенной системы, где учитываются производные входов (например в EquationSystem.to_poly_equations()).

17) default_scoring(system)

Расположение: quadro.sage -> default_scoring()
Назначение: функция оценки состояния системы.
Сейчас просто возвращает количество введённых переменных (len(system.variables.generated)).

Зачем нужно: используется как scoring-функция в алгоритме квадратизации (можно заменить на более умную).

18) default_scoring(system)

Расположение: quadro.sage -> default_scoring()
Назначение: функция оценки состояния системы.
Сейчас просто возвращает количество введённых переменных (len(system.variables.generated)).

Зачем нужно: используется как scoring-функция в алгоритме квадратизации (можно заменить на более умную).

19) pruning_by_too_many_vars(algo, system, *args, nvars=10)

Расположение: quadro.sage -> pruning_by_too_many_vars()
Назначение: правило pruning (отсечения), которое останавливает ветку алгоритма, если введено слишком много новых переменных.

Возвращает True, если:

len(system.variables.generated) >= nvars

Зачем нужно: ограничение роста размерности системы.

⚠️ параметр algo сейчас фактически не используется.

20) default_pruning_rules()

Расположение: quadro.sage -> default_pruning_rules()
Назначение: возвращает список стандартных pruning-функций.
Сейчас возвращает только [pruning_by_too_many_vars].

Зачем нужно: предоставляет дефолтные ограничения для алгоритма квадратизации.

21) quadratize_poly(polynomials, max_vars=10, generation_strategy=default_generation, scoring=default_scoring, pruning_functions=None)

Расположение: quadro.sage -> quadratize_poly()
Назначение: главный алгоритм квадратизации полиномиальной системы.

Основные шаги:

Создаёт EquationSystem(dict(polynomials))
В цикле до max_vars:
генерирует кандидатов generation_strategy(system)
пробует кандидата: создаёт новую переменную system.variables.create()
вызывает system.add_new_var(expr, new_var) чтобы заменить выражение новой переменной
После цикла вызывает system.to_poly_equations({})
Возвращает QuadratizationResult(...)

Зачем нужно: автоматическое введение переменных для превращения системы в квадратичную/полиномиальную форму.

⚠️ Важные моменты:

pruning_functions передаются, но вообще не применяются в цикле.
scoring передаётся, но не используется.
introduced заполняется, но в QuadratizationResult не передаётся.
greedy-алгоритм выбирает первый успешный кандидат, без реального сравнения.
Класс QuadratizationResult
QuadratizationResult.__init__(self, equations, variables, quad_variables, algo)

Расположение: quadro.sage -> class QuadratizationResult -> __init__()
Назначение: контейнер результата квадратизации.

Хранит:

equations — итоговая система уравнений (в полиномиальном виде)
variables — переменные системы
quad_variables — переменные, связанные с квадратизацией
algo — объект алгоритма (сейчас None)
_introduced — список введённых переменных (сейчас всегда пустой)
QuadratizationResult.introduced_variables

Расположение: quadro.sage -> class QuadratizationResult -> @property introduced_variables
Назначение: возвращает список введённых переменных и соответствующих выражений (substitutions).
⚠️ Сейчас возвращает пустой список, потому что _introduced нигде не заполняется.

QuadratizationResult.print()

Расположение: quadro.sage -> class QuadratizationResult -> print()
Назначение: печатает в консоль:

введённые переменные
итоговые уравнения

⚠️ Так как _introduced не заполняется, секция "Introduced variables" обычно пустая.