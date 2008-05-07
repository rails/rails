require 'fileutils'
require 'uri'

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
    # This will generate cache files such as <tt>weblog/show/5.html</tt> and <tt>weblog/new.html</tt>,
    # which match the URLs used to trigger the dynamic generation. This is how the web server is able
    # pick up a cache file when it exists and otherwise let the request pass on to Action Pack to generate it.
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
    #
    # == Setting the cache directory
    #
    # The cache directory should be the document root for the web server and is set using <tt>Base.page_cache_directory = "/document/root"</tt>.
    # For Rails, this directory has already been set to Rails.public_path (which is usually set to <tt>RAILS_ROOT + "/public"</tt>). Changing
    # this setting can be useful to avoid naming conflicts with files in <tt>public/</tt>, but doing so will likely require configuring your
    # web server to look in the new location for cached files.
    #
    # == Setting the cache extension
    #
    # Most Rails requests do not have an extension, such as <tt>/weblog/new</tt>. In these cases, the page caching mechanism will add one in
    # order to make it easy for the cached files to be picked up properly by the web server. By default, this cache extension is <tt>.html</tt>.
    # If you want something else, like <tt>.php</tt> or <tt>.shtml</tt>, just set Base.page_cache_extension. In cases where a request already has an
    # extension, such as <tt>.xml</tt> or <tt>.rss</tt>, page caching will not add an extension. This allows it to work well with RESTful apps.
    module Pages
      def self.included(base) #:nodoc:
        base.extend(ClassMethods)
        base.class_eval do
          @@page_cache_directory = defined?(Rails.public_path) ? Rails.public_path : ""
          cattr_accessor :page_cache_directory

          @@page_cache_extension = '.html'
          cattr_accessor :page_cache_extension
        end
      end

      module ClassMethods
        # Expires the page that was cached with the +path+ as a key. Example:
        #   expire_page "/lists/show"
        def expire_page(path)
          return unless perform_caching

          benchmark "Expired page: #{page_cache_file(path)}" do
            File.delete(page_cache_path(path)) if File.exist?(page_cache_path(path))
          end
        end

        # Manually cache the +content+ in the key determined by +path+. Example:
        #   cache_page "I'm the cached content", "/lists/show"
        def cache_page(content, path)
          return unless perform_caching

          benchmark "Cached page: #{page_cache_file(path)}" do
            FileUtils.makedirs(File.dirname(page_cache_path(path)))
            File.open(page_cache_path(path), "wb+") { |f| f.write(content) }
          end
        end

        # Caches the +actions+ using the page-caching approach that'll store the cache in a path within the page_cache_directory that
        # matches the triggering url.
        #
        # Usage:
        #
        #   # cache the index action
        #   caches_page :index
        #
        #   # cache the index action except for JSON requests
        #   caches_page :index, :if => Proc.new { |c| !c.request.format.json? }
        def caches_page(*actions)
          return unless perform_caching
          options = actions.extract_options!
          after_filter({:only => actions}.merge(options)) { |c| c.cache_page }
        end

        private
          def page_cache_file(path)
            name = (path.empty? || path == "/") ? "/index" : URI.unescape(path.chomp('/'))
            name << page_cache_extension unless (name.split('/').last || name).include? '.'
            return name
          end

          def page_cache_path(path)
            page_cache_directory + page_cache_file(path)
          end
      end

      # Expires the page that was cached with the +options+ as a key. Example:
      #   expire_page :controller => "lists", :action => "show"
      def expire_page(options = {})
        return unless perform_caching

        if options.is_a?(Hash)
          if options[:action].is_a?(Array)
            options[:action].dup.each do |action|
              self.class.expire_page(url_for(options.merge(:only_path => true, :skip_relative_url_root => true, :action => action)))
            end
          else
            self.class.expire_page(url_for(options.merge(:only_path => true, :skip_relative_url_root => true)))
          end
        else
          self.class.expire_page(options)
        end
      end

      # Manually cache the +content+ in the key determined by +options+. If no content is provided, the contents of response.body is used
      # If no options are provided, the requested url is used. Example:
      #   cache_page "I'm the cached content", :controller => "lists", :action => "show"
      def cache_page(content = nil, options = nil)
        return unless perform_caching && caching_allowed

        path = case options
          when Hash
            url_for(options.merge(:only_path => true, :skip_relative_url_root => true, :format => params[:format]))
          when String
            options
          else
            request.path
        end

        self.class.cache_page(content || response.body, path)
      end

      private
        def caching_allowed
          request.get? && response.headers['Status'].to_i == 200
        end
    end
  end
end