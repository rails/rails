require 'active_support/core_ext/file'
require 'action_view/helpers/asset_tag_helpers/asset_include_tag'

module ActionView
  module Helpers
    module AssetTagHelper

      class StylesheetIncludeTag < AssetIncludeTag #:nodoc:
        def asset_name
          'stylesheet'
        end

        def extension
          'css'
        end

        def asset_tag(source, options)
          # We force the :request protocol here to avoid a double-download bug in IE7 and IE8
          tag("link", { "rel" => "stylesheet", "media" => "screen", "href" => path_to_asset(source, :protocol => :request) }.merge(options))
        end

        def custom_dir
          config.stylesheets_dir
        end
      end


      module StylesheetTagHelpers
        extend ActiveSupport::Concern

        module ClassMethods
          # Register one or more stylesheet files to be included when <tt>symbol</tt>
          # is passed to <tt>stylesheet_link_tag</tt>. This method is typically intended
          # to be called from plugin initialization to register stylesheet files
          # that the plugin installed in <tt>public/stylesheets</tt>.
          #
          #   ActionView::Helpers::AssetTagHelper.register_stylesheet_expansion :monkey => ["head", "body", "tail"]
          #
          #   stylesheet_link_tag :monkey # =>
          #     <link href="/stylesheets/head.css"  media="screen" rel="stylesheet" />
          #     <link href="/stylesheets/body.css"  media="screen" rel="stylesheet" />
          #     <link href="/stylesheets/tail.css"  media="screen" rel="stylesheet" />
          def register_stylesheet_expansion(expansions)
            style_expansions = StylesheetIncludeTag.expansions
            expansions.each do |key, values|
              style_expansions[key] = (style_expansions[key] || []) | Array(values)
            end
          end
        end

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
        # You can also include all styles in the stylesheets directory using <tt>:all</tt> as the source:
        #
        #   stylesheet_link_tag :all # =>
        #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" />
        #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" />
        #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" />
        #
        # If you want Rails to search in all the subdirectories under stylesheets, you should explicitly set <tt>:recursive</tt>:
        #
        #   stylesheet_link_tag :all, :recursive => true
        #
        # == Caching multiple stylesheets into one
        #
        # You can also cache multiple stylesheets into one file, which requires less HTTP connections and can better be
        # compressed by gzip (leading to faster transfers). Caching will only happen if +config.perform_caching+
        # is set to true (which is the case by default for the Rails production environment, but not for the development
        # environment). Examples:
        #
        #   stylesheet_link_tag :all, :cache => true # when config.perform_caching is false =>
        #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" />
        #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" />
        #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" />
        #
        #   stylesheet_link_tag :all, :cache => true # when config.perform_caching is true =>
        #     <link href="/stylesheets/all.css"  media="screen" rel="stylesheet" />
        #
        #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when config.perform_caching is false =>
        #     <link href="/stylesheets/shop.css"  media="screen" rel="stylesheet" />
        #     <link href="/stylesheets/cart.css"  media="screen" rel="stylesheet" />
        #     <link href="/stylesheets/checkout.css" media="screen" rel="stylesheet" />
        #
        #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when config.perform_caching is true =>
        #     <link href="/stylesheets/payment.css"  media="screen" rel="stylesheet" />
        #
        # The <tt>:recursive</tt> option is also available for caching:
        #
        #   stylesheet_link_tag :all, :cache => true, :recursive => true
        #
        # To force concatenation (even in development mode) set <tt>:concat</tt> to true. This is useful if
        # you have too many stylesheets for IE to load.
        #
        #   stylesheet_link_tag :all, :concat => true
        #
        def stylesheet_link_tag(*sources)
          @stylesheet_include ||= StylesheetIncludeTag.new(config, asset_paths)
          @stylesheet_include.include_tag(*sources)
        end

      end

    end
  end
end
