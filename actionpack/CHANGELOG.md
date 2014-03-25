*   Swapped the parameters of assert_equal in `assert_select` so that the
    proper values were printed correctly

    Fixes #14422.

    *Vishal Lal*

*   Fix URL generation in controller tests with request-dependent
    `default_url_options` methods.

    *Tony Wooster*

*   Introduce `render :html` as an option to render HTML content with a content
    type of `text/html`. This rendering option calls `ERB::Util.html_escape`
    internally to escape unsafe HTML string, so you will have to mark your
    string as html safe if you have any HTML tag in it.

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
    before commiting.

    Fixes #12552.

    *Kevin Casey*

*   Add new config option `config.action_dispatch.cookies_serializer` for
    specifying a serializer for the signed and encrypted cookie jars.

    The possible values are:

    * `:json` - serialize cookie values with `JSON`
    * `:marshal` - serialize cookie values with `Marshal`
    * `:hybrid` - transparently migrate existing `Marshal` cookie values to `JSON`

    For new apps `:json` option is added by default and `:marshal` is used
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
    uninitialized constant error for `ENCODING_FLAG`.

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

    Deep munge solves CVE-2013-0155 security vulnerability, but its
    behaviour is definately confusing, so now at least information
    about for which keys values were set to nil is visible in logs.

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

    In Rails 3.2 you only needed pass an argument for dynamic segment once so
    unique the segment keys array to match the number of args. Since the number
    of args is less than required parts the non-optimized code path is selected.
    This means to benefit from optimized url generation the arg needs to be
    specified as many times as it appears in the path.

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
    redirect if the path returned contains a host then the path is treated as
    absolute. Similarly for option redirects, if the options hash returned
    contains a `:host` or `:domain` key then the path is treated as absolute.

    Fixes #7977.

    *Andrew White*

*   Fix `Encoding::CompatibilityError` when public path is UTF-8

    In #5337 we forced the path encoding to ASCII-8BIT to prevent static file handling
    from blowing up before an application has had chance to deal with possibly invalid
    urls. However this has a negative side effect of making it an incompatible encoding
    if the application's public path has UTF-8 characters in it.

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
    address security vulnerability CVE-2013-0155. In your app config:

        config.action_dispatch.perform_deep_munge = false

    Take care to understand the security risk involved before disabling this.
    [Read more.](https://groups.google.com/forum/#!topic/rubyonrails-security/t1WFuuQyavI)

    *Bernard Potocki*

*   `rake routes` shows routes defined under assets prefix.

    *Ryunosuke SATO*

*   Extend cross-site request forgery (CSRF) protection to GET requests with
    JavaScript responses, protecting apps from cross-origin `<script>` tags.

    *Jeremy Kemper*

*   Fix generating a path for engine inside a resources block.

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

    Variants also support common `any`/`all` block that formats have.

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

*   Fix render of localized templates without an explicit format using wrong
    content header and not passing correct formats to template due to the
    introduction of the `NullType` for mimes.

    Templates like `hello.it.erb` were subject to this issue.

    Fixes #13064.

    *Angelo Capilleri*, *Carlos Antonio da Silva*

*   Try to escape each part of a url correctly when using a redirect route.

    Fixes #13110.

    *Andrew White*

*   Better error message for typos in assert_response argument.

    When the response type argument to `assert_response` is not a known
    response type, `assert_response` now throws an ArgumentError with a clear
    message. This is intended to help debug typos in the response type.

    *Victor Costan*

*   Fix formatting for `rake routes` when a section is shorter than a header.

    *Sıtkı Bağdat*

*   Take a hash with options inside array in `#url_for`.

    Example:

        url_for [:new, :admin, :post, { param: 'value' }]
        # => http://example.com/admin/posts/new?param=value

    *Andrey Ognevsky*

*   Add `session#fetch` method

    fetch behaves like [Hash#fetch](http://www.ruby-doc.org/core-1.9.3/Hash.html#method-i-fetch).
    It returns a value from the hash for the given key.
    If the key can’t be found, there are several options:

      * With no other arguments, it will raise an KeyError exception.
      * If a default value is given, then that will be returned.
      * If the optional code block is specified, then that will be run and its result returned.

    *Damien Mathieu*

*   Don't let strong parameters mutate the given hash via `fetch`

    Create a new instance if the given parameter is a `Hash` instead of
    passing it to the `convert_hashes_to_parameters` method since it is
    overriding its default value.

    *Brendon Murphy*, *Doug Cole*

*   Add `params` option to `button_to` form helper, which renders the given hash
    as hidden form fields.

    *Andy Waite*

*   Make assets helpers work in the controllers like it works in the views.

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

    This now redirects to the path `/blog/admin/dashboard`, whereas before it would've
    generated an invalid url because there would be no slash between the host name and
    the path. It also allows redirects to work where the application is deployed to a
    subdirectory of a website.

    Fixes #7977.

    *Andrew White*

*   Fixing repond_with working directly on the options hash
    This fixes an issue where the respond_with worked directly with the given
    options hash, so that if a user relied on it after calling respond_with,
    the hash wouldn't be the same.

    Fixes #12029.

    *bluehotdog*

*   Fix `ActionDispatch::RemoteIp::GetIp#calculate_ip` to only check for spoofing
    attacks if both `HTTP_CLIENT_IP` and `HTTP_X_FORWARDED_FOR` are set.

    Fixes #10844.

    *Tamir Duberstein*

*   Strong parameters should permit nested number as key.

    Fixes #12293.

    *kennyj*

*   Fix regex used to detect URI schemes in `redirect_to` to be consistent with
    RFC 3986.

    *Derek Prior*

*   Fix incorrect `assert_redirected_to` failure message for protocol-relative
    URLs.

    *Derek Prior*

*   Fix an issue where router can't recognize downcased url encoding path.

    Fixes #12269.

    *kennyj*

*   Fix custom flash type definition. Misusage of the `_flash_types` class variable
    caused an error when reloading controllers with custom flash types.

    Fixes #12057.

    *Ricardo de Cillo*

*   Do not break params filtering on `nil` values.

    Fixes #12149.

    *Vasiliy Ermolovich*

*   Development mode exceptions are rendered in text format in case of XHR request.

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

*   Fix an issue where rails raise exception about missing helper where it
    should throw `LoadError`. When helper file exists and only loaded file from
    this helper does not exist rails should throw LoadError instead of
    `MissingHelperError`.

    *Piotr Niełacny*

*   Fix `ActionDispatch::ParamsParser#parse_formatted_parameters` to rewind body input stream on
    parsing json params.

    Fixes #11345.

    *Yuri Bol*, *Paul Nikitochkin*

*   Ignore spaces around delimiter in Set-Cookie header.

    *Yamagishi Kazutoshi*

*   Remove deprecated Rails application fallback for integration testing, set
    `ActionDispatch.test_app` instead.

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

*   Fix `Mime::Type.parse` when bad accepts header is looked up. Previously it
    was setting `request.formats` with an array containing a `nil` value, which
    raised an error when setting the controller formats.

    Fixes #10965.

    *Becker*

*   Merge `:action` from routing scope and assign endpoint if both `:controller`
    and `:action` are present. The endpoint assignment only occurs if there is
    no `:to` present in the options hash so should only affect routes using the
    shorthand syntax (i.e. endpoint is inferred from the path).

    Fixes #9856.

    *Yves Senn*, *Andrew White*

*   Action View extracted from Action Pack.

    *Piotr Sarnacki*, *Łukasz Strzałkowski*

Please check [4-0-stable](https://github.com/rails/rails/blob/4-0-stable/actionpack/CHANGELOG.md) for previous changes.
