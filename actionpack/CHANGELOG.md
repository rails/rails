## Rails 3.1.9

## Rails 3.1.8 (Aug 9, 2012)

* There is an XSS vulnerability in the strip_tags helper in Ruby on Rails, the
  helper doesn't correctly handle malformed html.  As a result an attacker can
  execute arbitrary javascript through the use of specially crafted malformed
  html.

  *Marek from Nethemba (www.nethemba.com) & Santiago Pastorino*

* When a "prompt" value is supplied to the `select_tag` helper, the "prompt" value is not escaped.
  If untrusted data is not escaped, and is supplied as the prompt value, there is a potential for XSS attacks.
  Vulnerable code will look something like this:
    select_tag("name", options, :prompt => UNTRUSTED_INPUT)

  *Santiago Pastorino*

## Rails 3.1.7 (Jul 26, 2012)

* Do not convert digest auth strings to symbols. CVE-2012-3424

## Rails 3.1.6 (Jun 12, 2012)

*   nil is removed from array parameter values

    CVE-2012-2694

## Rails 3.1.5 (May 31, 2012) ##

*   Detect optional glob params when adding non-greedy regexp - closes #4817.

*   Strip null bytes from Location header

*   Return the same session data object when setting session id

*   Avoid inspecting the whole route set, closes #1525

*   Strip [nil] from parameters hash.  Thanks to Ben Murphy for reporting this!
    CVE-2012-2660

## Rails 3.1.4 (unreleased) ##

*   :subdomain can now be specified with a value of false in url_for, 
    allowing for subdomain(s) removal from the host during link generation. GH #4083

    *Arun Agrawal*

*   Skip assets group in Gemfile and all assets configurations options
    when the application is generated with --skip-sprockets option.

    *Guillermo Iguaran*

*   Use ProcessedAsset#pathname in Sprockets helpers when debugging is on. Closes #3333 #3348 #3361.

    *Guillermo Iguaran*

*   Allow to use asset_path on named_routes aliasing RailsHelper's
    asset_path to path_to_asset *Adrian Pike*

*   Assets should use the request protocol by default or default to relative if no request is available *Jonathan del Strother*

## Rails 3.1.3 (November 20, 2011) ##

*   Downgrade sprockets to ~> 2.0.3. Using 2.1.0 caused regressions.

*   Fix using `tranlate` helper with a html translation which uses the `:count` option for
    pluralization.

    *Jon Leighton*

## Rails 3.1.2 (November 18, 2011) ##

*   Fix XSS security vulnerability in the `translate` helper method. When using interpolation
    in combination with HTML-safe translations, the interpolated input would not get HTML
    escaped. *GH 3664*

    Before:

        translate('foo_html', :something => '<script>') # => "...<script>..."

    After:

        translate('foo_html', :something => '<script>') # => "...&lt;script&gt;..."

    *Sergey Nartimov*

*   Upgrade sprockets dependency to ~> 2.1.0

*   Ensure that the format isn't applied twice to the cache key, else it becomes impossible
    to target with expire_action.

    *Christopher Meiklejohn*

*   Swallow error when can't unmarshall object from session.

    *Bruno Zanchet*

*   Implement a workaround for a bug in ruby-1.9.3p0 where an error would be raised
    while attempting to convert a template from one encoding to another.

    Please see http://redmine.ruby-lang.org/issues/5564 for details of the bug.

    The workaround is to load all conversions into memory ahead of time, and will
    only happen if the ruby version is *exactly* 1.9.3p0. The hope is obviously that
    the underlying problem will be resolved in the next patchlevel release of
    1.9.3.

    *Jon Leighton*

*   Ensure users upgrading from 3.0.x to 3.1.x will properly upgrade their flash object in session (issues #3298 and #2509)

## Rails 3.1.1 (October 7, 2011) ##

*   stylesheet_link_tag('/stylesheets/application') and similar helpers doesn't
    throw Sprockets::FileOutsidePaths exception anymore *Santiago Pastorino*

*   Ensure default_asset_host_protocol is respected, closes #2980. *José Valim*

    Changing rake db:schema:dump to run :environment as well as :load_config,
    as running :load_config alone will lead to the dumper being run without
    including extensions such as those included in foreigner and
    spatial_adapter.

    This reverses a change made here:
    https://github.com/rails/rails/commit/5df72a238e9fcb18daf6ab6e6dc9051c9106d7bb#L0L324

    I'm assuming here that :load_config needs to be invoked
    separately from :environment, as it is elsewhere in the
    file for db operations, if not the alternative is to go
    back to "task :dump => :environment do".

    *Ben Woosley*

*   Update to rack-cache 1.1.

    Versions prior to 1.1 delete the If-Modified-Since and If-Not-Modified
    headers when config.action_controller.perform_caching is true. This has two
    problems:
        * unexpected inconsistent behaviour between development &
          production environments
        * breaks applications that use of these headers

    *Brendan Ribera*

*   Ensure that enhancements to assets:precompile task are only run once *Sam Pohlenz*

*   TestCase should respect the view_assigns API instead of pulling variables on
    its own. *José Valim*

*   javascript_path and stylesheet_path now refer to /assets if asset pipelining
    is on. *Santiago Pastorino*

*   button_to support form option. Now you're able to pass for example
    'data-type' => 'json'. *ihower*

*   image_path and image_tag should use /assets if asset pipelining is turned
    on. Closes #3126 *Santiago Pastorino and christos*

*   Avoid use of existing precompiled assets during rake assets:precompile run.
    Closes #3119 *Guillermo Iguaran*

*   Copy assets to nondigested filenames too *Santiago Pastorino*

*   Give precedence to `config.digest = false` over the existence of
    manifest.yml asset digests *christos*

*   escape options for the stylesheet_link_tag method *Alexey Vakhov*

*   Re-launch assets:precompile task using (Rake.)ruby instead of Kernel.exec so
    it works on Windows *cablegram*

*   env var passed to process shouldn't be modified in process method. [Santiago
    Pastorino]

*   `rake assets:precompile` loads the application but does not initialize
    it.

    To the app developer, this means configuration add in
    config/initializers/* will not be executed.

    Plugins developers need to special case their initializers that are
    meant to be run in the assets group by adding :group => :assets. *José Valim*

*   Sprockets uses config.assets.prefix for asset_path *asee*

*   FileStore key_file_path properly limit filenames to 255 characters. *phuibonhoa*

*   Fix Hash#to_query edge case with html_safe strings. *brainopia*

*   Allow asset tag helper methods to accept :digest => false option in order to completely avoid the digest generation.
    Useful for linking assets from static html files or from emails when the user
    could probably look at an older html email with an older asset. *Santiago Pastorino*

*   Don't mount Sprockets server at config.assets.prefix if config.assets.compile is false. *Mark J. Titorenko*

*   Set relative url root in assets when controller isn't available for Sprockets (eg. Sass files using asset_path). Fixes #2435 *Guillermo Iguaran*

*   Fix basic auth credential generation to not make newlines. GH #2882

*   Fixed the behavior of asset pipeline when config.assets.digest and config.assets.compile are false and requested asset isn't precompiled.
    Before the requested asset were compiled anyway ignoring that the config.assets.compile flag is false. *Guillermo Iguaran*

*   CookieJar is now Enumerable. Fixes #2795

*   Fixed AssetNotPrecompiled error raised when rake assets:precompile is compiling certain .erb files. See GH #2763 #2765 #2805 *Guillermo Iguaran*

*   Manifest is correctly placed in assets path when default assets prefix is changed. Fixes #2776 *Guillermo Iguaran*

*   Fixed stylesheet_link_tag and javascript_include_tag to respect additional options passed by the users when debug is on. *Guillermo Iguaran*

*   Fix ActiveRecord#exists? when passsed a nil value

*   Fix assert_select_email to work on multipart and non-multipart emails as the method stopped working correctly in Rails 3.x due to changes in the new mail gem.


## Rails 3.1.0 (August 30, 2011) ##

*   Param values are `paramified` in controller tests. *David Chelimsky*

*   x_sendfile_header now defaults to nil and config/environments/production.rb doesn't set a particular value for it. This allows servers to set it through X-Sendfile-Type. *Santiago Pastorino*

*   The submit form helper does not generate an id "object_name_id" anymore. *fbrusatti*

*   Make sure respond_with with :js tries to render a template in all cases *José Valim*

*   json_escape will now return a SafeBuffer string if it receives SafeBuffer string *tenderlove*

*   Make sure escape_js returns SafeBuffer string if it receives SafeBuffer string *Prem Sichanugrist*

*   Fix escape_js to work correctly with the new SafeBuffer restriction *Paul Gallagher*

*   Brought back alternative convention for namespaced models in i18n *thoefer*

    Now the key can be either "namespace.model" or "namespace/model" until further deprecation.

*   It is prohibited to perform a in-place SafeBuffer mutation *tenderlove*

    The old behavior of SafeBuffer allowed you to mutate string in place via
    method like `sub!`. These methods can add unsafe strings to a safe buffer,
    and the safe buffer will continue to be marked as safe.

    An example problem would be something like this:

        <%= link_to('hello world', @user).sub!(/hello/, params[:xss])  %>

    In the above example, an untrusted string (`params[:xss]`) is added to the
    safe buffer returned by `link_to`, and the untrusted content is successfully
    sent to the client without being escaped.  To prevent this from happening
    `sub!` and other similar methods will now raise an exception when they are called on a safe buffer.

    In addition to the in-place versions, some of the versions of these methods which return a copy of the string will incorrectly mark strings as safe. For example:

         <%= link_to('hello world', @user).sub(/hello/, params[:xss]) %>

    The new versions will now ensure that *all* strings returned by these methods on safe buffers are marked unsafe.

    You can read more about this change in http://groups.google.com/group/rubyonrails-security/browse_thread/thread/2e516e7acc96c4fb

*   Warn if we cannot verify CSRF token authenticity *José Valim*

*   Allow AM/PM format in datetime selectors *Aditya Sanghi*

*   Only show dump of regular env methods on exception screen (not all the rack crap) *DHH*

*   auto_link has been removed with no replacement.  If you still use auto_link
    please install the rails_autolink gem:
        http://github.com/tenderlove/rails_autolink

    *tenderlove*

*   Added streaming support, you can enable it with: *José Valim*

        class PostsController < ActionController::Base
          stream :only => :index
        end

    Please read the docs at `ActionController::Streaming` for more information.

*   Added `ActionDispatch::Request.ignore_accept_header` to ignore accept headers and only consider the format given as parameter *José Valim*

*   Created `ActionView::Renderer` and specified an API for `ActionView::Context`, check those objects for more information *José Valim*

*   Added `ActionController::ParamsWrapper` to wrap parameters into a nested hash, and will be turned on for JSON request in new applications by default *Prem Sichanugrist*

    This can be customized by setting `ActionController::Base.wrap_parameters` in `config/initializer/wrap_parameters.rb`

*   RJS has been extracted out to a gem. *fxn*

*   Implicit actions named not_implemented can be rendered. *Santiago Pastorino*

*   Wildcard route will always match the optional format segment by default. *Prem Sichanugrist*

    For example if you have this route:

        map '*pages' => 'pages#show'

    by requesting '/foo/bar.json', your `params[:pages]` will be equals to "foo/bar" with the request format of JSON. If you want the old 3.0.x behavior back, you could supply `:format => false` like this:

        map '*pages' => 'pages#show', :format => false

*   Added Base.http_basic_authenticate_with to do simple http basic authentication with a single class method call *DHH*

        class PostsController < ApplicationController
          USER_NAME, PASSWORD = "dhh", "secret"

          before_filter :authenticate, :except => [ :index ]

          def index
            render :text => "Everyone can see me!"
          end

          def edit
            render :text => "I'm only accessible if you know the password"
          end

          private
            def authenticate
              authenticate_or_request_with_http_basic do |user_name, password|
                user_name == USER_NAME && password == PASSWORD
              end
            end
        end

    ..can now be written as

        class PostsController < ApplicationController
          http_basic_authenticate_with :name => "dhh", :password => "secret", :except => :index

          def index
            render :text => "Everyone can see me!"
          end

          def edit
            render :text => "I'm only accessible if you know the password"
          end
        end

*   Allow you to add `force_ssl` into controller to force browser to transfer data via HTTPS protocol on that particular controller. You can also specify `:only` or `:except` to specific it to particular action. *DHH and Prem Sichanugrist*

*   Allow FormHelper#form_for to specify the :method as a direct option instead of through the :html hash *DHH*

        form_for(@post, remote: true, method: :delete) instead of form_for(@post, remote: true, html: { method: :delete })

*   Make JavaScriptHelper#j() an alias for JavaScriptHelper#escape_javascript() -- note this then supersedes the Object#j() method that the JSON gem adds within templates using the JavaScriptHelper *DHH*

*   Sensitive query string parameters (specified in config.filter_parameters) will now be filtered out from the request paths in the log file. *Prem Sichanugrist, fxn*

*   URL parameters which return false for to_param now appear in the query string (previously they were removed) *Andrew White*

*   URL parameters which return nil for to_param are now removed from the query string *Andrew White*

*   ActionDispatch::MiddlewareStack now uses composition over inheritance. It is
    no longer an array which means there may be methods missing that were not
    tested.

*   Add an :authenticity_token option to form_tag for custom handling or to omit the token (pass :authenticity_token => false).  *Jakub Kuźma, Igor Wiedler*

*   HTML5 button_tag helper. *Rizwan Reza*

*   Template lookup now searches further up in the inheritance chain. *Artemave*

*   Brought back config.action_view.cache_template_loading, which allows to decide whether templates should be cached or not. *Piotr Sarnacki*

*   url_for and named url helpers now accept :subdomain and :domain as options, *Josh Kalderimis*

*   The redirect route method now also accepts a hash of options which will only change the parts of the url in question, or an object which responds to call, allowing for redirects to be reused (check the documentation for examples). *Josh Kalderimis*

*   Added config.action_controller.include_all_helpers. By default 'helper :all' is done in ActionController::Base, which includes all the helpers by default. Setting include_all_helpers to false will result in including only application_helper and helper corresponding to controller (like foo_helper for foo_controller). *Piotr Sarnacki*

*   Added a convenience idiom to generate HTML5 data-* attributes in tag helpers from a :data hash of options:

        tag("div", :data => {:name => 'Stephen', :city_state => %w(Chicago IL)})
        # => <div data-name="Stephen" data-city-state="[&quot;Chicago&quot;,&quot;IL&quot;]" />

    Keys are dasherized. Values are JSON-encoded, except for strings and symbols. *Stephen Celis*

*   Deprecate old template handler API. The new API simply requires a template handler to respond to call. *José Valim*

*   :rhtml and :rxml were finally removed as template handlers. *José Valim*

*   Moved etag responsibility from ActionDispatch::Response to the middleware stack. *José Valim*

*   Rely on Rack::Session stores API for more compatibility across the Ruby world. This is backwards incompatible since Rack::Session expects #get_session to accept 4 arguments and requires #destroy_session instead of simply #destroy. *José Valim*

*   file_field automatically adds :multipart => true to the enclosing form. *Santiago Pastorino*

*   Renames csrf_meta_tag -> csrf_meta_tags, and aliases csrf_meta_tag for backwards compatibility. *fxn*

*   Add Rack::Cache to the default stack. Create a Rails store that delegates to the Rails cache, so by default, whatever caching layer you are using will be used for HTTP caching. Note that Rack::Cache will be used if you use #expires_in, #fresh_when or #stale with :public => true. Otherwise, the caching rules will apply to the browser only. *Yehuda Katz, Carl Lerche*

Please check [3-0-stable](https://github.com/rails/rails/blob/3-0-stable/actionpack/CHANGELOG) for previous changes.
