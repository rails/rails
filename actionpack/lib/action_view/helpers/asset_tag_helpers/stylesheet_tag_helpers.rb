require 'active_support/concern'
require 'action_view/helpers/asset_tag_helpers/helper_methods'

module ActionView
  module Helpers
    module AssetTagHelper

      module StylesheetTagHelpers
        extend ActiveSupport::Concern
        extend HelperMethods
        include SharedHelpers

        included do
          mattr_accessor :stylesheet_expansions
          self.stylesheet_expansions = { }
        end

        module ClassMethods
          # Register one or more stylesheet files to be included when <tt>symbol</tt>
          # is passed to <tt>stylesheet_link_tag</tt>. This method is typically intended
          # to be called from plugin initialization to register stylesheet files
          # that the plugin installed in <tt>public/stylesheets</tt>.
          #
          #   ActionView::Helpers::AssetTagHelper.register_stylesheet_expansion :monkey => ["head", "body", "tail"]
          #
          #   stylesheet_link_tag :monkey # =>
          #     <link href="/stylesheets/head.css"  media="screen" rel="stylesheet" type="text/css" />
          #     <link href="/stylesheets/body.css"  media="screen" rel="stylesheet" type="text/css" />
          #     <link href="/stylesheets/tail.css"  media="screen" rel="stylesheet" type="text/css" />
          def register_stylesheet_expansion(expansions)
            self.stylesheet_expansions.merge!(expansions)
          end
        end

        # Computes the path to a stylesheet asset in the public stylesheets directory.
        # If the +source+ filename has no extension, <tt>.css</tt> will be appended (except for explicit URIs).
        # Full paths from the document root will be passed through.
        # Used internally by +stylesheet_link_tag+ to build the stylesheet path.
        #
        # ==== Examples
        #   stylesheet_path "style" # => /stylesheets/style.css
        #   stylesheet_path "dir/style.css" # => /stylesheets/dir/style.css
        #   stylesheet_path "/dir/style.css" # => /dir/style.css
        #   stylesheet_path "http://www.railsapplication.com/css/style" # => http://www.railsapplication.com/css/style
        #   stylesheet_path "http://www.railsapplication.com/css/style.css" # => http://www.railsapplication.com/css/style.css
        asset_path :stylesheet, 'css'


        # Returns a stylesheet link tag for the sources specified as arguments. If
        # you don't specify an extension, <tt>.css</tt> will be appended automatically.
        # You can modify the link attributes by passing a hash as the last argument.
        #
        # ==== Examples
        #   stylesheet_link_tag "style" # =>
        #     <link href="/stylesheets/style.css" media="screen" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "style.css" # =>
        #     <link href="/stylesheets/style.css" media="screen" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "http://www.railsapplication.com/style.css" # =>
        #     <link href="http://www.railsapplication.com/style.css" media="screen" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "style", :media => "all" # =>
        #     <link href="/stylesheets/style.css" media="all" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "style", :media => "print" # =>
        #     <link href="/stylesheets/style.css" media="print" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "random.styles", "/css/stylish" # =>
        #     <link href="/stylesheets/random.styles" media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/css/stylish.css" media="screen" rel="stylesheet" type="text/css" />
        #
        # You can also include all styles in the stylesheets directory using <tt>:all</tt> as the source:
        #
        #   stylesheet_link_tag :all # =>
        #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" type="text/css" />
        #
        # If you want Rails to search in all the subdirectories under stylesheets, you should explicitly set <tt>:recursive</tt>:
        #
        #   stylesheet_link_tag :all, :recursive => true
        #
        # == Caching multiple stylesheets into one
        #
        # You can also cache multiple stylesheets into one file, which requires less HTTP connections and can better be
        # compressed by gzip (leading to faster transfers). Caching will only happen if config.perform_caching
        # is set to true (which is the case by default for the Rails production environment, but not for the development
        # environment). Examples:
        #
        # ==== Examples
        #   stylesheet_link_tag :all, :cache => true # when config.perform_caching is false =>
        #     <link href="/stylesheets/style1.css"  media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/stylesheets/styleB.css"  media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/stylesheets/styleX2.css" media="screen" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag :all, :cache => true # when config.perform_caching is true =>
        #     <link href="/stylesheets/all.css"  media="screen" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when config.perform_caching is false =>
        #     <link href="/stylesheets/shop.css"  media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/stylesheets/cart.css"  media="screen" rel="stylesheet" type="text/css" />
        #     <link href="/stylesheets/checkout.css" media="screen" rel="stylesheet" type="text/css" />
        #
        #   stylesheet_link_tag "shop", "cart", "checkout", :cache => "payment" # when config.perform_caching is true =>
        #     <link href="/stylesheets/payment.css"  media="screen" rel="stylesheet" type="text/css" />
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
          options = sources.extract_options!.stringify_keys
          concat  = options.delete("concat")
          cache   = concat || options.delete("cache")
          recursive = options.delete("recursive")

          if concat || (config.perform_caching && cache)
            joined_stylesheet_name = (cache == true ? "all" : cache) + ".css"
            joined_stylesheet_path = File.join(joined_stylesheet_name[/^#{File::SEPARATOR}/] ? config.assets_dir : config.stylesheets_dir, joined_stylesheet_name)

            unless config.perform_caching && File.exists?(joined_stylesheet_path)
              write_asset_file_contents(joined_stylesheet_path, compute_stylesheet_paths(sources, recursive))
            end
            stylesheet_tag(joined_stylesheet_name, options)
          else
            sources = expand_stylesheet_sources(sources, recursive)
            ensure_stylesheet_sources!(sources) if cache
            sources.collect { |source| stylesheet_tag(source, options) }.join("\n").html_safe
          end
        end

        private

          def stylesheet_tag(source, options)
            tag("link", { "rel" => "stylesheet", "type" => Mime::CSS, "media" => "screen", "href" => ERB::Util.html_escape(path_to_stylesheet(source)) }.merge(options), false, false)
          end

          def compute_stylesheet_paths(*args)
            expand_stylesheet_sources(*args).collect { |source| compute_public_path(source, 'stylesheets', 'css', false) }
          end

          def expand_stylesheet_sources(sources, recursive)
            if sources.first == :all
              collect_asset_files(config.stylesheets_dir, ('**' if recursive), '*.css')
            else
              sources.collect do |source|
                determine_source(source, self.stylesheet_expansions)
              end.flatten
            end
          end

          def ensure_stylesheet_sources!(sources)
            sources.each do |source|
              asset_file_path!(path_to_stylesheet(source))
            end
            return sources
          end

      end

    end
  end
end