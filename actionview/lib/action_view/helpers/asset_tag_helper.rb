require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/hash/keys"
require "action_view/helpers/asset_url_helper"
require "action_view/helpers/tag_helper"

module ActionView
  # = Action View Asset Tag Helpers
  module Helpers #:nodoc:
    # This module provides methods for generating HTML that links views to assets such
    # as images, JavaScripts, stylesheets, and feeds. These methods do not verify
    # the assets exist before linking to them:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/assets/application.css?body=1" media="screen" rel="stylesheet" />
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
      # When passing paths, the ".js" extension is optional.  If you do not want ".js"
      # appended to the path <tt>extname: false</tt> can be set on the options.
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
      #   javascript_include_tag "template.jst", extname: false
      #   # => <script src="/assets/template.jst?1284139606"></script>
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
      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!("protocol", "extname", "host", "skip_pipeline").symbolize_keys
        sources.uniq.map { |source|
          tag_options = {
            "src" => path_to_javascript(source, path_options)
          }.merge!(options)
          content_tag("script".freeze, "", tag_options)
        }.join("\n").html_safe
      end

      # Returns a stylesheet link tag for the sources specified as arguments. If
      # you don't specify an extension, <tt>.css</tt> will be appended automatically.
      # You can modify the link attributes by passing a hash as the last argument.
      # For historical reasons, the 'media' attribute will always be present and defaults
      # to "screen", so you must explicitly set it to "all" for the stylesheet(s) to
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
      def stylesheet_link_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!("protocol", "host", "skip_pipeline").symbolize_keys
        sources.uniq.map { |source|
          tag_options = {
            "rel" => "stylesheet",
            "media" => "screen",
            "href" => path_to_stylesheet(source, path_options)
          }.merge!(options)
          tag(:link, tag_options)
        }.join("\n").html_safe
      end

      # Returns a link tag that browsers and feed readers can use to auto-detect
      # an RSS or Atom feed. The +type+ can either be <tt>:rss</tt> (default) or
      # <tt>:atom</tt>. Control the link options in url_for format using the
      # +url_options+. You can modify the LINK tag itself in +tag_options+.
      #
      # ==== Options
      #
      # * <tt>:rel</tt>  - Specify the relation of this link, defaults to "alternate"
      # * <tt>:type</tt>  - Override the auto-generated mime type
      # * <tt>:title</tt>  - Specify the title of the link, defaults to the +type+
      #
      # ==== Examples
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
      #   # => <link rel="alternate" type="application/rss+xml" title="Example RSS" href="http://www.example.com/feed.rss" />
      def auto_discovery_link_tag(type = :rss, url_options = {}, tag_options = {})
        if !(type == :rss || type == :atom) && tag_options[:type].blank?
          raise ArgumentError.new("You should pass :type tag_option key explicitly, because you have passed #{type} type other than :rss or :atom.")
        end

        tag(
          "link",
          "rel"   => tag_options[:rel] || "alternate",
          "type"  => tag_options[:type] || Template::Types[type].to_s,
          "title" => tag_options[:title] || type.to_s.upcase,
          "href"  => url_options.is_a?(Hash) ? url_for(url_options.merge(only_path: false)) : url_options
        )
      end

      # Returns a link tag for a favicon managed by the asset pipeline.
      #
      # If a page has no link like the one generated by this helper, browsers
      # ask for <tt>/favicon.ico</tt> automatically, and cache the file if the
      # request succeeds. If the favicon changes it is hard to get it updated.
      #
      # To have better control applications may let the asset pipeline manage
      # their favicon storing the file under <tt>app/assets/images</tt>, and
      # using this helper to generate its corresponding link tag.
      #
      # The helper gets the name of the favicon file as first argument, which
      # defaults to "favicon.ico", and also supports +:rel+ and +:type+ options
      # to override their defaults, "shortcut icon" and "image/x-icon"
      # respectively:
      #
      #   favicon_link_tag
      #   # => <link href="/assets/favicon.ico" rel="shortcut icon" type="image/x-icon" />
      #
      #   favicon_link_tag 'myicon.ico'
      #   # => <link href="/assets/myicon.ico" rel="shortcut icon" type="image/x-icon" />
      #
      # Mobile Safari looks for a different link tag, pointing to an image that
      # will be used if you add the page to the home screen of an iOS device.
      # The following call would generate such a tag:
      #
      #   favicon_link_tag 'mb-icon.png', rel: 'apple-touch-icon', type: 'image/png'
      #   # => <link href="/assets/mb-icon.png" rel="apple-touch-icon" type="image/png" />
      def favicon_link_tag(source="favicon.ico", options={})
        tag("link", {
          rel: "shortcut icon",
          type: "image/x-icon",
          href: path_to_image(source, skip_pipeline: options.delete(:skip_pipeline))
        }.merge!(options.symbolize_keys))
      end

      # Returns an HTML image tag for the +source+. The +source+ can be a full
      # path or a file.
      #
      # ==== Options
      #
      # You can add HTML attributes using the +options+. The +options+ supports
      # two additional keys for convenience and conformance:
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
      #   image_tag("/icons/icon.gif", data: { title: 'Rails Application' })
      #   # => <img data-title="Rails Application" src="/icons/icon.gif" />
      def image_tag(source, options={})
        options = options.symbolize_keys
        check_for_image_tag_errors(options)

        src = options[:src] = path_to_image(source, skip_pipeline: options.delete(:skip_pipeline))

        unless src.start_with?("cid:") || src.start_with?("data:") || src.blank?
          options[:alt] = options.fetch(:alt) { image_alt(src) }
        end

        options[:width], options[:height] = extract_dimensions(options.delete(:size)) if options[:size]
        tag("img", options)
      end

      # Returns a string suitable for an HTML image tag alt attribute.
      # The +src+ argument is meant to be an image file path.
      # The method removes the basename of the file path and the digest,
      # if any. It also removes hyphens and underscores from file names and
      # replaces them with spaces, returning a space-separated, titleized
      # string.
      #
      # ==== Examples
      #
      #   image_alt('rails.png')
      #   # => Rails
      #
      #   image_alt('hyphenated-file-name.png')
      #   # => Hyphenated file name
      #
      #   image_alt('underscored_file_name.png')
      #   # => Underscored file name
      def image_alt(src)
        File.basename(src, ".*".freeze).sub(/-[[:xdigit:]]{32,64}\z/, "".freeze).tr("-_".freeze, " ".freeze).capitalize
      end

      # Returns an HTML video tag for the +sources+. If +sources+ is a string,
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
      # * <tt>:size</tt> - Supplied as "{Width}x{Height}" or "{Number}", so "30x45" becomes
      #   width="30" and height="45", and "50" becomes width="50" and height="50".
      #   <tt>:size</tt> will be ignored if the value is not in the correct format.
      # * <tt>:poster_skip_pipeline</tt> will bypass the asset pipeline when using
      #   the <tt>:poster</tt> option instead using an asset in the public folder.
      #
      # ==== Examples
      #
      #   video_tag("trailer")
      #   # => <video src="/videos/trailer"></video>
      #   video_tag("trailer.ogg")
      #   # => <video src="/videos/trailer.ogg"></video>
      #   video_tag("trailer.ogg", controls: true, preload: 'none')
      #   # => <video preload="none" controls="controls" src="/videos/trailer.ogg" ></video>
      #   video_tag("trailer.m4v", size: "16x10", poster: "screenshot.png")
      #   # => <video src="/videos/trailer.m4v" width="16" height="10" poster="/assets/screenshot.png"></video>
      #   video_tag("trailer.m4v", size: "16x10", poster: "screenshot.png", poster_skip_pipeline: true)
      #   # => <video src="/videos/trailer.m4v" width="16" height="10" poster="screenshot.png"></video>
      #   video_tag("/trailers/hd.avi", size: "16x16")
      #   # => <video src="/trailers/hd.avi" width="16" height="16"></video>
      #   video_tag("/trailers/hd.avi", size: "16")
      #   # => <video height="16" src="/trailers/hd.avi" width="16"></video>
      #   video_tag("/trailers/hd.avi", height: '32', width: '32')
      #   # => <video height="32" src="/trailers/hd.avi" width="32"></video>
      #   video_tag("trailer.ogg", "trailer.flv")
      #   # => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      #   video_tag(["trailer.ogg", "trailer.flv"])
      #   # => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      #   video_tag(["trailer.ogg", "trailer.flv"], size: "160x120")
      #   # => <video height="120" width="160"><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      def video_tag(*sources)
        options = sources.extract_options!.symbolize_keys
        public_poster_folder = options.delete(:poster_skip_pipeline)
        sources << options
        multiple_sources_tag_builder("video", sources) do |tag_options|
          tag_options[:poster] = path_to_image(tag_options[:poster], skip_pipeline: public_poster_folder) if tag_options[:poster]
          tag_options[:width], tag_options[:height] = extract_dimensions(tag_options.delete(:size)) if tag_options[:size]
        end
      end

      # Returns an HTML audio tag for the +source+.
      # The +source+ can be full path or file that exists in
      # your public audios directory.
      #
      #   audio_tag("sound")
      #   # => <audio src="/audios/sound"></audio>
      #   audio_tag("sound.wav")
      #   # => <audio src="/audios/sound.wav"></audio>
      #   audio_tag("sound.wav", autoplay: true, controls: true)
      #   # => <audio autoplay="autoplay" controls="controls" src="/audios/sound.wav"></audio>
      #   audio_tag("sound.wav", "sound.mid")
      #   # => <audio><source src="/audios/sound.wav" /><source src="/audios/sound.mid" /></audio>
      def audio_tag(*sources)
        multiple_sources_tag_builder("audio", sources)
      end

      private
        def multiple_sources_tag_builder(type, sources)
          options       = sources.extract_options!.symbolize_keys
          skip_pipeline = options.delete(:skip_pipeline)
          sources.flatten!

          yield options if block_given?

          if sources.size > 1
            content_tag(type, options) do
              safe_join sources.map { |source| tag("source", src: send("path_to_#{type}", source, skip_pipeline: skip_pipeline)) }
            end
          else
            options[:src] = send("path_to_#{type}", sources.first, skip_pipeline: skip_pipeline)
            content_tag(type, nil, options)
          end
        end

        def extract_dimensions(size)
          size = size.to_s
          if /\A\d+x\d+\z/.match?(size)
            size.split("x")
          elsif /\A\d+\z/.match?(size)
            [size, size]
          end
        end

        def check_for_image_tag_errors(options)
          if options[:size] && (options[:height] || options[:width])
            raise ArgumentError, "Cannot pass a :size option with a :height or :width option"
          end
        end
    end
  end
end
