*   Add `ActionController::Live#send_stream` that makes it more convenient to send generated streams:

    ```ruby
    send_stream(filename: "subscribers.csv") do |stream|
      stream.write "email_address,updated_at\n"
    
      @subscribers.find_each do |subscriber|
        stream.write "#{subscriber.email_address},#{subscriber.updated_at}\n"
      end
    end
    ```
    
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

*   Change the request method to a `GET` when passing failed requests down to `config.exceptions_app`.

    *Alex Robbin*

*   Add `redirect_back_or_to(fallback_location, **)` as a more aesthetically pleasing version of `redirect_back fallback_location:, **`.
    The old method name is retained without explicit deprecation.

    *DHH*


Please check [6-1-stable](https://github.com/rails/rails/blob/6-1-stable/actionpack/CHANGELOG.md) for previous changes.
