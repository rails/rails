*   Reduced log noise handling ActionController::RoutingErrors.

    *Alberto Fernández-Capel*

*   Add DSL for configuring HTTP Feature Policy

    This new DSL provides a way to configure a HTTP Feature Policy at a
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

*   Calling `ActionController::Parameters#transform_keys/!` without a block now returns
    an enumerator for the parameters instead of the underlying hash.

    *Eugene Kenny*

*   Fix strong parameters blocks all attributes even when only some keys are invalid (non-numerical).
    It should only block invalid key's values instead.

    *Stan Lo*


Please check [6-0-stable](https://github.com/rails/rails/blob/6-0-stable/actionpack/CHANGELOG.md) for previous changes.
