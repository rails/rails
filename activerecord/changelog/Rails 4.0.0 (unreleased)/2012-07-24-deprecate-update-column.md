*   Deprecate `update_column` method in favor of `update_columns`.

    *Rafael Mendonça França*

*   Added an `update_columns` method. This new method updates the given attributes on an object,
    without calling save, hence skipping validations and callbacks.
    Example:

        User.first.update_columns({:name => "sebastian", :age => 25})         # => true

    *Sebastian Martinez + Rafael Mendonça França*
