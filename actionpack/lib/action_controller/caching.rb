require 'fileutils'

module ActionController #:nodoc:
  module Caching #:nodoc:
    def self.append_features(base)
      super
      base.send(:include, Pages)
      base.send(:include, Fragments)
    end

    # Page caching is an approach to caching where the entire action output of is stored as a HTML file that the web server 
    # can serve without going through the Action Pack. This can be as much as 100 times faster than going the process of dynamically
    # generating the content. Unfortunately, this incredible speed-up is only available to stateless pages where all visitors
    # are treated the same. Content management systems -- including weblogs and wikis -- have many pages that are a great fit
    # for this approach, but account-based systems where people log in and manipulate their own data are often less likely candidates.
    #
    # Specifying which actions to cach is done through the <tt>caches</tt> class method:
    #
    #   class WeblogController < ActionController::Base
    #     caches :show, :new
    #   end
    #
    # This will generate cache files such as weblog/show/5 and weblog/new, which match the URLs used to trigger the dynamic
    # generation. This is how the web server is able pick up a cache file when it exists and otherwise let the request pass on to
    # the Action Pack to generate it.
    #
    # Expiration of the cache is handled by deleting the cached file, which results in a lazy regeneration approach where the cache
    # is not restored before another hit is made against it. The API for doing so mimics the options from url_for and friends:
    #
    #   class WeblogController < ActionController::Base
    #     def update
    #       List.update(@params["list"]["id"], @params["list"])
    #       expire_page :action => "show", :id => @params["list"]["id"]
    #       redirect_to :action => "show", :id => @params["list"]["id"]
    #     end
    #   end
    #
    # Additionally, you can expire caches -- or even record new caches -- from outside of the controller, such as from a Active
    # Record observer:
    #
    #   class PostObserver < ActiveRecord::Observer
    #     def after_update(post)
    #       WeblogController.expire_page "/weblog/show/#{post.id}"
    #     end
    #   end
    module Pages
      def self.append_features(base)
        super
        base.extend(ClassMethods)
        base.class_eval do
          @@page_cache_directory = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/public" : ""
          cattr_accessor :page_cache_directory
        end
      end

      module ClassMethods
        def cache_page(content, path)
          FileUtils.makedirs(File.dirname(page_cache_directory + path))
          File.open(page_cache_directory + path, "w+") { |f| f.write(content) }
          logger.info "Cached page: #{path}" unless logger.nil?
        end

        def expire_page(path)
          File.delete(page_cache_directory + path) if File.exists?(page_cache_directory + path)
          logger.info "Expired page: #{path}" unless logger.nil?
        end
        
        def caches(*actions)
          actions.each do |action| 
            class_eval "after_filter { |c| c.cache_page if c.action_name == '#{action}' }"
          end
        end
      end

      def expire_page(options = {})
        self.class.expire_page(url_for(options.merge({ :only_path => true })))
      end

      # Expires more than one page at the time. Example:
      #   expire_pages(
      #     { :controller => "lists", :action => "public", :id => list_id },
      #     { :controller => "lists", :action => "show", :id => list_id }
      #   )
      def expire_pages(*options)
        options.each { |option| expire_page(option) }
      end
      
      def cache_page(content = nil, options = {})
        self.class.cache_page(content || @response.body, url_for(options.merge({ :only_path => true })))
      end
    end

    module Fragments
      def self.append_features(base)
        super
        base.class_eval do
          @@cache_store = MemoryStore.new
          cattr_accessor :fragment_cache_store
        end
      end

      def cache_fragment(binding, name, key = nil)
        buffer = eval("_erbout", binding)
        if cache = fragment_cache_store.read(name, key)
          buffer.concat(cache)
          logger.info "Fragment hit: #{name}/#{key}" unless logger.nil?
        else
          pos = buffer.length
          yield
          fragment_cache_store.write(name, key, buffer[pos..-1])
          logger.info "Cached fragment: #{name}/#{key}" unless logger.nil?
        end
      end

      def expire_fragment(name, key = nil)
        fragment_cache_store.delete(name, key)
        logger.info "Expired fragment: #{name}/#{key}" unless logger.nil?
      end
    
      class MemoryStore
        def initialize
          @data = { }
        end
    
        def read(name, key)
          begin
            key ? @data[name][key] : @data[name]
          rescue
            nil
          end
        end

        def write(name, key, value)
          if key
            @data[name] ||= {}
            @data[name][key] = value
          else
            @data[name] = value
          end
        end

        def delete(name, key)
          key ? @data[name].delete(key) : @data.delete(name)
        end
      end

      class DRbStore < MemoryStore
        def initialize(address = 'druby://localhost:9192')
          @data = DRbObject.new(nil, address)
        end    
      end

      class FileStore
        def initialize(cache_path)
          @cache_path = cache_path
        end
    
        def write(name, key, value)
          ensure_cache_path(File.dirname(cache_file_path(name, key)))
          File.open(cache_file_path(name, key), "w+") { |f| f.write(value) }
        end

        def read(name, key)
          begin
            IO.read(cache_file_path(name, key))
          rescue
            nil
          end
        end

        def delete(name, key)
          File.delete(cache_file_path(name, key)) if File.exist?(cache_file_path(name, key))
        end
    
        private
          def cache_file_path(name, key)
            key ? "#{@cache_path}/#{name}/#{key}" : "#{@cache_path}/#{name}"
          end
      
          def ensure_cache_path(path)
            FileUtils.makedirs(path) unless File.exists?(path)
          end
      end
    end
  end
end