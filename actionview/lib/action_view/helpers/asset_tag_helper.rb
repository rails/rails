# frozen_string_literal: true

require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/inclusion"
require "action_view/helpers/asset_url_helper"
require "action_view/helpers/tag_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View Asset Tag \Helpers
    #
    # This module provides methods for generating HTML that links views to assets such
    # as images, JavaScripts, stylesheets, and feeds. These methods do not verify
    # the assets exist before linking to them:
    #
    #   image_tag("rails.png")
    #   # => <img src="/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/assets/application.css?body=1" rel="stylesheet" />
    module AssetTagHelper
      include AssetUrlHelper
      include TagHelper

      mattr_accessor :image_loading
      mattr_accessor :image_decoding
      mattr_accessor :preload_links_header
      mattr_accessor :apply_stylesheet_media_default

      # Returns an HTML script tag for each of the +sources+ provided.
      #
      # Sources may be paths to JavaScript files. Relative paths are assumed to be relative
      # to <tt>assets/javascripts</tt>, full paths are assumed to be relative to the document
      # root. Relative paths are idiomatic, use absolute paths only when needed.
      #
      # When passing paths, the ".js" extension is optional. If you do not want ".js"
      # appended to the path <tt>extname: false</tt> can be set on the options.
      #
      # You can modify the HTML attributes of the script tag by passing a hash as the
      # last argument.
      #
      # When the Asset Pipeline is enabled, you can pass the name of your manifest as
      # source, and include other JavaScript or CoffeeScript files inside the manifest.
      #
      # If the server supports HTTP Early Hints, and the +defer+ option is not
      # enabled, \Rails will push a <tt>103 Early Hints</tt> response that links
      # to the assets.
      #
      # ==== Options
      #
      # When the last parameter is a hash you can add HTML attributes using that
      # parameter. This includes but is not limited to the following options:
      #
      # * <tt>:extname</tt>  - Append an extension to the generated URL unless the extension
      #   already exists. This only applies for relative URLs.
      # * <tt>:protocol</tt>  - Sets the protocol of the generated URL. This option only
      #   applies when a relative URL and +host+ options are provided.
      # * <tt>:host</tt>  - When a relative URL is provided the host is added to the
      #   that path.
      # * <tt>:skip_pipeline</tt>  - This option is used to bypass the asset pipeline
      #   when it is set to true.
      # * <tt>:nonce</tt>  - When set to true, adds an automatic nonce value if
      #   you have Content Security Policy enabled.
      # * <tt>:async</tt>  - When set to +true+, adds the +async+ HTML
      #   attribute, allowing the script to be fetched in parallel to be parsed
      #   and evaluated as soon as possible.
      # * <tt>:defer</tt>  - When set to +true+, adds the +defer+ HTML
      #   attribute, which indicates to the browser that the script is meant to
      #   be executed after the document has been parsed. Additionally, prevents
      #   sending the Preload Links header.
      # * <tt>:nopush</tt>  - Specify if the use of server push is not desired
      #   for the script. Defaults to +true+.
      #
      # Any other specified options will be treated as HTML attributes for the
      # +script+ tag.
      #
      # For more information regarding how the <tt>:async</tt> and <tt>:defer</tt>
      # options affect the <tt><script></tt> tag, please refer to the
      # {MDN docs}[https://developer.mozilla.org/en-US/docs/Web/HTML/Element/script].
      #
      # ==== Examples
      #
      #   javascript_include_tag "xmlhr"
      #   # => <script src="/assets/xmlhr.debug-1284139606.js"></script>
      #
      #   javascript_include_tag "xmlhr", host: "localhost", protocol: "https"
      #   # => <script src="https://localhost/assets/xmlhr.debug-1284139606.js"></script>
      #
      #   javascript_include_tag "template.jst", extname: false
      #   # => <script src="/assets/template.debug-1284139606.jst"></script>
      #
      #   javascript_include_tag "xmlhr.js"
      #   # => <script src="/assets/xmlhr.debug-1284139606.js"></script>
      #
      #   javascript_include_tag "common.javascript", "/elsewhere/cools"
      #   # => <script src="/assets/common.javascript.debug-1284139606.js"></script>
      #   #    <script src="/elsewhere/cools.debug-1284139606.js"></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr"
      #   # => <script src="http://www.example.com/xmlhr"></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr.js"
      #   # => <script src="http://www.example.com/xmlhr.js"></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr.js", nonce: true
      #   # => <script src="http://www.example.com/xmlhr.js" nonce="..."></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr.js", async: true
      #   # => <script src="http://www.example.com/xmlhr.js" async="async"></script>
      #
      #   javascript_include_tag "http://www.example.com/xmlhr.js", defer: true
      #   # => <script src="http://www.example.com/xmlhr.js" defer="defer"></script>
      def javascript_include_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!("protocol", "extname", "host", "skip_pipeline").symbolize_keys
        preload_links = []
        use_preload_links_header = options["preload_links_header"].nil? ? preload_links_header : options.delete("preload_links_header")
        nopush = options["nopush"].nil? ? true : options.delete("nopush")
        crossorigin = options.delete("crossorigin")
        crossorigin = "anonymous" if crossorigin == true
        integrity = options["integrity"]
        rel = options["type"] == "module" ? "modulepreload" : "preload"

        sources_tags = sources.uniq.map { |source|
          href = path_to_javascript(source, path_options)
          if use_preload_links_header && !options["defer"] && href.present? && !href.start_with?("data:")
            preload_link = "<#{href}>; rel=#{rel}; as=script"
            preload_link += "; crossorigin=#{crossorigin}" unless crossorigin.nil?
            preload_link += "; integrity=#{integrity}" unless integrity.nil?
            preload_link += "; nopush" if nopush
            preload_links << preload_link
          end
          tag_options = {
            "src" => href,
            "crossorigin" => crossorigin
          }.merge!(options)
          if tag_options["nonce"] == true
            tag_options["nonce"] = content_security_policy_nonce
          end
          content_tag("script", "", tag_options)
        }.join("\n").html_safe

        if use_preload_links_header
          send_preload_links_header(preload_links)
        end

        sources_tags
      end

      # Returns a stylesheet link tag for the sources specified as arguments.
      #
      # When passing paths, the <tt>.css</tt> extension is optional.
      # If you don't specify an extension, <tt>.css</tt> will be appended automatically.
      # If you do not want <tt>.css</tt> appended to the path,
      # set <tt>extname: false</tt> in the options.
      # You can modify the link attributes by passing a hash as the last argument.
      #
      # If the server supports HTTP Early Hints, \Rails will push a <tt>103 Early
      # Hints</tt> response that links to the assets.
      #
      # ==== Options
      #
      # * <tt>:extname</tt>  - Append an extension to the generated URL unless the extension
      #   already exists. This only applies for relative URLs.
      # * <tt>:protocol</tt>  - Sets the protocol of the generated URL. This option only
      #   applies when a relative URL and +host+ options are provided.
      # * <tt>:host</tt>  - When a relative URL is provided the host is added to the
      #   that path.
      # * <tt>:skip_pipeline</tt>  - This option is used to bypass the asset pipeline
      #   when it is set to true.
      # * <tt>:nonce</tt>  - When set to true, adds an automatic nonce value if
      #   you have Content Security Policy enabled.
      # * <tt>:nopush</tt>  - Specify if the use of server push is not desired
      #   for the stylesheet. Defaults to +true+.
      #
      # ==== Examples
      #
      #   stylesheet_link_tag "style"
      #   # => <link href="/assets/style.css" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style.css"
      #   # => <link href="/assets/style.css" rel="stylesheet" />
      #
      #   stylesheet_link_tag "http://www.example.com/style.css"
      #   # => <link href="http://www.example.com/style.css" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style.less", extname: false, skip_pipeline: true, rel: "stylesheet/less"
      #   # => <link href="/stylesheets/style.less" rel="stylesheet/less">
      #
      #   stylesheet_link_tag "style", media: "all"
      #   # => <link href="/assets/style.css" media="all" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style", media: "print"
      #   # => <link href="/assets/style.css" media="print" rel="stylesheet" />
      #
      #   stylesheet_link_tag "random.styles", "/css/stylish"
      #   # => <link href="/assets/random.styles" rel="stylesheet" />
      #   #    <link href="/css/stylish.css" rel="stylesheet" />
      #
      #   stylesheet_link_tag "style", nonce: true
      #   # => <link href="/assets/style.css" rel="stylesheet" nonce="..." />
      def stylesheet_link_tag(*sources)
        options = sources.extract_options!.stringify_keys
        path_options = options.extract!("protocol", "extname", "host", "skip_pipeline").symbolize_keys
        use_preload_links_header = options["preload_links_header"].nil? ? preload_links_header : options.delete("preload_links_header")
        preload_links = []
        crossorigin = options.delete("crossorigin")
        crossorigin = "anonymous" if crossorigin == true
        nopush = options["nopush"].nil? ? true : options.delete("nopush")
        integrity = options["integrity"]

        sources_tags = sources.uniq.map { |source|
          href = path_to_stylesheet(source, path_options)
          if use_preload_links_header && href.present? && !href.start_with?("data:")
            preload_link = "<#{href}>; rel=preload; as=style"
            preload_link += "; crossorigin=#{crossorigin}" unless crossorigin.nil?
            preload_link += "; integrity=#{integrity}" unless integrity.nil?
            preload_link += "; nopush" if nopush
            preload_links << preload_link
          end
          tag_options = {
            "rel" => "stylesheet",
            "crossorigin" => crossorigin,
            "href" => href
          }.merge!(options)
          if tag_options["nonce"] == true
            tag_options["nonce"] = content_security_policy_nonce
          end

          if apply_stylesheet_media_default && tag_options["media"].blank?
            tag_options["media"] = "screen"
          end

          tag(:link, tag_options)
        }.join("\n").html_safe

        if use_preload_links_header
          send_preload_links_header(preload_links)
        end

        sources_tags
      end

      # Returns a link tag that browsers and feed readers can use to auto-detect
      # an RSS, Atom, or JSON feed. The +type+ can be <tt>:rss</tt> (default),
      # <tt>:atom</tt>, or <tt>:json</tt>. Control the link options in url_for format
      # using the +url_options+. You can modify the LINK tag itself in +tag_options+.
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
      #   auto_discovery_link_tag(:json)
      #   # => <link rel="alternate" type="application/json" title="JSON" href="http://www.currenthost.com/controller/action" />
      #   auto_discovery_link_tag(:rss, {action: "feed"})
      #   # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/feed" />
      #   auto_discovery_link_tag(:rss, {action: "feed"}, {title: "My RSS"})
      #   # => <link rel="alternate" type="application/rss+xml" title="My RSS" href="http://www.currenthost.com/controller/feed" />
      #   auto_discovery_link_tag(:rss, {controller: "news", action: "feed"})
      #   # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/news/feed" />
      #   auto_discovery_link_tag(:rss, "http://www.example.com/feed.rss", {title: "Example RSS"})
      #   # => <link rel="alternate" type="application/rss+xml" title="Example RSS" href="http://www.example.com/feed.rss" />
      def auto_discovery_link_tag(type = :rss, url_options = {}, tag_options = {})
        if !(type == :rss || type == :atom || type == :json) && tag_options[:type].blank?
          raise ArgumentError.new("You should pass :type tag_option key explicitly, because you have passed #{type} type other than :rss, :atom, or :json.")
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
      # to override their defaults, "icon" and "image/x-icon"
      # respectively:
      #
      #   favicon_link_tag
      #   # => <link href="/assets/favicon.ico" rel="icon" type="image/x-icon" />
      #
      #   favicon_link_tag 'myicon.ico'
      #   # => <link href="/assets/myicon.ico" rel="icon" type="image/x-icon" />
      #
      # Mobile Safari looks for a different link tag, pointing to an image that
      # will be used if you add the page to the home screen of an iOS device.
      # The following call would generate such a tag:
      #
      #   favicon_link_tag 'mb-icon.png', rel: 'apple-touch-icon', type: 'image/png'
      #   # => <link href="/assets/mb-icon.png" rel="apple-touch-icon" type="image/png" />
      def favicon_link_tag(source = "favicon.ico", options = {})
        tag("link", {
          rel: "icon",
          type: "image/x-icon",
          href: path_to_image(source, skip_pipeline: options.delete(:skip_pipeline))
        }.merge!(options.symbolize_keys))
      end

      # Returns a link tag that browsers can use to preload the +source+.
      # The +source+ can be the path of a resource managed by asset pipeline,
      # a full path, or an URI.
      #
      # ==== Options
      #
      # * <tt>:type</tt>  - Override the auto-generated mime type, defaults to the mime type for +source+ extension.
      # * <tt>:as</tt>  - Override the auto-generated value for as attribute, calculated using +source+ extension and mime type.
      # * <tt>:crossorigin</tt>  - Specify the crossorigin attribute, required to load cross-origin resources.
      # * <tt>:nopush</tt>  - Specify if the use of server push is not desired for the resource. Defaults to +false+.
      # * <tt>:integrity</tt> - Specify the integrity attribute.
      #
      # ==== Examples
      #
      #   preload_link_tag("custom_theme.css")
      #   # => <link rel="preload" href="/assets/custom_theme.css" as="style" type="text/css" />
      #
      #   preload_link_tag("/videos/video.webm")
      #   # => <link rel="preload" href="/videos/video.mp4" as="video" type="video/webm" />
      #
      #   preload_link_tag(post_path(format: :json), as: "fetch")
      #   # => <link rel="preload" href="/posts.json" as="fetch" type="application/json" />
      #
      #   preload_link_tag("worker.js", as: "worker")
      #   # => <link rel="preload" href="/assets/worker.js" as="worker" type="text/javascript" />
      #
      #   preload_link_tag("//example.com/font.woff2")
      #   # => <link rel="preload" href="//example.com/font.woff2" as="font" type="font/woff2" crossorigin="anonymous"/>
      #
      #   preload_link_tag("//example.com/font.woff2", crossorigin: "use-credentials")
      #   # => <link rel="preload" href="//example.com/font.woff2" as="font" type="font/woff2" crossorigin="use-credentials" />
      #
      #   preload_link_tag("/media/audio.ogg", nopush: true)
      #   # => <link rel="preload" href="/media/audio.ogg" as="audio" type="audio/ogg" />
      #
      def preload_link_tag(source, options = {})
        href = path_to_asset(source, skip_pipeline: options.delete(:skip_pipeline))
        extname = File.extname(source).downcase.delete(".")
        mime_type = options.delete(:type) || Template::Types[extname]&.to_s
        as_type = options.delete(:as) || resolve_link_as(extname, mime_type)
        crossorigin = options.delete(:crossorigin)
        crossorigin = "anonymous" if crossorigin == true || (crossorigin.blank? && as_type == "font")
        integrity = options[:integrity]
        nopush = options.delete(:nopush) || false
        rel = mime_type == "module" ? "modulepreload" : "preload"

        link_tag = tag.link(
          rel: rel,
          href: href,
          as: as_type,
          type: mime_type,
          crossorigin: crossorigin,
          **options.symbolize_keys)

        preload_link = "<#{href}>; rel=#{rel}; as=#{as_type}"
        preload_link += "; type=#{mime_type}" if mime_type
        preload_link += "; crossorigin=#{crossorigin}" if crossorigin
        preload_link += "; integrity=#{integrity}" if integrity
        preload_link += "; nopush" if nopush

        send_preload_links_header([preload_link])

        link_tag
      end

      # Returns an HTML image tag for the +source+. The +source+ can be a full
      # path, a file, or an Active Storage attachment.
      #
      # ==== Options
      #
      # You can add HTML attributes using the +options+. The +options+ supports
      # additional keys for convenience and conformance:
      #
      # * <tt>:size</tt> - Supplied as <tt>"#{width}x#{height}"</tt> or <tt>"#{number}"</tt>, so <tt>"30x45"</tt> becomes
      #   <tt>width="30" height="45"</tt>, and <tt>"50"</tt> becomes <tt>width="50" height="50"</tt>.
      #   <tt>:size</tt> will be ignored if the value is not in the correct format.
      # * <tt>:srcset</tt> - If supplied as a hash or array of <tt>[source, descriptor]</tt>
      #   pairs, each image path will be expanded before the list is formatted as a string.
      #
      # ==== Examples
      #
      # Assets (images that are part of your app):
      #
      #   image_tag("icon")
      #   # => <img src="/assets/icon" />
      #   image_tag("icon.png")
      #   # => <img src="/assets/icon.png" />
      #   image_tag("icon.png", size: "16x10", alt: "Edit Entry")
      #   # => <img src="/assets/icon.png" width="16" height="10" alt="Edit Entry" />
      #   image_tag("/icons/icon.gif", size: "16")
      #   # => <img src="/icons/icon.gif" width="16" height="16" />
      #   image_tag("/icons/icon.gif", height: '32', width: '32')
      #   # => <img height="32" src="/icons/icon.gif" width="32" />
      #   image_tag("/icons/icon.gif", class: "menu_icon")
      #   # => <img class="menu_icon" src="/icons/icon.gif" />
      #   image_tag("/icons/icon.gif", data: { title: 'Rails Application' })
      #   # => <img data-title="Rails Application" src="/icons/icon.gif" />
      #   image_tag("icon.png", srcset: { "icon_2x.png" => "2x", "icon_4x.png" => "4x" })
      #   # => <img src="/assets/icon.png" srcset="/assets/icon_2x.png 2x, /assets/icon_4x.png 4x">
      #   image_tag("pic.jpg", srcset: [["pic_1024.jpg", "1024w"], ["pic_1980.jpg", "1980w"]], sizes: "100vw")
      #   # => <img src="/assets/pic.jpg" srcset="/assets/pic_1024.jpg 1024w, /assets/pic_1980.jpg 1980w" sizes="100vw">
      #
      # Active Storage blobs (images that are uploaded by the users of your app):
      #
      #   image_tag(user.avatar)
      #   # => <img src="/rails/active_storage/blobs/.../tiger.jpg" />
      #   image_tag(user.avatar.variant(resize_to_limit: [100, 100]))
      #   # => <img src="/rails/active_storage/representations/.../tiger.jpg" />
      #   image_tag(user.avatar.variant(resize_to_limit: [100, 100]), size: '100')
      #   # => <img width="100" height="100" src="/rails/active_storage/representations/.../tiger.jpg" />
      def image_tag(source, options = {})
        options = options.symbolize_keys
        check_for_image_tag_errors(options)
        skip_pipeline = options.delete(:skip_pipeline)

        options[:src] = resolve_asset_source("image", source, skip_pipeline)

        if options[:srcset] && !options[:srcset].is_a?(String)
          options[:srcset] = options[:srcset].map do |src_path, size|
            src_path = path_to_image(src_path, skip_pipeline: skip_pipeline)
            "#{src_path} #{size}"
          end.join(", ")
        end

        options[:width], options[:height] = extract_dimensions(options.delete(:size)) if options[:size]

        options[:loading] ||= image_loading if image_loading
        options[:decoding] ||= image_decoding if image_decoding

        tag("img", options)
      end

      # Returns an HTML picture tag for the +sources+. If +sources+ is a string,
      # a single picture tag will be returned. If +sources+ is an array, a picture
      # tag with nested source tags for each source will be returned. The
      # +sources+ can be full paths, files that exist in your public images
      # directory, or Active Storage attachments. Since the picture tag requires
      # an img tag, the last element you provide will be used for the img tag.
      # For complete control over the picture tag, a block can be passed, which
      # will populate the contents of the tag accordingly.
      #
      # ==== Options
      #
      # When the last parameter is a hash you can add HTML attributes using that
      # parameter. Apart from all the HTML supported options, the following are supported:
      #
      # * <tt>:image</tt> - Hash of options that are passed directly to the +image_tag+ helper.
      #
      # ==== Examples
      #
      #   picture_tag("picture.webp")
      #   # => <picture><img src="/images/picture.webp" /></picture>
      #   picture_tag("gold.png", :image => { :size => "20" })
      #   # => <picture><img height="20" src="/images/gold.png" width="20" /></picture>
      #   picture_tag("gold.png", :image => { :size => "45x70" })
      #   # => <picture><img height="70" src="/images/gold.png" width="45" /></picture>
      #   picture_tag("picture.webp", "picture.png")
      #   # => <picture><source srcset="/images/picture.webp" /><source srcset="/images/picture.png" /><img src="/images/picture.png" /></picture>
      #   picture_tag("picture.webp", "picture.png", :image => { alt: "Image" })
      #   # => <picture><source srcset="/images/picture.webp" /><source srcset="/images/picture.png" /><img alt="Image" src="/images/picture.png" /></picture>
      #   picture_tag(["picture.webp", "picture.png"], :image => { alt: "Image" })
      #   # => <picture><source srcset="/images/picture.webp" /><source srcset="/images/picture.png" /><img alt="Image" src="/images/picture.png" /></picture>
      #   picture_tag(:class => "my-class") { tag(:source, :srcset => image_path("picture.webp")) + image_tag("picture.png", :alt => "Image") }
      #   # => <picture class="my-class"><source srcset="/images/picture.webp" /><img alt="Image" src="/images/picture.png" /></picture>
      #   picture_tag { tag(:source, :srcset => image_path("picture-small.webp"), :media => "(min-width: 600px)") + tag(:source, :srcset => image_path("picture-big.webp")) + image_tag("picture.png", :alt => "Image") }
      #   # => <picture><source srcset="/images/picture-small.webp" media="(min-width: 600px)" /><source srcset="/images/picture-big.webp" /><img alt="Image" src="/images/picture.png" /></picture>
      #
      # Active Storage blobs (images that are uploaded by the users of your app):
      #
      #   picture_tag(user.profile_picture)
      #   # => <picture><img src="/rails/active_storage/blobs/.../profile_picture.webp" /></picture>
      def picture_tag(*sources, &block)
        sources.flatten!
        options = sources.extract_options!.symbolize_keys
        image_options = options.delete(:image) || {}
        skip_pipeline = options.delete(:skip_pipeline)

        content_tag("picture", options) do
          if block.present?
            capture(&block).html_safe
          elsif sources.size <= 1
            image_tag(sources.last, image_options)
          else
            source_tags = sources.map do |source|
              tag("source",
               srcset: resolve_asset_source("image", source, skip_pipeline),
               type: Template::Types[File.extname(source)[1..]]&.to_s)
            end
            safe_join(source_tags << image_tag(sources.last, image_options))
          end
        end
      end

      # Returns an HTML video tag for the +sources+. If +sources+ is a string,
      # a single video tag will be returned. If +sources+ is an array, a video
      # tag with nested source tags for each source will be returned. The
      # +sources+ can be full paths, files that exist in your public videos
      # directory, or Active Storage attachments.
      #
      # ==== Options
      #
      # When the last parameter is a hash you can add HTML attributes using that
      # parameter. The following options are supported:
      #
      # * <tt>:poster</tt> - Set an image (like a screenshot) to be shown
      #   before the video loads. The path is calculated like the +src+ of +image_tag+.
      # * <tt>:size</tt> - Supplied as <tt>"#{width}x#{height}"</tt> or <tt>"#{number}"</tt>, so <tt>"30x45"</tt> becomes
      #   <tt>width="30" height="45"</tt>, and <tt>"50"</tt> becomes <tt>width="50" height="50"</tt>.
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
      #   # => <video preload="none" controls="controls" src="/videos/trailer.ogg"></video>
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
      #
      # Active Storage blobs (videos that are uploaded by the users of your app):
      #
      #   video_tag(user.intro_video)
      #   # => <video src="/rails/active_storage/blobs/.../intro_video.mp4"></video>
      def video_tag(*sources)
        options = sources.extract_options!.symbolize_keys
        public_poster_folder = options.delete(:poster_skip_pipeline)
        sources << options
        multiple_sources_tag_builder("video", sources) do |tag_options|
          tag_options[:poster] = path_to_image(tag_options[:poster], skip_pipeline: public_poster_folder) if tag_options[:poster]
          tag_options[:width], tag_options[:height] = extract_dimensions(tag_options.delete(:size)) if tag_options[:size]
        end
      end

      # Returns an HTML audio tag for the +sources+. If +sources+ is a string,
      # a single audio tag will be returned. If +sources+ is an array, an audio
      # tag with nested source tags for each source will be returned. The
      # +sources+ can be full paths, files that exist in your public audios
      # directory, or Active Storage attachments.
      #
      # When the last parameter is a hash you can add HTML attributes using that
      # parameter.
      #
      #   audio_tag("sound")
      #   # => <audio src="/audios/sound"></audio>
      #   audio_tag("sound.wav")
      #   # => <audio src="/audios/sound.wav"></audio>
      #   audio_tag("sound.wav", autoplay: true, controls: true)
      #   # => <audio autoplay="autoplay" controls="controls" src="/audios/sound.wav"></audio>
      #   audio_tag("sound.wav", "sound.mid")
      #   # => <audio><source src="/audios/sound.wav" /><source src="/audios/sound.mid" /></audio>
      #
      # Active Storage blobs (audios that are uploaded by the users of your app):
      #
      #   audio_tag(user.name_pronunciation_audio)
      #   # => <audio src="/rails/active_storage/blobs/.../name_pronunciation_audio.mp3"></audio>
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
              safe_join sources.map { |source| tag("source", src: resolve_asset_source(type, source, skip_pipeline)) }
            end
          else
            options[:src] = resolve_asset_source(type, sources.first, skip_pipeline)
            content_tag(type, nil, options)
          end
        end

        def resolve_asset_source(asset_type, source, skip_pipeline)
          if source.is_a?(Symbol) || source.is_a?(String)
            path_to_asset(source, type: asset_type.to_sym, skip_pipeline: skip_pipeline)
          else
            polymorphic_url(source)
          end
        rescue NoMethodError => e
          raise ArgumentError, "Can't resolve #{asset_type} into URL: #{e}"
        end

        def extract_dimensions(size)
          size = size.to_s
          if /\A\d+(?:\.\d+)?x\d+(?:\.\d+)?\z/.match?(size)
            size.split("x")
          elsif /\A\d+(?:\.\d+)?\z/.match?(size)
            [size, size]
          end
        end

        def check_for_image_tag_errors(options)
          if options[:size] && (options[:height] || options[:width])
            raise ArgumentError, "Cannot pass a :size option with a :height or :width option"
          end
        end

        def resolve_link_as(extname, mime_type)
          case extname
          when "js"  then "script"
          when "css" then "style"
          when "vtt" then "track"
          else
            mime_type.to_s.split("/").first.presence_in(%w(audio video font image))
          end
        end

        # Some HTTP client and proxies have a 4kiB header limit, but more importantly
        # including preload links has diminishing returns so it's best to not go overboard
        MAX_HEADER_SIZE = 1_000 # :nodoc:

        def send_preload_links_header(preload_links, max_header_size: MAX_HEADER_SIZE)
          return if preload_links.empty?
          response_present = respond_to?(:response) && response
          return if response_present && response.sending?

          if respond_to?(:request) && request
            request.send_early_hints("link" => preload_links.join(","))
          end

          if response_present
            header = +response.headers["link"].to_s
            preload_links.each do |link|
              break if header.bytesize + link.bytesize > max_header_size

              if header.empty?
                header << link
              else
                header << "," << link
              end
            end

            response.headers["link"] = header
          end
        end
    end
  end
end
