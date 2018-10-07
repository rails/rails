*   Exclude additional flash types from `ActionController::Base.action_methods`

    Ensures that additional flash types defined on ActionController::Base subclasses
    are not listed as actions on that controller.

        class MyController < ApplicationController
          add_flash_types :hype
        end

        MyController.action_methods.include?('hype') # => false

    *Gavin Morrice*

*   Remove undocumented `params` option from `url_for` helper.

    *Ilkka Oksanen*

*   Encode Content-Disposition filenames on `send_data` and `send_file`.
    Previously, `send_data 'data', filename: "\u{3042}.txt"` sends
    `"filename=\"\u{3042}.txt\""` as Content-Disposition and it can be
    garbled.
    Now it follows [RFC 2231](https://tools.ietf.org/html/rfc2231) and
    [RFC 5987](https://tools.ietf.org/html/rfc5987) and sends
    `"filename=\"%3F.txt\"; filename*=UTF-8''%E3%81%82.txt"`.
    Most browsers can find filename correctly and old browsers fallback to ASCII
    converted name.

    *Fumiaki Matsushima*

*   Expose `ActionController::Parameters#each_key` which allows iterating over
    keys without allocating an array.

    *Richard Schneeman*

*   Purpose metadata for signed/encrypted cookies.

    Rails can now thwart attacks that attempt to copy signed/encrypted value
    of a cookie and use it as the value of another cookie.

    It does so by stashing the cookie-name in the purpose field which is
    then signed/encrypted along with the cookie value. Then, on a server-side
    read, we verify the cookie-names and discard any attacked cookies.

    Enable `action_dispatch.use_cookies_with_metadata` to use this feature, which
    writes cookies with the new purpose and expiry metadata embedded.

    *Assain Jaleel*

*   Raises `ActionController::RespondToMismatchError` with confliciting `respond_to` invocations.

    `respond_to` can match multiple types and lead to undefined behavior when
    multiple invocations are made and the types do not match:

        respond_to do |outer_type|
          outer_type.js do
            respond_to do |inner_type|
              inner_type.html { render body: "HTML" }
            end
          end
        end

    *Patrick Toomey*

*   `ActionDispatch::Http::UploadedFile` now delegates `to_path` to its tempfile.

    This allows uploaded file objects to be passed directly to `File.read`
    without raising a `TypeError`:

        uploaded_file = ActionDispatch::Http::UploadedFile.new(tempfile: tmp_file)
        File.read(uploaded_file)

    *Aaron Kromer*

*   Pass along arguments to underlying `get` method in `follow_redirect!`.

    Now all arguments passed to `follow_redirect!` are passed to the underlying
    `get` method. This for example allows to set custom headers for the
    redirection request to the server.

        follow_redirect!(params: { foo: :bar })

    *Remo Fritzsche*

*   Introduce a new error page to when the implicit render page is accessed in the browser.

    Now instead of showing an error page that with exception and backtraces we now show only
    one informative page.

    *Vinicius Stock*

*   Introduce `ActionDispatch::DebugExceptions.register_interceptor`.

    Exception aware plugin authors can use the newly introduced
    `.register_interceptor` method to get the processed exception, instead of
    monkey patching DebugExceptions.

        ActionDispatch::DebugExceptions.register_interceptor do |request, exception|
          HypoteticalPlugin.capture_exception(request, exception)
        end

    *Genadi Samokovarov*

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
