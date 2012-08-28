require 'active_support/core_ext/array/extract_options'
require 'active_support/core_ext/hash/keys'
require 'action_view/helpers/asset_tag_helpers/javascript_tag_helpers'
require 'action_view/helpers/asset_tag_helpers/stylesheet_tag_helpers'
require 'action_view/helpers/asset_tag_helpers/asset_paths'
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
    #
    # === Using asset hosts
    #
    # By default, Rails links to these assets on the current host in the public
    # folder, but you can direct Rails to link to assets from a dedicated asset
    # server by setting <tt>ActionController::Base.asset_host</tt> in the application
    # configuration, typically in <tt>config/environments/production.rb</tt>.
    # For example, you'd define <tt>assets.example.com</tt> to be your asset
    # host this way, inside the <tt>configure</tt> block of your environment-specific
    # configuration files or <tt>config/application.rb</tt>:
    #
    #   config.action_controller.asset_host = "assets.example.com"
    #
    # Helpers take that into account:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets.example.com/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets.example.com/assets/application.css" media="screen" rel="stylesheet" />
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
    #   # => <img alt="Rails" src="http://assets0.example.com/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets2.example.com/assets/application.css" media="screen" rel="stylesheet" />
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
    #     "http://assets#{Digest::MD5.hexdigest(source).to_i(16) % 2 + 1}.example.com"
    #   }
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets1.example.com/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://assets2.example.com/assets/application.css" media="screen" rel="stylesheet" />
    #
    # The example above generates "http://assets1.example.com" and
    # "http://assets2.example.com". This option is useful for example if
    # you need fewer/more than four hosts, custom host names, etc.
    #
    # As you see the proc takes a +source+ parameter. That's a string with the
    # absolute path of the asset, for example "/assets/rails.png".
    #
    #    ActionController::Base.asset_host = Proc.new { |source|
    #      if source.ends_with?('.css')
    #        "http://stylesheets.example.com"
    #      else
    #        "http://assets.example.com"
    #      end
    #    }
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="http://assets.example.com/assets/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="http://stylesheets.example.com/assets/application.css" media="screen" rel="stylesheet" />
    #
    # Alternatively you may ask for a second parameter +request+. That one is
    # particularly useful for serving assets from an SSL-protected page. The
    # example proc below disables asset hosting for HTTPS connections, while
    # still sending assets for plain HTTP requests from asset hosts. If you don't
    # have SSL certificates for each of the asset hosts this technique allows you
    # to avoid warnings in the client about mixed media.
    #
    #   config.action_controller.asset_host = Proc.new { |source, request|
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
    #   config.action_controller.asset_path = proc { |asset_path|
    #     "/release-#{RELEASE_NUMBER}#{asset_path}"
    #   }
    #
    # This example would cause the following behavior on all servers no
    # matter when they were deployed:
    #
    #   image_tag("rails.png")
    #   # => <img alt="Rails" src="/release-12345/images/rails.png" />
    #   stylesheet_link_tag("application")
    #   # => <link href="/release-12345/stylesheets/application.css?1232285206" media="screen" rel="stylesheet" />
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
      include TagHelper
      include JavascriptTagHelpers
      include StylesheetTagHelpers
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
      # ==== Examples
      #  auto_discovery_link_tag
      #  # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/action" />
      #  auto_discovery_link_tag(:atom)
      #  # => <link rel="alternate" type="application/atom+xml" title="ATOM" href="http://www.currenthost.com/controller/action" />
      #  auto_discovery_link_tag(:rss, {:action => "feed"})
      #  # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/controller/feed" />
      #  auto_discovery_link_tag(:rss, {:action => "feed"}, {:title => "My RSS"})
      #  # => <link rel="alternate" type="application/rss+xml" title="My RSS" href="http://www.currenthost.com/controller/feed" />
      #  auto_discovery_link_tag(:rss, {:controller => "news", :action => "feed"})
      #  # => <link rel="alternate" type="application/rss+xml" title="RSS" href="http://www.currenthost.com/news/feed" />
      #  auto_discovery_link_tag(:rss, "http://www.example.com/feed.rss", {:title => "Example RSS"})
      #  # => <link rel="alternate" type="application/rss+xml" title="Example RSS" href="http://www.example.com/feed" />
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

      #   <%= favicon_link_tag %>
      #
      # generates
      #
      #   <link href="/assets/favicon.ico" rel="shortcut icon" type="image/vnd.microsoft.icon" />
      #
      # You may specify a different file in the first argument:
      #
      #   <%= favicon_link_tag '/myicon.ico' %>
      #
      # That's passed to +path_to_image+ as is, so it gives
      #
      #   <link href="/myicon.ico" rel="shortcut icon" type="image/vnd.microsoft.icon" />
      #
      # The helper accepts an additional options hash where you can override "rel" and "type".
      #
      # For example, Mobile Safari looks for a different LINK tag, pointing to an image that
      # will be used if you add the page to the home screen of an iPod Touch, iPhone, or iPad.
      # The following call would generate such a tag:
      #
      #   <%= favicon_link_tag 'mb-icon.png', :rel => 'apple-touch-icon', :type => 'image/png' %>
      def favicon_link_tag(source='favicon.ico', options={})
        tag('link', {
          :rel  => 'shortcut icon',
          :type => 'image/vnd.microsoft.icon',
          :href => path_to_image(source)
        }.merge(options.symbolize_keys))
      end

      # Computes the path to an image asset.
      # Full paths from the document root will be passed through.
      # Used internally by +image_tag+ to build the image path:
      #
      #   image_path("edit")                                         # => "/assets/edit"
      #   image_path("edit.png")                                     # => "/assets/edit.png"
      #   image_path("icons/edit.png")                               # => "/assets/icons/edit.png"
      #   image_path("/icons/edit.png")                              # => "/icons/edit.png"
      #   image_path("http://www.example.com/img/edit.png")          # => "http://www.example.com/img/edit.png"
      #
      # If you have images as application resources this method may conflict with their named routes.
      # The alias +path_to_image+ is provided to avoid that. Rails uses the alias internally, and
      # plugin authors are encouraged to do so.
      def image_path(source)
        source.present? ? asset_paths.compute_public_path(source, 'images') : ""
      end
      alias_method :path_to_image, :image_path # aliased to avoid conflicts with an image_path named route

      # Computes the full URL to an image asset.
      # This will use +image_path+ internally, so most of their behaviors will be the same.
      def image_url(source)
        URI.join(current_host, path_to_image(source)).to_s
      end
      alias_method :url_to_image, :image_url # aliased to avoid conflicts with an image_url named route

      # Computes the path to a video asset in the public videos directory.
      # Full paths from the document root will be passed through.
      # Used internally by +video_tag+ to build the video path.
      #
      #   video_path("hd")                                            # => /videos/hd
      #   video_path("hd.avi")                                        # => /videos/hd.avi
      #   video_path("trailers/hd.avi")                               # => /videos/trailers/hd.avi
      #   video_path("/trailers/hd.avi")                              # => /trailers/hd.avi
      #   video_path("http://www.example.com/vid/hd.avi")             # => http://www.example.com/vid/hd.avi
      def video_path(source)
        asset_paths.compute_public_path(source, 'videos')
      end
      alias_method :path_to_video, :video_path # aliased to avoid conflicts with a video_path named route

      # Computes the full URL to a video asset in the public videos directory.
      # This will use +video_path+ internally, so most of their behaviors will be the same.
      def video_url(source)
        URI.join(current_host, path_to_video(source)).to_s
      end
      alias_method :url_to_video, :video_url # aliased to avoid conflicts with an video_url named route

      # Computes the path to an audio asset in the public audios directory.
      # Full paths from the document root will be passed through.
      # Used internally by +audio_tag+ to build the audio path.
      #
      #   audio_path("horse")                                            # => /audios/horse
      #   audio_path("horse.wav")                                        # => /audios/horse.wav
      #   audio_path("sounds/horse.wav")                                 # => /audios/sounds/horse.wav
      #   audio_path("/sounds/horse.wav")                                # => /sounds/horse.wav
      #   audio_path("http://www.example.com/sounds/horse.wav")          # => http://www.example.com/sounds/horse.wav
      def audio_path(source)
        asset_paths.compute_public_path(source, 'audios')
      end
      alias_method :path_to_audio, :audio_path # aliased to avoid conflicts with an audio_path named route

      # Computes the full URL to an audio asset in the public audios directory.
      # This will use +audio_path+ internally, so most of their behaviors will be the same.
      def audio_url(source)
        URI.join(current_host, path_to_audio(source)).to_s
      end
      alias_method :url_to_audio, :audio_url # aliased to avoid conflicts with an audio_url named route

      # Computes the path to a font asset.
      # Full paths from the document root will be passed through.
      #
      #   font_path("font")                                           # => /assets/font
      #   font_path("font.ttf")                                       # => /assets/font.ttf
      #   font_path("dir/font.ttf")                                   # => /assets/dir/font.ttf
      #   font_path("/dir/font.ttf")                                  # => /dir/font.ttf
      #   font_path("http://www.example.com/dir/font.ttf")            # => http://www.example.com/dir/font.ttf
      def font_path(source)
        asset_paths.compute_public_path(source, 'fonts')
      end
      alias_method :path_to_font, :font_path # aliased to avoid conflicts with an font_path named route

      # Computes the full URL to a font asset.
      # This will use +font_path+ internally, so most of their behaviors will be the same.
      def font_url(source)
        URI.join(current_host, path_to_font(source)).to_s
      end
      alias_method :url_to_font, :font_url # aliased to avoid conflicts with an font_url named route

      # Returns an html image tag for the +source+. The +source+ can be a full
      # path or a file.
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
      #
      #  image_tag("icon")
      #  # => <img src="/assets/icon" alt="Icon" />
      #  image_tag("icon.png")
      #  # => <img src="/assets/icon.png" alt="Icon" />
      #  image_tag("icon.png", :size => "16x10", :alt => "Edit Entry")
      #  # => <img src="/assets/icon.png" width="16" height="10" alt="Edit Entry" />
      #  image_tag("/icons/icon.gif", :size => "16x16")
      #  # => <img src="/icons/icon.gif" width="16" height="16" alt="Icon" />
      #  image_tag("/icons/icon.gif", :height => '32', :width => '32')
      #  # => <img alt="Icon" height="32" src="/icons/icon.gif" width="32" />
      #  image_tag("/icons/icon.gif", :class => "menu_icon")
      #  # => <img alt="Icon" class="menu_icon" src="/icons/icon.gif" />
      def image_tag(source, options={})
        options = options.symbolize_keys

        src = options[:src] = path_to_image(source)

        unless src =~ /^(?:cid|data):/ || src.blank?
          options[:alt] = options.fetch(:alt){ image_alt(src) }
        end

        if size = options.delete(:size)
          options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
        end

        tag("img", options)
      end

      def image_alt(src)
        File.basename(src, '.*').sub(/-[[:xdigit:]]{32}\z/, '').capitalize
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
      #  video_tag("trailer")
      #  # => <video src="/videos/trailer" />
      #  video_tag("trailer.ogg")
      #  # => <video src="/videos/trailer.ogg" />
      #  video_tag("trailer.ogg", :controls => true, :autobuffer => true)
      #  # => <video autobuffer="autobuffer" controls="controls" src="/videos/trailer.ogg" />
      #  video_tag("trailer.m4v", :size => "16x10", :poster => "screenshot.png")
      #  # => <video src="/videos/trailer.m4v" width="16" height="10" poster="/assets/screenshot.png" />
      #  video_tag("/trailers/hd.avi", :size => "16x16")
      #  # => <video src="/trailers/hd.avi" width="16" height="16" />
      #  video_tag("/trailers/hd.avi", :height => '32', :width => '32')
      #  # => <video height="32" src="/trailers/hd.avi" width="32" />
      #  video_tag("trailer.ogg", "trailer.flv")
      #  # => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      #  video_tag(["trailer.ogg", "trailer.flv"])
      #  # => <video><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      #  video_tag(["trailer.ogg", "trailer.flv"], :size => "160x120")
      #  # => <video height="120" width="160"><source src="/videos/trailer.ogg" /><source src="/videos/trailer.flv" /></video>
      def video_tag(*sources)
        multiple_sources_tag('video', sources) do |options|
          options[:poster] = path_to_image(options[:poster]) if options[:poster]

          if size = options.delete(:size)
            options[:width], options[:height] = size.split("x") if size =~ %r{^\d+x\d+$}
          end
        end
      end

      # Returns an html audio tag for the +source+.
      # The +source+ can be full path or file that exists in
      # your public audios directory.
      #
      #   audio_tag("sound")  # =>
      #     <audio src="/audios/sound" />
      #   audio_tag("sound.wav")  # =>
      #     <audio src="/audios/sound.wav" />
      #   audio_tag("sound.wav", :autoplay => true, :controls => true)  # =>
      #     <audio autoplay="autoplay" controls="controls" src="/audios/sound.wav" />
      #   audio_tag("sound.wav", "sound.mid")  # =>
      #     <audio><source src="/audios/sound.wav" /><source src="/audios/sound.mid" /></audio>
      def audio_tag(*sources)
        multiple_sources_tag('audio', sources)
      end

      private

        def asset_paths
          @asset_paths ||= AssetTagHelper::AssetPaths.new(config, controller)
        end

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

        def current_host
          url_for(:only_path => false)
        end
    end
  end
end
