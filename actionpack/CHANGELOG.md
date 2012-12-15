## Rails 4.0.0 (unreleased) ##

*   `assert_template` can be used to verify the locals of partials,
    which live inside a directory.
    Fixes #8516.

        # Prefixed partials inside directories worked and still work.
        assert_template partial: 'directory/_partial', locals: {name: 'John'}

        # This did not work but does now.
        assert_template partial: 'directory/partial', locals: {name: 'John'}

    *Yves Senn*

*   Fix `content_tag_for` with array html option.
    It would embed array as string instead of joining it like `content_tag` does:

        content_tag(:td, class: ["foo", "bar"]){}
        #=> '<td class="foo bar"></td>'

    Before:

        content_tag_for(:td, item, class: ["foo", "bar"])
        #=> '<td class="item [&quot;foo&quot;, &quot;bar&quot;]" id="item_1"></td>'

    After:

        content_tag_for(:td, item, class: ["foo", "bar"])
        #=> '<td class="item foo bar" id="item_1"></td>'

    *Semyon Perepelitsa*

*   Remove `BestStandardsSupport` middleware, !DOCTYPE html already triggers
    standards mode per http://msdn.microsoft.com/en-us/library/jj676915(v=vs.85).aspx
    and ChromeFrame header has been moved to `config.action_dispatch.default_headers`

    *Guillermo Iguaran*

*   Fix CSRF protection and `current_url?` helper to work with HEAD requests
    now that `ActionDispatch::Head` has been removed in favor of `Rack::Head`.

    *Michiel Sikkes*

*   Change `asset_path` to not include `SCRIPT_NAME` when it's used
    from a mounted engine. Fixes #8119.

    *Piotr Sarnacki*

*   Add javascript based routing path matcher to `/rails/info/routes`.
    Routes can now be filtered by whether or not they match a path.

    *Richard Schneeman*

*   Given

        params.permit(:name)

    `:name` passes if it is a key of `params` whose value is a permitted scalar.

    Similarly, given

        params.permit(tags: [])

    `:tags` passes if it is a key of `params` whose value is an array of
    permitted scalars.

    Permitted scalars filtering happens at any level of nesting.

    *Xavier Noria*

*   Change the behavior of route defaults so that explicit defaults are no longer
    required where the key is not part of the path. For example:

        resources :posts, bucket_type: 'posts'

    will be required whenever constructing the url from a hash such as a functional
    test or using url_for directly. However using the explicit form alters the
    behavior so it's not required:

        resources :projects, defaults: { bucket_type: 'projects' }

    This changes existing behavior slightly in that any routes which only differ
    in their defaults will match the first route rather than the closest match.

    *Andrew White*

*   Add support for routing constraints other than Regexp and String.
    For example this now allows the use of arrays like this:

        get '/foo/:action', to: 'foo', constraints: { subdomain: %w[www admin] }

    or constraints where the request method returns an Fixnum like this:

        get '/foo', to: 'foo#index', constraints: { port: 8080 }

    Note that this only applies to constraints on the request - path constraints
    still need to be specified as Regexps as the various constraints are compiled
    into a single Regexp.

    *Andrew White*

*   Fix a bug in integration tests where setting the port via a url passed to
    the process method was ignored when constructing the request environment.

    *Andrew White*

*   Allow `:selected` to be set on `date_select` tag helper.

    *Colin Burn-Murdoch*

*   Fixed json params parsing regression for non-object JSON content.

    *Dylan Smith*

*   Extract `ActionDispatch::PerformanceTest` into https://github.com/rails/rails-perftest
    You can add the gem to your Gemfile to keep using performance tests.

        gem 'rails-perftest'

    *Yves Senn*

*   Added view_cache_dependency API for declaring dependencies that affect
    cache digest computation.

    *Jamis Buck*

*   `image_submit_tag` will set `alt` attribute from image source if not
    specified.

    *Nihad Abbasov*

*   Do not generate local variables for partials without object or collection.
    Previously rendering a partial without giving `:object` or `:collection`
    would generate a local variable with the partial name by default.

    *Carlos Antonio da Silva*

*   Return the last valid, non-private IP address from the X-Forwarded-For,
    Client-IP and Remote-Addr headers, in that order. Document the rationale
    for that decision, and describe the options that can be passed to the
    RemoteIp middleware to change it.
    Fix #7979

    *André Arko*, *Steve Klabnik*, *Alexey Gaziev*

*   Do not append second slash to `root_url` when using `trailing_slash: true`
    Fix #8700

    Example:
        # before
        root_url # => http://test.host//

        # after
        root_url # => http://test.host/

    *Yves Senn*

*   Allow to toggle dumps on error pages.

    *Gosha Arinich*

*   Fix a bug in `content_tag_for` that prevents it from working without a block.

    *Jasl*

*   Change the stylesheet of exception pages for development mode.
    Additionally display also the line of code and fragment that raised
    the exception in all exceptions pages.

    *Guillermo Iguaran + Jorge Cuadrado*

*   Do not append `charset=` parameter when `head` is called with a
    `:content_type` option.
    Fix #8661.

    *Yves Senn*

*   Added `Mime::NullType` class. This  allows to use html?, xml?, json?..etc when
    the `format` of `request` is unknown, without raise an exception.

    *Angelo Capilleri*

*   Integrate the Journey gem into Action Dispatch so that the global namespace
    is not polluted with names that may be used as models.

    *Andrew White*

*   Extract support for email address obfuscation via `:encode`, `:replace_at`, and `replace_dot`
    options from the `mail_to` helper into the `actionview-encoded_mail_to` gem.

    *Nick Reed + DHH*

*   Handle `:protocol` option in `stylesheet_link_tag` and `javascript_include_tag`

    *Vasiliy Ermolovich*

*   Clear url helper methods when routes are reloaded. *Andrew White*

*   Fix a bug in `ActionDispatch::Request#raw_post` that caused `env['rack.input']`
    to be read but not rewound.

    *Matt Venables*

*   Prevent raising EOFError on multipart GET request (IE issue). *Adam Stankiewicz*

*   Rename all action callbacks from *_filter to *_action to avoid the misconception that these
    callbacks are only suited for transforming or halting the response. With the new style,
    it's more inviting to use them as they were intended, like setting shared ivars for views.

    Example:

        class PeopleController < ActionController::Base
          before_action :set_person,      except: [:index, :new, :create]
          before_action :ensure_permission, only: [:edit, :update]

          ...

          private
            def set_person
              @person = current_account.people.find(params[:id])
            end

            def ensure_permission
              current_person.can_change?(@person)
            end
        end

    The old *_filter methods still work with no deprecation notice.

    *DHH*

*   Add `cache_if` and `cache_unless` for conditional fragment caching:

    Example:

        <%= cache_if condition, project do %>
          <b>All the topics on this project</b>
          <%= render project.topics %>
        <% end %>

        # and

        <%= cache_unless condition, project do %>
          <b>All the topics on this project</b>
          <%= render project.topics %>
        <% end %>

    *Stephen Ausman + Fabrizio Regini + Angelo Capilleri*

*   Add filter capability to ActionController logs for redirect locations:

        config.filter_redirect << 'http://please.hide.it/'

    *Fabrizio Regini*

*   Fixed a bug that ignores constraints on a glob route. This was caused because the constraint
    regular expression is overwritten when the `routes.rb` file is processed. Fixes #7924

    *Maura Fitzgerald*

*   More descriptive error messages when calling `render :partial` with
    an invalid `:layout` argument.

    Fixes #8376.

        render partial: 'partial', layout: true

        # results in ActionView::MissingTemplate: Missing partial /true

    *Yves Senn*

*   Sweepers was extracted from Action Controller as `rails-observers` gem.

    *Rafael Mendonça França*

*   Add option flag to `CacheHelper#cache` to manually bypass automatic template digests:

        <% cache project, skip_digest: true do %>
          ...
        <% end %>

    *Drew Ulmer*

*   Do not sort Hash options in `grouped_options_for_select`. *Sergey Kojin*

*   Accept symbols as `send_data :disposition` value *Elia Schito*

*   Add i18n scope to `distance_of_time_in_words`. *Steve Klabnik*

*   `assert_template`:
    - is no more passing with empty string.
    - is now validating option keys. It accepts: `:layout`, `:partial`, `:locals` and `:count`.

    *Roberto Soares*

*   Allow setting a symbol as path in scope on routes. This is now allowed:

        scope :api do
          resources :users
        end

    It is also possible to pass multiple symbols to scope to shorten multiple nested scopes:

        scope :api do
          scope :v1 do
            resources :users
          end
        end

    can be rewritten as:

        scope :api, :v1 do
          resources :users
        end

    *Guillermo Iguaran + Amparo Luna*

*   Fix error when using a non-hash query argument named "params" in `url_for`.

    Before:

        url_for(params: "") # => undefined method `reject!' for "":String

    After:

        url_for(params: "") # => http://www.example.com?params=

    *tumayun + Carlos Antonio da Silva*

*   Render every partial with a new `ActionView::PartialRenderer`. This resolves
    issues when rendering nested partials.
    Fix #8197.

    *Yves Senn*

*   Introduce `ActionView::Template::Handlers::ERB.escape_whitelist`. This is a list
    of mime types where template text is not html escaped by default. It prevents `Jack & Joe`
    from rendering as `Jack &amp; Joe` for the whitelisted mime types. The default whitelist
    contains `text/plain`.
    Fix #7976.

    *Joost Baaij*

*   Fix input name when `multiple: true` and `:index` are set.

    Before:

        check_box("post", "comment_ids", { multiple: true, index: "foo" }, 1)
        #=> <input name=\"post[foo][comment_ids]\" type=\"hidden\" value=\"0\" /><input id=\"post_foo_comment_ids_1\" name=\"post[foo][comment_ids]\" type=\"checkbox\" value=\"1\" />

    After:

        check_box("post", "comment_ids", { multiple: true, index: "foo" }, 1)
        #=> <input name=\"post[foo][comment_ids][]\" type=\"hidden\" value=\"0\" /><input id=\"post_foo_comment_ids_1\" name=\"post[foo][comment_ids][]\" type=\"checkbox\" value=\"1\" />

    Fix #8108.

    *Daniel Fox, Grant Hutchins & Trace Wax*

*   `BestStandardsSupport` middleware now appends it's `X-UA-Compatible` value to app's
    returned value if any.
    Fix #8086.

    *Nikita Afanasenko*

*   `date_select` helper accepts `with_css_classes: true` to add css classes similar with type
    of generated select tags.

    *Pavel Nikitin*

*   Only non-js/css under `app/assets` path will be included in default `config.assets.precompile`.

    *Josh Peek*

*   Remove support for the `RAILS_ASSET_ID` environment configuration
    (no longer needed now that we have the asset pipeline).

    *Josh Peek*

*   Remove old `asset_path` configuration (no longer needed now that we have the asset pipeline).

    *Josh Peek*

*   `assert_template` can be used to assert on the same template with different locals
    Fix #3675.

    *Yves Senn*

*   Remove old asset tag concatenation (no longer needed now that we have the asset pipeline).

    *Josh Peek*

*   Accept `:remote` as symbolic option for `link_to` helper. *Riley Lynch*

*   Warn when the `:locals` option is passed to `assert_template` outside of a view test case
    Fix #3415.

    *Yves Senn*

*   The `Rack::Cache` middleware is now disabled by default. To enable it,
    set `config.action_dispatch.rack_cache = true` and add `gem rack-cache` to your Gemfile.

    *Guillermo Iguaran*

*   `ActionController::Base.page_cache_extension` option is deprecated
    in favour of `ActionController::Base.default_static_extension`.

    *Francesco Rodriguez*

*   Action and Page caching has been extracted from Action Dispatch
    as `actionpack-action_caching` and `actionpack-page_caching` gems.
    Please read the `README.md` file on both gems for the usage.

    *Francesco Rodriguez*

*   Failsafe exception returns `text/plain`. *Steve Klabnik*

*   Remove `rack-cache` dependency from Action Pack and declare it on Gemfile

    *Guillermo Iguaran*

*   Rename internal variables on `ActionController::TemplateAssertions` to prevent
    naming collisions. `@partials`, `@templates` and `@layouts` are now prefixed with an underscore.
    Fix #7459.

    *Yves Senn*

*   `resource` and `resources` don't modify the passed options hash.
    Fix #7777.

    *Yves Senn*

*   Precompiled assets include aliases from `foo.js` to `foo/index.js` and vice versa.

        # Precompiles phone-<digest>.css and aliases phone/index.css to phone.css.
        config.assets.precompile = [ 'phone.css' ]

        # Precompiles phone/index-<digest>.css and aliases phone.css to phone/index.css.
        config.assets.precompile = [ 'phone/index.css' ]

        # Both of these work with either precompile thanks to their aliases.
        <%= stylesheet_link_tag 'phone', media: 'all' %>
        <%= stylesheet_link_tag 'phone/index', media: 'all' %>

    *Jeremy Kemper*

*   `assert_template` is no more passing with what ever string that matches
    with the template name.

    Before when we have a template `/layout/hello.html.erb`, `assert_template`
    was passing with any string that matches. This behavior allowed false
    positive like:

        assert_template "layout"
        assert_template "out/hello"

    Now it only passes with:

        assert_template "layout/hello"
        assert_template "hello"

    Fixes #3849.

    *Hugolnx*

*   `image_tag` will set the same width and height for image if numerical value
    passed to `size` option.

    *Nihad Abbasov*

*   Deprecate `Mime::Type#verify_request?` and `Mime::Type.browser_generated_types`,
    since they are no longer used inside of Rails, they will be removed in Rails 4.1.

    *Michael Grosser*

*   `ActionDispatch::Http::UploadedFile` now delegates `close` to its tempfile. *Sergio Gil*

*   Add `ActionController::StrongParameters`, this module converts `params` hash into
    an instance of ActionController::Parameters that allows whitelisting of permitted
    parameters. Non-permitted parameters are forbidden to be used in Active Model by default
    For more details check the documentation of the module or the
    [strong_parameters gem](https://github.com/rails/strong_parameters)

    *DHH + Guillermo Iguaran*

*   Remove Integration between `attr_accessible`/`attr_protected` and
    `ActionController::ParamsWrapper`. ParamWrapper now wraps all the parameters returned
    by the class method `attribute_names`.

    *Guillermo Iguaran*

*   Log now displays the correct status code when an exception is raised.
    Fix #7646.

    *Yves Senn*

*   Allow pass couple extensions to `ActionView::Template.register_template_handler` call.

    *Tima Maslyuchenko*

*   Sprockets integration has been extracted from Action Pack to the `sprockets-rails`
    gem. `rails` gem is depending on `sprockets-rails` by default.

    *Guillermo Iguaran*

*   `ActionDispatch::Session::MemCacheStore` now uses `dalli` instead of the deprecated
    `memcache-client` gem. As side effect the autoloading of unloaded classes objects
    saved as values in session isn't supported anymore when mem_cache session store is
    used, this can have an impact in apps only when config.cache_classes is false.

    *Arun Agrawal + Guillermo Iguaran*

*   Support multiple etags in If-None-Match header. *Travis Warlick*

*   Allow to configure how unverified request will be handled using `:with`
    option in `protect_from_forgery` method.

    Valid unverified request handling methods are:

    - `:exception` - Raises ActionController::InvalidAuthenticityToken exception.
    - `:reset_session` - Resets the session.
    - `:null_session` - Provides an empty session during request but doesn't
      reset it completely. Used as default if `:with` option is not specified.

    New applications are generated with:

        protect_from_forgery with: :exception

    *Sergey Nartimov*

*   Add `.ruby` template handler, this handler simply allows arbitrary Ruby code as a template. *Guillermo Iguaran*

*   Add `separator` option for `ActionView::Helpers::TextHelper#excerpt`:

        excerpt('This is a very beautiful morning', 'very', separator: ' ', radius: 1)
        # => ...a very beautiful...

    *Guirec Corbel*

*   Added controller-level etag additions that will be part of the action etag computation *Jeremy Kemper/DHH*

        class InvoicesController < ApplicationController
          etag { current_user.try :id }

          def show
            # Etag will differ even for the same invoice when it's viewed by a different current_user
            @invoice = Invoice.find(params[:id])
            fresh_when(@invoice)
          end
        end

*   Add automatic template digests to all `CacheHelper#cache` calls (originally spiked in the `cache_digests` plugin) *DHH*

*   When building a URL fails, add missing keys provided by Journey. Failed URL
    generation now returns a 500 status instead of a 404.

    *Richard Schneeman*

*   Deprecate availability of `ActionView::RecordIdentifier` in controllers by default.
    It's view specific and can be easily included in controllers manually if someone
    really needs it. Also deprecate calling `ActionController::RecordIdentifier.dom_id` and
    `dom_class` directly, in favor of `ActionView::RecordIdentifier.dom_id` and `dom_class`.
    `RecordIdentifier` will be removed from `ActionController::Base` in Rails 4.1.

    *Piotr Sarnacki*

*   Fix `ActionView::RecordIdentifier` to work as a singleton. *Piotr Sarnacki*

*   Deprecate `Template#mime_type`, it will be removed in Rails 4.1 in favor of `#type`.
    *Piotr Sarnacki*

*   Move vendored html-scanner from `action_controller` to `action_view` directory. If you
    require it directly, please use 'action_view/vendor/html-scanner', reference to
    'action_controller/vendor/html-scanner' will be removed in Rails 4.1. *Piot Sarnacki*

*   Fix handling of date selects when using both disabled and discard options.
    Fixes #7431.

    *Vasiliy Ermolovich*

*   `ActiveRecord::SessionStore` is extracted out of Rails into a gem `activerecord-session_store`.
    Setting `config.session_store` to `:active_record_store` will no longer work and will break
    if the `activerecord-session_store` gem isn't available. *Prem Sichanugrist*

*   Fix `select_tag` when `option_tags` is nil.
    Fixes #7404.

    *Sandeep Ravichandran*

*   Add `Request#formats=(extensions)` that lets you set multiple formats directly in a prioritized order.

    Example of using this for custom iphone views with an HTML fallback:

        class ApplicationController < ActionController::Base
          before_filter :adjust_format_for_iphone_with_html_fallback

          private
            def adjust_format_for_iphone_with_html_fallback
              request.formats = [ :iphone, :html ] if request.env["HTTP_USER_AGENT"][/iPhone/]
            end
        end

    *DHH*

*   Add Routing Concerns to declare common routes that can be reused inside
    others resources and routes.

    Code before:

        resources :messages do
          resources :comments
        end

        resources :posts do
          resources :comments
          resources :images, only: :index
        end

    Code after:

        concern :commentable do
          resources :comments
        end

        concern :image_attachable do
          resources :images, only: :index
        end

        resources :messages, concerns: :commentable

        resources :posts, concerns: [:commentable, :image_attachable]

    *DHH + Rafael Mendonça França*

*   Add `start_hour` and `end_hour` options to the `select_hour` helper. *Evan Tann*

*   Raises an `ArgumentError` when the first argument in `form_for` contain `nil`
    or is empty.

    *Richard Schneeman*

*   Add 'X-Frame-Options' => 'SAMEORIGIN'
    'X-XSS-Protection' => '1; mode=block' and
    'X-Content-Type-Options' => 'nosniff'
    as default headers.

    *Egor Homakov*

*   Allow data attributes to be set as a first-level option for `form_for`, so you can write `form_for @record, data: { behavior: 'autosave' }` instead of `form_for @record, html: { data: { behavior: 'autosave' } }` *DHH*

*   Deprecate `button_to_function` and `link_to_function` helpers.

    We recommend the use of Unobtrusive JavaScript instead. For example:

        link_to "Greeting", "#", class: "nav_link"

        $(function() {
          $('.nav_link').click(function() {
            // Some complex code

            return false;
          });
        });

    or

        link_to "Greeting", '#', onclick: "alert('Hello world!'); return false", class: "nav_link"

    for simple cases.

    *Rafael Mendonça França*

*   `javascript_include_tag :all` will now not include `application.js` if the file does not exists. *Prem Sichanugrist*

*   Send an empty response body when call `head` with status between 100 and 199, 204, 205 or 304.

    *Armand du Plessis*

*   Fixed issue with where digest authentication would not work behind a proxy. *Arthur Smith*

*   Added `ActionController::Live`.  Mix it in to your controller and you can
    stream data to the client live.  For example:

        class FooController < ActionController::Base
          include ActionController::Live

          def index
            100.times {
              # Client will see this as it's written
              response.stream.write "hello world\n"
              sleep 1
            }
            response.stream.close
          end
        end

    *Aaron Patterson*

*   Remove `ActionDispatch::Head` middleware in favor of `Rack::Head`. *Santiago Pastorino*

*   Deprecate `:confirm` in favor of `data: { confirm: "Text" }` option for `button_to`, `button_tag`, `image_submit_tag`, `link_to` and `submit_tag` helpers.

    *Carlos Galdino + Rafael Mendonça França*

*   Show routes in exception page while debugging a `RoutingError` in development.

    *Richard Schneeman + Mattt Thompson + Yves Senn*

*   Add `ActionController::Flash.add_flash_types` method to allow people to register their own flash types. e.g.:

        class ApplicationController
          add_flash_types :error, :warning
        end

    If you add the above code, you can use `<%= error %>` in an erb, and `redirect_to /foo, error: 'message'` in a controller.

    *kennyj*

*   Remove Active Model dependency from Action Pack. *Guillermo Iguaran*

*   Support unicode characters in routes. Route will be automatically escaped, so instead of manually escaping:

        get Rack::Utils.escape('こんにちは') => 'home#index'

    You just have to write the unicode route:

        get 'こんにちは' => 'home#index'

    *kennyj*

*   Return proper format on exceptions. *Santiago Pastorino*

*   Allow to use `mounted_helpers` (helpers for accessing mounted engines) in `ActionView::TestCase`. *Piotr Sarnacki*

*   Include `mounted_helpers` (helpers for accessing mounted engines) in `ActionDispatch::IntegrationTest` by default. *Piotr Sarnacki*

*   Extracted redirect logic from `ActionController::ForceSSL::ClassMethods.force_ssl`  into `ActionController::ForceSSL#force_ssl_redirect`

    *Jeremy Friesen*

*   Make possible to use a block in `button_to` if the button text is hard
    to fit into the name parameter, e.g.:

        <%= button_to [:make_happy, @user] do %>
          Make happy <strong><%= @user.name %></strong>
        <% end %>
        # => "<form method="post" action="/users/1/make_happy" class="button_to">
        #      <div>
        #        <button type="submit">
        #          Make happy <strong>Name</strong>
        #        </button>
        #      </div>
        #    </form>"

    *Sergey Nartimov*

*   Change a way of ordering helpers from several directories. Previously,
    when loading helpers from multiple paths, all of the helpers files were
    gathered into one array an then they were sorted. Helpers from different
    directories should not be mixed before loading them to make loading more
    predictable. The most common use case for such behavior is loading helpers
    from engines. When you load helpers from application and engine Foo, in
    that order, first rails will load all of the helpers from application,
    sorted alphabetically and then it will do the same for Foo engine.

    *Piotr Sarnacki*

*   `truncate` now always returns an escaped HTML-safe string. The option `:escape` can be used as
    false to not escape the result.

    *Li Ellis Gallardo + Rafael Mendonça França*

*   `truncate` now accepts a block to show extra content when the text is truncated. *Li Ellis Gallardo*

*   Add `week_field`, `week_field_tag`, `month_field`, `month_field_tag`, `datetime_local_field`,
    `datetime_local_field_tag`, `datetime_field` and `datetime_field_tag` helpers. *Carlos Galdino*

*   Add `color_field` and `color_field_tag` helpers. *Carlos Galdino*

*   `assert_generates`, `assert_recognizes`, and `assert_routing` all raise
    `Assertion` instead of `RoutingError` *David Chelimsky*

*   URL path parameters with invalid encoding now raise ActionController::BadRequest. *Andrew White*

*   Malformed query and request parameter hashes now raise ActionController::BadRequest. *Andrew White*

*   Add `divider` option to `grouped_options_for_select` to generate a separator
    `optgroup` automatically, and deprecate `prompt` as third argument, in favor
    of using an options hash. *Nicholas Greenfield*

*   Add `time_field` and `time_field_tag` helpers which render an `input[type="time"]` tag. *Alex Soulim*

*   Removed old text helper apis from `highlight`, `excerpt` and `word_wrap`. *Jeremy Walker*

*   Templates without a handler extension now raises a deprecation warning but still
    defaults to ERB. In future releases, it will simply return the template contents. *Steve Klabnik*

*   Deprecate `:disable_with` in favor of `data: { disable_with: "Text" }` option from `submit_tag`, `button_tag` and `button_to` helpers.

    *Carlos Galdino + Rafael Mendonça França*

*   Remove `:mouseover` option from `image_tag` helper. *Rafael Mendonça França*

*   The `select` method (select tag) forces `:include_blank` if `required` is true and
    `display size` is one and `multiple` is not true. *Angelo Capilleri*

*   Copy literal route constraints to defaults so that url generation know about them.
    The copied constraints are `:protocol`, `:subdomain`, `:domain`, `:host` and `:port`.

    *Andrew White*

*   `respond_to` and `respond_with` now raise ActionController::UnknownFormat instead
    of directly returning head 406. The exception is rescued and converted to 406
    in the exception handling middleware. *Steven Soroka*

*   Allows `assert_redirected_to` to match against a regular expression. *Andy Lindeman*

*   Add backtrace to development routing error page. *Richard Schneeman*

*   Replace `include_seconds` boolean argument with `include_seconds: true` option
    in `distance_of_time_in_words` and `time_ago_in_words` signature. *Dmitriy Kiriyenko*

*   Make current object and counter (when it applies) variables accessible when
    rendering templates with :object / :collection. *Carlos Antonio da Silva*

*   JSONP now uses mimetype `text/javascript` instead of `application/json`. *omjokine*

*   Allow to lazy load `default_form_builder` by passing a `String` instead of a constant. *Piotr Sarnacki*

*   Session arguments passed to `process` calls in functional tests are now merged into
    the existing session, whereas previously they would replace the existing session.
    This change may break some existing tests if they are asserting the exact contents of
    the session but should not break existing tests that only assert individual keys.

    *Andrew White*

*   Add `index` method to FormBuilder class. *Jorge Bejar*

*   Remove the leading \n added by textarea on `assert_select`. *Santiago Pastorino*

*   Changed default value for `config.action_view.embed_authenticity_token_in_remote_forms`
    to `false`. This change breaks remote forms that need to work also without javascript,
    so if you need such behavior, you can either set it to `true` or explicitly pass
    `authenticity_token: true` in form options.

*   Added `ActionDispatch::SSL` middleware that when included force all the requests to be under HTTPS protocol. *Rafael Mendonça França*

*   Add `include_hidden` option to select tag. With `include_hidden: false` select with `multiple` attribute doesn't generate hidden input with blank value. *Vasiliy Ermolovich*

*   Removed default `size` option from the `text_field`, `search_field`, `telephone_field`, `url_field`, `email_field` helpers. *Philip Arndt*

*   Removed default `cols` and `rows` options from the `text_area` helper. *Philip Arndt*

*   Adds support for layouts when rendering a partial with a given collection. *serabe*

*   Allows the route helper `root` to take a string argument. For example, `root 'pages#main'`. *bcardarella*

*   Forms of persisted records use always PATCH (via the `_method` hack). *fxn*

*   For resources, both PATCH and PUT are routed to the `update` action. *fxn*

*   Don't ignore `force_ssl` in development. This is a change of behavior - use a `:if` condition to recreate the old behavior.

        class AccountsController < ApplicationController
          force_ssl if: :ssl_configured?

          def ssl_configured?
            !Rails.env.development?
          end
        end

    *Pat Allan*

*   Adds support for the PATCH verb:
      * Request objects respond to `patch?`.
      * Routes have a new `patch` method, and understand `:patch` in the
        existing places where a verb is configured, like `:via`.
      * New method `patch` available in functional tests.
      * If `:patch` is the default verb for updates, edits are
        tunneled as PATCH rather than as PUT, and routing acts accordingly.
      * New method `patch_via_redirect` available in integration tests.

    *dlee*

*   Integration tests support the `OPTIONS` method. *Jeremy Kemper*

*   `expires_in` accepts a `must_revalidate` flag. If true, "must-revalidate"
    is added to the Cache-Control header. *fxn*

*   Add `date_field` and `date_field_tag` helpers which render an `input[type="date"]` tag *Olek Janiszewski*

*   Adds `image_url`, `javascript_url`, `stylesheet_url`, `audio_url`, `video_url`, and `font_url`
    to assets tag helper. These URL helpers will return the full path to your assets. This is useful
    when you are going to reference this asset from external host. *Prem Sichanugrist*

*   Default responder will now always use your overridden block in `respond_with` to render your response. *Prem Sichanugrist*

*   Allow `value_method` and `text_method` arguments from `collection_select` and
    `options_from_collection_for_select` to receive an object that responds to `:call`,
    such as a `proc`, to evaluate the option in the current element context. This works
    the same way with `collection_radio_buttons` and `collection_check_boxes`.

    *Carlos Antonio da Silva + Rafael Mendonça França*

*   Add `collection_check_boxes` form helper, similar to `collection_select`:
    Example:

        collection_check_boxes :post, :author_ids, Author.all, :id, :name
        # Outputs something like:
        <input id="post_author_ids_1" name="post[author_ids][]" type="checkbox" value="1" />
        <label for="post_author_ids_1">D. Heinemeier Hansson</label>
        <input id="post_author_ids_2" name="post[author_ids][]" type="checkbox" value="2" />
        <label for="post_author_ids_2">D. Thomas</label>
        <input name="post[author_ids][]" type="hidden" value="" />

    The label/check_box pairs can be customized with a block.

    *Carlos Antonio da Silva + Rafael Mendonça França*

*   Add `collection_radio_buttons` form helper, similar to `collection_select`:
    Example:

        collection_radio_buttons :post, :author_id, Author.all, :id, :name
        # Outputs something like:
        <input id="post_author_id_1" name="post[author_id]" type="radio" value="1" />
        <label for="post_author_id_1">D. Heinemeier Hansson</label>
        <input id="post_author_id_2" name="post[author_id]" type="radio" value="2" />
        <label for="post_author_id_2">D. Thomas</label>

    The label/radio_button pairs can be customized with a block.

    *Carlos Antonio da Silva + Rafael Mendonça França*

*   `check_box` with `:form` html5 attribute will now replicate the `:form`
    attribute to the hidden field as well. *Carlos Antonio da Silva*

*   Turn off verbose mode of rack-cache, we still have X-Rack-Cache to
    check that info. Closes #5245. *Santiago Pastorino*

*   `label` form helper accepts `for: nil` to not generate the attribute. *Carlos Antonio da Silva*

*   Add `:format` option to `number_to_percentage`. *Rodrigo Flores*

*   Add `config.action_view.logger` to configure logger for Action View. *Rafael Mendonça França*

*   Deprecated `ActionController::Integration` in favour of `ActionDispatch::Integration`.

*   Deprecated `ActionController::IntegrationTest` in favour of `ActionDispatch::IntegrationTest`.

*   Deprecated `ActionController::PerformanceTest` in favour of `ActionDispatch::PerformanceTest`.

*   Deprecated `ActionController::AbstractRequest` in favour of `ActionDispatch::Request`.

*   Deprecated `ActionController::Request` in favour of `ActionDispatch::Request`.

*   Deprecated `ActionController::AbstractResponse` in favour of `ActionDispatch::Response`.

*   Deprecated `ActionController::Response` in favour of `ActionDispatch::Response`.

*   Deprecated `ActionController::Routing` in favour of `ActionDispatch::Routing`.

*   `check_box helper` with `disabled: true` will generate a disabled
    hidden field to conform with the HTML convention where disabled fields are
    not submitted with the form. This is a behavior change, previously the hidden
    tag had a value of the disabled checkbox. *Tadas Tamosauskas*

*   `favicon_link_tag` helper will now use the favicon in app/assets by default. *Lucas Caton*

*   `ActionView::Helpers::TextHelper#highlight` now defaults to the
    HTML5 `mark` element. *Brian Cardarella*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/actionpack/CHANGELOG.md) for previous changes.
