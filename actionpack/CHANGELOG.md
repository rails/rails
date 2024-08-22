## Rails 7.2.1 (August 22, 2024) ##

*   Fix `Request#raw_post` raising `NoMethodError` when `rack.input` is `nil`.

    *Hartley McGuire*


## Rails 7.2.0 (August 09, 2024) ##

*   Allow bots to ignore `allow_browser`.

    *Matthew Nguyen*

*   Include the HTTP Permissions-Policy on non-HTML Content-Types
    [CVE-2024-28103]

    *Aaron Patterson*, *Zack Deveau*

*   Fix `Mime::Type.parse` handling type parameters for HTTP Accept headers.

    *Taylor Chaparro*

*   Fix the error page that is displayed when a view template is missing to account for nested controller paths in the
    suggested correct location for the missing template.

    *Joshua Young*

*   Add `save_and_open_page` helper to `IntegrationTest`.

    `save_and_open_page` is a helpful helper to keep a short feedback loop when working on system tests.
    A similar helper with matching signature has been added to integration tests.

    *Joé Dupuis*

*   Fix a regression in 7.1.3 passing a `to:` option without a controller when the controller is already defined by a scope.

    ```ruby
    Rails.application.routes.draw do
      controller :home do
        get "recent", to: "recent_posts"
      end
    end
    ```

    *Étienne Barrié*

*   Request Forgery takes relative paths into account.

    *Stefan Wienert*

*   Add ".test" as a default allowed host in development to ensure smooth golden-path setup with puma.dev.

    *DHH*

*   Add `allow_browser` to set minimum browser versions for the application.

    A browser that's blocked will by default be served the file in `public/406-unsupported-browser.html` with a HTTP status code of "406 Not Acceptable".

    ```ruby
    class ApplicationController < ActionController::Base
      # Allow only browsers natively supporting webp images, web push, badges, import maps, CSS nesting + :has
      allow_browser versions: :modern
    end

    class ApplicationController < ActionController::Base
      # All versions of Chrome and Opera will be allowed, but no versions of "internet explorer" (ie). Safari needs to be 16.4+ and Firefox 121+.
      allow_browser versions: { safari: 16.4, firefox: 121, ie: false }
    end

    class MessagesController < ApplicationController
      # In addition to the browsers blocked by ApplicationController, also block Opera below 104 and Chrome below 119 for the show action.
      allow_browser versions: { opera: 104, chrome: 119 }, only: :show
    end
    ```

    *DHH*

*   Add rate limiting API.

    ```ruby
    class SessionsController < ApplicationController
      rate_limit to: 10, within: 3.minutes, only: :create
    end

    class SignupsController < ApplicationController
      rate_limit to: 1000, within: 10.seconds,
        by: -> { request.domain }, with: -> { redirect_to busy_controller_url, alert: "Too many signups!" }, only: :new
    end
    ```

    *DHH*, *Jean Boussier*

*   Add `image/svg+xml` to the compressible content types of `ActionDispatch::Static`.

    *Georg Ledermann*

*   Add instrumentation for `ActionController::Live#send_stream`.

    Allows subscribing to `send_stream` events. The event payload contains the filename, disposition, and type.

    *Hannah Ramadan*

*   Add support for `with_routing` test helper in `ActionDispatch::IntegrationTest`.

    *Gannon McGibbon*

*   Remove deprecated support to set `Rails.application.config.action_dispatch.show_exceptions` to `true` and `false`.

    *Rafael Mendonça França*

*   Remove deprecated `speaker`, `vibrate`, and `vr` permissions policy directives.

    *Rafael Mendonça França*

*   Remove deprecated `Rails.application.config.action_dispatch.return_only_request_media_type_on_content_type`.

    *Rafael Mendonça França*

*   Deprecate `Rails.application.config.action_controller.allow_deprecated_parameters_hash_equality`.

    *Rafael Mendonça França*

*   Remove deprecated comparison between `ActionController::Parameters` and `Hash`.

    *Rafael Mendonça França*

*   Remove deprecated constant `AbstractController::Helpers::MissingHelperError`.

    *Rafael Mendonça França*

*   Fix a race condition that could cause a `Text file busy - chromedriver`
    error with parallel system tests.

    *Matt Brictson*

*   Add `racc` as a dependency since it will become a bundled gem in Ruby 3.4.0

    *Hartley McGuire*
*   Remove deprecated constant `ActionDispatch::IllegalStateError`.

    *Rafael Mendonça França*

*   Add parameter filter capability for redirect locations.

    It uses the `config.filter_parameters` to match what needs to be filtered.
    The result would be like this:

        Redirected to http://secret.foo.bar?username=roque&password=[FILTERED]

    Fixes #14055.

    *Roque Pinel*, *Trevor Turk*, *tonytonyjan*

Please check [7-1-stable](https://github.com/rails/rails/blob/7-1-stable/actionpack/CHANGELOG.md) for previous changes.
