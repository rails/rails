require 'cgi'
require File.dirname(__FILE__) + '/url_helper'
require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers #:nodoc:
    # Provides methods for linking an HTML page together with other assets such
    # as images, javascripts, stylesheets, and feeds. You can direct Rails to
    # link to assets from a dedicated assets server by setting ActionController::Base.asset_host
    # in your environment.rb. These methods do not verify the assets exist before
    # linking to them.
    #
    #   ActionController::Base.asset_host = "http://assets.example.com"
    #   image_tag("rails.png")  
    #     => <img src="http://assets.example.com/images/rails.png" alt="Rails" />
    #   stylesheet_include_tag("application")
    #     => <link href="http://assets.example.com/stylesheets/application.css" media="screen" rel="Stylesheet" type="text/css" />
    module AssetTagHelper
      # Returns a link tag that browsers and news readers can use to auto-detect
      # an RSS or ATOM feed. The +type+ can either be <tt>:rss</tt> (default) or 
      # <tt>:atom</tt>. Control the link options in url_for format using the
      # +url_options+. You can modify the LINK tag itself in +tag_options+.
      #
      # Tag Options:
      # * <tt>:rel</tt>  - Specify the relation of this link, defaults to "alternate"
      # * <tt>:type</tt>  - Override the auto-generated mime type
      # * <tt>:title</tt>  - Specify the title of the link, defaults to the +type+
      #
      #  auto_discovery_link_tag # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.curenthost.com/controller/action" />
      #  auto_discovery_link_tag(:atom) # =>
      #     <link rel="alternate" type="application/atom+xml" title="ATOM" href="http://www.curenthost.com/controller/action" />
      #  auto_discovery_link_tag(:rss, {:action => "feed"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.curenthost.com/controller/feed" />
      #  auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="My RSS" href="http://www.curenthost.com/controller/feed" />
      def auto_discovery_link_tag(type = :rss, url_options = {}, tag_options = {})
        tag(
          "link", 
          "rel"   => tag_options[:rel] || "alternate",
          "type"  => tag_options[:type] || "application/#{type}+xml",
          "title" => tag_options[:title] || type.to_s.upcase,
          "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(:only_path => false)) : url_options
        )
      end

      # Computes the path to a javascript asset in the public javascripts directory.
      # If the +source+ filename has no extension, .js will be appended.
      # Full paths from the document root will be passed through.
      # Used internally by javascript_include_tag to build the script path.
      #
      #   javascript_path "xmlhr" # => /javascripts/xmlhr.js
      #   javascript_path "dir/xmlhr.js" # => /javascripts/dir/xmlhr.js
      #   javascript_path "/dir/xmlhr" # => /dir/xmlhr.js
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
      #   javascript_include_tag "xmlhr" # =>
      #     <script type="text/javascript" src="/javascripts/xmlhr.js"></script>
      #
      #   javascript_include_tag "common.javascript", "/elsewhere/cools" # =>
      #     <script type="text/javascript" src="/javascripts/common.javascript"></script>
      #     <script type="text/javascript" src="/elsewhere/cools.js"></script>
      #
      #   javascript_include_tag :defaults # =>
      #     <script type="text/javascript" src="/javascripts/prototype.js"></script>
      #     <script type="text/javascript" src="/javascripts/effects.js"></script>
      #     ...
      #     <script type="text/javascript" src="/javascripts/application.js"></script> *see below
      def javascript_include_tag(*sources)
        options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }

        if sources.include?(:defaults) 
          sources = sources[0..(sources.index(:defaults))] + 
            @@javascript_default_sources.dup + 
            sources[(sources.index(:defaults) + 1)..sources.length]

          sources.delete(:defaults) 
          sources << "application" if defined?(RAILS_ROOT) && File.exists?("#{RAILS_ROOT}/public/javascripts/application.js") 
        end

        sources.collect do |source|
          source = javascript_path(source)        
          content_tag("script", "", { "type" => "text/javascript", "src" => source }.merge(options))
        end.join("\n")
      end
      
      # Register one or more additional JavaScript files to be included when
      # <tt>javascript_include_tag :defaults</tt> is called. This method is
      # only intended to be called from plugin initialization to register additional 
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
      #   stylesheet_path "style" # => /stylesheets/style.css
      #   stylesheet_path "dir/style.css" # => /stylesheets/dir/style.css
      #   stylesheet_path "/dir/style.css" # => /dir/style.css
      def stylesheet_path(source)
        compute_public_path(source, 'stylesheets', 'css')
      end

      # Returns a stylesheet link tag for the sources specified as arguments. If
      # you don't specify an extension, .css will be appended automatically.
      # You can modify the link attributes by passing a hash as the last argument.
      #
      #   stylesheet_link_tag "style" # =>
      #     <link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "style", :media => "all" # =>
      #     <link href="/stylesheets/style.css" media="all" rel="Stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "random.styles", "/css/stylish" # =>
      #     <link href="/stylesheets/random.styles" media="screen" rel="Stylesheet" type="text/css" />
      #     <link href="/css/stylish.css" media="screen" rel="Stylesheet" type="text/css" />
      def stylesheet_link_tag(*sources)
        options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
        sources.collect do |source|
          source = stylesheet_path(source)
          tag("link", { "rel" => "Stylesheet", "type" => "text/css", "media" => "screen", "href" => source }.merge(options))
        end.join("\n")
      end

      # Computes the path to an image asset in the public images directory.
      # Full paths from the document root will be passed through.
      # Used internally by image_tag to build the image path. Passing
      # a filename without an extension is deprecated.
      #
      #   image_path("edit.png")  # => /images/edit.png
      #   image_path("icons/edit.png")  # => /images/icons/edit.png
      #   image_path("/icons/edit.png")  # => /icons/edit.png
      def image_path(source)
        unless (source.split("/").last || source).include?(".") || source.blank?
          ActiveSupport::Deprecation.warn(
            "You've called image_path with a source that doesn't include an extension. " +
            "In Rails 2.0, that will not result in .png automatically being appended. " +
            "So you should call image_path('#{source}.png') instead", caller
          )
        end

        compute_public_path(source, 'images', 'png')
      end

      # Returns an html image tag for the +source+. The +source+ can be a full
      # path or a file that exists in your public images directory. Note that 
      # specifying a filename without the extension is now deprecated in Rails.
      # You can add html attributes using the +options+. The +options+ supports
      # two additional keys for convienence and conformance:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the 
      #   +source+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "{Width}x{Height}", so "30x45" becomes 
      #   width="30" and height="45". <tt>:size</tt> will be ignored if the
      #   value is not in the correct format.
      #
      #  image_tag("icon.png")  # =>
      #    <img src="/images/icon.png" alt="Icon" />
      #  image_tag("icon.png", :size => "16x10", :alt => "Edit Entry")  # =>
      #    <img src="/images/icon.png" width="16" height="10" alt="Edit Entry" />
      #  image_tag("/icons/icon.gif", :size => "16x16")  # =>
      #    <img src="/icons/icon.gif" width="16" height="16" alt="Icon" />
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
        def compute_public_path(source, dir, ext)
          source = source.dup
          source << ".#{ext}" if File.extname(source).blank?
          unless source =~ %r{^[-a-z]+://}
            source = "/#{dir}/#{source}" unless source[0] == ?/
            asset_id = rails_asset_id(source)
            source << '?' + asset_id if defined?(RAILS_ROOT) && !asset_id.blank?
            source = "#{ActionController::Base.asset_host}#{@controller.request.relative_url_root}#{source}"
          end
          source
        end
        
        def rails_asset_id(source)
          ENV["RAILS_ASSET_ID"] || 
            File.mtime("#{RAILS_ROOT}/public/#{source}").to_i.to_s rescue ""
        end
    end
  end
end
