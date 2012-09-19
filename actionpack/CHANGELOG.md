## Rails 3.2.9 (unreleased) ##

*   Fixed a bug with shorthand routes scoped with the `:module` option not
    adding the module to the controller as described in issue #6497.
    This should now work properly:

        scope :module => "engine" do
          get "api/version" # routes to engine/api#version
        end

    *Luiz Felipe Garcia Pereira*

*   Respect `config.digest = false` for `asset_path`

    Previously, the `asset_path` internals only respected the `:digest`
    option, but ignored the global config setting. This meant that
    `config.digest = false` could not be used in conjunction with
    `config.compile = false` this corrects the behavior.

    *Peter Wagenet*

*   Fix #7646, the log now displays the correct status code when an exception is raised.

    *Yves Senn*

*   Fix handling of date selects when using both disabled and discard options.
    Fixes #7431.

    *Vasiliy Ermolovich*

*   Fix select_tag when option_tags is nil.
    Fixes #7404.

    *Sandeep Ravichandran*

*   `javascript_include_tag :all` will now not include `application.js` if the file does not exists. *Prem Sichanugrist*

*   Support cookie jar options (e.g., domain :all) for all session stores.
    Fixes GH#3047, GH#2483.

    *Ravil Bayramgalin*

*   Performance Improvement to send_file: Avoid having to pass an open file handle as the response body. Rack::Sendfile
    will usually intercept the response and just uses the path directly, so no reason to open the file. This performance
    improvement also resolves an issue with jRuby encodings, and is the reason for the backport, see issue #6844.

    *Jeremy Kemper & Erich Menge*


## Rails 3.2.8 (Aug 9, 2012) ##

*   There is an XSS vulnerability in the strip_tags helper in Ruby on Rails, the
    helper doesn't correctly handle malformed html.  As a result an attacker can
    execute arbitrary javascript through the use of specially crafted malformed
    html.

    *Marek from Nethemba (www.nethemba.com) & Santiago Pastorino*

*   When a "prompt" value is supplied to the `select_tag` helper, the "prompt" value is not escaped.
    If untrusted data is not escaped, and is supplied as the prompt value, there is a potential for XSS attacks.
    Vulnerable code will look something like this:
    select_tag("name", options, :prompt => UNTRUSTED_INPUT)

    *Santiago Pastorino*

*   Reverted the deprecation of `:confirm`. *Rafael Mendonça França*

*   Reverted the deprecation of `:disable_with`. *Rafael Mendonça França*

*   Reverted the deprecation of `:mouseover` option to `image_tag`. *Rafael Mendonça França*

*   Reverted the deprecation of `button_to_function` and `link_to_function` helpers.

    *Rafael Mendonça França*


## Rails 3.2.7 (Jul 26, 2012) ##

*   Do not convert digest auth strings to symbols. CVE-2012-3424

*   Bump Journey requirements to 1.0.4

*   Add support for optional root segments containing slashes

*   Fixed bug creating invalid HTML in select options

*   Show in log correct wrapped keys

*   Fix NumberHelper options wrapping to prevent verbatim blocks being rendered instead of line continuations.

*   ActionController::Metal doesn't have logger method, check it and then delegate

*   ActionController::Caching depends on RackDelegation and AbstractController::Callbacks


## Rails 3.2.6 (Jun 12, 2012) ##

*   nil is removed from array parameter values

    CVE-2012-2694

*   Deprecate `:confirm` in favor of `':data => { :confirm => "Text" }'` option for `button_to`, `button_tag`, `image_submit_tag`, `link_to` and `submit_tag` helpers.

    *Carlos Galdino*

*   Allow to use mounted_helpers (helpers for accessing mounted engines) in ActionView::TestCase. *Piotr Sarnacki*

*   Include mounted_helpers (helpers for accessing mounted engines) in ActionDispatch::IntegrationTest by default. *Piotr Sarnacki*


## Rails 3.2.5 (Jun 1, 2012) ##

*   No changes.


## Rails 3.2.4 (May 31, 2012) ##

*   Deprecate old APIs for highlight, excerpt and word_wrap *Jeremy Walker*

*   Deprecate `:disable_with` in favor of `'data-disable-with'` option for `button_to`, `button_tag` and `submit_tag` helpers.

    *Carlos Galdino + Rafael Mendonça França*

*   Deprecate `:mouseover` option for `image_tag` helper. *Rafael Mendonça França*

*   Deprecate `button_to_function` and `link_to_function` helpers. *Rafael Mendonça França*

*   Don't break Haml with textarea newline fix.  GH #393, #4000, #5190, #5191

*   Fix options handling on labels. GH #2492, #5614

*   Added config.action_view.embed_authenticity_token_in_remote_forms to deal
    with regression from 16ee611fa

*   Set rendered_format when doing render :inline. GH #5632

*   Fix the redirect when it receive blocks with arity of 1. Closes #5677

*   Strip [nil] from parameters hash. Thanks to Ben Murphy for
    reporting this! CVE-2012-2660


## Rails 3.2.3 (March 30, 2012) ##

*   Allow to lazy load `default_form_builder` by passing a `String` instead of a constant. *Piotr Sarnacki*

*   Fix #5632, render :inline set the proper rendered format. *Santiago Pastorino*

*   Fix textarea rendering when using plugins like HAML. Such plugins encode the first newline character in the content. This issue was introduced in https://github.com/rails/rails/pull/5191 *James Coleman*

*   Remove the leading \n added by textarea on assert_select. *Santiago Pastorino*

*   Add `config.action_view.embed_authenticity_token_in_remote_forms` (defaults to true) which allows to set if authenticity token will be included by default in remote forms. If you change it to false, you can still force authenticity token by passing `:authenticity_token => true` in form options *Piotr Sarnacki*

*   Do not include the authenticity token in forms where remote: true as ajax forms use the meta-tag value *DHH*

*   Turn off verbose mode of rack-cache, we still have X-Rack-Cache to
    check that info. Closes #5245. *Santiago Pastorino*

*   Fix #5238, rendered_format is not set when template is not rendered. *Piotr Sarnacki*

*   Upgrade rack-cache to 1.2. *José Valim*

*   ActionController::SessionManagement is deprecated. *Santiago Pastorino*

*   Since the router holds references to many parts of the system like engines, controllers and the application itself, inspecting the route set can actually be really slow, therefore we default alias inspect to to_s. *José Valim*

*   Add a new line after the textarea opening tag. Closes #393 *Rafael Mendonça França*

*   Always pass a respond block from to responder. We should let the responder to decide what to do with the given overridden response block, and not short circuit it. *sikachu*

*   Fixes layout rendering regression from 3.2.2. *José Valim*


## Rails 3.2.2 (March 1, 2012) ##

*   Format lookup for partials is derived from the format in which the template is being rendered. Closes #5025 part 2 *Santiago Pastorino*

*   Use the right format when a partial is missing. Closes #5025. *Santiago Pastorino*

*   Default responder will now always use your overridden block in `respond_with` to render your response. *Prem Sichanugrist*

*   check_box helper with :disabled => true will generate a disabled hidden field to conform with the HTML convention where disabled fields are not submitted with the form.
    This is a behavior change, previously the hidden tag had a value of the disabled checkbox.
    *Tadas Tamosauskas*


## Rails 3.2.1 (January 26, 2012) ##

*   Documentation improvements.

*   Allow `form.select` to accept ranges (regression). *Jeremy Walker*

*   `datetime_select` works with -/+ infinity dates. *Joe Van Dyk*


## Rails 3.2.0 (January 20, 2012) ##

*   Setting config.assets.logger to false turn off Sprockets logger *Guillermo Iguaran*

*   Add `config.action_dispatch.default_charset` to configure default charset for ActionDispatch::Response. *Carlos Antonio da Silva*

*   Deprecate setting default charset at controller level, use the new `config.action_dispatch.default_charset` instead. *Carlos Antonio da Silva*

*   Deprecate ActionController::UnknownAction in favour of AbstractController::ActionNotFound. *Carlos Antonio da Silva*

*   Deprecate ActionController::DoubleRenderError in favour of AbstractController::DoubleRenderError. *Carlos Antonio da Silva*

*   Deprecate method_missing handling for not found actions, use action_missing instead. *Carlos Antonio da Silva*

*   Deprecate ActionController#rescue_action, ActionController#initialize_template_class, and ActionController#assign_shortcuts.
    These methods were not being used internally anymore and are going to be removed in Rails 4. *Carlos Antonio da Silva*

*   Add config.assets.logger to configure Sprockets logger *Rafael França*

*   Use a BodyProxy instead of including a Module that responds to
    close. Closes #4441 if Active Record is disabled assets are delivered
    correctly *Santiago Pastorino*

*   Rails initialization with initialize_on_precompile = false should set assets_dir *Santiago Pastorino*

*   Add font_path helper method *Santiago Pastorino*

*   Depends on rack ~> 1.4.0 *Santiago Pastorino*

*   Add :gzip option to `caches_page`. The default option can be configured globally using `page_cache_compression` *Andrey Sitnik*

*   The ShowExceptions middleware now accepts a exceptions application that is responsible to render an exception when the application fails. The application is invoked with a copy of the exception in `env["action_dispatch.exception"]` and with the PATH_INFO rewritten to the status code. *José Valim*

*   Add `button_tag` support to ActionView::Helpers::FormBuilder.

    This support mimics the default behavior of `submit_tag`.

    Example:

        <%= form_for @post do |f| %>
          <%= f.button %>
        <% end %>

*   Date helpers accept a new option, `:use_two_digit_numbers = true`, that renders select boxes for months and days with a leading zero without changing the respective values.
    For example, this is useful for displaying ISO8601-style dates such as '2011-08-01'. *Lennart Fridén and Kim Persson*

*   Make ActiveSupport::Benchmarkable a default module for ActionController::Base, so the #benchmark method is once again available in the controller context like it used to be *DHH*

*   Deprecated implied layout lookup in controllers whose parent had a explicit layout set:

        class ApplicationController
          layout "application"
        end

        class PostsController < ApplicationController
        end

    In the example above, Posts controller will no longer automatically look up for a posts layout.

    If you need this functionality you could either remove `layout "application"` from ApplicationController or explicitly set it to nil in PostsController. *José Valim*

*   Rails will now use your default layout (such as "layouts/application") when you specify a layout with `:only` and `:except` condition, and those conditions fail. *Prem Sichanugrist*

    For example, consider this snippet:

        class CarsController
          layout 'single_car', :only => :show
        end

    Rails will use 'layouts/single_car' when a request comes in `:show` action, and use 'layouts/application' (or 'layouts/cars', if exists) when a request comes in for any other actions.

*   form_for with +:as+ option uses "#{action}_#{as}" as css class and id:

    Before:

        form_for(@user, :as => 'client') # => "<form class="client_new">..."

    Now:

        form_for(@user, :as => 'client') # => "<form class="new_client">..."

    *Vasiliy Ermolovich*

*   Allow rescue responses to be configured through a railtie as in `config.action_dispatch.rescue_responses`. Please look at ActiveRecord::Railtie for an example *José Valim*

*   Allow fresh_when/stale? to take a record instead of an options hash *DHH*

*   Assets should use the request protocol by default or default to relative if no request is available *Jonathan del Strother*

*   Log "Filter chain halted as CALLBACKNAME rendered or redirected" every time a before callback halts *José Valim*

*   You can provide a namespace for your form to ensure uniqueness of id attributes on form elements.
    The namespace attribute will be prefixed with underscore on the generate HTML id. *Vasiliy Ermolovich*

    Example:

        <%= form_for(@offer, :namespace => 'namespace') do |f| %>
          <%= f.label :version, 'Version' %>:
          <%= f.text_field :version %>
        <% end %>

*   Refactor ActionDispatch::ShowExceptions. The controller is responsible for choosing to show exceptions when `consider_all_requests_local` is false.

    It's possible to override `show_detailed_exceptions?` in controllers to specify which requests should provide debugging information on errors. The default value is now false, meaning local requests in production will no longer show the detailed exceptions page unless `show_detailed_exceptions?` is overridden and set to `request.local?`.

*   Responders now return 204 No Content for API requests without a response body (as in the new scaffold) *José Valim*

*   Added ActionDispatch::RequestId middleware that'll make a unique X-Request-Id header available to the response and enables the ActionDispatch::Request#uuid method. This makes it easy to trace requests from end-to-end in the stack and to identify individual requests in mixed logs like Syslog *DHH*

*   Limit the number of options for select_year to 1000.

    Pass the :max_years_allowed option to set your own limit.

    *Libo Cannici*

*   Passing formats or handlers to render :template and friends is deprecated. For example: *Nick Sutterer & José Valim*

        render :template => "foo.html.erb"

    Instead, you can provide :handlers and :formats directly as option:
             render :template => "foo", :formats => [:html, :js], :handlers => :erb

*   Changed log level of warning for missing CSRF token from :debug to :warn. *Mike Dillon*

*   content_tag_for and div_for can now take the collection of records. It will also yield the record as the first argument if you set a receiving argument in your block *Prem Sichanugrist*

    So instead of having to do this:

        @items.each do |item|
          content_tag_for(:li, item) do
             Title: <%= item.title %>
          end
        end

    You can now do this:

        content_tag_for(:li, @items) do |item|
          Title: <%= item.title %>
        end

*   send_file now guess the mime type *Esad Hajdarevic*

*   Mime type entries for PDF, ZIP and other formats were added *Esad Hajdarevic*

*   Generate hidden input before select with :multiple option set to true.
    This is useful when you rely on the fact that when no options is set,
    the state of select will be sent to rails application. Without hidden field
    nothing is sent according to HTML spec *Bogdan Gusiev*

*   Refactor ActionController::TestCase cookies *Andrew White*

    Assigning cookies for test cases should now use cookies[], e.g:

        cookies[:email] = 'user@example.com'
        get :index
        assert_equal 'user@example.com', cookies[:email]

    To clear the cookies, use clear, e.g:

        cookies.clear
        get :index
        assert_nil cookies[:email]

    We now no longer write out HTTP_COOKIE and the cookie jar is
    persistent between requests so if you need to manipulate the environment
    for your test you need to do it before the cookie jar is created.

*   ActionController::ParamsWrapper on ActiveRecord models now only wrap
    attr_accessible attributes if they were set, if not, only the attributes
    returned by the class method attribute_names will be wrapped. This fixes
    the wrapping of nested attributes by adding them to attr_accessible.

Please check [3-1-stable](https://github.com/rails/rails/blob/3-1-stable/actionpack/CHANGELOG.md) for previous changes.
