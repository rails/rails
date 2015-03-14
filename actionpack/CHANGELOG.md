*   Drop request class from RouteSet constructor.
 
    If you would like to use a custom request class, please subclass and implement
    the `request_class` method.

    *tenderlove@ruby-lang.org*

*   Fallback to `ENV['RAILS_RELATIVE_URL_ROOT']` in `url_for`.

    Fixed an issue where the `RAILS_RELATIVE_URL_ROOT` environment variable is not
    prepended to the path when `url_for` is called. If `SCRIPT_NAME` (used by Rack)
    is set, it takes precedence.

    Fixes #5122.

    *Yasyf Mohamedali*

*   Partitioning of routes is now done when the routes are being drawn. This
    helps to decrease the time spent filtering the routes during the first request.

    *Guo Xiang Tan*

*   Fix regression in functional tests. Responses should have default headers
    assigned.

    See #18423.

    *Jeremy Kemper*, *Yves Senn*

*   Deprecate AbstractController#skip_action_callback in favor of individual skip_callback methods
    (which can be made to raise an error if no callback was removed).

    *Iain Beeston*

*   Alias the `ActionDispatch::Request#uuid` method to `ActionDispatch::Request#request_id`.
    Due to implementation, `config.log_tags = [:request_id]` also works in substitute
    for `config.log_tags = [:uuid]`.

    *David Ilizarov*

*   Change filter on /rails/info/routes to use an actual path regexp from rails
    and not approximate javascript version. Oniguruma supports much more
    extensive list of features than javascript regexp engine.

    Fixes #18402.

    *Ravil Bayramgalin*

*   Non-string authenticity tokens do not raise NoMethodError when decoding
    the masked token.

    *Ville Lautanala*

*   Add `http_cache_forever` to Action Controller, so we can cache a response
    that never gets expired.

    *arthurnn*

*   `ActionController#translate` supports symbols as shortcuts.
    When shortcut is given it also lookups without action name.

    *Max Melentiev*

*   Expand `ActionController::ConditionalGet#fresh_when` and `stale?` to also
    accept a collection of records as the first argument, so that the
    following code can be written in a shorter form.

        # Before
        def index
          @articles = Article.all
          fresh_when(etag: @articles, last_modified: @articles.maximum(:updated_at))
        end

        # After
        def index
          @articles = Article.all
          fresh_when(@articles)
        end

    *claudiob*

*   Explicitly ignored wildcard verbs when searching for HEAD routes before fallback

    Fixes an issue where a mounted rack app at root would intercept the HEAD
    request causing an incorrect behavior during the fall back to GET requests.

    Example:

        draw do
            get '/home' => 'test#index'
            mount rack_app, at: '/'
        end
        head '/home'
        assert_response :success

    In this case, a HEAD request runs through the routes the first time and fails
    to match anything. Then, it runs through the list with the fallback and matches
    `get '/home'`. The original behavior would match the rack app in the first pass.

    *Terence Sun*

*   Migrating xhr methods to keyword arguments syntax
    in `ActionController::TestCase` and `ActionDispatch::Integration`

    Old syntax:

        xhr :get, :create, params: { id: 1 }

    New syntax example:

        get :create, params: { id: 1 }, xhr: true

    *Kir Shatrov*

*   Migrating to keyword arguments syntax in `ActionController::TestCase` and
    `ActionDispatch::Integration` HTTP request methods.

    Example:

        post :create, params: { y: x }, session: { a: 'b' }
        get :view, params: { id: 1 }
        get :view, params: { id: 1 }, format: :json

    *Kir Shatrov*

*   Preserve default url options when generating URLs.

    Fixes an issue that would cause default_url_options to be lost when
    generating URLs with fewer positional arguments than parameters in the
    route definition.

    *Tekin Suleyman*

*   Deprecate *_via_redirect integration test methods.

    Use `follow_redirect!` manually after the request call for the same behavior.

    *Aditya Kapoor*

*   Add `ActionController::Renderer` to render arbitrary templates
    outside controller actions.

    Its functionality is accessible through class methods `render` and
    `renderer` of `ActionController::Base`.

    *Ravil Bayramgalin*

*   Support `:assigns` option when rendering with controllers/mailers.

    *Ravil Bayramgalin*

*   Default headers, removed in controller actions, are no longer reapplied on
    the test response.

    *Jonas Baumann*

*   Deprecate all *_filter callbacks in favor of *_action callbacks.

    *Rafael Mendonça França*

*   Allow you to pass `prepend: false` to protect_from_forgery to have the
    verification callback appended instead of prepended to the chain.
    This allows you to let the verification step depend on prior callbacks.

    Example:

        class ApplicationController < ActionController::Base
          before_action :authenticate
          protect_from_forgery prepend: false, unless: -> { @authenticated_by.oauth? }

          private
            def authenticate
              if oauth_request?
                # authenticate with oauth
                @authenticated_by = 'oauth'.inquiry
              else
                # authenticate with cookies
                @authenticated_by = 'cookie'.inquiry
              end
            end
        end

    *Josef Šimánek*

*   Remove `ActionController::HideActions`.

    *Ravil Bayramgalin*

*   Remove `respond_to`/`respond_with` placeholder methods, this functionality
    has been extracted to the `responders` gem.

    *Carlos Antonio da Silva*

*   Remove deprecated assertion files.

    *Rafael Mendonça França*

*   Remove deprecated usage of string keys in URL helpers.

    *Rafael Mendonça França*

*   Remove deprecated `only_path` option on `*_path` helpers.

    *Rafael Mendonça França*

*   Remove deprecated `NamedRouteCollection#helpers`.

    *Rafael Mendonça França*

*   Remove deprecated support to define routes with `:to` option that doesn't contain `#`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Response#to_ary`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Request#deep_munge`.

    *Rafael Mendonça França*

*   Remove deprecated `ActionDispatch::Http::Parameters#symbolized_path_parameters`.

    *Rafael Mendonça França*

*   Remove deprecated option `use_route` in controller tests.

    *Rafael Mendonça França*

*   Ensure `append_info_to_payload` is called even if an exception is raised.

    Fixes an issue where when an exception is raised in the request the additonal
    payload data is not available.

    See:
    * #14903
    * https://github.com/roidrage/lograge/issues/37

    *Dieter Komendera*, *Margus Pärt*

*   Correctly rely on the response's status code to handle calls to `head`.

    *Robin Dupret*

*   Using `head` method returns empty response_body instead
    of returning a single space " ".

    The old behavior was added as a workaround for a bug in an early
    version of Safari, where the HTTP headers are not returned correctly
    if the response body has a 0-length. This is been fixed since and
    the workaround is no longer necessary.

    Fixes #18253.

    *Prathamesh Sonpatki*

*   Fix how polymorphic routes works with objects that implement `to_model`.

    *Travis Grathwell*

*   Stop converting empty arrays in `params` to `nil`.

    This behaviour was introduced in response to CVE-2012-2660, CVE-2012-2694
    and CVE-2013-0155

    ActiveRecord now issues a safe query when passing an empty array into
    a where clause, so there is no longer a need to defend against this type
    of input (any nils are still stripped from the array).

    *Chris Sinjakli*

*   Fixed usage of optional scopes in url helpers.

    *Alex Robbin*

*   Fixed handling of positional url helper arguments when `format: false`.

    Fixes #17819.

    *Andrew White*, *Tatiana Soukiassian*

Please check [4-2-stable](https://github.com/rails/rails/blob/4-2-stable/actionpack/CHANGELOG.md) for previous changes.
