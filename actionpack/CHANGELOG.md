*   Add support for 'private, no-store' Cache-Control headers.

    Previously, 'no-store' was exclusive; no other directives could be specified.

    *Alex Smith*

*   Expand payload of `unpermitted_parameters.action_controller` instrumentation to allow subscribers to
    know which controller action received unpermitted parameters.

    *bbuchalter*

*   Add `ActionController::Live#send_stream` that makes it more convenient to send generated streams:

    ```ruby
    send_stream(filename: "subscribers.csv") do |stream|
      stream.writeln "email_address,updated_at"
    
      @subscribers.find_each do |subscriber|
        stream.writeln [ subscriber.email_address, subscriber.updated_at ].join(",")
      end
    end
    ```
    
    *DHH*

*   Add `ActionController::Live::Buffer#writeln` to write a line to the stream with a newline included.

    *DHH*

*   `ActionDispatch::Request#content_type` now returned Content-Type header as it is.

    Previously, `ActionDispatch::Request#content_type` returned value does NOT contain charset part.
    This behavior changed to returned Content-Type header containing charset part as it is.

    If you want just MIME type, please use `ActionDispatch::Request#media_type` instead.

    Before:

    ```ruby
    request = ActionDispatch::Request.new("CONTENT_TYPE" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
    request.content_type #=> "text/csv"
    ```

    After:

    ```ruby
    request = ActionDispatch::Request.new("Content-Type" => "text/csv; header=present; charset=utf-16", "REQUEST_METHOD" => "GET")
    request.content_type #=> "text/csv; header=present; charset=utf-16"
    request.media_type   #=> "text/csv"
    ```

    *Rafael Mendonça França*

*   Change `ActionDispatch::Request#media_type` to return `nil` when the request don't have a `Content-Type` header.

    *Rafael Mendonça França*

*   Fix error in `ActionController::LogSubscriber` that would happen when throwing inside a controller action.

    *Janko Marohnić*

*   Allow anything with `#to_str` (like `Addressable::URI`) as a `redirect_to` location

    *ojab*

*   Change the request method to a `GET` when passing failed requests down to `config.exceptions_app`.

    *Alex Robbin*

*   Deprecate the ability to assign a single value to `config.action_dispatch.trusted_proxies`
    as `RemoteIp` middleware behaves inconsistently depending on whether this is configured
    with a single value or an enumerable.

    Fixes #40772

    *Christian Sutter*

*   Add `redirect_back_or_to(fallback_location, **)` as a more aesthetically pleasing version of `redirect_back fallback_location:, **`.
    The old method name is retained without explicit deprecation.

    *DHH*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionpack/CHANGELOG.md) for previous changes.
