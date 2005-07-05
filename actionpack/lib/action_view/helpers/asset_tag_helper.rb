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
      def auto_discovery_link_tag(type = :rss, options = {}, tag_options = {})
        tag(
          "link", 
          "rel" => tag_options[:rel] || "alternate",
          "type" => tag_options[:type] || "application/#{type}+xml",
          "title" => tag_options[:title] || type.to_s.upcase,
          "href" => url_for(options.merge(:only_path => false))
        )
      end

      # Returns path to a javascript asset. Example:
      #
      #   javascript_path "xmlhr" # => /javascripts/xmlhr.js
      def javascript_path(source)
        compute_public_path(source, 'javascripts', 'js')        
      end

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
      #     <script type="text/javascript" src="/javascripts/controls.js"></script>
      #     <script type="text/javascript" src="/javascripts/dragdrop.js"></script>      
      def javascript_include_tag(*sources)
        options = sources.last.is_a?(Hash) ? sources.pop.stringify_keys : { }
        sources = ['prototype', 'effects', 'controls', 'dragdrop'] if sources.first == :defaults
        sources.collect { |source|
          source = javascript_path(source)        
          content_tag("script", "", { "type" => "text/javascript", "src" => source }.merge(options))
        }.join("\n")
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
        compute_public_path(source, 'images', 'png')
      end

      # Returns an image tag converting the +options+ instead html options on the tag, but with these special cases:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the +src+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "XxY", so "30x45" becomes width="30" and height="45"
      #
      # The +src+ can be supplied as a...
      # * full path, like "/my_images/image.gif"
      # * file name, like "rss.gif", that gets expanded to "/images/rss.gif"
      # * file name without extension, like "logo", that gets expanded to "/images/logo.png"
      def image_tag(source, options = {})
        options.symbolize_keys
                
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
          source = "/#{dir}/#{source}" unless source.include?("/")
          source = "#{source}.#{ext}" unless source.include?(".")
          source = "#{@request.relative_url_root}#{source}" unless %r{^[-a-z]+://} =~ source
          ActionController::Base.asset_host + source
        end
    end
  end
end
