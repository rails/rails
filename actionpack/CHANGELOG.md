*   Deprecate calling `[]` on non-scalar parameters

    Calling `[]` is deprecated for non-scalar types.
    This makes sure you never get a hash where you expect a scalar value.
    For non-scalar types you can use `param_at` or `dig`.

        params = ActionController::Parameters.new(
          person: {
            name: { "Matz" }
          }
        )

        # Directly calling params[:person] isn't permitted, as it isn't a
        # scalar type.
        params[:person] # => nil

        # Permitting the param still works
        params.require(:person).permit(:name)[:name] # => "Matz"

        # The old behaviour still works with `param_at`
        params.param_at(:person)[:name] # => "Matz"

    Fixes #42942

    *Petrik de Heus*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionpack/CHANGELOG.md) for previous changes.
