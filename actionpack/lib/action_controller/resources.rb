module ActionController
  module Resources
    class Resource #:nodoc:
      attr_reader :collection_methods, :member_methods, :new_methods
      attr_reader :path_prefix, :name_prefix
      attr_reader :plural, :singular
      attr_reader :options

      def initialize(entities, options)
        @plural   = entities
        @singular = options[:singular] || plural.to_s.singularize
        
        @options = options

        arrange_actions
        add_default_actions
        set_prefixes
      end
      
      def controller
        (options[:controller] || plural).to_s
      end
      
      def path
        "#{path_prefix}/#{plural}"
      end
      
      def new_path
        "#{path}/new"
      end
      
      def member_path
        "#{path}/:id"
      end
      
      def nesting_path_prefix
        "#{path}/:#{singular}_id"
      end
      
      private
        def arrange_actions
          @collection_methods = arrange_actions_by_methods(options.delete(:collection))
          @member_methods     = arrange_actions_by_methods(options.delete(:member))
          @new_methods        = arrange_actions_by_methods(options.delete(:new))
        end
        
        def add_default_actions
          add_default_action(collection_methods, :post,   :create)
          add_default_action(member_methods,     :get,    :edit)
          add_default_action(member_methods,     :put,    :update)
          add_default_action(member_methods,     :delete, :destroy)
          add_default_action(new_methods,        :get,    :new)
        end

        def set_prefixes
          @path_prefix = options.delete(:path_prefix)
          @name_prefix = options.delete(:name_prefix)
        end

        def arrange_actions_by_methods(actions)
          (actions || {}).inject({}) do |flipped_hash, (key, value)|
            (flipped_hash[value] ||= []) << key
            flipped_hash
          end
        end
        
        def add_default_action(collection, method, action)
          (collection[method] ||= []).unshift(action)
        end
    end
    
    # Creates named routes for implementing verb-oriented controllers. This is
    # useful for implementing REST API's, where a single resource has different
    # behavior based on the HTTP verb (method) used to access it.
    # 
    # Because browsers don't yet support any verbs except GET and POST, you can send
    # a parameter named "_method" and the plugin will use that as the request method.
    # 
    # example:
    #
    #   map.resources :messages 
    #
    #   class MessagesController < ActionController::Base
    #     # GET messages_url
    #     def index
    #       # return all messages
    #     end
    # 
    #     # GET new_message_url
    #     def new
    #       # return an HTML form for describing a new message
    #     end
    # 
    #     # POST messages_url
    #     def create
    #       # create a new message
    #     end
    # 
    #     # GET message_url(:id => 1)
    #     def show
    #       # find and return a specific message
    #     end
    # 
    #     # GET edit_message_url(:id => 1)
    #     def edit
    #       # return an HTML form for editing a specific message
    #     end
    # 
    #     # PUT message_url(:id => 1)
    #     def update
    #       # find and update a specific message
    #     end
    # 
    #     # DELETE message_url(:id => 1)
    #     def destroy
    #       # delete a specific message
    #     end
    #   end
    # 
    # The #resource method accepts various options, too, to customize the resulting
    # routes:
    # * <tt>:controller</tt> -- specify the controller name for the routes.
    # * <tt>:singular</tt> -- specify the singular name used in the member routes.
    # * <tt>:path_prefix</tt> -- set a prefix to the routes with required route variables.
    #   Weblog comments usually belong to a post, so you might use a resource like:
    #
    #     map.resources :comments, :path_prefix => '/articles/:article_id'
    #
    #   You can nest resource calls to set this automatically:
    #
    #     map.resources :posts do |post|
    #       map.resources :comments
    #     end
    # 
    # * <tt>:name_prefix</tt> -- define a prefix for all generated routes, usually ending in an underscore.
    #   Use this if you have named routes that may clash.
    #
    #     map.resources :tags, :path_prefix => '/books/:book_id', :name_prefix => 'book_'
    #     map.resources :tags, :path_prefix => '/toys/:toy_id',   :name_prefix => 'toy_'
    #
    # * <tt>:collection</tt> -- add named routes for other actions that operate on the collection.
    #   Takes a hash of <tt>#{action} => #{method}</tt>, where method is <tt>:get</tt>/<tt>:post</tt>/<tt>:put</tt>/<tt>:delete</tt>
    #   or <tt>:any</tt> if the method does not matter.  These routes map to a URL like /messages;rss, with a route of rss_messages_url.
    # * <tt>:member</tt> -- same as :collection, but for actions that operate on a specific member.
    # * <tt>:new</tt> -- same as :collection, but for actions that operate on the new resource action.
    #
    # If <tt>map.resources</tt> is called with multiple resources, they all get the same options applied.
    #
    # Examples:
    # 
    #   map.resources :messages, :path_prefix => "/thread/:thread_id"
    #   # --> GET /thread/7/messages/1
    #  
    #   map.resources :messages, :collection => { :rss => :get }
    #   # --> GET /messages;rss (maps to the #rss action)
    #   #     also adds a url named "rss_messages"
    # 
    #   map.resources :messages, :member => { :mark => :post }
    #   # --> POST /messages/1;mark (maps to the #mark action)
    #   #     also adds a url named "mark_message"
    # 
    #   map.resources :messages, :new => { :preview => :post }
    #   # --> POST /messages/new;preview (maps to the #preview action)
    #   #     also adds a url named "preview_new_message"
    # 
    #   map.resources :messages, :new => { :new => :any, :preview => :post }
    #   # --> POST /messages/new;preview (maps to the #preview action)
    #   #     also adds a url named "preview_new_message"
    #   # --> /messages/new can be invoked via any request method
    # 
    #   map.resources :messages, :controller => "categories",
    #         :path_prefix => "/category/:category_id",
    #         :name_prefix => "category_"
    #   # --> GET /categories/7/messages/1
    #   #     has named route "category_message"
    def resources(*entities, &block)
      options = entities.last.is_a?(Hash) ? entities.pop : { }
      entities.each { |entity| map_resource entity, options.dup, &block }
    end

    private
      def map_resource(entities, options = {}, &block)
        resource = Resource.new(entities, options)

        with_options :controller => resource.controller do |map|
          map_collection_actions(map, resource)
          map_new_actions(map, resource)
          map_member_actions(map, resource)

          if block_given?
            with_options(:path_prefix => resource.nesting_path_prefix, &block)
          end
        end
      end

      def map_collection_actions(map, resource)
        resource.collection_methods.each do |method, actions|
          primary       = actions.shift.to_s if method != :get
          route_options = requirements_for(method)

          actions.each do |action|
            map.named_route(
              "#{resource.name_prefix}#{action}_#{resource.plural}", 
              "#{resource.path};#{action}", 
              route_options.merge(:action => action.to_s)
            )

            map.named_route(
              "formatted_#{resource.name_prefix}#{action}_#{resource.plural}",
              "#{resource.path}.:format;#{action}",
              route_options.merge(:action => action.to_s)
            )
          end

          unless primary.blank?
            map.connect(resource.path, route_options.merge(:action => primary))
            map.connect("#{resource.path}.:format", route_options.merge(:action => primary))
          end

          map.named_route("#{resource.name_prefix}#{resource.plural}", resource.path, :action => "index", :conditions => { :method => :get })
          map.named_route("formatted_#{resource.name_prefix}#{resource.plural}", "#{resource.path}.:format", :action => "index", :conditions => { :method => :get })
        end
      end
      
      def map_new_actions(map, resource)
        resource.new_methods.each do |method, actions|
          route_options = requirements_for(method)
          actions.each do |action|
            path = action == :new ? resource.new_path : "#{resource.new_path};#{action}"
            name = "new_#{resource.singular}"
            name = "#{action}_#{name}" unless action == :new

            map.named_route("#{resource.name_prefix}#{name}", path, route_options.merge(:action => action.to_s))
            map.named_route("formatted_#{resource.name_prefix}#{name}", action == :new ? "#{resource.new_path}.:format" : "#{resource.new_path}.:format;#{action}", route_options.merge(:action => action.to_s))
          end
        end
      end
      
      def map_member_actions(map, resource)
        resource.member_methods.each do |method, actions|
          route_options = requirements_for(method)
          primary = actions.shift.to_s unless [ :get, :post, :any ].include?(method)

          actions.each do |action|
            map.named_route("#{resource.name_prefix}#{action}_#{resource.singular}", "#{resource.member_path};#{action}", route_options.merge(:action => action.to_s))
            map.named_route("formatted_#{resource.name_prefix}#{action}_#{resource.singular}", "#{resource.member_path}.:format;#{action}", route_options.merge(:action => action.to_s))
          end

          map.connect(resource.member_path, route_options.merge(:action => primary)) unless primary.blank?
        end

        map.named_route("#{resource.name_prefix}#{resource.singular}", resource.member_path, :action => "show", :conditions => { :method => :get })
        map.named_route("formatted_#{resource.name_prefix}#{resource.singular}", "#{resource.member_path}.:format", :action => "show", :conditions => { :method => :get })
      end
    
      def requirements_for(method)
        method == :any ? {} : { :conditions => { :method => method } }
      end
  end
end

ActionController::Routing::RouteSet::Mapper.send :include, ActionController::Resources