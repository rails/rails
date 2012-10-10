require 'active_support/core_ext/file'

module ActionView
  module Helpers
    module AssetTagHelper
      module StylesheetTagHelpers
        extend ActiveSupport::Concern

        # Computes the path to a stylesheet asset in the public stylesheets directory.
        # If the +source+ filename has no extension, <tt>.css</tt> will be appended (except for explicit URIs).
        # Full paths from the document root will be passed through.
        # Used internally by +stylesheet_link_tag+ to build the stylesheet path.
        #
        #   stylesheet_path "style"                                  # => /stylesheets/style.css
        #   stylesheet_path "dir/style.css"                          # => /stylesheets/dir/style.css
        #   stylesheet_path "/dir/style.css"                         # => /dir/style.css
        #   stylesheet_path "http://www.example.com/css/style"       # => http://www.example.com/css/style
        #   stylesheet_path "http://www.example.com/css/style.css"   # => http://www.example.com/css/style.css
        def stylesheet_path(source)
          asset_paths.compute_public_path(source, 'stylesheets', :ext => 'css', :protocol => :request)
        end
        alias_method :path_to_stylesheet, :stylesheet_path # aliased to avoid conflicts with a stylesheet_path named route

        # Computes the full URL to a stylesheet asset in the public stylesheets directory.
        # This will use +stylesheet_path+ internally, so most of their behaviors will be the same.
        def stylesheet_url(source)
          URI.join(current_host, path_to_stylesheet(source)).to_s
        end
        alias_method :url_to_stylesheet, :stylesheet_url # aliased to avoid conflicts with a stylesheet_url named route

        # Returns a stylesheet link tag for the sources specified as arguments. If
        # you don't specify an extension, <tt>.css</tt> will be appended automatically.
        # You can modify the link attributes by passing a hash as the last argument.
        # For historical reasons, the 'media' attribute will always be present and defaults
        # to "screen", so you must explicitely set it to "all" for the stylesheet(s) to
        # apply to all media types.
        #
        #   stylesheet_link_tag "style" # =>
        #     <link href="/stylesheets/style.css" media="screen" rel="stylesheet" />
        #
        #   stylesheet_link_tag "style.css" # =>
        #     <link href="/stylesheets/style.css" media="screen" rel="stylesheet" />
        #
        #   stylesheet_link_tag "http://www.example.com/style.css" # =>
        #     <link href="http://www.example.com/style.css" media="screen" rel="stylesheet" />
        #
        #   stylesheet_link_tag "style", :media => "all" # =>
        #     <link href="/stylesheets/style.css" media="all" rel="stylesheet" />
        #
        #   stylesheet_link_tag "style", :media => "print" # =>
        #     <link href="/stylesheets/style.css" media="print" rel="stylesheet" />
        #
        #   stylesheet_link_tag "random.styles", "/css/stylish" # =>
        #     <link href="/stylesheets/random.styles" media="screen" rel="stylesheet" />
        #     <link href="/css/stylish.css" media="screen" rel="stylesheet" />
        #
        def stylesheet_link_tag(*sources)
          options = sources.extract_options!.stringify_keys
          sources.uniq.map { |source|
            tag_options = {
              "rel" => "stylesheet",
              "media" => "screen",
              "href" => path_to_stylesheet(source)
            }.merge(options)
            tag(:link, tag_options)
          }.join("\n").html_safe
        end
      end
    end
  end
end
