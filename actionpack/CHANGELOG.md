*   Access rate limiting context from `ActionDispatch::Request` and `ActionDispatch::Response`

    Add `ActionDispatch::Request#rate_limit` and `ActionDispatch::Response#retry_after`.

    *Sean Doyle*

*   Define `ActionController::Parameters#deconstruct_keys` to support pattern matching

    ```ruby
    if params in { search:, page: }
      Article.search(search).limit(page)
    else
      …
    end

    case (value = params[:string_or_hash_with_nested_key])
    in String
      # do something with a String `value`…
    in { nested_key: }
      # do something with `nested_key` or `value`
    else
      # …
    end
    ```

    *Sean Doyle*

*   Submit test requests using `as: :html` with `Content-Type: x-www-form-urlencoded`

    *Sean Doyle*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/actionpack/CHANGELOG.md) for previous changes.
