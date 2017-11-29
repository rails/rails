*   Accept block as fallback_location for redirect_back.

    *Max Melentiev*

*   Introduce a new error page to when the implict render page is accessed in the browser.

    Now instead of showing an error page that with exception and backtraces we now show only
    one informative page.

    *Vinicius Stock*

*   Introduce ActionDispatch::DebugExceptions.register_interceptor

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
