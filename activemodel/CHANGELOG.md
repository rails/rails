*   Fix delegation in ActiveModel::Type::Registry#lookup

    Passing a last positional argument `{}` would be incorrectly considered as keyword argument.

    *Benoit Daloze*

*   Cache and re-use generated attribute methods.

    Generated methods with identical implementations will now share their instruction sequences
    leading to reduced memory retention, and slightly faster load time.

    *Jean Boussier*

*   Add `in: range`  parameter to `numericality` validator.

    *Michal Papis*

*   Add `locale` argument to `ActiveModel::Name#initialize` to be used to generate the `singular`,
   `plural`, `route_key` and `singular_route_key` values.

    *Lukas Pokorny*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activemodel/CHANGELOG.md) for previous changes.
