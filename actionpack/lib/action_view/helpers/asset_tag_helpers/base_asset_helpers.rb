require 'active_support/concern'
require 'active_support/hash_with_indifferent_access'
require 'action_view/helpers/url_helper'
require 'action_view/helpers/tag_helper'
require 'action_view/helpers/asset_tag_helpers/common_asset_helpers'

module ActionView
  module Helpers
    module AssetTagHelper

      module BaseAssetHelpers
        extend HelperMacros
        include CommonAssetHelpers
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
        asset_path :image

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
        asset_path :video

        # Computes the path to an audio asset in the public audios directory.
        # Full paths from the document root will be passed through.
        # Used internally by +audio_tag+ to build the audio path.
        #
        # ==== Examples
        #   audio_path("horse")                                            # => /audios/horse
        #   audio_path("horse.wav")                                        # => /audios/horse.wav
        #   audio_path("sounds/horse.wav")                                 # => /audios/sounds/horse.wav
        #   audio_path("/sounds/horse.wav")                                # => /sounds/horse.wav
        #   audio_path("http://www.railsapplication.com/sounds/horse.wav") # => http://www.railsapplication.com/sounds/horse.wav
        asset_path :audio

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
      end

    end
  end
end