## Rails 3.2.10 ##

## Rails 3.2.9 (Nov 12, 2012) ##

*   Due to a change in builder, nil values and empty strings now generates
    closed tags, so instead of this:

        <pseudonyms nil=\"true\"></pseudonyms>

    It generates this:

        <pseudonyms nil=\"true\"/>

    *Carlos Antonio da Silva*

## Rails 3.2.8 (Aug 9, 2012) ##

*   No changes.

## Rails 3.2.7 (Jul 26, 2012) ##

* `validates_inclusion_of` and `validates_exclusion_of` now accept `:within` option as alias of `:in` as documented.

* Fix the the backport of the object dup with the ruby 1.9.3p194.

## Rails 3.2.6 (Jun 12, 2012) ##

*   No changes.

## Rails 3.2.4 (May 31, 2012) ##

*   No changes.

## Rails 3.2.3 (March 30, 2012) ##

*   No changes.


## Rails 3.2.2 (March 1, 2012) ##

*   No changes.


## Rails 3.2.1 (January 26, 2012) ##

*   No changes.


## Rails 3.2.0 (January 20, 2012) ##

*   Deprecated `define_attr_method` in `ActiveModel::AttributeMethods`, because this only existed to
    support methods like `set_table_name` in Active Record, which are themselves being deprecated. *Jon Leighton*

*   Add ActiveModel::Errors#added? to check if a specific error has been added *Martin Svalin*

*   Add ability to define strict validation(with :strict => true option) that always raises exception when fails *Bogdan Gusiev*

*   Deprecate "Model.model_name.partial_path" in favor of "model.to_partial_path" *Grant Hutchins, Peter Jaros*

*   Provide mass_assignment_sanitizer as an easy API to replace the sanitizer behavior. Also support both :logger (default) and :strict sanitizer behavior *Bogdan Gusiev*

Please check [3-1-stable](https://github.com/rails/rails/blob/3-1-stable/activemodel/CHANGELOG.md) for previous changes.
