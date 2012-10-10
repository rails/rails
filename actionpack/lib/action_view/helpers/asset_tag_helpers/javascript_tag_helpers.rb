require 'active_support/core_ext/file'

module ActionView
  module Helpers
    module AssetTagHelper
      module JavascriptTagHelpers
        extend ActiveSupport::Concern

        # Computes the path to a javascript asset in the public javascripts directory.
        # If the +source+ filename has no extension, .js will be appended (except for explicit URIs)
        # Full paths from the document root will be passed through.
        # Used internally by javascript_include_tag to build the script path.
        #
        #   javascript_path "xmlhr"                              # => /javascripts/xmlhr.js
        #   javascript_path "dir/xmlhr.js"                       # => /javascripts/dir/xmlhr.js
        #   javascript_path "/dir/xmlhr"                         # => /dir/xmlhr.js
        #   javascript_path "http://www.example.com/js/xmlhr"    # => http://www.example.com/js/xmlhr
        #   javascript_path "http://www.example.com/js/xmlhr.js" # => http://www.example.com/js/xmlhr.js
        def javascript_path(source)
          asset_paths.compute_public_path(source, 'javascripts', :ext => 'js')
        end
        alias_method :path_to_javascript, :javascript_path # aliased to avoid conflicts with a javascript_path named route

        # Computes the full URL to a javascript asset in the public javascripts directory.
        # This will use +javascript_path+ internally, so most of their behaviors will be the same.
        def javascript_url(source)
          URI.join(current_host, path_to_javascript(source)).to_s
        end
        alias_method :url_to_javascript, :javascript_url # aliased to avoid conflicts with a javascript_url named route

        # Returns an HTML script tag for each of the +sources+ provided.
        #
        # Sources may be paths to JavaScript files. Relative paths are assumed to be relative
        # to <tt>public/javascripts</tt>, full paths are assumed to be relative to the document
        # root. Relative paths are idiomatic, use absolute paths only when needed.
        #
        # When passing paths, the ".js" extension is optional.
        #
        # You can modify the HTML attributes of the script tag by passing a hash as the
        # last argument.
        #
        #   javascript_include_tag "xmlhr"
        #   # => <script src="/javascripts/xmlhr.js?1284139606"></script>
        #
        #   javascript_include_tag "xmlhr.js"
        #   # => <script src="/javascripts/xmlhr.js?1284139606"></script>
        #
        #   javascript_include_tag "common.javascript", "/elsewhere/cools"
        #   # => <script src="/javascripts/common.javascript?1284139606"></script>
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
          sources.dup.map { |source|
            tag_options = {
              "src" => path_to_javascript(source)
            }.merge(options)
            content_tag(:script, "", tag_options)
          }.join("\n").html_safe
        end
      end
    end
  end
end
