*   Cache and re-use generated attibute methods.

    Generated methods with identical implementations will now share their instruction sequences
    leading to reduced memory retention, and sligtly faster load time.

    *Jean Boussier*

*   Add `in: range`  parameter to `numericality` validator.

    *Michal Papis*

*   Add `locale` argument to `ActiveModel::Name#initialize` to be used to generate the `singular`,
   `plural`, `route_key` and `singular_route_key` values.

    *Lukas Pokorny*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activemodel/CHANGELOG.md) for previous changes.
