*   Fix a race condition that could cause a `Text file busy - chromedriver`
    error with parallel system tests

    *Matt Brictson*

*   Add `racc` as a dependency since it will become a bundled gem in Ruby 3.4.0

    *Hartley McGuire*

*   Implement a `:force` option for `cookies.delete` to allow deleting cookies not present in the request

    *Felipe Zavan*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionpack/CHANGELOG.md) for previous changes.
