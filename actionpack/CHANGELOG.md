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
