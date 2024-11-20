# frozen_string_literal: true

require "active_support/core_ext/array/access"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/string/output_safety"
require "action_view/helpers/content_exfiltration_prevention_helper"
require "action_view/helpers/tag_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View URL \Helpers
    #
    # Provides a set of methods for making links and getting URLs that
    # depend on the routing subsystem (see ActionDispatch::Routing).
    # This allows you to use the same format for links in views
    # and controllers.
    module UrlHelper
      # This helper may be included in any class that includes the
      # URL helpers of a routes (routes.url_helpers). Some methods
      # provided here will only work in the context of a request
      # (link_to_unless_current, for instance), which must be provided
      # as a method called #request on the context.
      BUTTON_TAG_METHOD_VERBS = %w{patch put delete}
      extend ActiveSupport::Concern

      include TagHelper
      include ContentExfiltrationPreventionHelper

      module ClassMethods
        def _url_for_modules
          ActionView::RoutingUrlFor
        end
      end

      mattr_accessor :button_to_generates_button_tag, default: false

      # Basic implementation of url_for to allow use helpers without routes existence
      def url_for(options = nil) # :nodoc:
        case options
        when String
          options
        when :back
          _back_url
        else
          raise ArgumentError, "arguments passed to url_for can't be handled. Please require " \
                               "routes or provide your own implementation"
        end
      end

      def _back_url # :nodoc:
        _filtered_referrer || "javascript:history.back()"
      end
      private :_back_url

      def _filtered_referrer # :nodoc:
        if controller.respond_to?(:request)
          referrer = controller.request.env["HTTP_REFERER"]
          if referrer && URI(referrer).scheme != "javascript"
            referrer
          end
        end
      rescue URI::InvalidURIError
      end
      private :_filtered_referrer

      # Creates an anchor element of the given +name+ using a URL created by the set of +options+.
      # See the valid options in the documentation for +url_for+. It's also possible to
      # pass a \String instead of an options hash, which generates an anchor element that uses the
      # value of the \String as the href for the link. Using a <tt>:back</tt> \Symbol instead
      # of an options hash will generate a link to the referrer (a JavaScript back link
      # will be used in place of a referrer if none exists). If +nil+ is passed as the name
      # the value of the link itself will become the name.
      #
      # ==== Signatures
      #
      #   link_to(body, url, html_options = {})
      #     # url is a String; you can use URL helpers like
      #     # posts_path
      #
      #   link_to(body, url_options = {}, html_options = {})
      #     # url_options, except :method, is passed to url_for
      #
      #   link_to(options = {}, html_options = {}) do
      #     # name
      #   end
      #
      #   link_to(url, html_options = {}) do
      #     # name
      #   end
      #
      #   link_to(active_record_model)
      #
      # ==== Options
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      #
      # ==== Examples
      #
      # Because it relies on +url_for+, +link_to+ supports both older-style controller/action/id arguments
      # and newer RESTful routes. Current \Rails style favors RESTful routes whenever possible, so base
      # your application on resources and use
      #
      #   link_to "Profile", profile_path(@profile)
      #   # => <a href="/profiles/1">Profile</a>
      #
      # or the even pithier
      #
      #   link_to "Profile", @profile
      #   # => <a href="/profiles/1">Profile</a>
      #
      # in place of the older more verbose, non-resource-oriented
      #
      #   link_to "Profile", controller: "profiles", action: "show", id: @profile
      #   # => <a href="/profiles/show/1">Profile</a>
      #
      # Similarly,
      #
      #   link_to "Profiles", profiles_path
      #   # => <a href="/profiles">Profiles</a>
      #
      # is better than
      #
      #   link_to "Profiles", controller: "profiles"
      #   # => <a href="/profiles">Profiles</a>
      #
      # When name is +nil+ the href is presented instead
      #
      #   link_to nil, "http://example.com"
      #   # => <a href="http://www.example.com">http://www.example.com</a>
      #
      # More concise yet, when +name+ is an Active Record model that defines a
      # +to_s+ method returning a default value or a model instance attribute
      #
      #   link_to @profile
      #   # => <a href="http://www.example.com/profiles/1">Eileen</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. ERB example:
      #
      #   <%= link_to(@profile) do %>
      #     <strong><%= @profile.name %></strong> -- <span>Check it out!</span>
      #   <% end %>
      #   # => <a href="/profiles/1">
      #          <strong>David</strong> -- <span>Check it out!</span>
      #        </a>
      #
      # Classes and ids for CSS are easy to produce:
      #
      #   link_to "Articles", articles_path, id: "news", class: "article"
      #   # => <a href="/articles" class="article" id="news">Articles</a>
      #
      # Be careful when using the older argument style, as an extra literal hash is needed:
      #
      #   link_to "Articles", { controller: "articles" }, id: "news", class: "article"
      #   # => <a href="/articles" class="article" id="news">Articles</a>
      #
      # Leaving the hash off gives the wrong link:
      #
      #   link_to "WRONG!", controller: "articles", id: "news", class: "article"
      #   # => <a href="/articles/index/news?class=article">WRONG!</a>
      #
      # +link_to+ can also produce links with anchors or query strings:
      #
      #   link_to "Comment wall", profile_path(@profile, anchor: "wall")
      #   # => <a href="/profiles/1#wall">Comment wall</a>
      #
      #   link_to "Ruby on Rails search", controller: "searches", query: "ruby on rails"
      #   # => <a href="/searches?query=ruby+on+rails">Ruby on Rails search</a>
      #
      #   link_to "Nonsense search", searches_path(foo: "bar", baz: "quux")
      #   # => <a href="/searches?foo=bar&baz=quux">Nonsense search</a>
      #
      # You can set any link attributes such as <tt>target</tt>, <tt>rel</tt>, <tt>type</tt>:
      #
      #   link_to "External link", "http://www.rubyonrails.org/", target: "_blank", rel: "nofollow"
      #   # => <a href="http://www.rubyonrails.org/" target="_blank" rel="nofollow">External link</a>
      #
      # ==== Turbo
      #
      # Rails 7 ships with Turbo enabled by default. Turbo provides the following +:data+ options:
      #
      # * <tt>turbo_method: symbol of HTTP verb</tt> - Performs a Turbo link visit
      #   with the given HTTP verb. Forms are recommended when performing non-+GET+ requests.
      #   Only use <tt>data-turbo-method</tt> where a form is not possible.
      #
      # * <tt>turbo_confirm: "question?"</tt> - Adds a confirmation dialog to the link with the
      #   given value.
      #
      # {Consult the Turbo Handbook for more information on the options
      # above.}[https://turbo.hotwired.dev/handbook/drive#performing-visits-with-a-different-method]
      #
      # ===== \Examples
      #
      #   link_to "Delete profile", @profile, data: { turbo_method: :delete }
      #   # => <a href="/profiles/1" data-turbo-method="delete">Delete profile</a>
      #
      #   link_to "Visit Other Site", "https://rubyonrails.org/", data: { turbo_confirm: "Are you sure?" }
      #   # => <a href="https://rubyonrails.org/" data-turbo-confirm="Are you sure?">Visit Other Site</a>
      #
      def link_to(name = nil, options = nil, html_options = nil, &block)
        html_options, options, name = options, name, block if block_given?
        options ||= {}

        html_options = convert_options_to_data_attributes(options, html_options)

        url = url_target(name, options)
        html_options["href"] ||= url

        content_tag("a", name || url, html_options, &block)
      end

      # Generates a form containing a single button that submits to the URL created
      # by the set of +options+. This is the safest method to ensure links that
      # cause changes to your data are not triggered by search bots or accelerators.
      #
      # You can control the form and button behavior with +html_options+. Most
      # values in +html_options+ are passed through to the button element. For
      # example, passing a +:class+ option within +html_options+ will set the
      # class attribute of the button element.
      #
      # The class attribute of the form element can be set by passing a
      # +:form_class+ option within +html_options+. It defaults to
      # <tt>"button_to"</tt> to allow styling of the form and its children.
      #
      # The form submits a POST request by default if the object is not persisted;
      # conversely, if the object is persisted, it will submit a PATCH request.
      # To specify a different HTTP verb use the +:method+ option within +html_options+.
      #
      # If the HTML button generated from +button_to+ does not work with your layout, you can
      # consider using the +link_to+ method with the +data-turbo-method+
      # attribute as described in the +link_to+ documentation.
      #
      # ==== Options
      # The +options+ hash accepts the same options as +url_for+. To generate a
      # <tt><form></tt> element without an <tt>[action]</tt> attribute, pass
      # <tt>false</tt>:
      #
      #   <%= button_to "New", false %>
      #   # => "<form method="post" class="button_to">
      #   #      <button type="submit">New</button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"/>
      #   #    </form>"
      #
      # Most values in +html_options+ are passed through to the button element,
      # but there are a few special options:
      #
      # * <tt>:method</tt> - \Symbol of HTTP verb. Supported verbs are <tt>:post</tt>, <tt>:get</tt>,
      #   <tt>:delete</tt>, <tt>:patch</tt>, and <tt>:put</tt>. By default it will be <tt>:post</tt>.
      # * <tt>:disabled</tt> - If set to true, it will generate a disabled button.
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      # * <tt>:form</tt> - This hash will be form attributes
      # * <tt>:form_class</tt> - This controls the class of the form within which the submit button will
      #   be placed
      # * <tt>:params</tt> - \Hash of parameters to be rendered as hidden fields within the form.
      #
      # ==== Examples
      #   <%= button_to "New", action: "new" %>
      #   # => "<form method="post" action="/controller/new" class="button_to">
      #   #      <button type="submit">New</button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6" autocomplete="off"/>
      #   #    </form>"
      #
      #   <%= button_to "New", new_article_path %>
      #   # => "<form method="post" action="/articles/new" class="button_to">
      #   #      <button type="submit">New</button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6" autocomplete="off"/>
      #   #    </form>"
      #
      #   <%= button_to "New", new_article_path, params: { time: Time.now  } %>
      #   # => "<form method="post" action="/articles/new" class="button_to">
      #   #      <button type="submit">New</button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"/>
      #   #      <input type="hidden" name="time" value="2021-04-08 14:06:09 -0500" autocomplete="off">
      #   #    </form>"
      #
      #   <%= button_to [:make_happy, @user] do %>
      #     Make happy <strong><%= @user.name %></strong>
      #   <% end %>
      #   # => "<form method="post" action="/users/1/make_happy" class="button_to">
      #   #      <button type="submit">
      #   #        Make happy <strong><%= @user.name %></strong>
      #   #      </button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"  autocomplete="off"/>
      #   #    </form>"
      #
      #   <%= button_to "New", { action: "new" }, form_class: "new-thing" %>
      #   # => "<form method="post" action="/controller/new" class="new-thing">
      #   #      <button type="submit">New</button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"  autocomplete="off"/>
      #   #    </form>"
      #
      #   <%= button_to "Create", { action: "create" }, form: { "data-type" => "json" } %>
      #   # => "<form method="post" action="/images/create" class="button_to" data-type="json">
      #   #      <button type="submit">Create</button>
      #   #      <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"  autocomplete="off"/>
      #   #    </form>"
      #
      def button_to(name = nil, options = nil, html_options = nil, &block)
        html_options, options = options, name if block_given?
        html_options ||= {}
        html_options = html_options.stringify_keys

        url =
          case options
          when FalseClass then nil
          else url_for(options)
          end

        remote = html_options.delete("remote")
        params = html_options.delete("params")

        authenticity_token = html_options.delete("authenticity_token")

        method     = (html_options.delete("method").presence || method_for_options(options)).to_s
        method_tag = BUTTON_TAG_METHOD_VERBS.include?(method) ? method_tag(method) : "".html_safe

        form_method  = method == "get" ? "get" : "post"
        form_options = html_options.delete("form") || {}
        form_options[:class] ||= html_options.delete("form_class") || "button_to"
        form_options[:method] = form_method
        form_options[:action] = url
        form_options[:'data-remote'] = true if remote

        request_token_tag = if form_method == "post"
          request_method = method.empty? ? "post" : method
          token_tag(authenticity_token, form_options: { action: url, method: request_method })
        else
          ""
        end

        html_options = convert_options_to_data_attributes(options, html_options)
        html_options["type"] = "submit"

        button = if block_given?
          content_tag("button", html_options, &block)
        elsif button_to_generates_button_tag
          content_tag("button", name || url, html_options, &block)
        else
          html_options["value"] = name || url
          tag("input", html_options)
        end

        inner_tags = method_tag.safe_concat(button).safe_concat(request_token_tag)
        if params
          to_form_params(params).each do |param|
            inner_tags.safe_concat tag(:input, type: "hidden", name: param[:name], value: param[:value],
                                       autocomplete: "off")
          end
        end
        html = content_tag("form", inner_tags, form_options)
        prevent_content_exfiltration(html)
      end

      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ unless the current request URI is the same as the links, in
      # which case only the name is returned (or the given block is yielded, if
      # one exists). You can give +link_to_unless_current+ a block which will
      # specialize the default behavior (e.g., show a "Start Here" link rather
      # than the link's text).
      #
      # ==== Examples
      # Let's say you have a navigation menu...
      #
      #   <ul id="navbar">
      #     <li><%= link_to_unless_current("Home", { action: "index" }) %></li>
      #     <li><%= link_to_unless_current("About Us", { action: "about" }) %></li>
      #   </ul>
      #
      # If in the "about" action, it will render...
      #
      #   <ul id="navbar">
      #     <li><a href="/controller/index">Home</a></li>
      #     <li>About Us</li>
      #   </ul>
      #
      # ...but if in the "index" action, it will render:
      #
      #   <ul id="navbar">
      #     <li>Home</li>
      #     <li><a href="/controller/about">About Us</a></li>
      #   </ul>
      #
      # The implicit block given to +link_to_unless_current+ is evaluated if the current
      # action is the action given. So, if we had a comments page and wanted to render a
      # "Go Back" link instead of a link to the comments page, we could do something like this...
      #
      #    <%=
      #        link_to_unless_current("Comment", { controller: "comments", action: "new" }) do
      #           link_to("Go back", { controller: "posts", action: "index" })
      #        end
      #     %>
      def link_to_unless_current(name, options = {}, html_options = {}, &block)
        link_to_unless current_page?(options), name, options, html_options, &block
      end

      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ unless +condition+ is true, in which case only the name is
      # returned. To specialize the default behavior (i.e., show a login link rather
      # than just the plaintext link text), you can pass a block that
      # accepts the name or the full argument list for +link_to_unless+.
      #
      # ==== Examples
      #   <%= link_to_unless(@current_user.nil?, "Reply", { action: "reply" }) %>
      #   # If the user is logged in...
      #   # => <a href="/controller/reply/">Reply</a>
      #
      #   <%=
      #      link_to_unless(@current_user.nil?, "Reply", { action: "reply" }) do |name|
      #        link_to(name, { controller: "accounts", action: "signup" })
      #      end
      #   %>
      #   # If the user is logged in...
      #   # => <a href="/controller/reply/">Reply</a>
      #   # If not...
      #   # => <a href="/accounts/signup">Reply</a>
      def link_to_unless(condition, name, options = {}, html_options = {}, &block)
        link_to_if !condition, name, options, html_options, &block
      end

      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ if +condition+ is true, otherwise only the name is
      # returned. To specialize the default behavior, you can pass a block that
      # accepts the name or the full argument list for +link_to_if+.
      #
      # ==== Examples
      #   <%= link_to_if(@current_user.nil?, "Login", { controller: "sessions", action: "new" }) %>
      #   # If the user isn't logged in...
      #   # => <a href="/sessions/new/">Login</a>
      #
      #   <%=
      #      link_to_if(@current_user.nil?, "Login", { controller: "sessions", action: "new" }) do
      #        link_to(@current_user.login, { controller: "accounts", action: "show", id: @current_user })
      #      end
      #   %>
      #   # If the user isn't logged in...
      #   # => <a href="/sessions/new/">Login</a>
      #   # If they are logged in...
      #   # => <a href="/accounts/show/3">my_username</a>
      def link_to_if(condition, name, options = {}, html_options = {}, &block)
        if condition
          link_to(name, options, html_options)
        else
          if block_given?
            block.arity <= 1 ? capture(name, &block) : capture(name, options, html_options, &block)
          else
            ERB::Util.html_escape(name)
          end
        end
      end

      # Creates a mailto link tag to the specified +email_address+, which is
      # also used as the name of the link unless +name+ is specified. Additional
      # HTML attributes for the link can be passed in +html_options+.
      #
      # +mail_to+ has several methods for customizing the email itself by
      # passing special keys to +html_options+.
      #
      # ==== Options
      # * <tt>:subject</tt> - Preset the subject line of the email.
      # * <tt>:body</tt> - Preset the body of the email.
      # * <tt>:cc</tt> - Carbon Copy additional recipients on the email.
      # * <tt>:bcc</tt> - Blind Carbon Copy additional recipients on the email.
      # * <tt>:reply_to</tt> - Preset the +Reply-To+ field of the email.
      #
      # ==== Obfuscation
      # Prior to \Rails 4.0, +mail_to+ provided options for encoding the address
      # in order to hinder email harvesters.  To take advantage of these options,
      # install the +actionview-encoded_mail_to+ gem.
      #
      # ==== Examples
      #   mail_to "me@domain.com"
      #   # => <a href="mailto:me@domain.com">me@domain.com</a>
      #
      #   mail_to "me@domain.com", "My email"
      #   # => <a href="mailto:me@domain.com">My email</a>
      #
      #   mail_to "me@domain.com", cc: "ccaddress@domain.com",
      #            subject: "This is an example email"
      #   # => <a href="mailto:me@domain.com?cc=ccaddress@domain.com&subject=This%20is%20an%20example%20email">me@domain.com</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. ERB example:
      #
      #   <%= mail_to "me@domain.com" do %>
      #     <strong>Email me:</strong> <span>me@domain.com</span>
      #   <% end %>
      #   # => <a href="mailto:me@domain.com">
      #          <strong>Email me:</strong> <span>me@domain.com</span>
      #        </a>
      def mail_to(email_address, name = nil, html_options = {}, &block)
        html_options, name = name, nil if name.is_a?(Hash)
        html_options = (html_options || {}).stringify_keys

        extras = %w{ cc bcc body subject reply_to }.map! { |item|
          option = html_options.delete(item).presence || next
          "#{item.dasherize}=#{ERB::Util.url_encode(option)}"
        }.compact
        extras = extras.empty? ? "" : "?" + extras.join("&")

        encoded_email_address = ERB::Util.url_encode(email_address).gsub("%40", "@")
        html_options["href"] = "mailto:#{encoded_email_address}#{extras}"

        content_tag("a", name || email_address, html_options, &block)
      end

      # True if the current request URI was generated by the given +options+.
      #
      # ==== Examples
      # Let's say we're in the <tt>http://www.example.com/shop/checkout?order=desc&page=1</tt> action.
      #
      #   current_page?(action: 'process')
      #   # => false
      #
      #   current_page?(action: 'checkout')
      #   # => true
      #
      #   current_page?(controller: 'library', action: 'checkout')
      #   # => false
      #
      #   current_page?(controller: 'shop', action: 'checkout')
      #   # => true
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'asc')
      #   # => false
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'desc', page: '1')
      #   # => true
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'desc', page: '2')
      #   # => false
      #
      #   current_page?('http://www.example.com/shop/checkout')
      #   # => true
      #
      #   current_page?('http://www.example.com/shop/checkout', check_parameters: true)
      #   # => false
      #
      #   current_page?('/shop/checkout')
      #   # => true
      #
      #   current_page?('http://www.example.com/shop/checkout?order=desc&page=1')
      #   # => true
      #
      # Let's say we're in the <tt>http://www.example.com/products</tt> action with method POST in case of invalid product.
      #
      #   current_page?(controller: 'product', action: 'index')
      #   # => false
      #
      # We can also pass in the symbol arguments instead of strings.
      #
      def current_page?(options = nil, check_parameters: false, **options_as_kwargs)
        unless request
          raise "You cannot use helpers that need to determine the current " \
                "page unless your view context provides a Request object " \
                "in a #request method"
        end

        return false unless request.get? || request.head?

        options ||= options_as_kwargs
        check_parameters ||= options.is_a?(Hash) && options.delete(:check_parameters)
        url_string = URI::RFC2396_PARSER.unescape(url_for(options)).force_encoding(Encoding::BINARY)

        # We ignore any extra parameters in the request_uri if the
        # submitted URL doesn't have any either. This lets the function
        # work with things like ?order=asc
        # the behavior can be disabled with check_parameters: true
        request_uri = url_string.index("?") || check_parameters ? request.fullpath : request.path
        request_uri = URI::RFC2396_PARSER.unescape(request_uri).force_encoding(Encoding::BINARY)

        if %r{^\w+://}.match?(url_string)
          request_uri = +"#{request.protocol}#{request.host_with_port}#{request_uri}"
        end

        remove_trailing_slash!(url_string)
        remove_trailing_slash!(request_uri)

        url_string == request_uri
      end

      # Creates an SMS anchor link tag to the specified +phone_number+. When the
      # link is clicked, the default SMS messaging app is opened ready to send a
      # message to the linked phone number. If the +body+ option is specified,
      # the contents of the message will be preset to +body+.
      #
      # If +name+ is not specified, +phone_number+ will be used as the name of
      # the link.
      #
      # A +country_code+ option is supported, which prepends a plus sign and the
      # given country code to the linked phone number. For example,
      # <tt>country_code: "01"</tt> will prepend <tt>+01</tt> to the linked
      # phone number.
      #
      # Additional HTML attributes for the link can be passed via +html_options+.
      #
      # ==== Options
      # * <tt>:country_code</tt> - Prepend the country code to the phone number.
      # * <tt>:body</tt> - Preset the body of the message.
      #
      # ==== Examples
      #   sms_to "5155555785"
      #   # => <a href="sms:5155555785;">5155555785</a>
      #
      #   sms_to "5155555785", country_code: "01"
      #   # => <a href="sms:+015155555785;">5155555785</a>
      #
      #   sms_to "5155555785", "Text me"
      #   # => <a href="sms:5155555785;">Text me</a>
      #
      #   sms_to "5155555785", body: "I have a question about your product."
      #   # => <a href="sms:5155555785;?body=I%20have%20a%20question%20about%20your%20product">5155555785</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. \ERB example:
      #
      #   <%= sms_to "5155555785" do %>
      #     <strong>Text me:</strong>
      #   <% end %>
      #   # => <a href="sms:5155555785;">
      #          <strong>Text me:</strong>
      #        </a>
      def sms_to(phone_number, name = nil, html_options = {}, &block)
        html_options, name = name, nil if name.is_a?(Hash)
        html_options = (html_options || {}).stringify_keys

        country_code = html_options.delete("country_code").presence
        country_code = country_code ? "+#{ERB::Util.url_encode(country_code)}" : ""

        body = html_options.delete("body").presence
        body = body ? "?&body=#{ERB::Util.url_encode(body)}" : ""

        encoded_phone_number = ERB::Util.url_encode(phone_number)
        html_options["href"] = "sms:#{country_code}#{encoded_phone_number};#{body}"

        content_tag("a", name || phone_number, html_options, &block)
      end

      # Creates a TEL anchor link tag to the specified +phone_number+. When the
      # link is clicked, the default app to make phone calls is opened and
      # prepopulated with the phone number.
      #
      # If +name+ is not specified, +phone_number+ will be used as the name of
      # the link.
      #
      # A +country_code+ option is supported, which prepends a plus sign and the
      # given country code to the linked phone number. For example,
      # <tt>country_code: "01"</tt> will prepend <tt>+01</tt> to the linked
      # phone number.
      #
      # Additional HTML attributes for the link can be passed via +html_options+.
      #
      # ==== Options
      # * <tt>:country_code</tt> - Prepends the country code to the phone number
      #
      # ==== Examples
      #   phone_to "1234567890"
      #   # => <a href="tel:1234567890">1234567890</a>
      #
      #   phone_to "1234567890", "Phone me"
      #   # => <a href="tel:1234567890">Phone me</a>
      #
      #   phone_to "1234567890", country_code: "01"
      #   # => <a href="tel:+011234567890">1234567890</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. \ERB example:
      #
      #   <%= phone_to "1234567890" do %>
      #     <strong>Phone me:</strong>
      #   <% end %>
      #   # => <a href="tel:1234567890">
      #          <strong>Phone me:</strong>
      #        </a>
      def phone_to(phone_number, name = nil, html_options = {}, &block)
        html_options, name = name, nil if name.is_a?(Hash)
        html_options = (html_options || {}).stringify_keys

        country_code = html_options.delete("country_code").presence
        country_code = country_code.nil? ? "" : "+#{ERB::Util.url_encode(country_code)}"

        encoded_phone_number = ERB::Util.url_encode(phone_number)
        html_options["href"] = "tel:#{country_code}#{encoded_phone_number}"

        content_tag("a", name || phone_number, html_options, &block)
      end

      private
        def convert_options_to_data_attributes(options, html_options)
          if html_options
            html_options = html_options.stringify_keys
            html_options["data-remote"] = "true" if link_to_remote_options?(options) || link_to_remote_options?(html_options)

            method = html_options.delete("method")

            add_method_to_attributes!(html_options, method) if method

            html_options
          else
            link_to_remote_options?(options) ? { "data-remote" => "true" } : {}
          end
        end

        def url_target(name, options)
          if name.respond_to?(:model_name) && options.is_a?(Hash) && options.empty?
            url_for(name)
          else
            url_for(options)
          end
        end

        def link_to_remote_options?(options)
          if options.is_a?(Hash)
            options.delete("remote") || options.delete(:remote)
          end
        end

        def add_method_to_attributes!(html_options, method)
          if method_not_get_method?(method) && !html_options["rel"].to_s.include?("nofollow")
            if html_options["rel"].blank?
              html_options["rel"] = "nofollow"
            else
              html_options["rel"] = "#{html_options["rel"]} nofollow"
            end
          end
          html_options["data-method"] = method
        end

        def method_for_options(options)
          if options.is_a?(Array)
            method_for_options(options.last)
          elsif options.respond_to?(:persisted?)
            options.persisted? ? :patch : :post
          elsif options.respond_to?(:to_model)
            method_for_options(options.to_model)
          end
        end

        STRINGIFIED_COMMON_METHODS = {
          get:    "get",
          delete: "delete",
          patch:  "patch",
          post:   "post",
          put:    "put",
        }.freeze

        def method_not_get_method?(method)
          return false unless method
          (STRINGIFIED_COMMON_METHODS[method] || method.to_s.downcase) != "get"
        end

        def token_tag(token = nil, form_options: {})
          if token != false && defined?(protect_against_forgery?) && protect_against_forgery?
            token =
              if token == true || token.nil?
                form_authenticity_token(form_options: form_options.merge(authenticity_token: token))
              else
                token
              end
            tag(:input, type: "hidden", name: request_forgery_protection_token.to_s, value: token, autocomplete: "off")
          else
            ""
          end
        end

        def method_tag(method)
          tag("input", type: "hidden", name: "_method", value: method.to_s, autocomplete: "off")
        end

        # Returns an array of hashes each containing :name and :value keys
        # suitable for use as the names and values of form input fields:
        #
        #   to_form_params(name: 'David', nationality: 'Danish')
        #   # => [{name: 'name', value: 'David'}, {name: 'nationality', value: 'Danish'}]
        #
        #   to_form_params(country: { name: 'Denmark' })
        #   # => [{name: 'country[name]', value: 'Denmark'}]
        #
        #   to_form_params(countries: ['Denmark', 'Sweden']})
        #   # => [{name: 'countries[]', value: 'Denmark'}, {name: 'countries[]', value: 'Sweden'}]
        #
        # An optional namespace can be passed to enclose key names:
        #
        #   to_form_params({ name: 'Denmark' }, 'country')
        #   # => [{name: 'country[name]', value: 'Denmark'}]
        def to_form_params(attribute, namespace = nil)
          attribute = if attribute.respond_to?(:permitted?)
            attribute.to_h
          else
            attribute
          end

          params = []
          case attribute
          when Hash
            attribute.each do |key, value|
              prefix = namespace ? "#{namespace}[#{key}]" : key
              params.push(*to_form_params(value, prefix))
            end
          when Array
            array_prefix = "#{namespace}[]"
            attribute.each do |value|
              params.push(*to_form_params(value, array_prefix))
            end
          else
            params << { name: namespace.to_s, value: attribute.to_param }
          end

          params.sort_by { |pair| pair[:name] }
        end

        def remove_trailing_slash!(url_string)
          trailing_index = (url_string.index("?") || 0) - 1
          url_string[trailing_index] = "" if url_string[trailing_index] == "/"
        end
    end
  end
end
