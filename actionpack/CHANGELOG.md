*   Fix an issue where partials with a number in the filename weren't being digested for cache dependencies.

    *Bryan Ricker*

*   Store the request id provided by ActionDispatch::RequestId as a thread local-variable so it can be used
    by code that doesn't have explicit access to the current request.

    *Sam Neubardt*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
