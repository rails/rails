require 'cgi'
require 'action_view/helpers/url_helper'
require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers #:nodoc:
    # This module provides methods for generating HTML that links views to assets such
    # as images, javascripts, stylesheets, and feeds. These methods do not verify 
    # the assets exist before linking to them. 
    #
    # === Using asset hosts
    # By default, Rails links to these assets on the current host in the public
    # folder, but you can direct Rails to link to assets from a dedicated assets server by 
    # setting ActionController::Base.asset_host in your <tt>config/environment.rb</tt>.  For example,
    # let's say your asset host is <tt>assets.example.com</tt>.
    #
    #   ActionController::Base.asset_host = "assets.example.com"
    #   image_tag("rails.png")
    #     => <img src="http://assets.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_link_tag("application")
    #     => <link href="http://assets.example.com/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />
    #
    # This is useful since browsers typically open at most two connections to a single host,
    # which means your assets often wait in single file for their turn to load.  You can
    # alleviate this by using a <tt>%d</tt> wildcard in <tt>asset_host</tt> (for example, "assets%d.example.com") 
    # to automatically distribute asset requests among four hosts (e.g., "assets0.example.com" through "assets3.example.com")
    # so browsers will open eight connections rather than two.  
    #
    #   image_tag("rails.png")
    #     => <img src="http://assets0.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_link_tag("application")
    #     => <link href="http://assets3.example.com/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />
    #
    # To do this, you can either setup 4 actual hosts, or you can use wildcard DNS to CNAME 
    # the wildcard to a single asset host.  You can read more about setting up your DNS CNAME records from
    # your ISP.
    #
    # Note: This is purely a browser performance optimization and is not meant
    # for server load balancing. See http://www.die.net/musings/page_load_time/
    # for background.
    #
    # Alternatively, you can exert more control over the asset host by setting <tt>asset_host</tt> to a proc
    # that takes a single source argument. This is useful if you are unable to setup 4 actual hosts or have
    # fewer/more than 4 hosts. The example proc below generates http://assets1.example.com and
    # http://assets2.example.com randomly.
    #
    #   ActionController::Base.asset_host = Proc.new { |source| "http://assets#{rand(2) + 1}.example.com" }
    #   image_tag("rails.png")
    #     => <img src="http://assets2.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_link_tag("application")
    #     => <link href="http://assets1.example.com/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />
    #
    # The proc takes a <tt>source</tt> parameter (which is the path of the source asset) and an optional
    # <tt>request</tt> parameter (which is an entire instance of an <tt>ActionController::AbstractRequest</tt>
    # subclass). This can be used to generate a particular asset host depending on the asset path and the particular
    # request.
    #
    #    ActionController::Base.asset_host = Proc.new { |source|
    #      if source.starts_with?('/images')
    #        "http://images.example.com"
    #      else
    #        "http://assets.example.com"
    #      end
    #    }
    #   image_tag("rails.png")
    #     => <img src="http://images.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_link_tag("application")
    #     => <link href="http://assets.example.com/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />
    #
    # The optional <tt>request</tt> parameter to the proc is useful in particular for serving assets from an
    # SSL-protected page. The example proc below disables asset hosting for HTTPS connections, while still sending
    # assets for plain HTTP requests from asset hosts. This is useful for avoiding mixed media warnings when serving
    # non-HTTP assets from HTTPS web pages when you don't have an SSL certificate for each of the asset hosts.
    #
    #   ActionController::Base.asset_host = Proc.new { |source, request|
    #     if request.ssl?
    #       "#{request.protocol}#{request.host_with_port}"
    #     else
    #       "#{request.protocol}assets.example.com"
    #     end
    #   }
    #
    # === Using asset timestamps
    #
    # By default, Rails will append all asset paths with that asset's timestamp. This allows you to set a cache-expiration date for the
    # asset far into the future, but still be able to instantly invalidate it by simply updating the file (and hence updating the timestamp,
    # which then updates the URL as the timestamp is part of that, which in turn busts the cache).
    #
    # It's the responsibility of the web server you use to set the far-future expiration date on cache assets that you need to take 
    # advantage of this feature. Here's an example for Apache:
    #
    # # Asset Expiration
    # ExpiresActive On
    # <FilesMatch "\.(ico|gif|jpe?g|png|js|css)$">
    #   ExpiresDefault "access plus 1 year"
    # </FilesMatch>
    #
    # Also note that in order for this to work, all your application servers must return the same timestamps. This means that they must 
    # have their clocks synchronized. If one of them drift out of sync, you'll see different timestamps at random and the cache won't
    # work. Which means that the browser will request the same assets over and over again even thought they didn't change. You can use
    # something like Live HTTP Headers for Firefox to verify that the cache is indeed working (and that the assets are not being 
    # requested over and over).
    module AssetTagHelper
      ASSETS_DIR      = defined?(Rails.public_path) ? Rails.public_path : "public"
      JAVASCRIPTS_DIR = "#{ASSETS_DIR}/javascripts"
      STYLESHEETS_DIR = "#{ASSETS_DIR}/stylesheets"
      
      # Returns a link tag that browsers and news readers can use to auto-detect
      # an RSS or ATOM feed. The +type+ can either be <tt>:rss</tt> (default) or
      # <tt>:atom</tt>. Control the link options in url_for format using the
      # +url_options+. You can modify the LINK tag itself in +tag_options+.
      #
      # ==== Options:
      # * <tt>:rel</tt>  - Specify the relation of this link, defaults to "alternate"
      # * <tt>:type</tt>  - Override the auto-generated mime type
      # * <tt>:title</tt>  - Specify the title of the link, defaults to the +type+
      #
      # ==== Examples
      #  auto_discovery_link_tag # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/action" />
      #  auto_discovery_link_tag(:atom) # =>
      #     <link rel="alternate" type="application/atom+xml" title="ATOM" href="http://www.currenthost.com/controller/action" />
      #  auto_discovery_link_tag(:rss, {:action => "feed"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/feed" />
      #  auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="My RSS" href="http://www.currenthost.com/controller/feed" />
      #  auto_discovery_link_tag(:rss, {:controller => "news", :action => "feed"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/news/feed" />
      #  auto_discovery_link_tag(:rss, "http://www.example.com/feed.rss", {:title => "Example RSS"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="Example RSS" href="http://www.example.com/feed" />
      def auto_discovery_link_tag(type = :rss, url_options = {}, tag_options = {})
        tag(
          "link",
          "rel"   => tag_options[:rel] || "alternate",
          "type"  => tag_options[:type] || Mime::Type.lookup_by_extension(type.to_s).to_s,
          "title" => tag_options[:title] || type.to_s.upcase,
          "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(:only_path => false)) : url_options
        )
      end

      # Computes the path to a javascript asset in the public javascripts directory.
      # If the +source+ filename has no extension, .js will be appended.
      # Full paths from the document root will be passed through.
      # Used internally by javascript_include_tag to build the script path.
      #
      # ==== Examples
      #   javascript_path "xmlhr" # => /javascripts/xmlhr.js
      #   javascript_path "dir/xmlhr.js" # => /javascripts/dir/xmlhr.js
      #   javascript_path "/dir/xmlhr" # => /dir/xmlhr.js
      #   javascript_path "http://www.railsapplication.com/js/xmlhr" # => http://www.railsapplication.com/js/xmlhr.js
      #   javascript_path "http://www.railsapplication.com/js/xmlhr.js" # => http://www.railsapplication.com/js/xmlhr.js
      def javascript_path(source)
        compute_public_path(source, 'javascripts', 'js')
      end
      alias_method :path_to_javascript, :javascript_path # aliased to avoid conflicts with a javascript_path named route

      JAVASCRIPT_DEFAULT_SOURCES = ['prototype', 'effects', 'dragdrop', 'controls'] unless const_defined?(:JAVASCRIPT_DEFAULT_SOURCES)
      @@javascript_expansions = { :defaults => JAVASCRIPT_DEFAULT_SOURCES.dup }
      @@stylesheet_expansions = {}

      # Returns an html script tag for each of the +sources+ provided. You
      # can pass in the filename (.js extension is optional) of javascript files
      # that exist in your public/javascripts directory for inclusion into the
      # current page or you can pass the full path relative to your document
      # root. To include the Prototype and Scriptaculous javascript libraries in
      # your application, pass <tt>:defaults</tt> as the source. When using
      # <tt>:defaults</tt>, if an application.js file exists in your public
      # javascripts directory, it will be included as well. You can modify the
      # html attributes of the script tag by passing a hash as the last argument.
      #
      # ==== Examples
      #   javascript_include_tag "xmlhr" # =>
      #     <script type="text/javascript" src="/javascripts/xmlhr.js"></script>
      #
      #   javascript_include_tag "xmlhr.js" # =>
      #     <script type="text/javascript" src="/javascripts/xmlhr.js"></script>
      #
      #   javascript_include_tag "common.javascript", "/elsewhere/cools" # =>
      #     <script type="text/javascript" src="/javascripts/common.javascript"></script>
      #     <script type="text/javascript" src="/elsewhere/cools.js"></script>
      #
      #   javascript_include_tag "http://www.railsapplication.com/xmlhr" # =>
      #     <script type="text/javascript" src="http://www.railsapplication.com/xmlhr.js"></script>
      #
      #   javascript_include_tag "http://www.railsapplication.com/xmlhr.js" # =>
      #     <script type="text/javascript" src="http://www.railsapplication.com/xmlhr.js"></script>
      #
      #   javascript_include_tag :defaults # =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/effects.js"></script>
      #     ...
      #     <script type="text/javascript" src="/javascripts/application.js"></script>
      #
      # * = The application.js file is only referenced if it exists
      #
      # Though it's not really recommended practice, if you need to extend the default JavaScript set for any reason 
      # (e.g., you're going to be using a certain .js file in every action), then take a look at the register_javascript_include_default method.
      #
      # You can also include all javascripts in the javascripts directory using <tt>:all</tt> as the source:
      #
      #   javascript_include_tag :all # =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/effects.js"></script>
      #     ...
      #     <script type="text/javascript" src="/javascripts/application.js"></script>
      #     <script type="text/javascript" src="/javascripts/shop.js"></script>
      #     <script type="text/javascript" src="/javascripts/checkout.js"></script>
      #
      # Note that the default javascript files will be included first. So Prototype and Scriptaculous are available to
      # all subsequently included files.
      #
      # == Caching multiple javascripts into one
      #
      # You can also cache multiple javascripts into one file, which requires less HTTP connections to download and can better be
      # compressed by gzip (leading to faster transfers). Caching will only happen if ActionController::Base.perform_caching
      # is set to <tt>true</tt> (which is the case by default for the Rails production environment, but not for the development
      # environment). 
      #
      # ==== Examples
      #   javascript_include_tag :all, :cache => true # when ActionController::Base.perform_caching is false =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/effects.js"></script>
      #     ...
      #     <script type="text/javascript" src="/javascripts/application.js"></script>
      #     <script type="text/javascript" src="/javascripts/shop.js"></script>
      #     <script type="text/javascript" src="/javascripts/checkout.js"></script>
      #
      #   javascript_include_tag :all, :cache => true # when ActionController::Base.perform_caching is true =>
      #     <script type="text/javascript" src="/javascripts/all.js"></script>
      #
      #   javascript_include_tag "prototype", "cart", "checkout", :cache => "shop" # when ActionController::Base.perform_caching is false =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/cart.js"></script>
      #     <script type="text/javascript" src="/javascripts/checkout.js"></script>
      #
      #   javascript_include_tag "prototype", "cart", "checkout", :cache => "shop" # when ActionController::Base.perform_caching is true =>
      #     <script type="text/javascript" src="/javascripts/shop.js"></script>
      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        cache   = options.delete("cache")

        if ActionController::Base.perform_caching && cache
          joined_javascript_name = (cache == true ? "all" : cache) + ".js"
          joined_javascript_path = File.join(JAVASCRIPTS_DIR, joined_javascript_name)

          write_asset_file_contents(joined_javascript_path, compute_javascript_paths(sources))
          javascript_src_tag(joined_javascript_name, options)
        else
          expand_javascript_sources(sources).collect { |source| javascript_src_tag(source, options) }.join("\n")
        end
      end

      # Register one or more javascript files to be included when <tt>symbol</tt>
      # is passed to <tt>javascript_include_tag</tt>. This method is typically intended
      # to be called from plugin initialization to register javascript files
      # that the plugin installed in <tt>public/javascripts</tt>.
      #
      #   ActionView::Helpers::AssetTagHelper.register_javascript_expansion :monkey => ["head", "body", "tail"]
      #
      #   javascript_include_tag :monkey # =>
      #     <script type="text/javascript" src="/javascripts/head.js"></script>
      #     <script type="text/javascript" src="/javascripts/body.js"></script>
      #     <script type="text/javascript" src="/javascripts/tail.js"></script>
      def self.register_javascript_expansion(expansions)
        @@javascript_expansions.merge!(expansions)
      end

      # Register one or more stylesheet files to be included when <tt>symbol</tt>
      # is passed to <tt>stylesheet_link_tag</tt>. This method is typically intended
      # to be called from plugin initialization to register stylesheet files
      # that the plugin installed in <tt>public/stylesheets</tt>.
      #
      #   ActionView::Helpers::AssetTagHelper.register_stylesheet_expansion :monkey => ["head", "body", "tail"]
      #
      #   stylesheet_link_tag :monkey # =>
      #     <link href="/stylesheets/head.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/body.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/tail.css"  media="screen" rel="stylesheet" type="text/css" />
      def self.register_stylesheet_expansion(expansions)
        @@stylesheet_expansions.merge!(expansions)
      end

      # Register one or more additional JavaScript files to be included when
      # <tt>javascript_include_tag :defaults</tt> is called. This method is
      # typically intended to be called from plugin initialization to register additional
      # .js files that the plugin installed in <tt>public/javascripts</tt>.
      def self.register_javascript_include_default(*sources)
        @@javascript_expansions[:defaults].concat(sources)
      end

      def self.reset_javascript_include_default #:nodoc:
        @@javascript_expansions[:defaults] = JAVASCRIPT_DEFAULT_SOURCES.dup
      end

      # Computes the path to a stylesheet asset in the public stylesheets directory.
      # If the +source+ filename has no extension, <tt>.css</tt> will be appended.
      # Full paths from the document root will be passed through.
      # Used internally by +stylesheet_link_tag+ to build the stylesheet path.
      #
      # ==== Examples
      #   stylesheet_path "style" # => /stylesheets/style.css
      #   stylesheet_path "dir/style.css" # => /stylesheets/dir/style.css
      #   stylesheet_path "/dir/style.css" # => /dir/style.css
      #   stylesheet_path "http://www.railsapplication.com/css/style" # => http://www.railsapplication.com/css/style.css
      #   stylesheet_path "http://www.railsapplication.com/css/style.js" # => http://www.railsapplication.com/css/style.css
      def stylesheet_path(source)
        compute_public_path(source, 'stylesheets', 'css')
      end
      alias_method :path_to_stylesheet, :stylesheet_path # aliased to avoid conflicts with a stylesheet_path named route

      # Returns a stylesheet link tag for the sources specified as arguments. If
      # you don't specify an extension, <tt>.css</tt> will be appended automatically.
      # You can modify the link attributes by passing a hash as the last argument.
      #
      # ==== Examples
      #   stylesheet_link_tag "style" # =>
      #     <link href="/stylesheets/style.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "style.css" # =>
      #     <link href="/stylesheets/style.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "http://www.railsapplication.com/style.css" # =>
      #     <link href="http://www.railsapplication.com/style.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "style", :media => "all" # =>
      #     <link href="/stylesheets/style.css" media="all" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "style", :media => "print" # =>
      #     <link href="/stylesheets/style.css" media="print" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "random.styles", "/css/stylish" # =>
      #     <link href="/stylesheets/random.styles" media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/css/stylish.css" media="screen" rel="stylesheet" type="text/css" />
      #
      # You can also include all styles in the stylesheet directory using <tt>:all</tt> as the source:
      #
      #   stylesheet_link_tag :all # =>
      #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" type="text/css" />
      #
      # == Caching multiple stylesheets into one
      #
      # You can also cache multiple stylesheets into one file, which requires less HTTP connections and can better be
      # compressed by gzip (leading to faster transfers). Caching will only happen if ActionController::Base.perform_caching
      # is set to true (which is the case by default for the Rails production environment, but not for the development
      # environment). Examples:
      #
      # ==== Examples
      #   stylesheet_link_tag :all, :cache => true # when ActionController::Base.perform_caching is false =>
      #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag :all, :cache => true # when ActionController::Base.perform_caching is true =>
      #     <link href="/stylesheets/all.css"  media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when ActionController::Base.perform_caching is false =>
      #     <link href="/stylesheets/shop.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/cart.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/checkout.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when ActionController::Base.perform_caching is true =>
      #     <link href="/stylesheets/payment.css"  media="screen" rel="stylesheet" type="text/css" />
      def stylesheet_link_tag(*sources)
        options = sources.extract_options!.stringify_keys
        cache   = options.delete("cache")

        if ActionController::Base.perform_caching && cache
          joined_stylesheet_name = (cache == true ? "all" : cache) + ".css"
          joined_stylesheet_path = File.join(STYLESHEETS_DIR, joined_stylesheet_name)

          write_asset_file_contents(joined_stylesheet_path, compute_stylesheet_paths(sources))
          stylesheet_tag(joined_stylesheet_name, options)
        else
          expand_stylesheet_sources(sources).collect { |source| stylesheet_tag(source, options) }.join("\n")
        end
      end

      # Computes the path to an image asset in the public images directory.
      # Full paths from the document root will be passed through.
      # Used internally by +image_tag+ to build the image path.
      #
      # ==== Examples
      #   image_path("edit")                                         # => /images/edit
      #   image_path("edit.png")                                     # => /images/edit.png
      #   image_path("icons/edit.png")                               # => /images/icons/edit.png
      #   image_path("/icons/edit.png")                              # => /icons/edit.png
      #   image_path("http://www.railsapplication.com/img/edit.png") # => http://www.railsapplication.com/img/edit.png
      def image_path(source)
        compute_public_path(source, 'images')
      end
      alias_method :path_to_image, :image_path # aliased to avoid conflicts with an image_path named route

      # Returns an html image tag for the +source+. The +source+ can be a full
      # path or a file that exists in your public images directory.
      #
      # ==== Options
      # You can add HTML attributes using the +options+. The +options+ supports
      # three additional keys for convenience and conformance:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the
      #   +source+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "{Width}x{Height}", so "30x45" becomes
      #   width="30" and height="45". <tt>:size</tt> will be ignored if the
      #   value is not in the correct format.
      # * <tt>:mouseover</tt> - Set an alternate image to be used when the onmouseover
      #   event is fired, and sets the original image to be replaced onmouseout.
      #   This can be used to implement an easy image toggle that fires on onmouseover.
      #
      # ==== Examples
      #  image_tag("icon")  # =>
      #    <img src="/images/icon" alt="Icon" />
      #  image_tag("icon.png")  # =>
      #    <img src="/images/icon.png" alt="Icon" />
      #  image_tag("icon.png", :size => "16x10", :alt => "Edit Entry")  # =>
      #    <img src="/images/icon.png" width="16" height="10" alt="Edit Entry" />
      #  image_tag("/icons/icon.gif", :size => "16x16")  # =>
      #    <img src="/icons/icon.gif" width="16" height="16" alt="Icon" />
      #  image_tag("/icons/icon.gif", :height => '32', :width => '32') # =>
      #    <img alt="Icon" height="32" src="/icons/icon.gif" width="32" />
      #  image_tag("/icons/icon.gif", :class => "menu_icon") # =>
      #    <img alt="Icon" class="menu_icon" src="/icons/icon.gif" />
      #  image_tag("mouse.png", :mouseover => "/images/mouse_over.png") # => 
      #    <img src="/images/mouse.png" onmouseover="this.src='/images/mouse_over.png'" onmouseout="this.src='/images/mouse.png'" alt="Mouse" />
      #  image_tag("mouse.png", :mouseover => image_path("mouse_over.png")) # => 
      #    <img src="/images/mouse.png" onmouseover="this.src='/images/mouse_over.png'" onmouseout="this.src='/images/mouse.png'" alt="Mouse" />
      def image_tag(source, options = {})
        options.symbolize_keys!

        options[:src] = path_to_image(source)
        options[:alt] ||= File.basename(options[:src], '.*').split('.').first.to_s.capitalize

        if size = options.delete(:size)
          options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
        end

        if mouseover = options.delete(:mouseover)
          options[:onmouseover]	= "this.src='#{image_path(mouseover)}'"
          options[:onmouseout]	= "this.src='#{image_path(options[:src])}'"
        end

        tag("img", options)
      end

      private
        def file_exist?(path)
          @@file_exist_cache ||= {}
          if !(@@file_exist_cache[path] ||= File.exist?(path))
            @@file_exist_cache[path] = true
            false
          else
            true
          end
        end

        # Add the the extension +ext+ if not present. Return full URLs otherwise untouched.
        # Prefix with <tt>/dir/</tt> if lacking a leading +/+. Account for relative URL
        # roots. Rewrite the asset path for cache-busting asset ids. Include
        # asset host, if configured, with the correct request protocol.
        def compute_public_path(source, dir, ext = nil, include_host = true)
          has_request = @controller.respond_to?(:request)

          cache_key =
            if has_request
              [ @controller.request.protocol,
                ActionController::Base.asset_host.to_s,
                @controller.request.relative_url_root,
                dir, source, ext, include_host ].join
            else
              [ ActionController::Base.asset_host.to_s,
                dir, source, ext, include_host ].join
            end

          ActionView::Base.computed_public_paths[cache_key] ||=
            begin
              source += ".#{ext}" if ext && File.extname(source).blank? || File.exist?(File.join(ASSETS_DIR, dir, "#{source}.#{ext}"))

              if source =~ %r{^[-a-z]+://}
                source
              else
                source = "/#{dir}/#{source}" unless source[0] == ?/
                if has_request
                  unless source =~ %r{^#{@controller.request.relative_url_root}/}
                    source = "#{@controller.request.relative_url_root}#{source}"
                  end
                end
                source = rewrite_asset_path(source)

                if include_host
                  host = compute_asset_host(source)

                  if has_request && !host.blank? && host !~ %r{^[-a-z]+://}
                    host = "#{@controller.request.protocol}#{host}"
                  end

                  "#{host}#{source}"
                else
                  source
                end
              end
            end
        end

        # Pick an asset host for this source. Returns +nil+ if no host is set,
        # the host if no wildcard is set, the host interpolated with the
        # numbers 0-3 if it contains <tt>%d</tt> (the number is the source hash mod 4),
        # or the value returned from invoking the proc if it's a proc.
        def compute_asset_host(source)
          if host = ActionController::Base.asset_host
            if host.is_a?(Proc)
              case host.arity
              when 2
                host.call(source, @controller.request)
              else
                host.call(source)
              end
            else
              (host =~ /%d/) ? host % (source.hash % 4) : host
            end
          end
        end

        # Use the RAILS_ASSET_ID environment variable or the source's
        # modification time as its cache-busting asset id.
        def rails_asset_id(source)
          if asset_id = ENV["RAILS_ASSET_ID"]
            asset_id
          else
            path = File.join(ASSETS_DIR, source)

            if File.exist?(path)
              File.mtime(path).to_i.to_s
            else
              ''
            end
          end
        end

        # Break out the asset path rewrite in case plugins wish to put the asset id
        # someplace other than the query string.
        def rewrite_asset_path(source)
          asset_id = rails_asset_id(source)
          if asset_id.blank?
            source
          else
            source + "?#{asset_id}"
          end
        end

        def javascript_src_tag(source, options)
          content_tag("script", "", { "type" => Mime::JS, "src" => path_to_javascript(source) }.merge(options))
        end

        def stylesheet_tag(source, options)
          tag("link", { "rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen", "href" => html_escape(path_to_stylesheet(source)) }.merge(options), false, false)
        end

        def compute_javascript_paths(sources)
          expand_javascript_sources(sources).collect { |source| compute_public_path(source, 'javascripts', 'js', false) }
        end

        def compute_stylesheet_paths(sources)
          expand_stylesheet_sources(sources).collect { |source| compute_public_path(source, 'stylesheets', 'css', false) }
        end

        def expand_javascript_sources(sources)
          if sources.include?(:all)
            all_javascript_files = Dir[File.join(JAVASCRIPTS_DIR, '*.js')].collect { |file| File.basename(file).gsub(/\.\w+$/, '') }.sort
            @@all_javascript_sources ||= ((determine_source(:defaults, @@javascript_expansions).dup & all_javascript_files) + all_javascript_files).uniq
          else
            expanded_sources = sources.collect do |source|
              determine_source(source, @@javascript_expansions)
            end.flatten
            expanded_sources << "application" if sources.include?(:defaults) && file_exist?(File.join(JAVASCRIPTS_DIR, "application.js"))
            expanded_sources
          end
        end

        def expand_stylesheet_sources(sources)
          if sources.first == :all
            @@all_stylesheet_sources ||= Dir[File.join(STYLESHEETS_DIR, '*.css')].collect { |file| File.basename(file).gsub(/\.\w+$/, '') }.sort
          else
            sources.collect do |source|
              determine_source(source, @@stylesheet_expansions)
            end.flatten
          end
        end

        def determine_source(source, collection)
          case source
          when Symbol
            collection[source] || raise(ArgumentError, "No expansion found for #{source.inspect}")
          else
            source
          end
        end

        def join_asset_file_contents(paths)
          paths.collect { |path| File.read(File.join(ASSETS_DIR, path.split("?").first)) }.join("\n\n")
        end

        def write_asset_file_contents(joined_asset_path, asset_paths)
          unless file_exist?(joined_asset_path)
            FileUtils.mkdir_p(File.dirname(joined_asset_path))
            File.open(joined_asset_path, "w+") { |cache| cache.write(join_asset_file_contents(asset_paths)) }
          end
        end
    end
  end
end
