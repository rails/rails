require 'fileutils'
require 'active_support/core_ext/class/attribute_accessors'

module ActionController #:nodoc:
  module Caching
    # Page caching is an approach to caching where the entire action output of is stored as a HTML file that the web server
    # can serve without going through Action Pack. This is the fastest way to cache your content as opposed to going dynamically
    # through the process of generating the content. Unfortunately, this incredible speed-up is only available to stateless pages
    # where all visitors are treated the same. Content management systems -- including weblogs and wikis -- have many pages that are
    # a great fit for this approach, but account-based systems where people log in and manipulate their own data are often less
    # likely candidates.
    #
    # Specifying which actions to cache is done through the <tt>caches_page</tt> class method:
    #
    #   class WeblogController < ActionController::Base
    #     caches_page :show, :new
    #   end
    #
    # This will generate cache files such as <tt>weblog/show/5.html</tt> and <tt>weblog/new.html</tt>, which match the URLs used
    # that would normally trigger dynamic page generation. Page caching works by configuring a web server to first check for the
    # existence of files on disk, and to serve them directly when found, without passing the request through to Action Pack.
    # This is much faster than handling the full dynamic request in the usual way.
    #
    # Expiration of the cache is handled by deleting the cached file, which results in a lazy regeneration approach where the cache
    # is not restored before another hit is made against it. The API for doing so mimics the options from +url_for+ and friends:
    #
    #   class WeblogController < ActionController::Base
    #     def update
    #       List.update(params[:list][:id], params[:list])
    #       expire_page :action => "show", :id => params[:list][:id]
    #       redirect_to :action => "show", :id => params[:list][:id]
    #     end
    #   end
    #
    # Additionally, you can expire caches using Sweepers that act on changes in the model to determine when a cache is supposed to be
    # expired.
    module Pages
      extend ActiveSupport::Concern

      included do
        # The cache directory should be the document root for the web server and is set using <tt>Base.page_cache_directory = "/document/root"</tt>.
        # For Rails, this directory has already been set to Rails.public_path (which is usually set to <tt>Rails.root + "/public"</tt>). Changing
        # this setting can be useful to avoid naming conflicts with files in <tt>public/</tt>, but doing so will likely require configuring your
        # web server to look in the new location for cached files.
        class_attribute :page_cache_directory
        self.page_cache_directory ||= ''

        # Most Rails requests do not have an extension, such as <tt>/weblog/new</tt>. In these cases, the page caching mechanism will add one in
        # order to make it easy for the cached files to be picked up properly by the web server. By default, this cache extension is <tt>.html</tt>.
        # If you want something else, like <tt>.php</tt> or <tt>.shtml</tt>, just set Base.page_cache_extension. In cases where a request already has an
        # extension, such as <tt>.xml</tt> or <tt>.rss</tt>, page caching will not add an extension. This allows it to work well with RESTful apps.
        class_attribute :page_cache_extension
        self.page_cache_extension ||= '.html'

        # The compression used for gzip. If false (default), the page is not compressed.
        # If can be a symbol showing the ZLib compression method, for example, :best_compression
        # or :best_speed or an integer configuring the compression level.
        class_attribute :page_cache_compression
        self.page_cache_compression ||= false
      end

      module ClassMethods
        # Expires the page that was cached with the +path+ as a key. Example:
        #   expire_page "/lists/show"
        def expire_page(path)
          return unless perform_caching
          path = page_cache_path(path)

          instrument_page_cache :expire_page, path do
            File.delete(path) if File.exist?(path)
            File.delete(path + '.gz') if File.exist?(path + '.gz')
          end
        end

        # Manually cache the +content+ in the key determined by +path+. Example:
        #   cache_page "I'm the cached content", "/lists/show"
        def cache_page(content, path, extension = nil, gzip = Zlib::BEST_COMPRESSION)
          return unless perform_caching
          path = page_cache_path(path, extension)

          instrument_page_cache :write_page, path do
            FileUtils.makedirs(File.dirname(path))
            File.open(path, "wb+") { |f| f.write(content) }
            if gzip
              Zlib::GzipWriter.open(path + '.gz', gzip) { |f| f.write(content) }
            end
          end
        end

        # Caches the +actions+ using the page-caching approach that'll store
        # the cache in a path within the page_cache_directory that
        # matches the triggering url.
        #
        # You can also pass a :gzip option to override the class configuration one.
        #
        # Usage:
        #
        #   # cache the index action
        #   caches_page :index
        #
        #   # cache the index action except for JSON requests
        #   caches_page :index, :if => Proc.new { |c| !c.request.format.json? }
        #
        #   # don't gzip images
        #   caches_page :image, :gzip => false
        def caches_page(*actions)
          return unless perform_caching
          options = actions.extract_options!

          gzip_level = options.fetch(:gzip, page_cache_compression)
          gzip_level = case gzip_level
          when Symbol
            Zlib.const_get(gzip_level.to_s.upcase)
          when Fixnum
            gzip_level
          when false
            nil
          else
            Zlib::BEST_COMPRESSION
          end

          after_filter({:only => actions}.merge(options)) do |c|
            c.cache_page(nil, nil, gzip_level)
          end
        end

        private
          def page_cache_file(path, extension)
            name = (path.empty? || path == "/") ? "/index" : URI.parser.unescape(path.chomp('/'))
            unless (name.split('/').last || name).include? '.'
              name << (extension || self.page_cache_extension)
            end
            return name
          end

          def page_cache_path(path, extension = nil)
            page_cache_directory.to_s + page_cache_file(path, extension)
          end

          def instrument_page_cache(name, path)
            ActiveSupport::Notifications.instrument("#{name}.action_controller", :path => path){ yield }
          end
      end

      # Expires the page that was cached with the +options+ as a key. Example:
      #   expire_page :controller => "lists", :action => "show"
      def expire_page(options = {})
        return unless self.class.perform_caching

        if options.is_a?(Hash)
          if options[:action].is_a?(Array)
            options[:action].each do |action|
              self.class.expire_page(url_for(options.merge(:only_path => true, :action => action)))
            end
          else
            self.class.expire_page(url_for(options.merge(:only_path => true)))
          end
        else
          self.class.expire_page(options)
        end
      end

      # Manually cache the +content+ in the key determined by +options+. If no content is provided, the contents of response.body is used.
      # If no options are provided, the url of the current request being handled is used. Example:
      #   cache_page "I'm the cached content", :controller => "lists", :action => "show"
      def cache_page(content = nil, options = nil, gzip = Zlib::BEST_COMPRESSION)
        return unless self.class.perform_caching && caching_allowed?

        path = case options
          when Hash
            url_for(options.merge(:only_path => true, :format => params[:format]))
          when String
            options
          else
            request.path
        end

        if (type = Mime::LOOKUP[self.content_type]) && (type_symbol = type.symbol).present?
          extension = ".#{type_symbol}"
        end

        self.class.cache_page(content || response.body, path, extension, gzip)
      end

    end
  end
end
