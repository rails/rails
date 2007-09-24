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
    # setting ActionController::Base.asset_host in your environment.rb.  For example,
    # let's say your asset host is assets.example.com. 
    #
    #   ActionController::Base.asset_host = "assets.example.com"
    #   image_tag("rails.png")
    #     => <img src="http://assets.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_include_tag("application")
    #     => <link href="http://assets.example.com/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />
    #
    # This is useful since browsers typically open at most two connections to a single host,
    # which means your assets often wait in single file for their turn to load.  You can
    # alleviate this by using a %d wildcard in <tt>asset_host</tt> (for example, "assets%d.example.com") 
    # to automatically distribute asset requests among four hosts (e.g., assets0.example.com through assets3.example.com)
    # so browsers will open eight connections rather than two.  
    #
    #   image_tag("rails.png")
    #     => <img src="http://assets0.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_include_tag("application")
    #     => <link href="http://assets3.example.com/stylesheets/application.css" media="screen" rel="stylesheet" type="text/css" />
    #
    # To do this, you can either setup four actual hosts, or you can use wildcard DNS to CNAME 
    # the wildcard to a single asset host.  You can read more about setting up your DNS CNAME records from
    # your ISP.
    #
    # Note: This is purely a browser performance optimization and is not meant
    # for server load balancing. See http://www.die.net/musings/page_load_time/
    # for background.
    module AssetTagHelper
      ASSETS_DIR      = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/public" : "public"
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

      JAVASCRIPT_DEFAULT_SOURCES = ['prototype', 'effects', 'dragdrop', 'controls'] unless const_defined?(:JAVASCRIPT_DEFAULT_SOURCES)
      @@javascript_default_sources = JAVASCRIPT_DEFAULT_SOURCES.dup

      # Returns an html script tag for each of the +sources+ provided. You
      # can pass in the filename (.js extension is optional) of javascript files
      # that exist in your public/javascripts directory for inclusion into the
      # current page or you can pass the full path relative to your document
      # root. To include the Prototype and Scriptaculous javascript libraries in
      # your application, pass <tt>:defaults</tt> as the source. When using
      # :defaults, if an <tt>application.js</tt> file exists in your public
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
      #   javascript_include_tag "prototype", "cart", "checkout", :cache => "shop" # when ActionController::Base.perform_caching is false =>
      #     <script type="text/javascript" src="/javascripts/shop.js"></script>
      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        cache   = options.delete("cache")

        if ActionController::Base.perform_caching && cache
          joined_javascript_name = (cache == true ? "all" : cache) + ".js"
          joined_javascript_path = File.join(JAVASCRIPTS_DIR, joined_javascript_name)

          if !file_exist?(joined_javascript_path)
            File.open(joined_javascript_path, "w+") do |cache|
              javascript_paths = expand_javascript_sources(sources).collect do |source|
                compute_public_path(source, 'javascripts', 'js', false)
              end

              cache.write(join_asset_file_contents(javascript_paths))
            end
          end

          content_tag("script", "", {
            "type" => Mime::JS, "src" => javascript_path(joined_javascript_name)
          }.merge(options))
        else
          expand_javascript_sources(sources).collect do |source|
            content_tag("script", "", { "type" => Mime::JS, "src" => javascript_path(source) }.merge(options))
          end.join("\n")
        end
      end

      # Register one or more additional JavaScript files to be included when
      # <tt>javascript_include_tag :defaults</tt> is called. This method is
      # typically intended to be called from plugin initialization to register additional
      # .js files that the plugin installed in <tt>public/javascripts</tt>.
      def self.register_javascript_include_default(*sources)
        @@javascript_default_sources.concat(sources)
      end

      def self.reset_javascript_include_default #:nodoc:
        @@javascript_default_sources = JAVASCRIPT_DEFAULT_SOURCES.dup
      end

      # Computes the path to a stylesheet asset in the public stylesheets directory.
      # If the +source+ filename has no extension, .css will be appended.
      # Full paths from the document root will be passed through.
      # Used internally by stylesheet_link_tag to build the stylesheet path.
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

      # Returns a stylesheet link tag for the sources specified as arguments. If
      # you don't specify an extension, .css will be appended automatically.
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
      # You can also include all styles in the stylesheet directory using :all as the source:
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

          if !file_exist?(joined_stylesheet_path)
            File.open(joined_stylesheet_path, "w+") do |cache|
              stylesheet_paths = expand_stylesheet_sources(sources).collect do |source|
                compute_public_path(source, 'stylesheets', 'css', false) 
              end

              cache.write(join_asset_file_contents(stylesheet_paths))
            end
          end

          tag("link", {
            "rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen",
            "href" => html_escape(stylesheet_path(joined_stylesheet_name))
          }.merge(options), false, false)
        else
          options.delete("cache")

          expand_stylesheet_sources(sources).collect do |source|
            tag("link", {
              "rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen", "href" => html_escape(stylesheet_path(source))
            }.merge(options), false, false)
          end.join("\n")
        end
      end

      # Computes the path to an image asset in the public images directory.
      # Full paths from the document root will be passed through.
      # Used internally by image_tag to build the image path.
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

      # Returns an html image tag for the +source+. The +source+ can be a full
      # path or a file that exists in your public images directory.
      #
      # ==== Options
      # You can add HTML attributes using the +options+. The +options+ supports
      # two additional keys for convienence and conformance:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the
      #   +source+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "{Width}x{Height}", so "30x45" becomes
      #   width="30" and height="45". <tt>:size</tt> will be ignored if the
      #   value is not in the correct format.
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
      def image_tag(source, options = {})
        options.symbolize_keys!

        options[:src] = image_path(source)
        options[:alt] ||= File.basename(options[:src], '.*').split('.').first.capitalize

        if options[:size]
          options[:width], options[:height] = options[:size].split("x") if options[:size] =~ %r{^\d+x\d+$}
          options.delete(:size)
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

        # Add the .ext if not present. Return full URLs otherwise untouched.
        # Prefix with /dir/ if lacking a leading /. Account for relative URL
        # roots. Rewrite the asset path for cache-busting asset ids. Include
        # a single or wildcarded asset host, if configured, with the correct
        # request protocol.
        def compute_public_path(source, dir, ext = nil, include_host = true)
          cache_key = [ @controller.request.protocol,
                        ActionController::Base.asset_host,
                        @controller.request.relative_url_root,
                        dir, source, ext, include_host ].join

          ActionView::Base.computed_public_paths[cache_key] ||=
            begin
              source += ".#{ext}" if File.extname(source).blank? && ext

              if source =~ %r{^[-a-z]+://}
                source
              else
                source = "/#{dir}/#{source}" unless source[0] == ?/
                source = "#{@controller.request.relative_url_root}#{source}"
                rewrite_asset_path!(source)

                if include_host
                  host = compute_asset_host(source)

                  unless host.blank? or host =~ %r{^[-a-z]+://}
                    host = "#{@controller.request.protocol}#{host}"
                  end

                  "#{host}#{source}"
                else
                  source
                end
              end
            end
        end

        # Pick an asset host for this source. Returns nil if no host is set,
        # the host if no wildcard is set, or the host interpolated with the
        # numbers 0-3 if it contains %d. The number is the source hash mod 4.
        def compute_asset_host(source)
          if host = ActionController::Base.asset_host
            host % (source.hash % 4)
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

        # Break out the asset path rewrite so you wish to put the asset id
        # someplace other than the query string.
        def rewrite_asset_path!(source)
          asset_id = rails_asset_id(source)
          source << "?#{asset_id}" if !asset_id.blank?
        end

        def expand_javascript_sources(sources)          
          case
          when sources.include?(:all)
            all_javascript_files = Dir[File.join(JAVASCRIPTS_DIR, '*.js')].collect { |file| File.basename(file).split(".", 0).first }.sort
            sources = ((@@javascript_default_sources.dup & all_javascript_files) + all_javascript_files).uniq

          when sources.include?(:defaults)
            sources = sources[0..(sources.index(:defaults))] + 
              @@javascript_default_sources.dup + 
              sources[(sources.index(:defaults) + 1)..sources.length]

            sources.delete(:defaults)
            sources << "application" if file_exist?(File.join(JAVASCRIPTS_DIR, "application.js"))
          end

          sources
        end

        def expand_stylesheet_sources(sources)
          if sources.first == :all
            @@all_stylesheet_sources ||= Dir[File.join(STYLESHEETS_DIR, '*.css')].collect { |file| File.basename(file).split(".", 1).first }.sort
          else
            sources
          end
        end

        def join_asset_file_contents(paths)
          paths.collect { |path| File.read(File.join(ASSETS_DIR, path.split("?").first)) }.join("\n\n")
        end
    end
  end
end
