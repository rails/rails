*   Instance variables set in requests in a `ActionController::TestCase` are now cleared before the next request

    This means if you make multiple requests in the same test, instance variables set in the first request will
    not persist into the second one. (It's not recommended to make multiple requests in the same test.)

    *Alex Ghiculescu*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/actionpack/CHANGELOG.md) for previous changes.
