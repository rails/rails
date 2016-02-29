## Rails 4.1.14.2 (February 26, 2016) ##

*   Do not allow render with unpermitted parameter.

    Fixes CVE-2016-2098.

    *Arthur Neves*


## Rails 4.1.14.1 (January 25, 2015) ##

*   No changes.


## Rails 4.1.14 (November 12, 2015) ##

*   No changes.


## Rails 4.1.13 (August 24, 2015) ##

*   No changes.


## Rails 4.1.12 (June 25, 2015) ##

*   Fix handling of empty X_FORWARDED_HOST header in raw_host_with_port

    Previously, an empty X_FORWARDED_HOST header would cause
    Actiondispatch::Http:URL.raw_host_with_port to return nil, causing
    Actiondispatch::Http:URL.host to raise a NoMethodError.

    *Adam Forsyth*

*   Fix regression in functional tests. Responses should have default headers
    assigned.

    See #18423.

    *Jeremy Kemper*, *Yves Senn*


## Rails 4.1.11 (June 16, 2015) ##

*   No changes.


## Rails 4.1.10 (March 19, 2015) ##

*   Preserve default format when generating URLs

    Fixes an issue that would cause the format set in default_url_options to be
    lost when generating URLs with fewer positional arguments than parameters in
    the route definition.

    Backport of #18627

    *Tekin Suleyman*, *Dominic Baggott*

*   Default headers, removed in controller actions, are no longer reapplied on
    the test response.

    *Jonas Baumann*

*   Ensure `append_info_to_payload` is called even if an exception is raised.

    Fixes an issue where when an exception is raised in the request the additonal
    payload data is not available.

    See:
    * #14903
    * https://github.com/roidrage/lograge/issues/37

    *Dieter Komendera*, *Margus Pärt*


## Rails 4.1.9 (January 6, 2015) ##

*   Fixed handling of positional url helper arguments when `format: false`.

    Fixes #17819.

    *Andrew White*, *Tatiana Soukiassian*

*   Restore handling of a bare `Authorization` header, without `token=`
    prefix.

    Fixes #17108.

    *Guo Xiang Tan*


## Rails 4.1.8 (November 16, 2014) ##

*   Fix regression where path was getting overwritten when route anchor was false, and X-Cascade pass

    fixes #17035.

    *arthurnn*

*   Fix a bug where malformed query strings lead to 500.

    fixes #11502.

    *Yuki Nishijima*


## Rails 4.1.7.1 (November 19, 2014) ##

*   Fix arbitrary file existence disclosure in Action Pack.

    CVE-2014-7829.


## Rails 4.1.7 (October 29, 2014) ##

*   Fix arbitrary file existence disclosure in Action Pack.

    CVE-2014-7818.


## Rails 4.1.6 (September 11, 2014) ##

*   Prepend a JS comment to JSONP callbacks. Addresses CVE-2014-4671
    ("Rosetta Flash")

    *Greg Campbell*

*   Because URI paths may contain non US-ASCII characters we need to force
    the encoding of any unescaped URIs to UTF-8 if they are US-ASCII.
    This essentially replicates the functionality of the monkey patch to
    URI.parser.unescape in active_support/core_ext/uri.rb.

    Fixes #16104.

    *Karl Entwistle*

*   Generate shallow paths for all children of shallow resources.

    Fixes #15783.

    *Seb Jacobs*

*   JSONP responses are now rendered with the `text/javascript` content type
    when rendering through a `respond_to` block.

    Fixes #15081.

    *Lucas Mazza*

*   Fix env['PATH_INFO'] missing leading slash when a rack app mounted at '/'.

    Fixes #15511.

    *Larry Lv*

*   ActionController::Parameters#require now accepts `false` values.

    Fixes #15685.

    *Sergio Romano*

*   With authorization header `Authorization: Token token=`, `authenticate` now
    recognize token as nil, instead of "token".

    Fixes #14846.

    *Larry Lv*


## Rails 4.1.4 (July 2, 2014) ##

*   No changes.


## Rails 4.1.3 (July 2, 2014) ##

*   No changes.


## Rails 4.1.2 (June 26, 2014) ##

*   Fix URL generation with `:trailing_slash` such that it does not add
    a trailing slash after `.:format`

    *Dan Langevin*

*   Fix an issue with migrating legacy json cookies.

    Previously, the `VerifyAndUpgradeLegacySignedMessage` assumed all incoming
    cookies were marshal-encoded. This was not the case when `secret_token` was
    used in conjunction with the `:json` or `:hybrid` serializer.

    In those cases, when upgrading to use `secret_key_base`, this would cause a
    `TypeError: incompatible marshal file format` and a 500 error for the user.

    Fixes #14774.

    *Godfrey Chan*

*   `http_basic_authenticate_with` only checks the authentication if the schema is
    `Basic`.

    Fixes #10257.

    *tomykaira*

*   Fix `'Stack level too deep'` when rendering `head :ok` in an action method
    called 'status' in a controller.

    Fixes #13905.

    *Christiaan Van den Poel*

*   Always use the provided port if the protocol is relative.

    Fixes #15043.

    *Guilherme Cavalcanti*, *Andrew White*

*   Append a link in the backtrace to the bad code when a `SyntaxError` exception occurs.

    *Boris Kuznetsov*

*   Make URL escaping more consistent:

    1. Escape '%' characters in URLs - only unescaped data should be passed to URL helpers
    2. Add an `escape_segment` helper to `Router::Utils` that escapes '/' characters
    3. Use `escape_segment` rather than `escape_fragment` in optimized URL generation
    4. Use `escape_segment` rather than `escape_path` in URL generation

    For point 4 there are two exceptions. Firstly, when a route uses wildcard segments
    (e.g. `*foo`) then we use `escape_path` as the value may contain '/' characters. This
    means that wildcard routes can't be optimized. Secondly, if a `:controller` segment
    is used in the path then this uses `escape_path` as the controller may be namespaced.

    Fixes #14629, #14636 and #14070.

    *Andrew White*, *Edho Arief*

*   Returns a null type format when the format is not known and the controller is using an
    `any` format block.

    Fixes #14462.

    *Rafael Mendonça França*

*   Only make deeply nested routes shallow when the parent is shallow.

    Fixes #14684.

    *Andrew White*, *James Coglan*


## Rails 4.1.1 (May 6, 2014) ##

*   Only accept actions without `File::SEPARATOR` in the name.

    This will avoid directory traversal in implicit render.

    Fixes: CVE-2014-0130

    *Rafael Mendonça França*


## Rails 4.1.0 (April 8, 2014) ##

*   Swap the parameters of assert_equal in `assert_select` so that the
    proper values are printed correctly

    Fixes #14422.

    *Vishal Lal*

*   The method `shallow?` returns false if the parent resource is a singleton, so
    we need to check if we're not inside a nested scope before copying the :path
    and :as options to their shallow equivalents.

    Fixes #14388.

    *Andrew White*


## Rails 4.1.0 (April 8, 2014) ##

*   Fix URL generation in controller tests with request-dependent
    `default_url_options` methods.

    *Tony Wooster*

*   Introduce `render :html` as an option to render HTML content with a content
    type of `text/html`. This rendering option calls `ERB::Util.html_escape`
    internally to escape unsafe HTML strings, so you will need to mark a
    string as `html_safe` if it contains any HTML tag.

    See #14062, #12374.

    *Prem Sichanugrist*

*   Introduce `render :plain` as an option to render content with a content type
    of `text/plain`. This is the preferred option if you are planning to render
    a plain text content.

    See #14062, #12374.

    *Prem Sichanugrist*

*   Introduce `render :body` as an option for sending a raw content back to
    browser. Note that this rendering option does not include "Content-Type"
    header back in the response.

    You should only use this option if you don't care about the content type
    of the response. More information on "Content-Type" header can be found
    on RFC 2616, section 7.2.1.

    See #14062, #12374.

    *Prem Sichanugrist*

*   Set stream status to 500 (or 400 on BadRequest) when an error is thrown
    before committing.

    Fixes #12552.

    *Kevin Casey*

*   Add a new config option `config.action_dispatch.cookies_serializer` for
    specifying a serializer for the signed and encrypted cookie jars.

    The possible values are:

    * `:json` - serialize cookie values with `JSON`
    * `:marshal` - serialize cookie values with `Marshal`
    * `:hybrid` - transparently migrate existing `Marshal` cookie values to `JSON`

    For new apps the `:json` option is added by default and `:marshal` is used
    when no option is specified to maintain backwards compatibility.

    *Łukasz Sarnacki*, *Matt Aimonetti*, *Guillermo Iguaran*, *Godfrey Chan*, *Rafael Mendonça França*

*   `FlashHash` now behaves like a `HashWithIndifferentAccess`.

    *Guillermo Iguaran*

*   Set the `:shallow_path` scope option as each scope is generated rather than
    waiting until the `shallow` option is set. Also make the behavior of the
    `:shallow` resource option consistent with the behavior of the `shallow` method.

    Fixes #12498.

    *Andrew White*, *Aleksi Aalto*

*   Properly require `action_view` in `AbstractController::Rendering` to prevent
    an uninitialized constant error for `ENCODING_FLAG`.

    *Philipe Fatio*

*   Do not discard query parameters that form a hash with the same root key as
    the `wrapper_key` for a request using `wrap_parameters`.

    *Josh Jordan*

*   Ensure that `request.filtered_parameters` is reset between calls to `process`
    in `ActionController::TestCase`.

    Fixes #13803.

    *Andrew White*

*   Fix `rake routes` error when `Rails::Engine` with empty routes is mounted.

    Fixes #13810.

    *Maurizio De Santis*

*   Log which keys were affected by deep munge.

    Deep munge solves the CVE-2013-0155 security vulnerability, but its
    behaviour is confusing. With this commit, the information about which
    key values were set to nil is now visible in logs.

    *Łukasz Sarnacki*

*   Automatically convert dashes to underscores for shorthand routes, e.g:

        get '/our-work/latest'

    When running `rake routes` you will get the following output:

                 Prefix Verb URI Pattern                Controller#Action
        our_work_latest GET  /our-work/latest(.:format) our_work#latest

    *Mikko Johansson*

*   Automatically convert dashes to underscores for url helpers, e.g:

        get '/contact-us' => 'pages#contact'
        get '/about-us'   => 'pages#about_us'

    When running `rake routes` you will get the following output:

            Prefix Verb URI Pattern           Controller#Action
        contact_us GET  /contact-us(.:format) pages#contact
          about_us GET  /about-us(.:format)   pages#about_us

    *Amr Tamimi*

*   Fix stream closing when sending file with `ActionController::Live` included.

    Fixes #12381.

    *Alessandro Diaferia*

*   Allow an absolute controller path inside a module scope. Fixes #12777.

    Example:

        namespace :foo do
          # will route to BarController without the namespace.
          get '/special', to: '/bar#index'
        end


*   Unique the segment keys array for non-optimized url helpers

    In Rails 3.2 you only needed to pass an argument for a dynamic segment
    once so unique the segment keys array to match the number of args. Since
    the number of args is less than the required parts, the non-optimized code
    path is selected. To benefit from optimized url generation, the arg needs
    to be specified as many times as it appears in the path.

    Fixes #12808.

    *Andrew White*

*   Show full route constraints in error message.

    When an optimized helper fails to generate, show the full route constraints
    in the error message. Previously it would only show the contraints that were
    required as part of the path.

    Fixes #13592.

    *Andrew White*

*   Use a custom route visitor for optimized url generation. Fixes #13349.

    *Andrew White*

*   Allow engine root relative redirects using an empty string.

    Example:

        # application routes.rb
        mount BlogEngine => '/blog'

        # engine routes.rb
        get '/welcome' => redirect('')

    This now redirects to the path `/blog`, whereas before it would redirect
    to the application root path. In the case of a path redirect or a custom
    redirect, if the path returned contains a host then the path is treated as
    absolute. Similarly for option redirects, if the options hash returned
    contains a `:host` or `:domain` key then the path is treated as absolute.

    Fixes #7977.

    *Andrew White*

*   Fix `Encoding::CompatibilityError` when public path is UTF-8

    In #5337 we forced the path encoding to ASCII-8BIT to prevent static file
    handling from blowing up before an application has had a chance to deal
    with possibly invalid urls. However this has a negative side effect of
    making it an incompatible encoding if the application's public path has
    UTF-8 characters in it.

    To work around the problem we check to see if the path has a valid encoding once
    it has been unescaped. If it is not valid then we can return early since it will
    not match any file anyway.

    Fixes #13518.

    *Andrew White*

*   `ActionController::Parameters#permit!` permits hashes in array values.

    *Xavier Noria*

*   Converts hashes in arrays of unfiltered params to unpermitted params.

    Fixes #13382.

    *Xavier Noria*

*   New config option to opt out of params "deep munging" that was used to
    address the security vulnerability CVE-2013-0155. In your app config:

        config.action_dispatch.perform_deep_munge = false

    Take care to understand the security risk involved before disabling this.
    [Read more.](https://groups.google.com/forum/#!topic/rubyonrails-security/t1WFuuQyavI)

    *Bernard Potocki*

*   `rake routes` shows routes defined under assets prefix.

    *Ryunosuke SATO*

*   Extend cross-site request forgery (CSRF) protection to GET requests with
    JavaScript responses, protecting apps from cross-origin `<script>` tags.

    *Jeremy Kemper*

*   Fix generating a path for an engine inside a resources block.

    Fixes #8533.

    *Piotr Sarnacki*

*   Add `Mime::Type.register "text/vcard", :vcf` to the default list of mime types.

    *DHH*

*   Remove deprecated `ActionController::RecordIdentifier`, use
    `ActionView::RecordIdentifier` instead.

    *kennyj*

*   Fix regression when using `ActionView::Helpers::TranslationHelper#translate` with
    `options[:raise]`.

    This regression was introduced at ec16ba75a5493b9da972eea08bae630eba35b62f.

    *Shota Fukumori (sora_h)*

*   Introducing Variants

    We often want to render different html/json/xml templates for phones,
    tablets, and desktop browsers. Variants make it easy.

    The request variant is a specialization of the request format, like `:tablet`,
    `:phone`, or `:desktop`.

    You can set the variant in a `before_action`:

        request.variant = :tablet if request.user_agent =~ /iPad/

    Respond to variants in the action just like you respond to formats:

        respond_to do |format|
          format.html do |html|
            html.tablet # renders app/views/projects/show.html+tablet.erb
            html.phone { extra_setup; render ... }
          end
        end

    Provide separate templates for each format and variant:

        app/views/projects/show.html.erb
        app/views/projects/show.html+tablet.erb
        app/views/projects/show.html+phone.erb

    You can also simplify the variants definition using the inline syntax:

        respond_to do |format|
          format.js         { render "trash" }
          format.html.phone { redirect_to progress_path }
          format.html.none  { render "trash" }
        end

    Variants also support the common `any`/`all` block that formats have.

    It works for both inline:

        respond_to do |format|
          format.html.any   { render text: "any"   }
          format.html.phone { render text: "phone" }
        end

    and block syntax:

        respond_to do |format|
          format.html do |variant|
            variant.any(:tablet, :phablet){ render text: "any" }
            variant.phone { render text: "phone" }
          end
        end

    *Łukasz Strzałkowski*

*   Fix rendering localized templates without an explicit format using wrong
    content header and not passing correct formats to template due to the
    introduction of the `NullType` for mimes.

    Templates like `hello.it.erb` were subject to this issue.

    Fixes #13064.

    *Angelo Capilleri*, *Carlos Antonio da Silva*

*   Try to escape each part of a url correctly when using a redirect route.

    Fixes #13110.

    *Andrew White*

*   Better error message for typos in assert_response arguments.

    When the response type argument to `assert_response` is not a known
    response type, `assert_response` now throws an ArgumentError with a clear
    message. This is intended to help debug typos in the response type.

    *Victor Costan*

*   Fix formatting for `rake routes` when a section is shorter than a header.

    *Sıtkı Bağdat*

*   Accept an options hash inside the array in `#url_for`.

    Example:

        url_for [:new, :admin, :post, { param: 'value' }]
        # => http://example.com/admin/posts/new?param=value

    *Andrey Ognevsky*

*   Add `session#fetch` method

    fetch behaves like [Hash#fetch](http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-fetch).
    It returns a value from the hash for the given key.
    If the key can’t be found, there are several options:

      * With no other arguments, it will raise a KeyError exception.
      * If a default value is given, then it will be returned.
      * If the optional code block is specified, then it will be run and its result returned.

    *Damien Mathieu*

*   Don't let strong parameters mutate the given hash via `fetch`

    Create a new instance if the given parameter is a `Hash` instead of
    passing it to the `convert_hashes_to_parameters` method since it is
    overriding its default value.

    *Brendon Murphy*, *Doug Cole*

*   Add a `params` option to the `button_to` form helper which renders
    the given hash as hidden form fields.

    *Andy Waite*

*   Enable assets helpers to work in the controllers like they do in the views.

    Example:

        # config/application.rb
        config.asset_host = 'http://mycdn.com'

        ActionController::Base.helpers.asset_path('fallback.png')
        # => http://mycdn.com/assets/fallback.png

    Fixes #10051.

    *Tima Maslyuchenko*

*   Respect `SCRIPT_NAME` when using `redirect` with a relative path

    Example:

        # application routes.rb
        mount BlogEngine => '/blog'

        # engine routes.rb
        get '/admin' => redirect('admin/dashboard')

    This now redirects to the path `/blog/admin/dashboard`, whereas before it would
    have generated an invalid url because there would be no slash between the host name
    and the path. It also allows redirects to work when the application is deployed
    to a subdirectory of a website.

    Fixes #7977.

    *Andrew White*

*   Fixing `repond_with` working directly on the options hash
    This fixes an issue where the `respond_with` worked directly with the given
    options hash, so that if a user relied on it after calling `respond_with`,
    the hash wouldn't be the same.

    Fixes #12029.

    *bluehotdog*

*   Fix `ActionDispatch::RemoteIp::GetIp#calculate_ip` to only check for spoofing
    attacks if both `HTTP_CLIENT_IP` and `HTTP_X_FORWARDED_FOR` are set.

    Fixes #10844.

    *Tamir Duberstein*

*   Strong parameters should permit a nested number to be a key.

    Fixes #12293.

    *kennyj*

*   Fix the regex used to detect URI schemes in `redirect_to`, to be consistent
    with RFC 3986.

    *Derek Prior*

*   Fix incorrect `assert_redirected_to` failure message for protocol-relative
    URLs.

    *Derek Prior*

*   Fix an issue where the router could not recognize a downcased url encoding path.

    Fixes #12269.

    *kennyj*

*   Fix custom flash type definition. Misuse of the `_flash_types` class variable
    caused an error when reloading controllers with custom flash types.

    Fixes #12057.

    *Ricardo de Cillo*

*   Do not break params filtering on `nil` values.

    Fixes #12149.

    *Vasiliy Ermolovich*

*   Development mode exceptions are rendered in text format in case of
    an XHR request.

    *Kir Shatrov*

*   Fix an issue where :if and :unless controller action procs were being run
    before checking for the correct action in the :only and :unless options.

    Fixes #11799.

    *Nicholas Jakobsen*

*   Fix an issue where `assert_dom_equal` and `assert_dom_not_equal` were
    ignoring the passed failure message argument.

    Fixes #11751.

    *Ryan McGeary*

*   Allow REMOTE_ADDR, HTTP_HOST and HTTP_USER_AGENT to be overridden from
    the environment passed into `ActionDispatch::TestRequest.new`.

    Fixes #11590.

    *Andrew White*

*   Fix an issue where Journey was failing to clear the named routes hash when the
    routes were reloaded and since it doesn't overwrite existing routes then if a
    route changed but wasn't renamed it kept the old definition. This was being
    masked by the optimised url helpers so it only became apparent when passing an
    options hash to the url helper.

    *Andrew White*

*   Skip routes pointing to a redirect or mounted application when generating urls
    using an options hash as they aren't relevant and generate incorrect urls.

    Fixes #8018.

    *Andrew White*

*   Move `MissingHelperError` out of the `ClassMethods` module.

    *Yves Senn*

*   Fix an issue where Rails raised an exception about a missing helper when
    it should have thrown a `LoadError` instead. When the helper file exists
    and only the loaded file from the helper does not exist, Rails should now
    throw a `LoadError` instead of a `MissingHelperError`.

    *Piotr Niełacny*

*   Fix `ActionDispatch::ParamsParser#parse_formatted_parameters` to rewind
    body input stream on parsing json params.

    Fixes #11345.

    *Yuri Bol*, *Paul Nikitochkin*

*   Ignore spaces around delimiters in the Set-Cookie header.

    *Yamagishi Kazutoshi*

*   Remove deprecated Rails application fallback for integration testing.
    Set `ActionDispatch.test_app` instead.

    *Carlos Antonio da Silva*

*   Remove deprecated `page_cache_extension` config.

    *Francesco Rodriguez*

*   Remove deprecated constants from Action Controller:

        ActionController::AbstractRequest  => ActionDispatch::Request
        ActionController::Request          => ActionDispatch::Request
        ActionController::AbstractResponse => ActionDispatch::Response
        ActionController::Response         => ActionDispatch::Response
        ActionController::Routing          => ActionDispatch::Routing
        ActionController::Integration      => ActionDispatch::Integration
        ActionController::IntegrationTest  => ActionDispatch::IntegrationTest

    *Carlos Antonio da Silva*

*   Fix `Mime::Type.parse` when a bad accepts header is looked up.
    Previously, it was setting `request.formats` with an array containing a
    `nil` value, which raised an error when setting the controller formats.

    Fixes #10965.

    *Becker*

*   Merge `:action` from routing scope and assign endpoint if both `:controller`
    and `:action` are present. The endpoint assignment only occurs if there is
    no `:to` present in the options hash, so should only affect routes using the
    shorthand syntax (i.e. endpoint is inferred from the path).

    Fixes #9856.

    *Yves Senn*, *Andrew White*

*   Action View extracted from Action Pack.

    *Piotr Sarnacki*, *Łukasz Strzałkowski*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
