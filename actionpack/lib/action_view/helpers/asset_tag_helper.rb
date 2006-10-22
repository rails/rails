require 'cgi'
require File.dirname(__FILE__) + '/url_helper'
require File.dirname(__FILE__) + '/tag_helper'

module ActionView
  module Helpers
    # Provides methods for linking a HTML page together with other assets, such as javascripts, stylesheets, and feeds.
    module AssetTagHelper
      # Returns a link tag that browsers and news readers can use to auto-detect a RSS or ATOM feed for this page. The +type+ can
      # either be <tt>:rss</tt> (default) or <tt>:atom</tt> and the +options+ follow the url_for style of declaring a link target.
      #
      # Examples:
      #   auto_discovery_link_tag # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.curenthost.com/controller/action" />
      #   auto_discovery_link_tag(:atom) # =>
      #     <link rel="alternate" type="application/atom+xml" title="ATOM" href="http://www.curenthost.com/controller/action" />
      #   auto_discovery_link_tag(:rss, {:action => "feed"}) # =>
      #     <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.curenthost.com/controller/feed" />
      #   auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"}) # =>
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

      # Returns path to a javascript asset. Example:
      #
      #   javascript_path "xmlhr" # => /javascripts/xmlhr.js
      def javascript_path(source)
        compute_public_path(source, 'javascripts', 'js')        
      end

      JAVASCRIPT_DEFAULT_SOURCES = ['prototype', 'effects', 'dragdrop', 'controls'] unless const_defined?(:JAVASCRIPT_DEFAULT_SOURCES)
      @@javascript_default_sources = JAVASCRIPT_DEFAULT_SOURCES.dup

      # Returns a script include tag per source given as argument. Examples:
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
      #   
      # If there's an <tt>application.js</tt> file in your <tt>public/javascripts</tt> directory,
      # <tt>javascript_include_tag :defaults</tt> will automatically include it. This file
      # facilitates the inclusion of small snippets of JavaScript code, along the lines of
      # <tt>controllers/application.rb</tt> and <tt>helpers/application_helper.rb</tt>.
      def javascript_include_tag(*sources)
        options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }

        if sources.include?(:defaults) 
          sources = sources[0..(sources.index(:defaults))] + 
            @@javascript_default_sources.dup + 
            sources[(sources.index(:defaults) + 1)..sources.length]

          sources.delete(:defaults) 
          sources << "application" if defined?(RAILS_ROOT) && File.exists?("#{RAILS_ROOT}/public/javascripts/application.js") 
        end

        sources.collect { |source|
          source = javascript_path(source)        
          content_tag("script", "", { "type" => "text/javascript", "src" => source }.merge(options))
        }.join("\n")
      end
      
      # Register one or more additional JavaScript files to be included when
      #   
      #   javascript_include_tag :defaults
      #
      # is called. This method is intended to be called only from plugin initialization
      # to register extra .js files the plugin installed in <tt>public/javascripts</tt>.
      def self.register_javascript_include_default(*sources)
        @@javascript_default_sources.concat(sources)
      end
      
      def self.reset_javascript_include_default #:nodoc:
        @@javascript_default_sources = JAVASCRIPT_DEFAULT_SOURCES.dup
      end

      # Returns path to a stylesheet asset. Example:
      #
      #   stylesheet_path "style" # => /stylesheets/style.css
      def stylesheet_path(source)
        compute_public_path(source, 'stylesheets', 'css')
      end

      # Returns a css link tag per source given as argument. Examples:
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
        sources.collect { |source|
          source = stylesheet_path(source)
          tag("link", { "rel" => "Stylesheet", "type" => "text/css", "media" => "screen", "href" => source }.merge(options))
        }.join("\n")
      end

      # Returns path to an image asset. Example:
      #
      # The +src+ can be supplied as a...
      # * full path, like "/my_images/image.gif"
      # * file name, like "rss.gif", that gets expanded to "/images/rss.gif"
      # * file name without extension, like "logo", that gets expanded to "/images/logo.png"
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

      # Returns an image tag converting the +options+ into html options on the tag, but with these special cases:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the +src+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "XxY", so "30x45" becomes width="30" and height="45"
      #
      # The +src+ can be supplied as a...
      # * full path, like "/my_images/image.gif"
      # * file name, like "rss.gif", that gets expanded to "/images/rss.gif"
      # * file name without extension, like "logo", that gets expanded to "/images/logo.png"
      def image_tag(source, options = {})
        options.symbolize_keys!
                
        options[:src] = image_path(source)
        options[:alt] ||= File.basename(options[:src], '.*').split('.').first.capitalize
        
        if options[:size]
          options[:width], options[:height] = options[:size].split("x")
          options.delete :size
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
            source << '?' + asset_id if defined?(RAILS_ROOT) and not asset_id.blank?
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
