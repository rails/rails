## Rails 7.0.0.alpha2 (September 15, 2021) ##

*   No changes.


## Rails 7.0.0.alpha1 (September 15, 2021) ##

*   Introduce `ActiveModel::API`.

    Make `ActiveModel::API` the minimum API to talk with Action Pack and Action View.
    This will allow adding more functionality to `ActiveModel::Model`.

    *Petrik de Heus*, *Nathaniel Watts*

*   Fix dirty check for Float::NaN and BigDecimal::NaN.

    Float::NaN and BigDecimal::NaN in Ruby are [special values](https://bugs.ruby-lang.org/issues/1720) 
    and can't be compared with `==`.

    *Marcelo Lauxen*

*   Fix `to_json` for `ActiveModel::Dirty` object.

    Exclude `mutations_from_database` attribute from json as it lead to recursion.

    *Anil Maurya*

*   Add `ActiveModel::AttributeSet#values_for_database`.

    Returns attributes with values for assignment to the database.

    *Chris Salzberg*

*   Fix delegation in ActiveModel::Type::Registry#lookup and ActiveModel::Type.lookup.

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

*   Make ActiveModel::Errors#inspect slimmer for readability

    *lulalala*

Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/activemodel/CHANGELOG.md) for previous changes.
