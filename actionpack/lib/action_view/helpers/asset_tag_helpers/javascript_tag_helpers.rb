require 'active_support/concern'
require 'active_support/core_ext/file'
require 'action_view/helpers/asset_tag_helpers/asset_include_tag'

module ActionView
  module Helpers
    module AssetTagHelper

      class JavascriptIncludeTag < AssetIncludeTag
        def asset_name
          'javascript'
        end

        def extension
          'js'
        end

        def asset_tag(source, options)
          content_tag("script", "", { "type" => Mime::JS, "src" => path_to_asset(source) }.merge(options))
        end

        def custom_dir
          config.javascripts_dir
        end

        private

          def expand_sources(sources, recursive = false)
            if sources.include?(:all)
              all_asset_files = (collect_asset_files(custom_dir, ('**' if recursive), "*.#{extension}") - ['application']) << 'application'
              ((determine_source(:defaults, expansions).dup & all_asset_files) + all_asset_files).uniq
            else
              expanded_sources = sources.inject([]) do |list, source|
                determined_source = determine_source(source, expansions)
                update_source_list(list, determined_source)
              end
              add_application_js(expanded_sources, sources)
              expanded_sources
            end
          end

          def add_application_js(expanded_sources, sources)
            if sources.include?(:defaults) && File.exist?(File.join(custom_dir, "application.#{extension}"))
              expanded_sources.delete('application')
              expanded_sources << "application"
            end
          end
      end


      module JavascriptTagHelpers
        extend ActiveSupport::Concern

        module ClassMethods
          # Register one or more javascript files to be included when <tt>symbol</tt>
          # is passed to <tt>javascript_include_tag</tt>. This method is typically intended
          # to be called from plugin initialization to register javascript files
          # that the plugin installed in <tt>public/javascripts</tt>.
          #
          #   ActionView::Helpers::AssetTagHelper.register_javascript_expansion :monkey => ["head", "body", "tail"]
          #
          #   javascript_include_tag :monkey # =>
          #     <script type="text/javascript" src="/javascripts/head.js"></script>
          #     <script type="text/javascript" src="/javascripts/body.js"></script>
          #     <script type="text/javascript" src="/javascripts/tail.js"></script>
          def register_javascript_expansion(expansions)
            js_expansions = JavascriptIncludeTag.expansions
            expansions.each do |key, values|
              js_expansions[key] = (js_expansions[key] || []) | Array(values)
            end
          end
        end

        # Computes the path to a javascript asset in the public javascripts directory.
        # If the +source+ filename has no extension, .js will be appended (except for explicit URIs)
        # Full paths from the document root will be passed through.
        # Used internally by javascript_include_tag to build the script path.
        #
        # ==== Examples
        #   javascript_path "xmlhr"                              # => /javascripts/xmlhr.js
        #   javascript_path "dir/xmlhr.js"                       # => /javascripts/dir/xmlhr.js
        #   javascript_path "/dir/xmlhr"                         # => /dir/xmlhr.js
        #   javascript_path "http://www.example.com/js/xmlhr"    # => http://www.example.com/js/xmlhr
        #   javascript_path "http://www.example.com/js/xmlhr.js" # => http://www.example.com/js/xmlhr.js
        def javascript_path(source)
          asset_paths.compute_public_path(source, 'javascripts', :ext => 'js')
        end
        alias_method :path_to_javascript, :javascript_path # aliased to avoid conflicts with a javascript_path named route

        # Returns an HTML script tag for each of the +sources+ provided.
        #
        # Sources may be paths to JavaScript files. Relative paths are assumed to be relative
        # to <tt>public/javascripts</tt>, full paths are assumed to be relative to the document
        # root. Relative paths are idiomatic, use absolute paths only when needed.
        #
        # When passing paths, the ".js" extension is optional.
        #
        # If the application is not using the asset pipeline, to include the default JavaScript
        # expansion pass <tt>:defaults</tt> as source. By default, <tt>:defaults</tt> loads jQuery,
        # and that can be overridden in <tt>config/application.rb</tt>:
        #
        #   config.action_view.javascript_expansions[:defaults] = %w(foo.js bar.js)
        #
        # When using <tt>:defaults</tt>, if an <tt>application.js</tt> file exists in
        # <tt>public/javascripts</tt> it will be included as well at the end.
        #
        # You can modify the HTML attributes of the script tag by passing a hash as the
        # last argument.
        #
        # ==== Examples
        #   javascript_include_tag "xmlhr"
        #   # => <script type="text/javascript" src="/javascripts/xmlhr.js?1284139606"></script>
        #
        #   javascript_include_tag "xmlhr.js"
        #   # => <script type="text/javascript" src="/javascripts/xmlhr.js?1284139606"></script>
        #
        #   javascript_include_tag "common.javascript", "/elsewhere/cools"
        #   # => <script type="text/javascript" src="/javascripts/common.javascript?1284139606"></script>
        #   #    <script type="text/javascript" src="/elsewhere/cools.js?1423139606"></script>
        #
        #   javascript_include_tag "http://www.example.com/xmlhr"
        #   # => <script type="text/javascript" src="http://www.example.com/xmlhr"></script>
        #
        #   javascript_include_tag "http://www.example.com/xmlhr.js"
        #   # => <script type="text/javascript" src="http://www.example.com/xmlhr.js"></script>
        #
        #   javascript_include_tag :defaults
        #   # => <script type="text/javascript" src="/javascripts/jquery.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/rails.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/application.js?1284139606"></script>
        #
        # * = The application.js file is only referenced if it exists
        #
        # You can also include all JavaScripts in the +javascripts+ directory using <tt>:all</tt> as the source:
        #
        #   javascript_include_tag :all
        #   # => <script type="text/javascript" src="/javascripts/jquery.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/rails.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/application.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/shop.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/checkout.js?1284139606"></script>
        #
        # Note that your defaults of choice will be included first, so they will be available to all subsequently
        # included files.
        #
        # If you want Rails to search in all the subdirectories under <tt>public/javascripts</tt>, you should
        # explicitly set <tt>:recursive</tt>:
        #
        #   javascript_include_tag :all, :recursive => true
        #
        # == Caching multiple JavaScripts into one
        #
        # You can also cache multiple JavaScripts into one file, which requires less HTTP connections to download
        # and can better be compressed by gzip (leading to faster transfers). Caching will only happen if
        # <tt>config.perform_caching</tt> is set to true (which is the case by default for the Rails
        # production environment, but not for the development environment).
        #
        # ==== Examples
        #
        #   # assuming config.perform_caching is false
        #   javascript_include_tag :all, :cache => true
        #   # => <script type="text/javascript" src="/javascripts/jquery.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/rails.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/application.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/shop.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/checkout.js?1284139606"></script>
        #
        #   # assuming config.perform_caching is true
        #   javascript_include_tag :all, :cache => true
        #   # => <script type="text/javascript" src="/javascripts/all.js?1344139789"></script>
        #
        #   # assuming config.perform_caching is false
        #   javascript_include_tag "jquery", "cart", "checkout", :cache => "shop"
        #   # => <script type="text/javascript" src="/javascripts/jquery.js?1284139606"></script>
        #   #    <script type="text/javascript" src="/javascripts/cart.js?1289139157"></script>
        #   #    <script type="text/javascript" src="/javascripts/checkout.js?1299139816"></script>
        #
        #   # assuming config.perform_caching is true
        #   javascript_include_tag "jquery", "cart", "checkout", :cache => "shop"
        #   # => <script type="text/javascript" src="/javascripts/shop.js?1299139816"></script>
        #
        # The <tt>:recursive</tt> option is also available for caching:
        #
        #   javascript_include_tag :all, :cache => true, :recursive => true
        def javascript_include_tag(*sources)
          @javascript_include ||= JavascriptIncludeTag.new(config, asset_paths)
          @javascript_include.include_tag(*sources)
        end
      end
    end
  end
end
