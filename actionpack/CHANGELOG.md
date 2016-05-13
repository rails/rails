*   Add `config.action_dispatch.x_accel_mappings` to configure path rewriting for Nginx's `X-Accel-Redirect` header

    A developer can configure `#send_file` to use Nginx's `X-Accel-Redirect` header,
    but still not able to configure its pairing header `X-Accel-Mapping` from Rails.

    `Rack::Sendfile#initialize` supports custom mappings since ver 1.5.0 (Jan 2013).
    A new `config.action_dispatch.x_accel_mappings` option can be used to pass
    such custom mappings to `Rack::Sendfile` middleware.

    *Alexey Chernenkov*

Please check [5-0-stable](https://github.com/rails/rails/blob/5-0-stable/actionpack/CHANGELOG.md) for previous changes.
