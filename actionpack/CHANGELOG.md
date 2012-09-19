## Rails 4.0.0 (unreleased) ##

*   Add `ActionController::StrongParameters`, this module converts `params` hash into
    an instance of ActionController::Parameters that allows whitelisting of permitted 
    parameters. Non-permitted parameters are forbidden to be used in Active Model by default
    For more details check the documentation of the module or the 
    [strong_parameters gem](https://github.com/rails/strong_parameters)

    *DHH + Guillermo Iguaran*

*   Remove Integration between `attr_accessible`/`attr_protected` and
    `ActionController::ParamsWrapper`. ParamWrapper now wraps all the parameters returned 
    by the class method attribute_names

    *Guillermo Iguaran*

*   Fix #7646, the log now displays the correct status code when an exception is raised.

    *Yves Senn*

*   Allow pass couple extensions to `ActionView::Template.register_template_handler` call. *Tima Maslyuchenko*

*   Fixed a bug with shorthand routes scoped with the `:module` option not
    adding the module to the controller as described in issue #6497.
    This should now work properly:

        scope :module => "engine" do
          get "api/version" # routes to engine/api#version
        end
 
    *Luiz Felipe Garcia Pereira*

*   Sprockets integration has been extracted from Action Pack and the `sprockets-rails` 
    gem should be added to Gemfile (under the assets group) in order to use Rails asset
    pipeline in future versions of Rails.

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

        protect_from_forgery :with => :exception

    *Sergey Nartimov*

*   Add .ruby template handler, this handler simply allows arbitrary Ruby code as a template. *Guillermo Iguaran*

*   Add `separator` option for `ActionView::Helpers::TextHelper#excerpt`:

        excerpt('This is a very beautiful morning', 'very', :separator  => ' ', :radius => 1)
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

*   Add automatic template digests to all CacheHelper#cache calls (originally spiked in the cache_digests plugin) *DHH*

*   When building a URL fails, add missing keys provided by Journey. Failed URL
    generation now returns a 500 status instead of a 404.

    *Richard Schneeman*

*   Deprecate availbility of ActionView::RecordIdentifier in controllers by default.
    It's view specific and can be easily included in controller manually if someone
    really needs it. RecordIdentifier will be removed from ActionController::Base
    in Rails 4.1 *Piotr Sarnacki*

*   Fix ActionView::RecordIdentifier to work as a singleton *Piotr Sarnacki*

*   Deprecate Template#mime_type, it will be removed in Rails 4.1 in favor of #type.
    *Piotr Sarnacki*

*   Move vendored html-scanner from action_controller to action_view directory. If you
    require it directly, please use 'action_view/vendor/html-scanner', reference to
    'action_controller/vendor/html-scanner' will be removed in Rails 4.1 *Piot Sarnacki*

*   Fix handling of date selects when using both disabled and discard options.
    Fixes #7431.

    *Vasiliy Ermolovich*

*   `ActiveRecord::SessionStore` is extracted out of Rails into a gem `activerecord-session_store`.
    Setting `config.session_store` to `:active_record_store` will no longer work and will break
    if the `activerecord-session_store` gem isn't available. *Prem Sichanugrist*

*   Fix select_tag when option_tags is nil.
    Fixes #7404.

    *Sandeep Ravichandran*

*   Add Request#formats=(extensions) that lets you set multiple formats directly in a prioritized order *DHH*

    Example of using this for custom iphone views with an HTML fallback:

        class ApplicationController < ActionController::Base
          before_filter :adjust_format_for_iphone_with_html_fallback

          private
            def adjust_format_for_iphone_with_html_fallback
              request.formats = [ :iphone, :html ] if request.env["HTTP_USER_AGENT"][/iPhone/]
            end
        end


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

*   Add start_hour and end_hour options to the select_hour helper. *Evan Tann*

*   Raises an ArgumentError when the first argument in `form_for` contain `nil`
    or is empty.

    *Richard Schneeman*

*   Add 'X-Frame-Options' => 'SAMEORIGIN'
    'X-XSS-Protection' => '1; mode=block' and
    'X-Content-Type-Options' => 'nosniff'
    as default headers.

    *Egor Homakov*

*   Allow data attributes to be set as a first-level option for form_for, so you can write `form_for @record, data: { behavior: 'autosave' }` instead of `form_for @record, html: { data: { behavior: 'autosave' } }` *DHH*

*   Deprecate `button_to_function` and `link_to_function` helpers.

    We recommend the use of Unobtrusive JavaScript instead. For example:

        link_to "Greeting", "#", :class => "nav_link"

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

*   Fixed issue with where Digest authentication would not work behind a proxy. *Arthur Smith*

*   Added ActionController::Live.  Mix it in to your controller and you can
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

*   Remove ActionDispatch::Head middleware in favor of Rack::Head. *Santiago Pastorino*

*   Deprecate `:confirm` in favor of `:data => { :confirm => "Text" }` option for `button_to`, `button_tag`, `image_submit_tag`, `link_to` and `submit_tag` helpers.

    *Carlos Galdino + Rafael Mendonça França*

*   Show routes in exception page while debugging a `RoutingError` in development. *Richard Schneeman and Mattt Thompson*

*   Add `ActionController::Flash.add_flash_types` method to allow people to register their own flash types. e.g.:

        class ApplicationController
          add_flash_types :error, :warning
        end

    If you add the above code, you can use `<%= error %>` in an erb, and `redirect_to /foo, :error => 'message'` in a controller.

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

*   Make possible to use a block in button_to helper if button text is hard
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

*   change a way of ordering helpers from several directories. Previously,
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

*   Removed old text_helper apis for highlight, excerpt and word_wrap *Jeremy Walker*

*   Templates without a handler extension now raises a deprecation warning but still
    defaults to ERb. In future releases, it will simply return the template contents. *Steve Klabnik*

*   Deprecate `:disable_with` in favor of `:data => { :disable_with => "Text" }` option from `submit_tag`, `button_tag` and `button_to` helpers.

    *Carlos Galdino + Rafael Mendonça França*

*   Remove `:mouseover` option from `image_tag` helper. *Rafael Mendonça França*

*   The `select` method (select tag) forces :include_blank  if `required` is true and
    `display size` is one and `multiple` is not true. *Angelo Capilleri*

*   Copy literal route constraints to defaults so that url generation know about them.
    The copied constraints are `:protocol`, `:subdomain`, `:domain`, `:host` and `:port`.

    *Andrew White*

*   `respond_to` and `respond_with` now raise ActionController::UnknownFormat instead
    of directly returning head 406. The exception is rescued and converted to 406
    in the exception handling middleware. *Steven Soroka*

*   Allows `assert_redirected_to` to match against a regular expression. *Andy Lindeman*

*   Add backtrace to development routing error page. *Richard Schneeman*

*   Replace `include_seconds` boolean argument with `:include_seconds => true` option
    in `distance_of_time_in_words` and `time_ago_in_words` signature. *Dmitriy Kiriyenko*

*   Make current object and counter (when it applies) variables accessible when
    rendering templates with :object / :collection. *Carlos Antonio da Silva*

*   JSONP now uses mimetype application/javascript instead of application/json. *omjokine*

*   Allow to lazy load `default_form_builder` by passing a `String` instead of a constant. *Piotr Sarnacki*

*   Session arguments passed to `process` calls in functional tests are now merged into
    the existing session, whereas previously they would replace the existing session.
    This change may break some existing tests if they are asserting the exact contents of
    the session but should not break existing tests that only assert individual keys.

    *Andrew White*

*   Add `index` method to FormBuilder class. *Jorge Bejar*

*   Remove the leading \n added by textarea on assert_select. *Santiago Pastorino*

*   Changed default value for `config.action_view.embed_authenticity_token_in_remote_forms`
    to `false`. This change breaks remote forms that need to work also without javascript,
    so if you need such behavior, you can either set it to `true` or explicitly pass
    `:authenticity_token => true` in form options

*   Added ActionDispatch::SSL middleware that when included force all the requests to be under HTTPS protocol. *Rafael Mendonça França*

*   Add `include_hidden` option to select tag. With `:include_hidden => false` select with `multiple` attribute doesn't generate hidden input with blank value. *Vasiliy Ermolovich*

*   Removed default `size` option from the `text_field`, `search_field`, `telephone_field`, `url_field`, `email_field` helpers. *Philip Arndt*

*   Removed default `cols` and `rows` options from the `text_area` helper. *Philip Arndt*

*   Adds support for layouts when rendering a partial with a given collection. *serabe*

*   Allows the route helper `root` to take a string argument. For example, `root 'pages#main'`. *bcardarella*

*   Forms of persisted records use always PATCH (via the `_method` hack). *fxn*

*   For resources, both PATCH and PUT are routed to the `update` action. *fxn*

*   Don't ignore `force_ssl` in development. This is a change of behavior - use a `:if` condition to recreate the old behavior.

        class AccountsController < ApplicationController
          force_ssl :if => :ssl_configured?

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

*   check_box with `:form` html5 attribute will now replicate the `:form`
    attribute to the hidden field as well. *Carlos Antonio da Silva*

*   Turn off verbose mode of rack-cache, we still have X-Rack-Cache to
    check that info. Closes #5245. *Santiago Pastorino*

*   `label` form helper accepts :for => nil to not generate the attribute. *Carlos Antonio da Silva*

*   Add `:format` option to number_to_percentage *Rodrigo Flores*

*   Add `config.action_view.logger` to configure logger for ActionView. *Rafael Mendonça França*

*   Deprecated ActionController::Integration in favour of ActionDispatch::Integration

*   Deprecated ActionController::IntegrationTest in favour of ActionDispatch::IntegrationTest

*   Deprecated ActionController::PerformanceTest in favour of ActionDispatch::PerformanceTest

*   Deprecated ActionController::AbstractRequest in favour of ActionDispatch::Request

*   Deprecated ActionController::Request in favour of ActionDispatch::Request

*   Deprecated ActionController::AbstractResponse in favour of ActionDispatch::Response

*   Deprecated ActionController::Response in favour of ActionDispatch::Response

*   Deprecated ActionController::Routing in favour of ActionDispatch::Routing

*   check_box helper with :disabled => true will generate a disabled hidden field to conform with the HTML convention where disabled fields are not submitted with the form.
    This is a behavior change, previously the hidden tag had a value of the disabled checkbox.
    *Tadas Tamosauskas*

*   `favicon_link_tag` helper will now use the favicon in app/assets by default. *Lucas Caton*

*   `ActionView::Helpers::TextHelper#highlight` now defaults to the
    HTML5 `mark` element. *Brian Cardarella*

Please check [3-2-stable](https://github.com/rails/rails/blob/3-2-stable/actionpack/CHANGELOG.md) for previous changes.
