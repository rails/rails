*   Add rate limiting functionality for Active Job

    Similar to ActionController's rate limit feature, jobs can now limit
    their execution frequency using the `rate_limit` method.
    This helps prevent resource overload and respect third-party API limits.

    ```ruby
    class ExternalApiCallJob < ApplicationJob
        rate_limit to: 10, within: 1.second, name: "burst"
        rate_limit to: 1000, within: 1.hour, name: "sustained"
    end
    ```

    *heka1024*

Please check [8-1-stable](https://github.com/rails/rails/blob/8-1-stable/activejob/CHANGELOG.md) for previous changes.
