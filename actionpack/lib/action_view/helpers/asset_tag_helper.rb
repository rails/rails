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
      #   auto_discovery_link_tag(:rss, :action => "feed") # =>
      #     <link rel="alternate" type="application/atom+xml" title="ATOM" href="http://www.curenthost.com/controller/feed" />
      def auto_discovery_link_tag(type = :rss, options = {})
        tag(
          "link", "rel" => "alternate", "type" => "application/#{type}+xml", "title" => type.to_s.upcase,
          "href" => url_for(options.merge(:only_path => false))
        )
      end

      # Returns a script include tag per source given as argument. Examples:
      #
      #   javascript_include_tag "xmlhr" # =>
      #     <script language="JavaScript" type="text/javascript" src="/javascripts/xmlhr.js"></script>
      #
      #   javascript_include_tag "common.javascript", "/elsewhere/cools" # =>
      #     <script language="JavaScript" type="text/javascript" src="/javascripts/common.javascript"></script>
      #     <script language="JavaScript" type="text/javascript" src="/elsewhere/cools.js"></script>
      def javascript_include_tag(*sources)
        sources.collect { |source|
          source = "/javascripts/#{source}" unless source.include?("/")
          source = "#{source}.js" unless source.include?(".")
          content_tag("script", "", "language" => "JavaScript", "type" => "text/javascript", "src" => source)
        }.join("\n")
      end

      # Returns a css link tag per source given as argument. Examples:
      #
      #   stylesheet_link_tag "style" # =>
      #     <link href="/stylesheets/style.css" media="screen" rel="Stylesheet" type="text/css" />
      #
      #   stylesheet_link_tag "random.styles", "/css/stylish" # =>
      #     <link href="/stylesheets/random.styles" media="screen" rel="Stylesheet" type="text/css" />
      #     <link href="/css/stylish.css" media="screen" rel="Stylesheet" type="text/css" />
      def stylesheet_link_tag(*sources)
        sources.collect { |source|
          source = "/stylesheets/#{source}" unless source.include?("/")
          source = "#{source}.css" unless source.include?(".")
          tag("link", "rel" => "Stylesheet", "type" => "text/css", "media" => "screen", "href" => source)
        }.join("\n")
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
      def image_tag(src, options = {})
        options.symbolize_keys

        options.update({ :src => src.include?("/") ? src : "/images/#{src}" })
        options[:src] += ".png" unless options[:src].include?(".")

        options[:alt] ||= src.split("/").last.split(".").first.capitalize
        
        if options[:size]
          options[:width], options[:height] = options[:size].split("x")
          options.delete :size
        end

        tag("img", options)
      end
    end
  end
end
