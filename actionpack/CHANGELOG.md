*   Fix strong parameters `permit!` with nested arrays.

    Given:
    ```
    params = ActionController::Parameters.new(nested_arrays: [[{ x: 2, y: 3 }, { x: 21, y: 42 }]])
    params.permit!
    ```

    `params[:nested_arrays][0][0].permitted?` will now return `true` instead of `false`.

    *Steve Hull*

*   Output only one Content-Security-Policy nonce header value per request.

    Fixes #32597.

    *Andrey Novikov*, *Andrew White*

*   Move default headers configuration into their own module that can be included in controllers.

    *Kevin Deisz*

*   Add method `dig` to `session`.

    *claudiob*, *Takumi Shotoku*

*   Controller level `force_ssl` has been deprecated in favor of
    `config.force_ssl`.

    *Derek Prior*

*   Rails 6 requires Ruby 2.4.1 or newer.

    *Jeremy Daer*


Please check [5-2-stable](https://github.com/rails/rails/blob/5-2-stable/actionpack/CHANGELOG.md) for previous changes.
