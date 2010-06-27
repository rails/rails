require 'thread'
require 'cgi'
require 'action_view/helpers/url_helper'
require 'action_view/helpers/tag_helper'
require 'active_support/core_ext/file'
require 'active_support/core_ext/object/blank'

module ActionView
  # = Action View Asset Tag Helpers
  module Helpers #:nodoc:
    # This module provides methods for generating HTML that links views to assets such
    # as images, javascripts, stylesheets, and feeds. These methods do not verify
    # the assets exist before linking to them:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # === Using asset hosts
    #
    # By default, Rails links to these assets on the current host in the public
    # folder, but you can direct Rails to link to assets from a dedicated asset
    # server by setting ActionController::Base.asset_host in the application
    # configuration, typically in <tt>config/environments/production.rb</tt>.
    # For example, you'd define <tt>assets.example.com</tt> to be your asset
    # host this way:
    #
    #   ActionController::Base.asset_host = "assets.example.com"
    #
    # Helpers take that into account:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # Browsers typically open at most two simultaneous connections to a single
    # host, which means your assets often have to wait for other assets to finish
    # downloading. You can alleviate this by using a <tt>%d</tt> wildcard in the
    # +asset_host+. For example, "assets%d.example.com". If that wildcard is
    # present Rails distributes asset requests among the corresponding four hosts
    # "assets0.example.com", ..., "assets3.example.com". With this trick browsers
    # will open eight simultaneous connections rather than two.
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets0.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets2.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # To do this, you can either setup four actual hosts, or you can use wildcard
    # DNS to CNAME the wildcard to a single asset host. You can read more about
    # setting up your DNS CNAME records from your ISP.
    #
    # Note: This is purely a browser performance optimization and is not meant
    # for server load balancing. See http://www.die.net/musings/page_load_time/
    # for background.
    #
    # Alternatively, you can exert more control over the asset host by setting
    # +asset_host+ to a proc like this:
    #
    #   ActionController::Base.asset_host = Proc.new { |source|
    #     "http://assets#{source.hash % 2 + 1}.example.com"
    #   }
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets1.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets2.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # The example above generates "http://assets1.example.com" and
    # "http://assets2.example.com". This option is useful for example if
    # you need fewer/more than four hosts, custom host names, etc.
    #
    # As you see the proc takes a +source+ parameter. That's a string with the
    # absolute path of the asset with any extensions and timestamps in place,
    # for example "/images/rails.png?1230601161".
    #
    #    ActionController::Base.asset_host = Proc.new { |source|
    #      if source.starts_with?('/images')
    #        "http://images.example.com"
    #      else
    #        "http://assets.example.com"
    #      end
    #    }
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://images.example.com/images/rails.png?1230601161" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets.example.com/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # Alternatively you may ask for a second parameter +request+. That one is
    # particularly useful for serving assets from an SSL-protected page. The
    # example proc below disables asset hosting for HTTPS connections, while
    # still sending assets for plain HTTP requests from asset hosts. If you don't
    # have SSL certificates for each of the asset hosts this technique allows you
    # to avoid warnings in the client about mixed media.
    #
    #   ActionController::Base.asset_host = Proc.new { |source, request|
    #     if request.ssl?
    #       "#{request.protocol}#{request.host_with_port}"
    #     else
    #       "#{request.protocol}assets.example.com"
    #     end
    #   }
    #
    # You can also implement a custom asset host object that responds to +call+
    # and takes either one or two parameters just like the proc.
    #
    #   config.action_controller.asset_host = AssetHostingWithMinimumSsl.new(
    #     "http://asset%d.example.com", "https://asset1.example.com"
    #   )
    #
    # === Customizing the asset path
    #
    # By default, Rails appends asset's timestamps to all asset paths. This allows
    # you to set a cache-expiration date for the asset far into the future, but
    # still be able to instantly invalidate it by simply updating the file (and
    # hence updating the timestamp, which then updates the URL as the timestamp
    # is part of that, which in turn busts the cache).
    #
    # It's the responsibility of the web server you use to set the far-future
    # expiration date on cache assets that you need to take advantage of this
    # feature. Here's an example for Apache:
    #
    #   # Asset Expiration
    #   ExpiresActive On
    #   <FilesMatch "\.(ico|gif|jpe?g|png|js|css)$">
    #     ExpiresDefault "access plus 1 year"
    #   </FilesMatch>
    #
    # Also note that in order for this to work, all your application servers must
    # return the same timestamps. This means that they must have their clocks
    # synchronized. If one of them drifts out of sync, you'll see different
    # timestamps at random and the cache won't work. In that case the browser
    # will request the same assets over and over again even thought they didn't
    # change. You can use something like Live HTTP Headers for Firefox to verify
    # that the cache is indeed working.
    #
    # This strategy works well enough for most server setups and requires the
    # least configuration, but if you deploy several application servers at
    # different times - say to handle a temporary spike in load - then the
    # asset time stamps will be out of sync. In a setup like this you may want
    # to set the way that asset paths are generated yourself.
    #
    # Altering the asset paths that Rails generates can be done in two ways.
    # The easiest is to define the RAILS_ASSET_ID environment variable. The
    # contents of this variable will always be used in preference to
    # calculated timestamps. A more complex but flexible way is to set
    # <tt>ActionController::Base.config.asset_path</tt> to a proc
    # that takes the unmodified asset path and returns the path needed for
    # your asset caching to work. Typically you'd do something like this in
    # <tt>config/environments/production.rb</tt>:
    #
    #   # Normally you'd calculate RELEASE_NUMBER at startup.
    #   RELEASE_NUMBER = 12345
    #   config.action_controller.asset_path_template = proc { |asset_path|
    #     "/release-#{RELEASE_NUMBER}#{asset_path}"
    #   }
    #
    # This example would cause the following behaviour on all servers no
    # matter when they were deployed:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/release-12345/images/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/release-12345/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" type="text/css" />
    #
    # Changing the asset_path does require that your web servers have
    # knowledge of the asset template paths that you rewrite to so it's not
    # suitable for out-of-the-box use. To use the example given above you
    # could use something like this in your Apache VirtualHost configuration:
    #
    #   <LocationMatch "^/release-\d+/(images|javascripts|stylesheets)/.*$">
    #     # Some browsers still send conditional-GET requests if there's a
    #     # Last-Modified header or an ETag header even if they haven't
    #     # reached the expiry date sent in the Expires header.
    #     Header unset Last-Modified
    #     Header unset ETag
    #     FileETag None
    #
    #     # Assets requested using a cache-busting filename should be served
    #     # only once and then cached for a really long time. The HTTP/1.1
    #     # spec frowns on hugely-long expiration times though and suggests
    #     # that assets which never expire be served with an expiration date
    #     # 1 year from access.
    #     ExpiresActive On
    #     ExpiresDefault "access plus 1 year"
    #   </LocationMatch>
    #
    #   # We use cached-busting location names with the far-future expires
    #   # headers to ensure that if a file does change it can force a new
    #   # request. The actual asset filenames are still the same though so we
    #   # need to rewrite the location from the cache-busting location to the
    #   # real asset location so that we can serve it.
    #   RewriteEngine On
    #   RewriteRule ^/release-\d+/(images|javascripts|stylesheets)/(.*)$ /$1/$2 [L]
    module AssetTagHelper
      mattr_reader :javascript_expansions
      @@javascript_expansions = { }

      mattr_reader :stylesheet_expansions
      @@stylesheet_expansions = {}

      # You can enable or disable the asset tag timestamps cache.
      # With the cache enabled, the asset tag helper methods will make fewer
      # expensive file system calls. However this prevents you from modifying
      # any asset files while the server is running.
      #
      #   ActionView::Helpers::AssetTagHelper.cache_asset_timestamps = false
      mattr_accessor :cache_asset_timestamps

      # Returns a link tag that browsers and news readers can use to auto-detect
      # an RSS or ATOM feed. The +type+ can either be <tt>:rss</tt> (default) or
      # <tt>:atom</tt>. Control the link options in url_for format using the
      # +url_options+. You can modify the LINK tag itself in +tag_options+.
      #
      # ==== Options
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
      # If the +source+ filename has no extension, .js will be appended (except for explicit URIs)
      # Full paths from the document root will be passed through.
      # Used internally by javascript_include_tag to build the script path.
      #
      # ==== Examples
      #   javascript_path "xmlhr" # => /javascripts/xmlhr.js
      #   javascript_path "dir/xmlhr.js" # => /javascripts/dir/xmlhr.js
      #   javascript_path "/dir/xmlhr" # => /dir/xmlhr.js
      #   javascript_path "http://www.railsapplication.com/js/xmlhr" # => http://www.railsapplication.com/js/xmlhr
      #   javascript_path "http://www.railsapplication.com/js/xmlhr.js" # => http://www.railsapplication.com/js/xmlhr.js
      def javascript_path(source)
        compute_public_path(source, 'javascripts', 'js')
      end
      alias_method :path_to_javascript, :javascript_path # aliased to avoid conflicts with a javascript_path named route

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
      # If you want Rails to search in all the subdirectories under javascripts, you should explicitly set <tt>:recursive</tt>:
      #
      #   javascript_include_tag :all, :recursive => true
      #
      # == Caching multiple javascripts into one
      #
      # You can also cache multiple javascripts into one file, which requires less HTTP connections to download and can better be
      # compressed by gzip (leading to faster transfers). Caching will only happen if config.perform_caching
      # is set to <tt>true</tt> (which is the case by default for the Rails production environment, but not for the development
      # environment).
      #
      # ==== Examples
      #   javascript_include_tag :all, :cache => true # when config.perform_caching is false =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/effects.js"></script>
      #     ...
      #     <script type="text/javascript" src="/javascripts/application.js"></script>
      #     <script type="text/javascript" src="/javascripts/shop.js"></script>
      #     <script type="text/javascript" src="/javascripts/checkout.js"></script>
      #
      #   javascript_include_tag :all, :cache => true # when config.perform_caching is true =>
      #     <script type="text/javascript" src="/javascripts/all.js"></script>
      #
      #   javascript_include_tag "prototype", "cart", "checkout", :cache => "shop" # when config.perform_caching is false =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/cart.js"></script>
      #     <script type="text/javascript" src="/javascripts/checkout.js"></script>
      #
      #   javascript_include_tag "prototype", "cart", "checkout", :cache => "shop" # when config.perform_caching is true =>
      #     <script type="text/javascript" src="/javascripts/shop.js"></script>
      #
      # The <tt>:recursive</tt> option is also available for caching:
      #
      #   javascript_include_tag :all, :cache => true, :recursive => true
      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        concat  = options.delete("concat")
        cache   = concat || options.delete("cache")
        recursive = options.delete("recursive")

        if concat || (config.perform_caching && cache)
          joined_javascript_name = (cache == true ? "all" : cache) + ".js"
          joined_javascript_path = File.join(joined_javascript_name[/^#{File::SEPARATOR}/] ? config.assets_dir : config.javascripts_dir, joined_javascript_name)

          unless config.perform_caching && File.exists?(joined_javascript_path)
            write_asset_file_contents(joined_javascript_path, compute_javascript_paths(sources, recursive))
          end
          javascript_src_tag(joined_javascript_name, options)
        else
          sources = expand_javascript_sources(sources, recursive)
          ensure_javascript_sources!(sources) if cache
          sources.collect { |source| javascript_src_tag(source, options) }.join("\n").html_safe
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

      # Computes the path to a stylesheet asset in the public stylesheets directory.
      # If the +source+ filename has no extension, <tt>.css</tt> will be appended (except for explicit URIs).
      # Full paths from the document root will be passed through.
      # Used internally by +stylesheet_link_tag+ to build the stylesheet path.
      #
      # ==== Examples
      #   stylesheet_path "style" # => /stylesheets/style.css
      #   stylesheet_path "dir/style.css" # => /stylesheets/dir/style.css
      #   stylesheet_path "/dir/style.css" # => /dir/style.css
      #   stylesheet_path "http://www.railsapplication.com/css/style" # => http://www.railsapplication.com/css/style
      #   stylesheet_path "http://www.railsapplication.com/css/style.css" # => http://www.railsapplication.com/css/style.css
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
      # You can also include all styles in the stylesheets directory using <tt>:all</tt> as the source:
      #
      #   stylesheet_link_tag :all # =>
      #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" type="text/css" />
      #
      # If you want Rails to search in all the subdirectories under stylesheets, you should explicitly set <tt>:recursive</tt>:
      #
      #   stylesheet_link_tag :all, :recursive => true
      #
      # == Caching multiple stylesheets into one
      #
      # You can also cache multiple stylesheets into one file, which requires less HTTP connections and can better be
      # compressed by gzip (leading to faster transfers). Caching will only happen if config.perform_caching
      # is set to true (which is the case by default for the Rails production environment, but not for the development
      # environment). Examples:
      #
      # ==== Examples
      #   stylesheet_link_tag :all, :cache => true # when config.perform_caching is false =>
      #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag :all, :cache => true # when config.perform_caching is true =>
      #     <link href="/stylesheets/all.css"  media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when config.perform_caching is false =>
      #     <link href="/stylesheets/shop.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/cart.css"  media="screen" rel="stylesheet" type="text/css" />
      #     <link href="/stylesheets/checkout.css" media="screen" rel="stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when config.perform_caching is true =>
      #     <link href="/stylesheets/payment.css"  media="screen" rel="stylesheet" type="text/css" />
      #
      # The <tt>:recursive</tt> option is also available for caching:
      #
      #   stylesheet_link_tag :all, :cache => true, :recursive => true
      #
      # To force concatenation (even in development mode) set <tt>:concat</tt> to true. This is useful if
      # you have too many stylesheets for IE to load.
      #
      #   stylesheet_link_tag :all, :concat => true
      #
      def stylesheet_link_tag(*sources)
        options = sources.extract_options!.stringify_keys
        concat  = options.delete("concat")
        cache   = concat || options.delete("cache")
        recursive = options.delete("recursive")

        if concat || (config.perform_caching && cache)
          joined_stylesheet_name = (cache == true ? "all" : cache) + ".css"
          joined_stylesheet_path = File.join(joined_stylesheet_name[/^#{File::SEPARATOR}/] ? config.assets_dir : config.stylesheets_dir, joined_stylesheet_name)

          unless config.perform_caching && File.exists?(joined_stylesheet_path)
            write_asset_file_contents(joined_stylesheet_path, compute_stylesheet_paths(sources, recursive))
          end
          stylesheet_tag(joined_stylesheet_name, options)
        else
          sources = expand_stylesheet_sources(sources, recursive)
          ensure_stylesheet_sources!(sources) if cache
          sources.collect { |source| stylesheet_tag(source, options) }.join("\n").html_safe
        end
      end

      # Web browsers cache favicons. If you just throw a <tt>favicon.ico</tt> into the document
      # root of your application and it changes later, clients that have it in their cache
      # won't see the update. Using this helper prevents that because it appends an asset ID:
      #
      #   <%= favicon_link_tag %>
      #
      # generates
      #
      #   <link href="/favicon.ico?4649789979" rel="shortcut icon" type="image/vnd.microsoft.icon" />
      #
      # You may specify a different file in the first argument:
      #
      #   <%= favicon_link_tag 'favicon.ico' %>
      #
      # That's passed to +path_to_image+ as is, so it gives
      #
      #   <link href="/images/favicon.ico?4649789979" rel="shortcut icon" type="image/vnd.microsoft.icon" />
      #
      # The helper accepts an additional options hash where you can override "rel" and "type".
      #
      # For example, Mobile Safari looks for a different LINK tag, pointing to an image that
      # will be used if you add the page to the home screen of an iPod Touch, iPhone, or iPad.
      # The following call would generate such a tag:
      #
      #   <%= favicon_link_tag 'mb-icon.png', :rel => 'apple-touch-icon', :type => 'image/png' %>
      #
      def favicon_link_tag(source='/favicon.ico', options={})
        tag('link', {
          :rel  => 'shortcut icon',
          :type => 'image/vnd.microsoft.icon',
          :href => path_to_image(source)
        }.merge(options.symbolize_keys))
      end

      # Computes the path to an image asset in the public images directory.
      # Full paths from the document root will be passed through.
      # Used internally by +image_tag+ to build the image path:
      #
      #   image_path("edit")                                         # => "/images/edit"
      #   image_path("edit.png")                                     # => "/images/edit.png"
      #   image_path("icons/edit.png")                               # => "/images/icons/edit.png"
      #   image_path("/icons/edit.png")                              # => "/icons/edit.png"
      #   image_path("http://www.railsapplication.com/img/edit.png") # => "http://www.railsapplication.com/img/edit.png"
      #
      # If you have images as application resources this method may conflict with their named routes.
      # The alias +path_to_image+ is provided to avoid that. Rails uses the alias internally, and
      # plugin authors are encouraged to do so.
      def image_path(source)
        compute_public_path(source, 'images')
      end
      alias_method :path_to_image, :image_path # aliased to avoid conflicts with an image_path named route

      # Computes the path to a video asset in the public videos directory.
      # Full paths from the document root will be passed through.
      # Used internally by +video_tag+ to build the video path.
      #
      # ==== Examples
      #   video_path("hd")                                            # => /videos/hd
      #   video_path("hd.avi")                                        # => /videos/hd.avi
      #   video_path("trailers/hd.avi")                               # => /videos/trailers/hd.avi
      #   video_path("/trailers/hd.avi")                              # => /trailers/hd.avi
      #   video_path("http://www.railsapplication.com/vid/hd.avi") # => http://www.railsapplication.com/vid/hd.avi
      def video_path(source)
        compute_public_path(source, 'videos')
      end
      alias_method :path_to_video, :video_path # aliased to avoid conflicts with a video_path named route

      # Computes the path to an audio asset in the public audios directory.
      # Full paths from the document root will be passed through.
      # Used internally by +audio_tag+ to build the audio path.
      #
      # ==== Examples
      #   audio_path("horse")                                            # => /audios/horse
      #   audio_path("horse.wav")                                        # => /audios/horse.avi
      #   audio_path("sounds/horse.wav")                                 # => /audios/sounds/horse.avi
      #   audio_path("/sounds/horse.wav")                                # => /sounds/horse.avi
      #   audio_path("http://www.railsapplication.com/sounds/horse.wav") # => http://www.railsapplication.com/sounds/horse.wav
      def audio_path(source)
        compute_public_path(source, 'audios')
      end
      alias_method :path_to_audio, :audio_path # aliased to avoid conflicts with an audio_path named route

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

        src = options[:src] = path_to_image(source)

        unless src =~ /^cid:/
          options[:alt] = options.fetch(:alt){ File.basename(src, '.*').capitalize }
        end

        if size = options.delete(:size)
          options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
        end

        if mouseover = options.delete(:mouseover)
          options[:onmouseover] = "this.src='#{path_to_image(mouseover)}'"
          options[:onmouseout]  = "this.src='#{src}'"
        end

        tag("img", options)
      end

      # Returns an html video tag for the +sources+. If +sources+ is a string,
      # a single video tag will be returned. If +sources+ is an array, a video
      # tag with nested source tags for each source will be returned. The
      # +sources+ can be full paths or files that exists in your public videos
      # directory.
      #
      # ==== Options
      # You can add HTML attributes using the +options+. The +options+ supports
      # two additional keys for convenience and conformance:
      #
      # * <tt>:poster</tt> - Set an image (like a screenshot) to be shown
      #   before the video loads. The path is calculated like the +src+ of +image_tag+.
      # * <tt>:size</tt> - Supplied as "{Width}x{Height}", so "30x45" becomes
      #   width="30" and height="45". <tt>:size</tt> will be ignored if the
      #   value is not in the correct format.
      #
      # ==== Examples
      #  video_tag("trailer")  # =>
      #    <video src="/videos/trailer" />
      #  video_tag("trailer.ogg")  # =>
      #    <video src="/videos/trailer.ogg" />
      #  video_tag("trailer.ogg", :controls => true, :autobuffer => true)  # =>
      #    <video autobuffer="autobuffer" controls="controls" src="/videos/trailer.ogg" />
      #  video_tag("trailer.m4v", :size => "16x10", :poster => "screenshot.png")  # =>
      #    <video src="/videos/trailer.m4v" width="16" height="10" poster="/images/screenshot.png" />
      #  video_tag("/trailers/hd.avi", :size => "16x16")  # =>
      #    <video src="/trailers/hd.avi" width="16" height="16" />
      #  video_tag("/trailers/hd.avi", :height => '32', :width => '32') # =>
      #    <video height="32" src="/trailers/hd.avi" width="32" />
      #  video_tag(["trailer.ogg", "trailer.flv"]) # =>
      #    <video><source src="trailer.ogg" /><source src="trailer.ogg" /><source src="trailer.flv" /></video>
      #  video_tag(["trailer.ogg", "trailer.flv"] :size => "160x120") # =>
      #    <video height="120" width="160"><source src="trailer.ogg" /><source src="trailer.flv" /></video>
      def video_tag(sources, options = {})
        options.symbolize_keys!

        options[:poster] = path_to_image(options[:poster]) if options[:poster]

        if size = options.delete(:size)
          options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
        end

        if sources.is_a?(Array)
          content_tag("video", options) do
            sources.map { |source| tag("source", :src => source) }.join.html_safe
          end
        else
          options[:src] = path_to_video(sources)
          tag("video", options)
        end
      end

      # Returns an html audio tag for the +source+.
      # The +source+ can be full path or file that exists in
      # your public audios directory.
      #
      # ==== Examples
      #  audio_tag("sound")  # =>
      #    <audio src="/audios/sound" />
      #  audio_tag("sound.wav")  # =>
      #    <audio src="/audios/sound.wav" />
      #  audio_tag("sound.wav", :autoplay => true, :controls => true)  # =>
      #    <audio autoplay="autoplay" controls="controls" src="/audios/sound.wav" />
      def audio_tag(source, options = {})
        options.symbolize_keys!
        options[:src] = path_to_audio(source)
        tag("audio", options)
      end

      private

        def rewrite_extension?(source, dir, ext)
          source_ext = File.extname(source)[1..-1]
          ext && (source_ext.blank? || (ext != source_ext && File.exist?(File.join(config.assets_dir, dir, "#{source}.#{ext}"))))
        end

        def rewrite_host_and_protocol(source, has_request)
          host = compute_asset_host(source)
          if has_request && host.present? && !is_uri?(host)
            host = "#{controller.request.protocol}#{host}"
          end
          "#{host}#{source}"
        end

        # Add the the extension +ext+ if not present. Return full URLs otherwise untouched.
        # Prefix with <tt>/dir/</tt> if lacking a leading +/+. Account for relative URL
        # roots. Rewrite the asset path for cache-busting asset ids. Include
        # asset host, if configured, with the correct request protocol.
        def compute_public_path(source, dir, ext = nil, include_host = true)
          return source if is_uri?(source)

          source += ".#{ext}" if rewrite_extension?(source, dir, ext)
          source  = "/#{dir}/#{source}" unless source[0] == ?/
          source = rewrite_asset_path(source, config.asset_path)

          has_request = controller.respond_to?(:request)
          if has_request && include_host && source !~ %r{^#{controller.config.relative_url_root}/}
            source = "#{controller.config.relative_url_root}#{source}"
          end
          source = rewrite_host_and_protocol(source, has_request) if include_host

          source
        end

        def is_uri?(path)
          path =~ %r{^[-a-z]+://|^cid:}
        end

        # Pick an asset host for this source. Returns +nil+ if no host is set,
        # the host if no wildcard is set, the host interpolated with the
        # numbers 0-3 if it contains <tt>%d</tt> (the number is the source hash mod 4),
        # or the value returned from invoking the proc if it's a proc or the value from
        # invoking call if it's an object responding to call.
        def compute_asset_host(source)
          if host = config.asset_host
            if host.is_a?(Proc) || host.respond_to?(:call)
              case host.is_a?(Proc) ? host.arity : host.method(:call).arity
              when 2
                request = controller.respond_to?(:request) && controller.request
                host.call(source, request)
              else
                host.call(source)
              end
            else
              (host =~ /%d/) ? host % (source.hash % 4) : host
            end
          end
        end

        @@asset_timestamps_cache = {}
        @@asset_timestamps_cache_guard = Mutex.new

        # Use the RAILS_ASSET_ID environment variable or the source's
        # modification time as its cache-busting asset id.
        def rails_asset_id(source)
          if asset_id = ENV["RAILS_ASSET_ID"]
            asset_id
          else
            if @@cache_asset_timestamps && (asset_id = @@asset_timestamps_cache[source])
              asset_id
            else
              path = File.join(config.assets_dir, source)
              asset_id = File.exist?(path) ? File.mtime(path).to_i.to_s : ''

              if @@cache_asset_timestamps
                @@asset_timestamps_cache_guard.synchronize do
                  @@asset_timestamps_cache[source] = asset_id
                end
              end

              asset_id
            end
          end
        end

        # Break out the asset path rewrite in case plugins wish to put the asset id
        # someplace other than the query string.
        def rewrite_asset_path(source, path = nil)
          if path && path.respond_to?(:call)
            return path.call(source)
          elsif path && path.is_a?(String)
            return path % [source]
          end

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

        def compute_javascript_paths(*args)
          expand_javascript_sources(*args).collect { |source| compute_public_path(source, 'javascripts', 'js', false) }
        end

        def compute_stylesheet_paths(*args)
          expand_stylesheet_sources(*args).collect { |source| compute_public_path(source, 'stylesheets', 'css', false) }
        end

        def expand_javascript_sources(sources, recursive = false)
          if sources.include?(:all)
            all_javascript_files = collect_asset_files(config.javascripts_dir, ('**' if recursive), '*.js')
            ((determine_source(:defaults, @@javascript_expansions).dup & all_javascript_files) + all_javascript_files).uniq
          else
            expanded_sources = sources.collect do |source|
              determine_source(source, @@javascript_expansions)
            end.flatten
            expanded_sources << "application" if sources.include?(:defaults) && File.exist?(File.join(config.javascripts_dir, "application.js"))
            expanded_sources
          end
        end

        def expand_stylesheet_sources(sources, recursive)
          if sources.first == :all
            collect_asset_files(config.stylesheets_dir, ('**' if recursive), '*.css')
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

        def ensure_stylesheet_sources!(sources)
          sources.each do |source|
            asset_file_path!(path_to_stylesheet(source))
          end
          return sources
        end

        def ensure_javascript_sources!(sources)
          sources.each do |source|
            asset_file_path!(path_to_javascript(source))
          end
          return sources
        end

        def join_asset_file_contents(paths)
          paths.collect { |path| File.read(asset_file_path!(path)) }.join("\n\n")
        end

        def write_asset_file_contents(joined_asset_path, asset_paths)

          FileUtils.mkdir_p(File.dirname(joined_asset_path))
          File.atomic_write(joined_asset_path) { |cache| cache.write(join_asset_file_contents(asset_paths)) }

          # Set mtime to the latest of the combined files to allow for
          # consistent ETag without a shared filesystem.
          mt = asset_paths.map { |p| File.mtime(asset_file_path(p)) }.max
          File.utime(mt, mt, joined_asset_path)
        end

        def asset_file_path(path)
          File.join(config.assets_dir, path.split('?').first)
        end

        def asset_file_path!(path)
          unless is_uri?(path)
            absolute_path = asset_file_path(path)
            raise(Errno::ENOENT, "Asset file not found at '#{absolute_path}'" ) unless File.exist?(absolute_path)
            return absolute_path
          end
        end

        def collect_asset_files(*path)
          dir = path.first

          Dir[File.join(*path.compact)].collect do |file|
            file[-(file.size - dir.size - 1)..-1].sub(/\.\w+$/, '')
          end.sort
        end
    end
  end
end
