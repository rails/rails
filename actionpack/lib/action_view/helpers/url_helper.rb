#require 'action_view/helpers/javascript_helper'

module ActionView
  module Helpers #:nodoc:
    # Provides a set of methods for making links and getting URLs that
    # depend on the routing subsystem (see ActionController::Routing).
    # This allows you to use the same format for links in views
    # and controllers.
    module UrlHelper
      include JavaScriptHelper

      # Returns the URL for the set of +options+ provided. This takes the
      # same options as +url_for+ in Action Controller (see the
      # documentation for ActionController::Base#url_for). Note that by default
      # <tt>:only_path</tt> is <tt>true</tt> so you'll get the relative /controller/action
      # instead of the fully qualified URL like http://example.com/controller/action.
      #
      # When called from a view, url_for returns an HTML escaped url. If you
      # need an unescaped url, pass <tt>:escape => false</tt> in the +options+.
      #
      # ==== Options
      # * <tt>:anchor</tt> - Specifies the anchor name to be appended to the path.
      # * <tt>:only_path</tt> - If true, returns the relative URL (omitting the protocol, host name, and port) (<tt>true</tt> by default unless <tt>:host</tt> is specified).
      # * <tt>:trailing_slash</tt> - If true, adds a trailing slash, as in "/archive/2005/". Note that this
      #   is currently not recommended since it breaks caching.
      # * <tt>:host</tt> - Overrides the default (current) host if provided.
      # * <tt>:protocol</tt> - Overrides the default (current) protocol if provided.
      # * <tt>:user</tt> - Inline HTTP authentication (only plucked out if <tt>:password</tt> is also present).
      # * <tt>:password</tt> - Inline HTTP authentication (only plucked out if <tt>:user</tt> is also present).
      # * <tt>:escape</tt> - Determines whether the returned URL will be HTML escaped or not (<tt>true</tt> by default).
      #
      # ==== Relying on named routes
      #
      # If you instead of a hash pass a record (like an Active Record or Active Resource) as the options parameter,
      # you'll trigger the named route for that record. The lookup will happen on the name of the class. So passing
      # a Workshop object will attempt to use the workshop_path route. If you have a nested route, such as
      # admin_workshop_path you'll have to call that explicitly (it's impossible for url_for to guess that route).
      #
      # ==== Examples
      #   <%= url_for(:action => 'index') %>
      #   # => /blog/
      #
      #   <%= url_for(:action => 'find', :controller => 'books') %>
      #   # => /books/find
      #
      #   <%= url_for(:action => 'login', :controller => 'members', :only_path => false, :protocol => 'https') %>
      #   # => https://www.railsapplication.com/members/login/
      #
      #   <%= url_for(:action => 'play', :anchor => 'player') %>
      #   # => /messages/play/#player
      #
      #   <%= url_for(:action => 'checkout', :anchor => 'tax&ship') %>
      #   # => /testing/jump/#tax&amp;ship
      #
      #   <%= url_for(:action => 'checkout', :anchor => 'tax&ship', :escape => false) %>
      #   # => /testing/jump/#tax&ship
      #
      #   <%= url_for(Workshop.new) %>
      #   # relies on Workshop answering a new_record? call (and in this case returning true)
      #   # => /workshops
      #
      #   <%= url_for(@workshop) %>
      #   # calls @workshop.to_s
      #   # => /workshops/5
      #
      #   <%= url_for("http://www.example.com") %>
      #   # => http://www.example.com
      #
      #   <%= url_for(:back) %>
      #   # if request.env["HTTP_REFERER"] is set to "http://www.example.com"
      #   # => http://www.example.com
      #
      #   <%= url_for(:back) %>
      #   # if request.env["HTTP_REFERER"] is not set or is blank
      #   # => javascript:history.back()
      def url_for(options = {})
        options ||= {}
        url = case options
        when String
          escape = true
          options
        when Hash
          options = { :only_path => options[:host].nil? }.update(options.symbolize_keys)
          escape  = options.key?(:escape) ? options.delete(:escape) : true
          @controller.send(:url_for, options)
        when :back
          escape = false
          @controller.request.env["HTTP_REFERER"] || 'javascript:history.back()'
        else
          escape = false
          polymorphic_path(options)
        end

        escape ? escape_once(url) : url
      end

      # Creates a link tag of the given +name+ using a URL created by the set
      # of +options+. See the valid options in the documentation for
      # url_for. It's also possible to pass a string instead
      # of an options hash to get a link tag that uses the value of the string as the
      # href for the link, or use <tt>:back</tt> to link to the referrer - a JavaScript back
      # link will be used in place of a referrer if none exists. If nil is passed as
      # a name, the link itself will become the name.
      #
      # ==== Signatures
      #
      #   link_to(name, options = {}, html_options = nil)
      #   link_to(options = {}, html_options = nil) do
      #     # name
      #   end
      #
      # ==== Options
      # * <tt>:confirm => 'question?'</tt> - This will add a JavaScript confirm
      #   prompt with the question specified. If the user accepts, the link is
      #   processed normally, otherwise no action is taken.
      # * <tt>:popup => true || array of window options</tt> - This will force the
      #   link to open in a popup window. By passing true, a default browser window
      #   will be opened with the URL. You can also specify an array of options
      #   that are passed-thru to JavaScripts window.open method.
      # * <tt>:method => symbol of HTTP verb</tt> - This modifier will dynamically
      #   create an HTML form and immediately submit the form for processing using
      #   the HTTP verb specified. Useful for having links perform a POST operation
      #   in dangerous actions like deleting a record (which search bots can follow
      #   while spidering your site). Supported verbs are <tt>:post</tt>, <tt>:delete</tt> and <tt>:put</tt>.
      #   Note that if the user has JavaScript disabled, the request will fall back
      #   to using GET. If you are relying on the POST behavior, you should check
      #   for it in your controller's action by using the request object's methods
      #   for <tt>post?</tt>, <tt>delete?</tt> or <tt>put?</tt>.
      # * The +html_options+ will accept a hash of html attributes for the link tag.
      #
      # Note that if the user has JavaScript disabled, the request will fall back
      # to using GET. If <tt>:href => '#'</tt> is used and the user has JavaScript disabled
      # clicking the link will have no effect. If you are relying on the POST
      # behavior, your should check for it in your controller's action by using the
      # request object's methods for <tt>post?</tt>, <tt>delete?</tt> or <tt>put?</tt>.
      #
      # You can mix and match the +html_options+ with the exception of
      # <tt>:popup</tt> and <tt>:method</tt> which will raise an ActionView::ActionViewError
      # exception.
      #
      # ==== Examples
      # Because it relies on +url_for+, +link_to+ supports both older-style controller/action/id arguments
      # and newer RESTful routes.  Current Rails style favors RESTful routes whenever possible, so base
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
      #   link_to "Profile", :controller => "profiles", :action => "show", :id => @profile
      #   # => <a href="/profiles/show/1">Profile</a>
      #
      # Similarly,
      #
      #   link_to "Profiles", profiles_path
      #   # => <a href="/profiles">Profiles</a>
      #
      # is better than
      #
      #   link_to "Profiles", :controller => "profiles"
      #   # => <a href="/profiles">Profiles</a>
      #
      # You can use a block as well if your link target is hard to fit into the name parameter. ERb example:
      #
      #   <% link_to(@profile) do %>
      #     <strong><%= @profile.name %></strong> -- <span>Check it out!!</span>
      #   <% end %>
      #   # => <a href="/profiles/1"><strong>David</strong> -- <span>Check it out!!</span></a>
      #
      # Classes and ids for CSS are easy to produce:
      #
      #   link_to "Articles", articles_path, :id => "news", :class => "article"
      #   # => <a href="/articles" class="article" id="news">Articles</a>
      #
      # Be careful when using the older argument style, as an extra literal hash is needed:
      #
      #   link_to "Articles", { :controller => "articles" }, :id => "news", :class => "article"
      #   # => <a href="/articles" class="article" id="news">Articles</a>
      #
      # Leaving the hash off gives the wrong link:
      #
      #   link_to "WRONG!", :controller => "articles", :id => "news", :class => "article"
      #   # => <a href="/articles/index/news?class=article">WRONG!</a>
      #
      # +link_to+ can also produce links with anchors or query strings:
      #
      #   link_to "Comment wall", profile_path(@profile, :anchor => "wall")
      #   # => <a href="/profiles/1#wall">Comment wall</a>
      #
      #   link_to "Ruby on Rails search", :controller => "searches", :query => "ruby on rails"
      #   # => <a href="/searches?query=ruby+on+rails">Ruby on Rails search</a>
      #
      #   link_to "Nonsense search", searches_path(:foo => "bar", :baz => "quux")
      #   # => <a href="/searches?foo=bar&amp;baz=quux">Nonsense search</a>
      #
      # The three options specific to +link_to+ (<tt>:confirm</tt>, <tt>:popup</tt>, and <tt>:method</tt>) are used as follows:
      #
      #   link_to "Visit Other Site", "http://www.rubyonrails.org/", :confirm => "Are you sure?"
      #   # => <a href="http://www.rubyonrails.org/" onclick="return confirm('Are you sure?');">Visit Other Site</a>
      #
      #   link_to "Help", { :action => "help" }, :popup => true
      #   # => <a href="/testing/help/" onclick="window.open(this.href);return false;">Help</a>
      #
      #   link_to "View Image", @image, :popup => ['new_window_name', 'height=300,width=600']
      #   # => <a href="/images/9" onclick="window.open(this.href,'new_window_name','height=300,width=600');return false;">View Image</a>
      #
      #   link_to "Delete Image", @image, :confirm => "Are you sure?", :method => :delete
      #   # => <a href="/images/9" onclick="if (confirm('Are you sure?')) { var f = document.createElement('form');
      #        f.style.display = 'none'; this.parentNode.appendChild(f); f.method = 'POST'; f.action = this.href;
      #        var m = document.createElement('input'); m.setAttribute('type', 'hidden'); m.setAttribute('name', '_method');
      #        m.setAttribute('value', 'delete'); f.appendChild(m);f.submit(); };return false;">Delete Image</a>
      def link_to(*args, &block)
        if block_given?
          options      = args.first || {}
          html_options = args.second
          concat(link_to(capture(&block), options, html_options).html_safe!)
        else
          name         = args.first
          options      = args.second || {}
          html_options = args.third

          url = url_for(options)

          if html_options
            html_options = html_options.stringify_keys
            href = html_options['href']
            convert_options_to_javascript!(html_options, url)
            tag_options = tag_options(html_options)
          else
            tag_options = nil
          end

          href_attr = "href=\"#{url}\"" unless href
          "<a #{href_attr}#{tag_options}>#{name || url}</a>".html_safe!
        end
      end

      # Generates a form containing a single button that submits to the URL created
      # by the set of +options+. This is the safest method to ensure links that
      # cause changes to your data are not triggered by search bots or accelerators.
      # If the HTML button does not work with your layout, you can also consider
      # using the link_to method with the <tt>:method</tt> modifier as described in
      # the link_to documentation.
      #
      # The generated FORM element has a class name of <tt>button-to</tt>
      # to allow styling of the form itself and its children. You can control
      # the form submission and input element behavior using +html_options+.
      # This method accepts the <tt>:method</tt> and <tt>:confirm</tt> modifiers
      # described in the link_to documentation. If no <tt>:method</tt> modifier
      # is given, it will default to performing a POST operation. You can also
      # disable the button by passing <tt>:disabled => true</tt> in +html_options+.
      # If you are using RESTful routes, you can pass the <tt>:method</tt>
      # to change the HTTP verb used to submit the form.
      #
      # ==== Options
      # The +options+ hash accepts the same options at url_for.
      #
      # There are a few special +html_options+:
      # * <tt>:method</tt> - Specifies the anchor name to be appended to the path.
      # * <tt>:disabled</tt> - Specifies the anchor name to be appended to the path.
      # * <tt>:confirm</tt> - This will add a JavaScript confirm
      #   prompt with the question specified. If the user accepts, the link is
      #   processed normally, otherwise no action is taken.
      #
      # ==== Examples
      #   <%= button_to "New", :action => "new" %>
      #   # => "<form method="post" action="/controller/new" class="button-to">
      #   #      <div><input value="New" type="submit" /></div>
      #   #    </form>"
      #
      #   button_to "Delete Image", { :action => "delete", :id => @image.id },
      #             :confirm => "Are you sure?", :method => :delete
      #   # => "<form method="post" action="/images/delete/1" class="button-to">
      #   #      <div>
      #   #        <input type="hidden" name="_method" value="delete" />
      #   #        <input onclick="return confirm('Are you sure?');"
      #   #              value="Delete" type="submit" />
      #   #      </div>
      #   #    </form>"
      def button_to(name, options = {}, html_options = {})
        html_options = html_options.stringify_keys
        convert_boolean_attributes!(html_options, %w( disabled ))

        method_tag = ''
        if (method = html_options.delete('method')) && %w{put delete}.include?(method.to_s)
          method_tag = tag('input', :type => 'hidden', :name => '_method', :value => method.to_s)
        end

        form_method = method.to_s == 'get' ? 'get' : 'post'

        request_token_tag = ''
        if form_method == 'post' && protect_against_forgery?
          request_token_tag = tag(:input, :type => "hidden", :name => request_forgery_protection_token.to_s, :value => form_authenticity_token)
        end

        if confirm = html_options.delete("confirm")
          html_options["onclick"] = "return #{confirm_javascript_function(confirm)};"
        end

        url = options.is_a?(String) ? options : self.url_for(options)
        name ||= url

        html_options.merge!("type" => "submit", "value" => name)

        "<form method=\"#{form_method}\" action=\"#{escape_once url}\" class=\"button-to\"><div>" +
          method_tag + tag("input", html_options) + request_token_tag + "</div></form>".html_safe!
      end


      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ unless the current request URI is the same as the links, in
      # which case only the name is returned (or the given block is yielded, if
      # one exists).  You can give link_to_unless_current a block which will
      # specialize the default behavior (e.g., show a "Start Here" link rather
      # than the link's text).
      #
      # ==== Examples
      # Let's say you have a navigation menu...
      #
      #   <ul id="navbar">
      #     <li><%= link_to_unless_current("Home", { :action => "index" }) %></li>
      #     <li><%= link_to_unless_current("About Us", { :action => "about" }) %></li>
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
      # The implicit block given to link_to_unless_current is evaluated if the current
      # action is the action given.  So, if we had a comments page and wanted to render a
      # "Go Back" link instead of a link to the comments page, we could do something like this...
      #
      #    <%=
      #        link_to_unless_current("Comment", { :controller => 'comments', :action => 'new}) do
      #           link_to("Go back", { :controller => 'posts', :action => 'index' })
      #        end
      #     %>
      def link_to_unless_current(name, options = {}, html_options = {}, &block)
        link_to_unless current_page?(options), name, options, html_options, &block
      end

      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ unless +condition+ is true, in which case only the name is
      # returned. To specialize the default behavior (i.e., show a login link rather
      # than just the plaintext link text), you can pass a block that
      # accepts the name or the full argument list for link_to_unless.
      #
      # ==== Examples
      #   <%= link_to_unless(@current_user.nil?, "Reply", { :action => "reply" }) %>
      #   # If the user is logged in...
      #   # => <a href="/controller/reply/">Reply</a>
      #
      #   <%=
      #      link_to_unless(@current_user.nil?, "Reply", { :action => "reply" }) do |name|
      #        link_to(name, { :controller => "accounts", :action => "signup" })
      #      end
      #   %>
      #   # If the user is logged in...
      #   # => <a href="/controller/reply/">Reply</a>
      #   # If not...
      #   # => <a href="/accounts/signup">Reply</a>
      def link_to_unless(condition, name, options = {}, html_options = {}, &block)
        if condition
          if block_given?
            block.arity <= 1 ? yield(name) : yield(name, options, html_options)
          else
            name
          end
        else
          link_to(name, options, html_options)
        end
      end

      # Creates a link tag of the given +name+ using a URL created by the set of
      # +options+ if +condition+ is true, in which case only the name is
      # returned. To specialize the default behavior, you can pass a block that
      # accepts the name or the full argument list for link_to_unless (see the examples
      # in link_to_unless).
      #
      # ==== Examples
      #   <%= link_to_if(@current_user.nil?, "Login", { :controller => "sessions", :action => "new" }) %>
      #   # If the user isn't logged in...
      #   # => <a href="/sessions/new/">Login</a>
      #
      #   <%=
      #      link_to_if(@current_user.nil?, "Login", { :controller => "sessions", :action => "new" }) do
      #        link_to(@current_user.login, { :controller => "accounts", :action => "show", :id => @current_user })
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
      # mail_to has several methods for hindering email harvesters and customizing
      # the email itself by passing special keys to +html_options+.
      #
      # ==== Options
      # * <tt>:encode</tt>  - This key will accept the strings "javascript" or "hex".
      #   Passing "javascript" will dynamically create and encode the mailto: link then
      #   eval it into the DOM of the page. This method will not show the link on
      #   the page if the user has JavaScript disabled. Passing "hex" will hex
      #   encode the +email_address+ before outputting the mailto: link.
      # * <tt>:replace_at</tt>  - When the link +name+ isn't provided, the
      #   +email_address+ is used for the link label. You can use this option to
      #   obfuscate the +email_address+ by substituting the @ sign with the string
      #   given as the value.
      # * <tt>:replace_dot</tt>  - When the link +name+ isn't provided, the
      #   +email_address+ is used for the link label. You can use this option to
      #   obfuscate the +email_address+ by substituting the . in the email with the
      #   string given as the value.
      # * <tt>:subject</tt>  - Preset the subject line of the email.
      # * <tt>:body</tt> - Preset the body of the email.
      # * <tt>:cc</tt>  - Carbon Copy addition recipients on the email.
      # * <tt>:bcc</tt>  - Blind Carbon Copy additional recipients on the email.
      #
      # ==== Examples
      #   mail_to "me@domain.com"
      #   # => <a href="mailto:me@domain.com">me@domain.com</a>
      #
      #   mail_to "me@domain.com", "My email", :encode => "javascript"
      #   # => <script type="text/javascript">eval(decodeURIComponent('%64%6f%63...%27%29%3b'))</script>
      #
      #   mail_to "me@domain.com", "My email", :encode => "hex"
      #   # => <a href="mailto:%6d%65@%64%6f%6d%61%69%6e.%63%6f%6d">My email</a>
      #
      #   mail_to "me@domain.com", nil, :replace_at => "_at_", :replace_dot => "_dot_", :class => "email"
      #   # => <a href="mailto:me@domain.com" class="email">me_at_domain_dot_com</a>
      #
      #   mail_to "me@domain.com", "My email", :cc => "ccaddress@domain.com",
      #            :subject => "This is an example email"
      #   # => <a href="mailto:me@domain.com?cc=ccaddress@domain.com&subject=This%20is%20an%20example%20email">My email</a>
      def mail_to(email_address, name = nil, html_options = {})
        html_options = html_options.stringify_keys
        encode = html_options.delete("encode").to_s
        cc, bcc, subject, body = html_options.delete("cc"), html_options.delete("bcc"), html_options.delete("subject"), html_options.delete("body")

        string = ''
        extras = ''
        extras << "cc=#{CGI.escape(cc).gsub("+", "%20")}&" unless cc.nil?
        extras << "bcc=#{CGI.escape(bcc).gsub("+", "%20")}&" unless bcc.nil?
        extras << "body=#{CGI.escape(body).gsub("+", "%20")}&" unless body.nil?
        extras << "subject=#{CGI.escape(subject).gsub("+", "%20")}&" unless subject.nil?
        extras = "?" << extras.gsub!(/&?$/,"") unless extras.empty?

        email_address = email_address.to_s

        email_address_obfuscated = email_address.dup
        email_address_obfuscated.gsub!(/@/, html_options.delete("replace_at")) if html_options.has_key?("replace_at")
        email_address_obfuscated.gsub!(/\./, html_options.delete("replace_dot")) if html_options.has_key?("replace_dot")

        if encode == "javascript"
          "document.write('#{content_tag("a", name || email_address_obfuscated, html_options.merge({ "href" => "mailto:"+email_address+extras }))}');".each_byte do |c|
            string << sprintf("%%%x", c)
          end
          "<script type=\"#{Mime::JS}\">eval(decodeURIComponent('#{string}'))</script>"
        elsif encode == "hex"
          email_address_encoded = ''
          email_address_obfuscated.each_byte do |c|
            email_address_encoded << sprintf("&#%d;", c)
          end

          protocol = 'mailto:'
          protocol.each_byte { |c| string << sprintf("&#%d;", c) }

          email_address.each_byte do |c|
            char = c.chr
            string << (char =~ /\w/ ? sprintf("%%%x", c) : char)
          end
          content_tag "a", name || email_address_encoded, html_options.merge({ "href" => "#{string}#{extras}" })
        else
          content_tag "a", name || email_address_obfuscated, html_options.merge({ "href" => "mailto:#{email_address}#{extras}" })
        end
      end

      # True if the current request URI was generated by the given +options+.
      #
      # ==== Examples
      # Let's say we're in the <tt>/shop/checkout?order=desc</tt> action.
      #
      #   current_page?(:action => 'process')
      #   # => false
      #
      #   current_page?(:controller => 'shop', :action => 'checkout')
      #   # => true
      #
      #   current_page?(:controller => 'shop', :action => 'checkout', :order => 'asc')
      #   # => false
      #
      #   current_page?(:action => 'checkout')
      #   # => true
      #
      #   current_page?(:controller => 'library', :action => 'checkout')
      #   # => false
      #
      # Let's say we're in the <tt>/shop/checkout?order=desc&page=1</tt> action.
      #
      #   current_page?(:action => 'process')
      #   # => false
      #
      #   current_page?(:controller => 'shop', :action => 'checkout')
      #   # => true
      #
      #   current_page?(:controller => 'shop', :action => 'checkout', :order => 'desc', :page=>'1')
      #   # => true
      #
      #   current_page?(:controller => 'shop', :action => 'checkout', :order => 'desc', :page=>'2')
      #   # => false
      #
      #   current_page?(:controller => 'shop', :action => 'checkout', :order => 'desc')
      #   # => false
      #
      #   current_page?(:action => 'checkout')
      #   # => true
      #
      #   current_page?(:controller => 'library', :action => 'checkout')
      #   # => false
      def current_page?(options)
        url_string = CGI.unescapeHTML(url_for(options))
        request = @controller.request
        # We ignore any extra parameters in the request_uri if the 
        # submitted url doesn't have any either.  This lets the function
        # work with things like ?order=asc 
        if url_string.index("?")
          request_uri = request.request_uri
        else
          request_uri = request.request_uri.split('?').first
        end
        if url_string =~ /^\w+:\/\//
          url_string == "#{request.protocol}#{request.host_with_port}#{request_uri}"
        else
          url_string == request_uri
        end
      end

      private
        def convert_options_to_javascript!(html_options, url = '')
          confirm, popup = html_options.delete("confirm"), html_options.delete("popup")

          method, href = html_options.delete("method"), html_options['href']

          html_options["onclick"] = case
            when popup && method
              raise ActionView::ActionViewError, "You can't use :popup and :method in the same link"
            when confirm && popup
              "if (#{confirm_javascript_function(confirm)}) { #{popup_javascript_function(popup)} };return false;"
            when confirm && method
              "if (#{confirm_javascript_function(confirm)}) { #{method_javascript_function(method, url, href)} };return false;"
            when confirm
              "return #{confirm_javascript_function(confirm)};"
            when method
              "#{method_javascript_function(method, url, href)}return false;"
            when popup
              "#{popup_javascript_function(popup)}return false;"
            else
              html_options["onclick"]
          end
        end

        def confirm_javascript_function(confirm)
          "confirm('#{escape_javascript(confirm)}')"
        end

        def popup_javascript_function(popup)
          popup.is_a?(Array) ? "window.open(this.href,'#{popup.first}','#{popup.last}');" : "window.open(this.href);"
        end

        def method_javascript_function(method, url = '', href = nil)
          action = (href && url.size > 0) ? "'#{url}'" : 'this.href'
          submit_function =
            "var f = document.createElement('form'); f.style.display = 'none'; " +
            "this.parentNode.appendChild(f); f.method = 'POST'; f.action = #{action};"

          unless method == :post
            submit_function << "var m = document.createElement('input'); m.setAttribute('type', 'hidden'); "
            submit_function << "m.setAttribute('name', '_method'); m.setAttribute('value', '#{method}'); f.appendChild(m);"
          end

          if protect_against_forgery?
            submit_function << "var s = document.createElement('input'); s.setAttribute('type', 'hidden'); "
            submit_function << "s.setAttribute('name', '#{request_forgery_protection_token}'); s.setAttribute('value', '#{escape_javascript form_authenticity_token}'); f.appendChild(s);"
          end
          submit_function << "f.submit();"
        end

        # Processes the _html_options_ hash, converting the boolean
        # attributes from true/false form into the form required by
        # HTML/XHTML.  (An attribute is considered to be boolean if
        # its name is listed in the given _bool_attrs_ array.)
        #
        # More specifically, for each boolean attribute in _html_options_
        # given as:
        #
        #     "attr" => bool_value
        #
        # if the associated _bool_value_ evaluates to true, it is
        # replaced with the attribute's name; otherwise the attribute is
        # removed from the _html_options_ hash.  (See the XHTML 1.0 spec,
        # section 4.5 "Attribute Minimization" for more:
        # http://www.w3.org/TR/xhtml1/#h-4.5)
        #
        # Returns the updated _html_options_ hash, which is also modified
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
    end
  end
end
