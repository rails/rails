## Rails 7.0.5 (May 24, 2023) ##

*   No changes.


## Rails 7.0.4.3 (March 13, 2023) ##

*   No changes.


## Rails 7.0.4.2 (January 24, 2023) ##

*   No changes.


## Rails 7.0.4.1 (January 17, 2023) ##

*   No changes.


## Rails 7.0.4 (September 09, 2022) ##

*   Handle name clashes in attribute methods code generation cache.

    When two distinct attribute methods would generate similar names,
    the first implementation would be incorrectly re-used.

    ```ruby
    class A
      attribute_method_suffix "_changed?"
      define_attribute_methods :x
    end

    class B
      attribute_method_suffix "?"
      define_attribute_methods :x_changed
    end
    ```

    *Jean Boussier*

## Rails 7.0.3.1 (July 12, 2022) ##

*   No changes.


## Rails 7.0.3 (May 09, 2022) ##

*   No changes.


## Rails 7.0.2.4 (April 26, 2022) ##

*   No changes.


## Rails 7.0.2.3 (March 08, 2022) ##

*   No changes.


## Rails 7.0.2.2 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2.1 (February 11, 2022) ##

*   No changes.


## Rails 7.0.2 (February 08, 2022) ##

*   Use different cache namespace for proxy calls

    Models can currently have different attribute bodies for the same method
    names, leading to conflicts. Adding a new namespace `:active_model_proxy`
    fixes the issue.

    *Chris Salzberg*


## Rails 7.0.1 (January 06, 2022) ##

*   No changes.


## Rails 7.0.0 (December 15, 2021) ##

*   No changes.


## Rails 7.0.0.rc3 (December 14, 2021) ##

*   No changes.


## Rails 7.0.0.rc2 (December 14, 2021) ##

*   No changes.

## Rails 7.0.0.rc1 (December 06, 2021) ##

*   Remove support to Marshal load Rails 5.x `ActiveModel::AttributeSet` format.

    *Rafael Mendonça França*

*   Remove support to Marshal and YAML load Rails 5.x error format.

    *Rafael Mendonça França*

*   Remove deprecated support to use `[]=` in `ActiveModel::Errors#messages`.

    *Rafael Mendonça França*

*   Remove deprecated support to `delete` errors from `ActiveModel::Errors#messages`.

    *Rafael Mendonça França*

*   Remove deprecated support to `clear` errors from `ActiveModel::Errors#messages`.

    *Rafael Mendonça França*

*   Remove deprecated support concat errors to `ActiveModel::Errors#messages`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveModel::Errors#to_xml`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveModel::Errors#keys`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveModel::Errors#values`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveModel::Errors#slice!`.

    *Rafael Mendonça França*

*   Remove deprecated `ActiveModel::Errors#to_h`.

    *Rafael Mendonça França*

*   Remove deprecated enumeration of `ActiveModel::Errors` instances as a Hash.

    *Rafael Mendonça França*

*   Clear secure password cache if password is set to `nil`

    Before:

       user.password = 'something'
       user.password = nil

       user.password # => 'something'

    Now:

       user.password = 'something'
       user.password = nil

       user.password # => nil

    *Markus Doits*

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
