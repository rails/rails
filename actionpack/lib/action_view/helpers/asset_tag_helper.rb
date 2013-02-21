require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'
require 'action_view/helpers/asset_url_helper'
require 'action_view/helpers/tag_helper'

module ActionView
  # = Action View Asset Tag Helpers
  module Helpers #:nodoc:
    # This module provides methods for generating HTML that links views to assets such
    # as images, javascripts, stylesheets, and feeds. These methods do not verify
    # the assets exist before linking to them:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/assets/application.css?body=1" media="screen" rel="stylesheet" />
    #
    module AssetTagHelper
      extend ActiveSupport::Concern

      include AssetUrlHelper
      include TagHelper

      # Returns an HTML script tag for each of the +sources+ provided.
      #
      # Sources may be paths to JavaScript files. Relative paths are assumed to be relative
      # to <tt>assets/javascripts</tt>, full paths are assumed to be relative to the document
      # root. Relative paths are idiomatic, use absolute paths only when needed.
      #
      # When passing paths, the ".js" extension is optional.
      #
      # You can modify the HTML attributes of the script tag by passing a hash as the
      # last argument.
      #
      # When the Asset Pipeline is enabled, you can pass the name of your manifest as
      # source, and include other JavaScript or CoffeeScript files inside the manifest.
      #
      #   javascript_include_tag "xmlhr"
      #   # => <script src="/assets/xmlhr.js?1284139606"></script>
      #
      #   javascript_include_tag "xmlhr.js"
      #   # => <script src="/assets/xmlhr.js?1284139606"></script>
      #
      #   javascript_include_tag "common.javascript", "/elsewhere/cools"
      #   # => <script src="/assets/common.javascript?1284139606"></script>
      #   #    <script src="/elsewhere/cools.js?1423139606"></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr"
      #   # => <script src="http://www.example.com/xmlhr"></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr.js"
      #   # => <script src="http://www.example.com/xmlhr.js"></script>
      #
      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!('protocol').symbolize_keys

        sources.uniq.map { |source|
          tag_options = {
            "src" => path_to_javascript(source, path_options)
          }.merge(options)
          content_tag(:script, "", tag_options)
        }.join("\n").html_safe
      end

      # Returns a stylesheet link tag for the sources specified as arguments. If
      # you don't specify an extension, <tt>.css</tt> will be appended automatically.
      # You can modify the link attributes by passing a hash as the last argument.
      # For historical reasons, the 'media' attribute will always be present and defaults
      # to "screen", so you must explicitely set it to "all" for the stylesheet(s) to
      # apply to all media types.
      #
      #   stylesheet_link_tag "style"
      #   # => <link href="/assets/style.css" media="screen" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style.css"
      #   # => <link href="/assets/style.css" media="screen" rel="stylesheet" />
      #
      #   stylesheet_link_tag "http://www.example.com/style.css"
      #   # => <link href="http://www.example.com/style.css" media="screen" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style", media: "all"
      #   # => <link href="/assets/style.css" media="all" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style", media: "print"
      #   # => <link href="/assets/style.css" media="print" rel="stylesheet" />
      #
      #   stylesheet_link_tag "random.styles", "/css/stylish"
      #   # => <link href="/assets/random.styles" media="screen" rel="stylesheet" />
      #   #    <link href="/css/stylish.css" media="screen" rel="stylesheet" />
      #
      def stylesheet_link_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!('protocol').symbolize_keys

        sources.uniq.map { |source|
          tag_options = {
            "rel" => "stylesheet",
            "media" => "screen",
            "href" => path_to_stylesheet(source, path_options)
          }.merge(options)
          tag(:link, tag_options)
        }.join("\n").html_safe
      end

      # Returns a link tag that browsers and news readers can use to auto-detect
      # an RSS or Atom feed. The +type+ can either be <tt>:rss</tt> (default) or
      # <tt>:atom</tt>. Control the link options in url_for format using the
      # +url_options+. You can modify the LINK tag itself in +tag_options+.
      #
      # ==== Options
      # * <tt>:rel</tt>  - Specify the relation of this link, defaults to "alternate"
      # * <tt>:type</tt>  - Override the auto-generated mime type
      # * <tt>:title</tt>  - Specify the title of the link, defaults to the +type+
      #
      #   auto_discovery_link_tag
      #   # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/action" />
      #   auto_discovery_link_tag(:atom)
      #   # => <link rel="alternate" type="application/atom+xml" title="ATOM" href="http://www.currenthost.com/controller/action" />
      #   auto_discovery_link_tag(:rss, {action: "feed"})
      #   # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/feed" />
      #   auto_discovery_link_tag(:rss, {action: "feed"}, {title: "My RSS"})
      #   # => <link rel="alternate" type="application/rss+xml" title="My RSS" href="http://www.currenthost.com/controller/feed" />
      #   auto_discovery_link_tag(:rss, {controller: "news", action: "feed"})
      #   # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/news/feed" />
      #   auto_discovery_link_tag(:rss, "http://www.example.com/feed.rss", {title: "Example RSS"})
      #   # => <link rel="alternate" type="application/rss+xml" title="Example RSS" href="http://www.example.com/feed" />
      def auto_discovery_link_tag(type = :rss, url_options = {}, tag_options = {})
        if !(type == :rss || type == :atom) && tag_options[:type].blank?
          message = "You have passed type other than :rss or :atom to auto_discovery_link_tag and haven't supplied " +
                    "the :type option key. This behavior is deprecated and will be remove in Rails 4.1. You should pass " +
                    ":type option explicitly if you want to use other types, for example: " +
                    "auto_discovery_link_tag(:xml, '/feed.xml', :type => 'application/xml')"
          ActiveSupport::Deprecation.warn message
        end

        tag(
          "link",
          "rel"   => tag_options[:rel] || "alternate",
          "type"  => tag_options[:type] || Mime::Type.lookup_by_extension(type.to_s).to_s,
          "title" => tag_options[:title] || type.to_s.upcase,
          "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(:only_path => false)) : url_options
        )
      end

      # Returns a link loading a favicon file. You may specify a different file
      # in the first argument. The helper accepts an additional options hash where
      # you can override "rel" and "type".
      #
      # ==== Options
      # * <tt>:rel</tt>   - Specify the relation of this link, defaults to 'shortcut icon'
      # * <tt>:type</tt>  - Override the auto-generated mime type, defaults to 'image/vnd.microsoft.icon'
      #
      #   favicon_link_tag '/myicon.ico'
      #   # => <link href="/assets/favicon.ico" rel="shortcut icon" type="image/vnd.microsoft.icon" />
      #
      # Mobile Safari looks for a different <link> tag, pointing to an image that
      # will be used if you add the page to the home screen of an iPod Touch, iPhone, or iPad.
      # The following call would generate such a tag:
      #
      #   favicon_link_tag '/mb-icon.png', rel: 'apple-touch-icon', type: 'image/png'
      #   # => <link href="/assets/mb-icon.png" rel="apple-touch-icon" type="image/png" />
      #
      def favicon_link_tag(source='favicon.ico', options={})
        tag('link', {
          :rel  => 'shortcut icon',
          :type => 'image/vnd.microsoft.icon',
          :href => path_to_image(source)
        }.merge(options.symbolize_keys))
      end

      # Returns an HTML image tag for the +source+. The +source+ can be a full
      # path or a file.
      #
      # ==== Options
      # You can add HTML attributes using the +options+. The +options+ supports
      # three additional keys for convenience and conformance:
      #
      # * <tt>:alt</tt>  - If no alt text is given, the file name part of the
      #   +source+ is used (capitalized and without the extension)
      # * <tt>:size</tt> - Supplied as "{Width}x{Height}" or "{Number}", so "30x45" becomes
      #   width="30" and height="45", and "50" becomes width="50" and height="50".
      #   <tt>:size</tt> will be ignored if the value is not in the correct format.
      #
      # ==== Examples
      #
      #   image_tag("icon")
      #   # => <img alt="Icon" src="/assets/icon" />
      #   image_tag("icon.png")
      #   # => <img alt="Icon" src="/assets/icon.png" />
      #   image_tag("icon.png", size: "16x10", alt: "Edit Entry")
      #   # => <img src="/assets/icon.png" width="16" height="10" alt="Edit Entry" />
      #   image_tag("/icons/icon.gif", size: "16")
      #   # => <img src="/icons/icon.gif" width="16" height="16" alt="Icon" />
      #   image_tag("/icons/icon.gif", height: '32', width: '32')
      #   # => <img alt="Icon" height="32" src="/icons/icon.gif" width="32" />
      #   image_tag("/icons/icon.gif", class: "menu_icon")
      #   # => <img alt="Icon" class="menu_icon" src="/icons/icon.gif" />
      def image_tag(source, options={})
        options = options.symbolize_keys

        src = options[:src] = path_to_image(source)

        unless src =~ /^(?:cid|data):/ || src.blank?
          options[:alt] = options.fetch(:alt){ image_alt(src) }
        end

        if size = options.delete(:size)
          options[:width], options[:height] = size.split("x") if size =~ %r{\A\d+x\d+\z}
          options[:width] = options[:height] = size if size =~ %r{\A\d+\z}
        end

        tag("img", options)
      end

      # Returns a string suitable for an html image tag alt attribute.
      # The +src+ argument is meant to be an image file path.
      # The method removes the basename of the file path and the digest,
      # if any. It also removes hyphens and underscores from file names and
      # replaces them with spaces, returning a space-separated, titleized
      # string.
      #
      # ==== Examples
      #
      #   image_tag('rails.png')
      #   # => <img alt="Rails" src="/assets/rails.png" />
      #
      #   image_tag('hyphenated-file-name.png')
      #   # => <img alt="Hyphenated file name" src="/assets/hyphenated-file-name.png" />
      #
      #   image_tag('underscored_file_name.png')
      #   # => <img alt="Underscored file name" src="/assets/underscored_file_name.png" />
      def image_alt(src)
        File.basename(src, '.*').sub(/-[[:xdigit:]]{32}\z/, '').tr('-_', ' ').capitalize
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
      #   video_tag("trailer")
      #   # => <video src="/videos/trailer" />
      #   video_tag("trailer.ogg")
      #   # => <video src="/videos/trailer.ogg" />
      #   video_tag("trailer.ogg", controls: true, autobuffer: true)
      #   # => <video autobuffer="autobuffer" controls="controls" src="/videos/trailer.ogg" />
      #   video_tag("trailer.m4v", size: "16x10", poster: "screenshot.png")
      #   # => <video src="/videos/trailer.m4v" width="16" height="10" poster="/assets/screenshot.png" />
      #   video_tag("/trailers/hd.avi", size: "16x16")
      #   # => <video src="/trailers/hd.avi" width="16" height="16" />
      #   video_tag("/trailers/hd.avi", height: '32', width: '32')
      #   # => <video height="32" src="/trailers/hd.avi" width="32" />
      #   video_tag("trailer.ogg", "trailer.flv")
      #   # => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      #   video_tag(["trailer.ogg", "trailer.flv"])
      #   # => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      #   video_tag(["trailer.ogg", "trailer.flv"], size: "160x120")
      #   # => <video height="120" width="160"><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      def video_tag(*sources)
        multiple_sources_tag('video', sources) do |options|
          options[:poster] = path_to_image(options[:poster]) if options[:poster]

          if size = options.delete(:size)
            options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
          end
        end
      end

      # Returns an HTML audio tag for the +source+.
      # The +source+ can be full path or file that exists in
      # your public audios directory.
      #
      #   audio_tag("sound")
      #   # => <audio src="/audios/sound" />
      #   audio_tag("sound.wav")
      #   # => <audio src="/audios/sound.wav" />
      #   audio_tag("sound.wav", autoplay: true, controls: true)
      #   # => <audio autoplay="autoplay" controls="controls" src="/audios/sound.wav" />
      #   audio_tag("sound.wav", "sound.mid")
      #   # => <audio><source src="/audios/sound.wav" /><source src="/audios/sound.mid" /></audio>
      def audio_tag(*sources)
        multiple_sources_tag('audio', sources)
      end

      private
        def multiple_sources_tag(type, sources)
          options = sources.extract_options!.symbolize_keys
          sources.flatten!

          yield options if block_given?

          if sources.size > 1
            content_tag(type, options) do
              safe_join sources.map { |source| tag("source", :src => send("path_to_#{type}", source)) }
            end
          else
            options[:src] = send("path_to_#{type}", sources.first)
            content_tag(type, nil, options)
          end
        end
    end
  end
end
