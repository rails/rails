require 'action_view/helpers/javascript_helper'
require 'active_support/core_ext/array/access'
require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/output_safety'

module ActionView
  # = Action View URL Helpers
  module Helpers #:nodoc:
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

      module ClassMethods
        def _url_for_modules
          ActionView::RoutingUrlFor
        end
      end

      # Basic implementation of url_for to allow use helpers without routes existence
      def url_for(options = nil) # :nodoc:
        case options
        when String
          options
        when :back
          _back_url
        else
          raise ArgumentError, "arguments passed to url_for can't be handled. Please require " +
                               "routes or provide your own implementation"
        end
      end

      def _back_url # :nodoc:
        referrer = controller.respond_to?(:request) && controller.request.env["HTTP_REFERER"]
        referrer || 'javascript:history.back()'
      end
      protected :_back_url

      # Creates a link tag of the given +name+ using a URL created by the set of +options+.
      # See the valid options in the documentation for +url_for+. It's also possible to
      # pass a String instead of an options hash, which generates a link tag that uses the
      # value of the String as the href for the link. Using a <tt>:back</tt> Symbol instead
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
      # ==== Options
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      # * <tt>method: symbol of HTTP verb</tt> - This modifier will dynamically
      #   create an HTML form and immediately submit the form for processing using
      #   the HTTP verb specified. Useful for having links perform a POST operation
      #   in dangerous actions like deleting a record (which search bots can follow
      #   while spidering your site). Supported verbs are <tt>:post</tt>, <tt>:delete</tt>, <tt>:patch</tt>, and <tt>:put</tt>.
      #   Note that if the user has JavaScript disabled, the request will fall back
      #   to using GET. If <tt>href: '#'</tt> is used and the user has JavaScript
      #   disabled clicking the link will have no effect. If you are relying on the
      #   POST behavior, you should check for it in your controller's action by using
      #   the request object's methods for <tt>post?</tt>, <tt>delete?</tt>, <tt>patch?</tt>, or <tt>put?</tt>.
      # * <tt>remote: true</tt> - This will allow the unobtrusive JavaScript
      #   driver to make an Ajax request to the URL in question instead of following
      #   the link. The drivers each provide mechanisms for listening for the
      #   completion of the Ajax request and performing JavaScript operations once
      #   they're complete
      #
      # ==== Data attributes
      #
      # * <tt>confirm: 'question?'</tt> - This will allow the unobtrusive JavaScript
      #   driver to prompt with the question specified (in this case, the
      #   resulting text would be <tt>question?</tt>. If the user accepts, the
      #   link is processed normally, otherwise no action is taken.
      # * <tt>:disable_with</tt> - Value of this parameter will be
      #   used as the value for a disabled version of the submit
      #   button when the form is submitted. This feature is provided
      #   by the unobtrusive JavaScript driver.
      #
      # ==== Examples
      # Because it relies on +url_for+, +link_to+ supports both older-style controller/action/id arguments
      # and newer RESTful routes. Current Rails style favors RESTful routes whenever possible, so base
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
      #   # => <a href="/searches?foo=bar&amp;baz=quux">Nonsense search</a>
      #
      # The only option specific to +link_to+ (<tt>:method</tt>) is used as follows:
      #
      #   link_to("Destroy", "http://www.example.com", method: :delete)
      #   # => <a href='http://www.example.com' rel="nofollow" data-method="delete">Destroy</a>
      #
      # You can also use custom data attributes using the <tt>:data</tt> option:
      #
      #   link_to "Visit Other Site", "http://www.rubyonrails.org/", data: { confirm: "Are you sure?" }
      #   # => <a href="http://www.rubyonrails.org/" data-confirm="Are you sure?">Visit Other Site</a>
      def link_to(name = nil, options = nil, html_options = nil, &block)
        html_options, options, name = options, name, block if block_given?
        options ||= {}

        html_options = convert_options_to_data_attributes(options, html_options)

        url = url_for(options)
        html_options['href'] ||= url

        content_tag(:a, name || url, html_options, &block)
      end

      # Generates a form containing a single button that submits to the URL created
      # by the set of +options+. This is the safest method to ensure links that
      # cause changes to your data are not triggered by search bots or accelerators.
      # If the HTML button does not work with your layout, you can also consider
      # using the +link_to+ method with the <tt>:method</tt> modifier as described in
      # the +link_to+ documentation.
      #
      # By default, the generated form element has a class name of <tt>button_to</tt>
      # to allow styling of the form itself and its children. This can be changed
      # using the <tt>:form_class</tt> modifier within +html_options+. You can control
      # the form submission and input element behavior using +html_options+.
      # This method accepts the <tt>:method</tt> modifier described in the +link_to+ documentation.
      # If no <tt>:method</tt> modifier is given, it will default to performing a POST operation.
      # You can also disable the button by passing <tt>disabled: true</tt> in +html_options+.
      # If you are using RESTful routes, you can pass the <tt>:method</tt>
      # to change the HTTP verb used to submit the form.
      #
      # ==== Options
      # The +options+ hash accepts the same options as +url_for+.
      #
      # There are a few special +html_options+:
      # * <tt>:method</tt> - Symbol of HTTP verb. Supported verbs are <tt>:post</tt>, <tt>:get</tt>,
      #   <tt>:delete</tt>, <tt>:patch</tt>, and <tt>:put</tt>. By default it will be <tt>:post</tt>.
      # * <tt>:disabled</tt> - If set to true, it will generate a disabled button.
      # * <tt>:data</tt> - This option can be used to add custom data attributes.
      # * <tt>:remote</tt> -  If set to true, will allow the Unobtrusive JavaScript drivers to control the
      #   submit behavior. By default this behavior is an ajax submit.
      # * <tt>:form</tt> - This hash will be form attributes
      # * <tt>:form_class</tt> - This controls the class of the form within which the submit button will
      #   be placed
      # * <tt>:params</tt> - Hash of parameters to be rendered as hidden fields within the form.
      #
      # ==== Data attributes
      #
      # * <tt>:confirm</tt> - This will use the unobtrusive JavaScript driver to
      #   prompt with the question specified. If the user accepts, the link is
      #   processed normally, otherwise no action is taken.
      # * <tt>:disable_with</tt> - Value of this parameter will be
      #   used as the value for a disabled version of the submit
      #   button when the form is submitted. This feature is provided
      #   by the unobtrusive JavaScript driver.
      #
      # ==== Examples
      #   <%= button_to "New", action: "new" %>
      #   # => "<form method="post" action="/controller/new" class="button_to">
      #   #      <div><input value="New" type="submit" /></div>
      #   #    </form>"
      #
      #   <%= button_to "New", new_articles_path %>
      #   # => "<form method="post" action="/articles/new" class="button_to">
      #   #      <div><input value="New" type="submit" /></div>
      #   #    </form>"
      #
      #   <%= button_to [:make_happy, @user] do %>
      #     Make happy <strong><%= @user.name %></strong>
      #   <% end %>
      #   # => "<form method="post" action="/users/1/make_happy" class="button_to">
      #   #      <div>
      #   #        <button type="submit">
      #   #          Make happy <strong><%= @user.name %></strong>
      #   #        </button>
      #   #      </div>
      #   #    </form>"
      #
      #   <%= button_to "New", { action: "new" }, form_class: "new-thing" %>
      #   # => "<form method="post" action="/controller/new" class="new-thing">
      #   #      <div><input value="New" type="submit" /></div>
      #   #    </form>"
      #
      #
      #   <%= button_to "Create", { action: "create" }, remote: true, form: { "data-type" => "json" } %>
      #   # => "<form method="post" action="/images/create" class="button_to" data-remote="true" data-type="json">
      #   #      <div>
      #   #        <input value="Create" type="submit" />
      #   #        <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"/>
      #   #      </div>
      #   #    </form>"
      #
      #
      #   <%= button_to "Delete Image", { action: "delete", id: @image.id },
      #                                   method: :delete, data: { confirm: "Are you sure?" } %>
      #   # => "<form method="post" action="/images/delete/1" class="button_to">
      #   #      <div>
      #   #        <input type="hidden" name="_method" value="delete" />
      #   #        <input data-confirm='Are you sure?' value="Delete Image" type="submit" />
      #   #        <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"/>
      #   #      </div>
      #   #    </form>"
      #
      #
      #   <%= button_to('Destroy', 'http://www.example.com',
      #             method: "delete", remote: true, data: { confirm: 'Are you sure?', disable_with: 'loading...' }) %>
      #   # => "<form class='button_to' method='post' action='http://www.example.com' data-remote='true'>
      #   #       <div>
      #   #         <input name='_method' value='delete' type='hidden' />
      #   #         <input value='Destroy' type='submit' data-disable-with='loading...' data-confirm='Are you sure?' />
      #   #         <input name="authenticity_token" type="hidden" value="10f2163b45388899ad4d5ae948988266befcb6c3d1b2451cf657a0c293d605a6"/>
      #   #       </div>
      #   #     </form>"
      #   #
      def button_to(name = nil, options = nil, html_options = nil, &block)
        html_options, options = options, name if block_given?
        options      ||= {}
        html_options ||= {}

        html_options = html_options.stringify_keys
        convert_boolean_attributes!(html_options, %w(disabled))

        url    = options.is_a?(String) ? options : url_for(options)
        remote = html_options.delete('remote')
        params = html_options.delete('params')

        method     = html_options.delete('method').to_s
        method_tag = BUTTON_TAG_METHOD_VERBS.include?(method) ? method_tag(method) : ''.html_safe

        form_method  = method == 'get' ? 'get' : 'post'
        form_options = html_options.delete('form') || {}
        form_options[:class] ||= html_options.delete('form_class') || 'button_to'
        form_options.merge!(method: form_method, action: url)
        form_options.merge!("data-remote" => "true") if remote

        request_token_tag = form_method == 'post' ? token_tag : ''

        html_options = convert_options_to_data_attributes(options, html_options)
        html_options['type'] = 'submit'

        button = if block_given?
          content_tag('button', html_options, &block)
        else
          html_options['value'] = name || url
          tag('input', html_options)
        end

        inner_tags = method_tag.safe_concat(button).safe_concat(request_token_tag)
        if params
          params.each do |param_name, value|
            inner_tags.safe_concat tag(:input, type: "hidden", name: param_name, value: value.to_param)
          end
        end
        content_tag('form', content_tag('div', inner_tags), form_options)
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
        if condition
          if block_given?
            block.arity <= 1 ? capture(name, &block) : capture(name, options, html_options, &block)
          else
            ERB::Util.html_escape(name)
          end
        else
          link_to(name, options, html_options)
        end
      end

      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ if +condition+ is true, otherwise only the name is
      # returned. To specialize the default behavior, you can pass a block that
      # accepts the name or the full argument list for +link_to_unless+ (see the examples
      # in +link_to_unless+).
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
        link_to_unless !condition, name, options, html_options, &block
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
      #
      # ==== Obfuscation
      # Prior to Rails 4.0, +mail_to+ provided options for encoding the address
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
      #   mail_to "me@domain.com", "My email", cc: "ccaddress@domain.com",
      #            subject: "This is an example email"
      #   # => <a href="mailto:me@domain.com?cc=ccaddress@domain.com&subject=This%20is%20an%20example%20email">My email</a>
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
        html_options, name = name, nil if block_given?
        html_options = (html_options || {}).stringify_keys

        extras = %w{ cc bcc body subject }.map! { |item|
          option = html_options.delete(item) || next
          "#{item}=#{Rack::Utils.escape_path(option)}"
        }.compact
        extras = extras.empty? ? '' : '?' + ERB::Util.html_escape(extras.join('&'))

        encoded_email_address = ERB::Util.url_encode(email_address.to_str).gsub("%40", "@")
        html_options["href"] = "mailto:#{encoded_email_address}#{extras}".html_safe

        content_tag(:a, name || email_address, html_options, &block)
      end

      # True if the current request URI was generated by the given +options+.
      #
      # ==== Examples
      # Let's say we're in the <tt>http://www.example.com/shop/checkout?order=desc</tt> action.
      #
      #   current_page?(action: 'process')
      #   # => false
      #
      #   current_page?(controller: 'shop', action: 'checkout')
      #   # => true
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'asc')
      #   # => false
      #
      #   current_page?(action: 'checkout')
      #   # => true
      #
      #   current_page?(controller: 'library', action: 'checkout')
      #   # => false
      #
      #   current_page?('http://www.example.com/shop/checkout')
      #   # => true
      #
      #   current_page?('/shop/checkout')
      #   # => true
      #
      # Let's say we're in the <tt>http://www.example.com/shop/checkout?order=desc&page=1</tt> action.
      #
      #   current_page?(action: 'process')
      #   # => false
      #
      #   current_page?(controller: 'shop', action: 'checkout')
      #   # => true
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'desc', page: '1')
      #   # => true
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'desc', page: '2')
      #   # => false
      #
      #   current_page?(controller: 'shop', action: 'checkout', order: 'desc')
      #   # => false
      #
      #   current_page?(action: 'checkout')
      #   # => true
      #
      #   current_page?(controller: 'library', action: 'checkout')
      #   # => false
      #
      # Let's say we're in the <tt>http://www.example.com/products</tt> action with method POST in case of invalid product.
      #
      #   current_page?(controller: 'product', action: 'index')
      #   # => false
      #
      def current_page?(options)
        unless request
          raise "You cannot use helpers that need to determine the current " \
                "page unless your view context provides a Request object " \
                "in a #request method"
        end

        return false unless request.get? || request.head?

        url_string = URI.parser.unescape(url_for(options)).force_encoding(Encoding::BINARY)

        # We ignore any extra parameters in the request_uri if the
        # submitted url doesn't have any either. This lets the function
        # work with things like ?order=asc
        request_uri = url_string.index("?") ? request.fullpath : request.path
        request_uri = URI.parser.unescape(request_uri).force_encoding(Encoding::BINARY)

        if url_string =~ /^\w+:\/\//
          url_string == "#{request.protocol}#{request.host_with_port}#{request_uri}"
        else
          url_string == request_uri
        end
      end

      private
        def convert_options_to_data_attributes(options, html_options)
          if html_options
            html_options = html_options.stringify_keys
            html_options['data-remote'] = 'true' if link_to_remote_options?(options) || link_to_remote_options?(html_options)

            method  = html_options.delete('method')

            add_method_to_attributes!(html_options, method) if method

            html_options
          else
            link_to_remote_options?(options) ? {'data-remote' => 'true'} : {}
          end
        end

        def link_to_remote_options?(options)
          if options.is_a?(Hash)
            options.delete('remote') || options.delete(:remote)
          end
        end

        def add_method_to_attributes!(html_options, method)
          if method && method.to_s.downcase != "get" && html_options["rel"] !~ /nofollow/
            html_options["rel"] = "#{html_options["rel"]} nofollow".lstrip
          end
          html_options["data-method"] = method
        end

        # Processes the +html_options+ hash, converting the boolean
        # attributes from true/false form into the form required by
        # HTML/XHTML. (An attribute is considered to be boolean if
        # its name is listed in the given +bool_attrs+ array.)
        #
        # More specifically, for each boolean attribute in +html_options+
        # given as:
        #
        #   "attr" => bool_value
        #
        # if the associated +bool_value+ evaluates to true, it is
        # replaced with the attribute's name; otherwise the attribute is
        # removed from the +html_options+ hash. (See the XHTML 1.0 spec,
        # section 4.5 "Attribute Minimization" for more:
        # http://www.w3.org/TR/xhtml1/#h-4.5)
        #
        # Returns the updated +html_options+ hash, which is also modified
        # in place.
        #
        # Example:
        #
        #   convert_boolean_attributes!( html_options,
        #                                %w( checked disabled readonly ) )
        def convert_boolean_attributes!(html_options, bool_attrs)
          bool_attrs.each { |x| html_options[x] = x if html_options.delete(x) }
          html_options
        end

        def token_tag(token=nil)
          if token != false && protect_against_forgery?
            token ||= form_authenticity_token
            tag(:input, type: "hidden", name: request_forgery_protection_token.to_s, value: token)
          else
            ''
          end
        end

        def method_tag(method)
          tag('input', type: 'hidden', name: '_method', value: method.to_s)
        end
    end
  end
end
