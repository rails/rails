*   Add `config.log_tag_computer` to configure the computation of tags in
    Rails::Rack::Logger.

        module StructuredTagComputer
          def self.call(request, taggers)
            {
              request_id: request.request_id
            }
          end
        end

        config.log_tag_computer = StructuredTagComputer

    The `compute_tags` method on Rails::Rack::Logger is deprecated, but its functionality
    can be restored by passing ActiveSupport::TaggedLogging::TagComputer as the
    third argument when adding Rails::Rack::Logger to the middleware stack:

        app.middleware.use Rails::Rack::Logger, [:request_id], ActiveSupport::TaggedLogging::TagComputer

    *Hartley McGuire*

*   No longer add autoloaded paths to `$LOAD_PATH`.

    This means it won't be possible to load them with a manual `require` call, the class or module can be referenced instead.

    Reducing the size of `$LOAD_PATH` speed-up `require` calls for apps not using `bootsnap`, and reduce the
    size of the `bootsnap` cache for the others.

    *Jean Boussier*

*   Remove default `X-Download-Options` header

    This header is currently only used by Internet Explorer which
    will be discontinued in 2022 and since Rails 7 does not fully
    support Internet Explorer this header should not be a default one.

    *Harun Sabljaković*

Please check [7-0-stable](https://github.com/rails/rails/blob/7-0-stable/railties/CHANGELOG.md) for previous changes.
