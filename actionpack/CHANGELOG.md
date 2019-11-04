*   `process_action.action_controller` notifications now include the following in their payloads:

    * `:request` - the `ActionDispatch::Request`
    * `:location` - the `Location` response header

    *George Claghorn*

*   Updated `ActionDispatch::Request.remote_ip` setter to clear set the instance
    `remote_ip` to `nil` before setting the header that the value is derived
    from.

    Fixes https://github.com/rails/rails/issues/37383

    *Norm Provost*

*   `ActionController::Base.log_at` allows setting a different log level per request.

    ```ruby
    # Use the debug level if a particular cookie is set.
    class ApplicationController < ActionController::Base
      log_at :debug, if: -> { cookies[:debug] }
    end
    ```

    *George Claghorn*

*   Allow system test screen shots to be taken more than once in
    a test by prefixing the file name with an incrementing counter.

    Add an environment variable `RAILS_SYSTEM_TESTING_SCREENSHOT_HTML` to
    enable saving of HTML during a screenshot in addition to the image.
    This uses the same image name, with the extension replaced with `.html`

    *Tom Fakes*

*   Add `Vary: Accept` header when using `Accept` header for response

    For some requests like `/users/1`, Rails uses requests' `Accept`
    header to determine what to return. And if we don't add `Vary`
    in the response header, browsers might accidentally cache different
    types of content, which would cause issues: e.g. javascript got displayed
    instead of html content. This PR fixes these issues by adding `Vary: Accept`
    in these types of requests. For more detailed problem description, please read:

    https://github.com/rails/rails/pull/36213

    Fixes #25842

    *Stan Lo*

*   Fix IntegrationTest `follow_redirect!` to follow redirection using the same HTTP verb when following
    a 307 redirection.

    *Edouard Chin*

*   System tests require Capybara 3.26 or newer.

    *George Claghorn*

*   Reduced log noise handling ActionController::RoutingErrors.

    *Alberto Fernández-Capel*

*   Add DSL for configuring HTTP Feature Policy

    This new DSL provides a way to configure an HTTP Feature Policy at a
    global or per-controller level. Full details of HTTP Feature Policy
    specification and guidelines can be found at MDN:

    https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Feature-Policy

    Example global policy

    ```
    Rails.application.config.feature_policy do |f|
      f.camera      :none
      f.gyroscope   :none
      f.microphone  :none
      f.usb         :none
      f.fullscreen  :self
      f.payment     :self, "https://secure.example.com"
    end
    ```

    Example controller level policy

    ```
    class PagesController < ApplicationController
      feature_policy do |p|
        p.geolocation "https://example.com"
      end
    end
    ```

    *Jacob Bednarz*

*   Add the ability to set the CSP nonce only to the specified directives.

    Fixes #35137.

    *Yuji Yaginuma*

*   Keep part when scope option has value.

    When a route was defined within an optional scope, if that route didn't
    take parameters the scope was lost when using path helpers. This commit
    ensures scope is kept both when the route takes parameters or when it
    doesn't.

    Fixes #33219.

    *Alberto Almagro*

*   Added `deep_transform_keys` and `deep_transform_keys!` methods to ActionController::Parameters.

    *Gustavo Gutierrez*

*   Calling `ActionController::Parameters#transform_keys`/`!` without a block now returns
    an enumerator for the parameters instead of the underlying hash.

    *Eugene Kenny*

*   Fix strong parameters blocks all attributes even when only some keys are invalid (non-numerical).
    It should only block invalid key's values instead.

    *Stan Lo*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md) for previous changes.
