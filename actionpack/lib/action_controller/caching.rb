require 'fileutils'

module ActionController #:nodoc:
  # Caching is a cheap way of speeding up slow applications by keeping the result of calculations, renderings, and database calls
  # around for subsequent requests. Action Controller affords you three approaches in varying levels of granularity: Page, Action, Fragment.
  #
  # You can read more about each approach and the sweeping assistance by clicking the modules below.
  #
  # Note: To turn off all caching and sweeping, set Base.perform_caching = false.
  module Caching
    def self.append_features(base) #:nodoc:
      super
      base.send(:include, Pages, Actions, Fragments, Sweeping)
      base.class_eval do
        @@perform_caching = true
        cattr_accessor :perform_caching
      end
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
    #     caches_page :show, :new
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
    # Additionally, you can expire caches using Sweepers that act on changes in the model to determine when a cache is supposed to be
    # expired.
    #
    # == Setting the cache directory
    #
    # The cache directory should be the document root for the web server and is set using Base.page_cache_directory = "/document/root".
    # For Rails, this directory has already been set to RAILS_ROOT + "/public".
    module Pages
      def self.append_features(base) #:nodoc:
        super
        base.extend(ClassMethods)
        base.class_eval do
          @@page_cache_directory = defined?(RAILS_ROOT) ? "#{RAILS_ROOT}/public" : ""
          cattr_accessor :page_cache_directory
        end
      end

      module ClassMethods
        # Expires the page that was cached with the +path+ as a key. Example:
        #   expire_page "/lists/show"
        def expire_page(path)
          return unless perform_caching
          File.delete(page_cache_path(path)) if File.exists?(page_cache_path(path))
          logger.info "Expired page: #{path}" unless logger.nil?
        end
        
        # Manually cache the +content+ in the key determined by +path+. Example:
        #   cache_page "I'm the cached content", "/lists/show"
        def cache_page(content, path)
          return unless perform_caching
          FileUtils.makedirs(File.dirname(page_cache_path(path)))
          File.open(page_cache_path(path), "w+") { |f| f.write(content) }
          logger.info "Cached page: #{path}" unless logger.nil?
        end

        # Caches the +actions+ using the page-caching approach that'll store the cache in a path within the page_cache_directory that
        # matches the triggering url.
        def caches_page(*actions)
          return unless perform_caching
          actions.each do |action| 
            class_eval "after_filter { |c| c.cache_page if c.action_name == '#{action}' }"
          end
        end
        
        private
          def page_cache_path(path)
            if path[-1,1] == '/'
              page_cache_directory + path + '/index'
            else
              page_cache_directory + path
            end
          end
      end

      # Expires the page that was cached with the +options+ as a key. Example:
      #   expire_page :controller => "lists", :action => "show"
      def expire_page(options = {})
        return unless perform_caching
        if options[:action].is_a?(Array)
          options[:action].dup.each do |action|
            self.class.expire_page(url_for(options.merge({ :only_path => true, :action => action })))
          end
        else
          self.class.expire_page(url_for(options.merge({ :only_path => true })))
        end
      end

      # Manually cache the +content+ in the key determined by +options+. If no content is provided, the contents of @response.body is used
      # If no options are provided, the current +options+ for this action is used. Example:
      #   cache_page "I'm the cached content", :controller => "lists", :action => "show"
      def cache_page(content = nil, options = {})
        return unless perform_caching && caching_allowed
        self.class.cache_page(content || @response.body, url_for(options.merge({ :only_path => true })))
      end

      private
        def caching_allowed
          !@request.post? && (@request.parameters.reject { |k, v| %w( id action controller ).include?(k) }).empty?
        end
    end

    # Action caching is similar to page caching by the fact that the entire output of the response is cached, but unlike page caching, 
    # every request still goes through the Action Pack. The key benefit of this is that filters are run before the cache is served, which
    # allows for authentication and other restrictions on whether someone are supposed to see the cache. Example:
    #
    #   class ListsController < ApplicationController
    #     before_filter :authenticate, :except => :public
    #     caches_page   :public
    #     caches_action :show, :feed
    #   end
    #
    # In this example, the public action doesn't require authentication, so it's possible to use the faster page caching method. But both the
    # show and feed action are to be shielded behind the authenticate filter, so we need to implement those as action caches.
    #
    # Action caching internally uses the fragment caching and an around filter to do the job. The fragment cache is named according to both
    # the current host and the path. So a page that is accessed at http://david.somewhere.com/lists/show/1 will result in a fragment named
    # "david.somewhere.com/lists/show/1". This allows the cacher to differentiate between "david.somewhere.com/lists/" and
    # "jamis.somewhere.com/lists/" -- which is a helpful way of assisting the subdomain-as-account-key pattern.
    module Actions
      def self.append_features(base) #:nodoc:
        super
        base.extend(ClassMethods)
        base.send(:attr_accessor, :rendered_action_cache)
      end

      module ClassMethods #:nodoc:
        def caches_action(*actions)
          return unless perform_caching
          around_filter(ActionCacheFilter.new(*actions))
        end
      end

      def expire_action(options = {})
        return unless perform_caching
        if options[:action].is_a?(Array)
          options[:action].dup.each do |action|
            expire_fragment(url_for(options.merge({ :action => action })).split("://").last)
          end
        else
          expire_fragment(url_for(options).split("://").last)
        end
      end

      class ActionCacheFilter #:nodoc:
        def initialize(*actions)
          @actions = actions
        end
        
        def before(controller)
          return unless @actions.include?(controller.action_name.intern)
          if cache = controller.read_fragment(controller.url_for.split("://").last)
            controller.rendered_action_cache = true
            controller.send(:render_text, cache)
            false
          end
        end
        
        def after(controller)
          return if !@actions.include?(controller.action_name.intern) || controller.rendered_action_cache
          controller.write_fragment(controller.url_for.split("://").last, controller.response.body)
        end
      end
    end

    # Fragment caching is used for caching various blocks within templates without caching the entire action as a whole. This is useful when
    # certain elements of an action change frequently or depend on complicated state while other parts rarely change or can be shared amongst multiple
    # parties. The caching is doing using the cache helper available in the Action View. A template with caching might look something like:
    #
    #   <b>Hello <%= @name %></b>
    #   <% cache do %>
    #     All the topics in the system:
    #     <%= render_collection_of_partials "topic", Topic.find_all %>
    #   <% end %>
    #
    # This cache will bind to the name of action that called it. So you would be able to invalidate it using 
    # <tt>expire_fragment(:controller => "topics", :action => "list")</tt> -- if that was the controller/action used. This is not too helpful
    # if you need to cache multiple fragments per action or if the action itself is cached using <tt>caches_action</tt>. So instead we should
    # qualify the name of the action used with something like:
    #
    #   <% cache(:action => "list", :action_suffix => "all_topics") do %>
    #
    # That would result in a name such as "/topics/list/all_topics", which wouldn't conflict with any action cache and neither with another
    # fragment using a different suffix. Note that the URL doesn't have to really exist or be callable. We're just using the url_for system
    # to generate unique cache names that we can refer to later for expirations. The expiration call for this example would be
    # <tt>expire_fragment(:controller => "topics", :action => "list", :action_suffix => "all_topics")</tt>.
    #
    # == Fragment stores
    #
    # In order to use the fragment caching, you need to designate where the caches should be stored. This is done by assigning a fragment store
    # of which there are four different kinds:
    #
    # * FileStore: Keeps the fragments on disk in the +cache_path+, which works well for all types of environments and share the fragments for
    #   all the web server processes running off the same application directory.
    # * MemoryStore: Keeps the fragments in memory, which is fine for WEBrick and for FCGI (if you don't care that each FCGI process holds its
    #   own fragment store). It's not suitable for CGI as the process is thrown away at the end of each request. It can potentially also take
    #   up a lot of memory since each process keeps all the caches in memory.
    # * DRbStore: Keeps the fragments in the memory of a separate, shared DRb process. This works for all environments and only keeps one cache
    #   around for all processes, but requires that you run and manage a separate DRb process.
    # * MemCachedStore: Works like DRbStore, but uses Danga's MemCached instead.
    #
    # Configuration examples (MemoryStore is the default):
    #
    #   ActionController::Base.fragment_cache_store = 
    #     ActionController::Caching::Fragments::MemoryStore.new
    #
    #   ActionController::Base.fragment_cache_store = 
    #     ActionController::Caching::Fragments::FileStore.new("/path/to/cache/directory")
    #
    #   ActionController::Base.fragment_cache_store = 
    #     ActionController::Caching::Fragments::DRbStore.new("druby://localhost:9192")
    #
    #   ActionController::Base.fragment_cache_store = 
    #     ActionController::Caching::Fragments::FileStore.new("localhost")
    module Fragments
      def self.append_features(base) #:nodoc:
        super
        base.class_eval do
          @@fragment_cache_store = MemoryStore.new
          cattr_accessor :fragment_cache_store
        end
      end

      # Called by CacheHelper#cache
      def cache_erb_fragment(block, name = {}, options = {})
        unless perform_caching then block.call; return end
        
        buffer = eval("_erbout", block.binding)

        if cache = read_fragment(name, options)
          buffer.concat(cache)
        else
          pos = buffer.length
          block.call
          write_fragment(name, buffer[pos..-1], options)
        end
      end
      
      def write_fragment(name, content, options = {})
        name = url_for(name).split("://").last if name.is_a?(Hash)
        fragment_cache_store.write(name, content, options)
        logger.info "Cached fragment: #{name}" unless logger.nil?
        content
      end
      
      def read_fragment(name, options = {})
        name = url_for(name).split("://").last if name.is_a?(Hash)
        if cache = fragment_cache_store.read(name, options)
          logger.info "Fragment hit: #{name}" unless logger.nil?
          cache
        else
          false
        end
      end
      
      def expire_fragment(name, options = {})
        name = url_for(name).split("://").last if name.is_a?(Hash)
        fragment_cache_store.delete(name, options)
        logger.info "Expired fragment: #{name}" unless logger.nil?
      end
    
      class MemoryStore #:nodoc:
        def initialize
          @data, @mutex = { }, Mutex.new
        end

        def read(name, options = {}) #:nodoc:
          begin
            @mutex.synchronize { @data[name] }
          rescue
            nil
          end
        end

        def write(name, value, options = {}) #:nodoc:
          @mutex.synchronize { @data[name] = value }
        end

        def delete(name, options = {}) #:nodoc:
          @mutex.synchronize { @data.delete(name) }
        end
      end

      class DRbStore < MemoryStore #:nodoc:
        def initialize(address = 'druby://localhost:9192')
          @data = DRbObject.new(nil, address)
        end    
      end

      class MemCacheStore < MemoryStore #:nodoc:
        def initialize(address = 'localhost')
          @data = MemCache.new(address)
        end    
      end

      class FileStore #:nodoc:
        def initialize(cache_path)
          @cache_path = cache_path
        end
    
        def write(name, value, options = {}) #:nodoc:
          begin
            ensure_cache_path(File.dirname(real_file_path(name)))
            File.open(real_file_path(name), "w+") { |f| f.write(value) }
          rescue => e
            Base.logger.info "Couldn't create cache directory: #{name} (#{e.message})" unless Base.logger.nil?
          end
        end

        def read(name, options = {}) #:nodoc:
          begin
            IO.read(real_file_path(name))
          rescue
            nil
          end
        end

        def delete(name, options) #:nodoc:
          File.delete(real_file_path(name)) if File.exist?(real_file_path(name))
        end
    
        private
          def real_file_path(name)
            "#{@cache_path}/#{name}"
          end
        
          def ensure_cache_path(path)
            FileUtils.makedirs(path) unless File.exists?(path)
          end
      end
    end

    # Sweepers are the terminators of the caching world and responsible for expiring caches when model objects change.
    # They do this by being half-observers, half-filters and implementing callbacks for both roles. A Sweeper example:
    # 
    #   class ListSweeper < ActiveRecord::Observer
    #     observe List, Item
    #   
    #     def after_save(record)
    #       @list = record.is_a?(List) ? record : record.list
    #     end
    #     
    #     def filter(controller)
    #       controller.expire_page(:controller => "lists", :action => %w( show public feed ), :id => @list.id)
    #       controller.expire_action(:controller => "lists", :action => "all")
    #       @list.shares.each { |share| controller.expire_page(:controller => "lists", :action => "show", :id => share.url_key) }
    #     end
    #   end
    #
    # The sweeper is assigned on the controllers that wish to have its job performed using the <tt>cache_sweeper</tt> class method:
    #
    #   class ListsController < ApplicationController
    #     caches_action :index, :show, :public, :feed
    #     cache_sweeper :list_sweeper, :only => [ :edit, :destroy, :share ]
    #   end
    #
    # In the example above, four actions are cached and three actions are responsible of expiring those caches.
    module Sweeping
      def self.append_features(base) #:nodoc:
        super
        base.extend(ClassMethods)
      end

      module ClassMethods #:nodoc:
        def cache_sweeper(*sweepers)
          return unless perform_caching
          configuration = sweepers.last.is_a?(Hash) ? sweepers.pop : {}
          sweepers.each do |sweeper| 
            observer(sweeper)
            after_filter(Object.const_get(Inflector.classify(sweeper)).instance, :only => configuration[:only])
          end
        end
      end
    end
  end
end
