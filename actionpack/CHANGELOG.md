*   Allow ActionDispatch::FileHandler to respond with brotli encoded files

    Add support for Rails applications to serve brotli (.br) compressed static assets when incoming requests have the "Accept-Encoding" header set (contains "br") and the asset exists on the file system. Will prioritize brotli encoding over gzip due to the better compression ratio.

    *Ryan Edward Hall*

*   Add `Referrer-Policy` header to default headers set.

    *Guillermo Iguaran*

*   Changed the system tests to set Puma as default server only when the
    user haven't specified manually another server.

    *Guillermo Iguaran*

*   Add secure `X-Download-Options` and `X-Permitted-Cross-Domain-Policies` to
    default headers set.

    *Guillermo Iguaran*

*   Add headless firefox support to System Tests.

    *bogdanvlviv*

*   Changed the default system test screenshot output from `inline` to `simple`.

    `inline` works well for iTerm2 but not everyone uses iTerm2. Some terminals like
    Terminal.app ignore the `inline` and output the path to the file since it can't
    render the image. Other terminals, like those on Ubuntu, cannot handle the image
    inline, but also don't handle it gracefully and instead of outputting the file
    path, it dumps binary into the terminal.

    Commit 9d6e28 fixes this by changing the default for screenshot to be `simple`.

    *Eileen M. Uchitelle*

*   Register most popular audio/video/font mime types supported by modern browsers.

    *Guillermo Iguaran*

*   Fix optimized url helpers when using relative url root

    Fixes #31220.

    *Andrew White*


## Rails 5.2.0.beta2 (November 28, 2017) ##

*   No changes.


## Rails 5.2.0.beta1 (November 27, 2017) ##

*   Add DSL for configuring Content-Security-Policy header

    The DSL allows you to configure a global Content-Security-Policy
    header and then override within a controller. For more information
    about the Content-Security-Policy header see MDN:

    https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy

    Example global policy:

        # config/initializers/content_security_policy.rb
        Rails.application.config.content_security_policy do |p|
          p.default_src :self, :https
          p.font_src    :self, :https, :data
          p.img_src     :self, :https, :data
          p.object_src  :none
          p.script_src  :self, :https
          p.style_src   :self, :https, :unsafe_inline
        end

    Example controller overrides:

        # Override policy inline
        class PostsController < ApplicationController
          content_security_policy do |p|
            p.upgrade_insecure_requests true
          end
        end

        # Using literal values
        class PostsController < ApplicationController
          content_security_policy do |p|
            p.base_uri "https://www.example.com"
          end
        end

        # Using mixed static and dynamic values
        class PostsController < ApplicationController
          content_security_policy do |p|
            p.base_uri :self, -> { "https://#{current_user.domain}.example.com" }
          end
        end

    Allows you to also only report content violations for migrating
    legacy content using the `content_security_policy_report_only`
    configuration attribute, e.g;

        # config/initializers/content_security_policy.rb
        Rails.application.config.content_security_policy_report_only = true

        # controller override
        class PostsController < ApplicationController
          self.content_security_policy_report_only = true
        end

    Note that this feature does not validate the header for performance
    reasons since the header is calculated at runtime.

    *Andrew White*

*   Make `assert_recognizes` to traverse mounted engines

    *Yuichiro Kaneko*

*   Remove deprecated `ActionController::ParamsParser::ParseError`.

    *Rafael Mendonça França*

*   Add `:allow_other_host` option to `redirect_back` method.

    When `allow_other_host` is set to `false`, the `redirect_back` will not allow redirecting from a
    different host. `allow_other_host` is `true` by default.

    *Tim Masliuchenko*

*   Add headless chrome support to System Tests.

    *Yuji Yaginuma*

*   Add ability to enable Early Hints for HTTP/2

    If supported by the server, and enabled in Puma this allows H2 Early Hints to be used.

    The `javascript_include_tag` and the `stylesheet_link_tag` automatically add Early Hints if requested.

    *Eileen M. Uchitelle*, *Aaron Patterson*

*   Simplify cookies middleware with key rotation support

    Use the `rotate` method for both `MessageEncryptor` and
    `MessageVerifier` to add key rotation support for encrypted and
    signed cookies. This also helps simplify support for legacy cookie
    security.

    *Michael J Coyne*

*   Use Capybara registered `:puma` server config.

    The Capybara registered `:puma` server ensures the puma server is run in process so
    connection sharing and open request detection work correctly by default.

    *Thomas Walpole*

*   Cookies `:expires` option supports `ActiveSupport::Duration` object.

        cookies[:user_name] = { value: "assain", expires: 1.hour }
        cookies[:key] = { value: "a yummy cookie", expires: 6.months }

    Pull Request: #30121

    *Assain Jaleel*

*   Enforce signed/encrypted cookie expiry server side.

    Rails can thwart attacks by malicious clients that don't honor a cookie's expiry.

    It does so by stashing the expiry within the written cookie and relying on the
    signing/encrypting to vouch that it hasn't been tampered with. Then on a
    server-side read, the expiry is verified and any expired cookie is discarded.

    Pull Request: #30121

    *Assain Jaleel*

*   Make `take_failed_screenshot` work within engine.

    Fixes #30405.

    *Yuji Yaginuma*

*   Deprecate `ActionDispatch::TestResponse` response aliases.

    `#success?`, `#missing?` & `#error?` are not supported by the actual
    `ActionDispatch::Response` object and can produce false-positives. Instead,
    use the response helpers provided by `Rack::Response`.

    *Trevor Wistaff*

*   Protect from forgery by default

    Rather than protecting from forgery in the generated `ApplicationController`,
    add it to `ActionController::Base` depending on
    `config.action_controller.default_protect_from_forgery`. This configuration
    defaults to false to support older versions which have removed it from their
    `ApplicationController`, but is set to true for Rails 5.2.

    *Lisa Ugray*

*   Fallback `ActionController::Parameters#to_s` to `Hash#to_s`.

    *Kir Shatrov*

*   `driven_by` now registers poltergeist and capybara-webkit.

    If poltergeist or capybara-webkit are set as drivers is set for System Tests,
    `driven_by` will register the driver and set additional options passed via
    the `:options` parameter.

    Refer to the respective driver's documentation to see what options can be passed.

    *Mario Chavez*

*   AEAD encrypted cookies and sessions with GCM.

    Encrypted cookies now use AES-GCM which couples authentication and
    encryption in one faster step and produces shorter ciphertexts. Cookies
    encrypted using AES in CBC HMAC mode will be seamlessly upgraded when
    this new mode is enabled via the
    `action_dispatch.use_authenticated_cookie_encryption` configuration value.

    *Michael J Coyne*

*   Change the cache key format for fragments to make it easier to debug key churn. The new format is:

        views/template/action.html.erb:7a1156131a6928cb0026877f8b749ac9/projects/123
              ^template path           ^template tree digest            ^class   ^id

    *DHH*

*   Add support for recyclable cache keys with fragment caching. This uses the new versioned entries in the
    `ActiveSupport::Cache` stores and relies on the fact that Active Record has split `#cache_key` and `#cache_version`
    to support it.

    *DHH*

*   Add `action_controller_api` and `action_controller_base` load hooks to be called in `ActiveSupport.on_load`

    `ActionController::Base` and `ActionController::API` have differing implementations. This means that
    the one umbrella hook `action_controller` is not able to address certain situations where a method
    may not exist in a certain implementation.

    This is fixed by adding two new hooks so you can target `ActionController::Base` vs `ActionController::API`

    Fixes #27013.

    *Julian Nadeau*


Please check [5-1-stable](https://github.com/rails/rails/blob/5-1-stable/actionpack/CHANGELOG.md) for previous changes.
