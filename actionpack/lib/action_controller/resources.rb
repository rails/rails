module ActionController
  # == Overview
  #
  # ActionController::Resources are a way of defining RESTful resources.  A RESTful resource, in basic terms,
  # is something that can be pointed at and it will respond with a representation of the data requested.
  # In real terms this could mean a user with a browser requests an HTML page, or that a desktop application
  # requests XML data.
  #
  # RESTful design is based on the assumption that there are four generic verbs that a user of an
  # application can request from a resource (the noun).
  #
  # Resources can be requested using four basic HTTP verbs (GET, POST, PUT, DELETE), the method used
  # denotes the type of action that should take place.
  #
  # === The Different Methods and their Usage
  #
  # +GET+     Requests for a resource, no saving or editing of a resource should occur in a GET request
  # +POST+    Creation of resources
  # +PUT+     Editing of attributes on a resource
  # +DELETE+  Deletion of a resource
  #
  # === Examples
  #
  #   # A GET request on the Posts resource is asking for all Posts
  #   GET /posts
  #
  #   # A GET request on a single Post resource is asking for that particular Post
  #   GET /posts/1
  #
  #   # A POST request on the Posts resource is asking for a Post to be created with the supplied details
  #   POST /posts # with => { :title => "My Whizzy New Post", :body => "I've got a brand new combine harvester" }
  #
  #   # A PUT request on a single Post resource is asking for a Post to be updated
  #   POST /posts # with => { :id => 1, :title => "Changed Whizzy Title" }
  #
  #   # A DELETE request on a single Post resource is asking for it to be deleted
  #   DELETE /posts # with => { :id => 1 }
  #
  # By using the REST convention, users of our application can assume certain things about how the data
  # is requested and how it is returned.  Rails simplifies the routing part of RESTful design by
  # supplying you with methods to create them in your routes.rb file.
  #
  # Read more about REST at http://en.wikipedia.org/wiki/Representational_State_Transfer
  module Resources
    class Resource #:nodoc:
      attr_reader :collection_methods, :member_methods, :new_methods
      attr_reader :path_prefix, :name_prefix
      attr_reader :plural, :singular
      attr_reader :options

      def initialize(entities, options)
        @plural   ||= entities
        @singular ||= options[:singular] || plural.to_s.singularize

        @options = options

        arrange_actions
        add_default_actions
        set_prefixes
      end

      def controller
        @controller ||= "#{options[:namespace]}#{(options[:controller] || plural).to_s}"
      end

      def requirements(with_id = false)
        @requirements   ||= @options[:requirements] || {}
        @id_requirement ||= { :id => @requirements.delete(:id) || /[^#{Routing::SEPARATORS.join}]+/ }

        with_id ? @requirements.merge(@id_requirement) : @requirements
      end

      def path
        @path ||= "#{path_prefix}/#{plural}"
      end

      def new_path
        @new_path ||= "#{path}/new"
      end

      def member_path
        @member_path ||= "#{path}/:id"
      end

      def nesting_path_prefix
        @nesting_path_prefix ||= "#{path}/:#{singular}_id"
      end

      def nesting_name_prefix
        "#{name_prefix}#{singular}_"
      end


      protected
        def arrange_actions
          @collection_methods = arrange_actions_by_methods(options.delete(:collection))
          @member_methods     = arrange_actions_by_methods(options.delete(:member))
          @new_methods        = arrange_actions_by_methods(options.delete(:new))
        end

        def add_default_actions
          add_default_action(member_methods, :get, :edit)
          add_default_action(new_methods, :get, :new)
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

    class SingletonResource < Resource #:nodoc:
      def initialize(entity, options)
        @singular = @plural = entity
        options[:controller] ||= @singular.to_s.pluralize
        super
      end

      alias_method :member_path,         :path
      alias_method :nesting_path_prefix, :path
    end

    # Creates named routes for implementing verb-oriented controllers
    # for a collection resource.
    #
    # For example:
    #
    #   map.resources :messages
    #
    # will map the following actions in the corresponding controller:
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
    # Along with the routes themselves, #resources generates named routes for use in
    # controllers and views. <tt>map.resources :messages</tt> produces the following named routes and helpers:
    #
    #   Named Route   Helpers
    #   ============  =====================================================
    #   messages      messages_url, hash_for_messages_url,
    #                 messages_path, hash_for_messages_path
    #
    #   message       message_url(id), hash_for_message_url(id),
    #                 message_path(id), hash_for_message_path(id)
    #
    #   new_message   new_message_url, hash_for_new_message_url,
    #                 new_message_path, hash_for_new_message_path
    #
    #   edit_message  edit_message_url(id), hash_for_edit_message_url(id),
    #                 edit_message_path(id), hash_for_edit_message_path(id)
    #
    # You can use these helpers instead of #url_for or methods that take #url_for parameters. For example:
    #
    #   redirect_to :controller => 'messages', :action => 'index'
    #   # and
    #   <%= link_to "edit this message", :controller => 'messages', :action => 'edit', :id => @message.id %>
    #
    # now become:
    #
    #   redirect_to messages_url
    #   # and
    #   <%= link_to "edit this message", edit_message_url(@message) # calls @message.id automatically
    #
    # Since web browsers don't support the PUT and DELETE verbs, you will need to add a parameter '_method' to your
    # form tags. The form helpers make this a little easier. For an update form with a <tt>@message</tt> object:
    #
    #   <%= form_tag message_path(@message), :method => :put %>
    #
    # or
    #
    #   <% form_for :message, @message, :url => message_path(@message), :html => {:method => :put} do |f| %>
    #
    # The #resources method accepts the following options to customize the resulting
    # routes:
    # * <tt>:collection</tt> - add named routes for other actions that operate on the collection.
    #   Takes a hash of <tt>#{action} => #{method}</tt>, where method is <tt>:get</tt>/<tt>:post</tt>/<tt>:put</tt>/<tt>:delete</tt>
    #   or <tt>:any</tt> if the method does not matter.  These routes map to a URL like /messages/rss, with a route of rss_messages_url.
    # * <tt>:member</tt> - same as :collection, but for actions that operate on a specific member.
    # * <tt>:new</tt> - same as :collection, but for actions that operate on the new resource action.
    # * <tt>:controller</tt> - specify the controller name for the routes.
    # * <tt>:singular</tt> - specify the singular name used in the member routes.
    # * <tt>:path_prefix</tt> - set a prefix to the routes with required route variables.
    #   Weblog comments usually belong to a post, so you might use resources like:
    #
    #     map.resources :articles
    #     map.resources :comments, :path_prefix => '/articles/:article_id'
    #
    #   You can nest resources calls to set this automatically:
    #
    #     map.resources :articles do |article|
    #       article.resources :comments
    #     end
    #
    #   The comment resources work the same, but must now include a value for :article_id.
    #
    #     comments_url(@article)
    #     comment_url(@article, @comment)
    #
    #     comments_url(:article_id => @article)
    #     comment_url(:article_id => @article, :id => @comment)
    #
    # * <tt>:name_prefix</tt> - define a prefix for all generated routes, usually ending in an underscore.
    #   Use this if you have named routes that may clash.
    #
    #     map.resources :tags, :path_prefix => '/books/:book_id', :name_prefix => 'book_'
    #     map.resources :tags, :path_prefix => '/toys/:toy_id',   :name_prefix => 'toy_'
    #
    # If <tt>map.resources</tt> is called with multiple resources, they all get the same options applied.
    #
    # Examples:
    #
    #   map.resources :messages, :path_prefix => "/thread/:thread_id"
    #   # --> GET /thread/7/messages/1
    #
    #   map.resources :messages, :collection => { :rss => :get }
    #   # --> GET /messages/rss (maps to the #rss action)
    #   #     also adds a named route called "rss_messages"
    #
    #   map.resources :messages, :member => { :mark => :post }
    #   # --> POST /messages/1/mark (maps to the #mark action)
    #   #     also adds a named route called "mark_message"
    #
    #   map.resources :messages, :new => { :preview => :post }
    #   # --> POST /messages/new/preview (maps to the #preview action)
    #   #     also adds a named route called "preview_new_message"
    #
    #   map.resources :messages, :new => { :new => :any, :preview => :post }
    #   # --> POST /messages/new/preview (maps to the #preview action)
    #   #     also adds a named route called "preview_new_message"
    #   # --> /messages/new can be invoked via any request method
    #
    #   map.resources :messages, :controller => "categories",
    #         :path_prefix => "/category/:category_id",
    #         :name_prefix => "category_"
    #   # --> GET /categories/7/messages/1
    #   #     has named route "category_message"
    #
    # The #resources method sets HTTP method restrictions on the routes it generates. For example, making an
    # HTTP POST on <tt>new_message_url</tt> will raise a RoutingError exception. The default route in
    # <tt>config/routes.rb</tt> overrides this and allows invalid HTTP methods for resource routes.
    def resources(*entities, &block)
      options = entities.last.is_a?(Hash) ? entities.pop : { }
      entities.each { |entity| map_resource(entity, options.dup, &block) }
    end

    # Creates named routes for implementing verb-oriented controllers for a singleton resource.
    # A singleton resource is global to its current context.  For unnested singleton resources,
    # the resource is global to the current user visiting the application, such as a user's
    # /account profile.  For nested singleton resources, the resource is global to its parent
    # resource, such as a <tt>projects</tt> resource that <tt>has_one :project_manager</tt>.
    # The <tt>project_manager</tt> should be mapped as a singleton resource under <tt>projects</tt>:
    #
    #   map.resources :projects do |project|
    #     project.resource :project_manager
    #   end
    #
    # See map.resources for general conventions.  These are the main differences:
    # * A singular name is given to map.resource.  The default controller name is still taken from the plural name.
    # * To specify a custom plural name, use the :plural option.  There is no :singular option.
    # * No default index route is created for the singleton resource controller.
    # * When nesting singleton resources, only the singular name is used as the path prefix (example: 'account/messages/1')
    #
    # For example:
    #
    #   map.resource :account
    #
    # maps these actions in the Accounts controller:
    #
    #   class AccountsController < ActionController::Base
    #     # GET new_account_url
    #     def new
    #       # return an HTML form for describing the new account
    #     end
    #
    #     # POST account_url
    #     def create
    #       # create an account
    #     end
    #
    #     # GET account_url
    #     def show
    #       # find and return the account
    #     end
    #
    #     # GET edit_account_url
    #     def edit
    #       # return an HTML form for editing the account
    #     end
    #
    #     # PUT account_url
    #     def update
    #       # find and update the account
    #     end
    #
    #     # DELETE account_url
    #     def destroy
    #       # delete the account
    #     end
    #   end
    #
    # Along with the routes themselves, #resource generates named routes for
    # use in controllers and views. <tt>map.resource :account</tt> produces
    # these named routes and helpers:
    #
    #   Named Route   Helpers
    #   ============  =============================================
    #   account       account_url, hash_for_account_url,
    #                 account_path, hash_for_account_path
    #
    #   new_account   new_account_url, hash_for_new_account_url,
    #                 new_account_path, hash_for_new_account_path
    #
    #   edit_account  edit_account_url, hash_for_edit_account_url,
    #                 edit_account_path, hash_for_edit_account_path
    def resource(*entities, &block)
      options = entities.last.is_a?(Hash) ? entities.pop : { }
      entities.each { |entity| map_singleton_resource(entity, options.dup, &block) }
    end

    private
      def map_resource(entities, options = {}, &block)
        resource = Resource.new(entities, options)

        with_options :controller => resource.controller do |map|
          map_collection_actions(map, resource)
          map_default_collection_actions(map, resource)
          map_new_actions(map, resource)
          map_member_actions(map, resource)

          map_associations(resource, options)

          if block_given?
            with_options(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix, &block)
          end
        end
      end

      def map_singleton_resource(entities, options = {}, &block)
        resource = SingletonResource.new(entities, options)

        with_options :controller => resource.controller do |map|
          map_collection_actions(map, resource)
          map_default_singleton_actions(map, resource)
          map_new_actions(map, resource)
          map_member_actions(map, resource)

          map_associations(resource, options)

          if block_given?
            with_options(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix, &block)
          end
        end
      end

      def map_associations(resource, options)
        path_prefix = "#{options.delete(:path_prefix)}#{resource.nesting_path_prefix}"
        name_prefix = "#{options.delete(:name_prefix)}#{resource.nesting_name_prefix}"
        namespace = options.delete(:namespace)

        Array(options[:has_many]).each do |association|
          resources(association, :path_prefix => path_prefix, :name_prefix => name_prefix, :namespace => namespace)
        end

        Array(options[:has_one]).each do |association|
          resource(association, :path_prefix => path_prefix, :name_prefix => name_prefix, :namespace => namespace)
        end
      end

      def map_collection_actions(map, resource)
        resource.collection_methods.each do |method, actions|
          actions.each do |action|
            action_options = action_options_for(action, resource, method)
            map.named_route("#{resource.name_prefix}#{action}_#{resource.plural}", "#{resource.path}/#{action}", action_options)
            map.named_route("formatted_#{resource.name_prefix}#{action}_#{resource.plural}", "#{resource.path}/#{action}.:format", action_options)
          end
        end
      end

      def map_default_collection_actions(map, resource)
        index_action_options = action_options_for("index", resource)
        map.named_route("#{resource.name_prefix}#{resource.plural}", resource.path, index_action_options)
        map.named_route("formatted_#{resource.name_prefix}#{resource.plural}", "#{resource.path}.:format", index_action_options)

        create_action_options = action_options_for("create", resource)
        map.connect(resource.path, create_action_options)
        map.connect("#{resource.path}.:format", create_action_options)
      end

      def map_default_singleton_actions(map, resource)
        create_action_options = action_options_for("create", resource)
        map.connect(resource.path, create_action_options)
        map.connect("#{resource.path}.:format", create_action_options)
      end

      def map_new_actions(map, resource)
        resource.new_methods.each do |method, actions|
          actions.each do |action|
            action_options = action_options_for(action, resource, method)
            if action == :new
              map.named_route("#{resource.name_prefix}new_#{resource.singular}", resource.new_path, action_options)
              map.named_route("formatted_#{resource.name_prefix}new_#{resource.singular}", "#{resource.new_path}.:format", action_options)
            else
              map.named_route("#{resource.name_prefix}#{action}_new_#{resource.singular}", "#{resource.new_path}/#{action}", action_options)
              map.named_route("formatted_#{resource.name_prefix}#{action}_new_#{resource.singular}", "#{resource.new_path}/#{action}.:format", action_options)
            end
          end
        end
      end

      def map_member_actions(map, resource)
        resource.member_methods.each do |method, actions|
          actions.each do |action|
            action_options = action_options_for(action, resource, method)
            map.named_route("#{resource.name_prefix}#{action}_#{resource.singular}", "#{resource.member_path}/#{action}", action_options)
            map.named_route("formatted_#{resource.name_prefix}#{action}_#{resource.singular}", "#{resource.member_path}/#{action}.:format",action_options)
          end
        end

        show_action_options = action_options_for("show", resource)
        map.named_route("#{resource.name_prefix}#{resource.singular}", resource.member_path, show_action_options)
        map.named_route("formatted_#{resource.name_prefix}#{resource.singular}", "#{resource.member_path}.:format", show_action_options)

        update_action_options = action_options_for("update", resource)
        map.connect(resource.member_path, update_action_options)
        map.connect("#{resource.member_path}.:format", update_action_options)

        destroy_action_options = action_options_for("destroy", resource)
        map.connect(resource.member_path, destroy_action_options)
        map.connect("#{resource.member_path}.:format", destroy_action_options)
      end

      def conditions_for(method)
        { :conditions => method == :any ? {} : { :method => method } }
      end

      def action_options_for(action, resource, method = nil)
        default_options = { :action => action.to_s }
        require_id = !resource.kind_of?(SingletonResource)
        case default_options[:action]
          when "index", "new" : default_options.merge(conditions_for(method || :get)).merge(resource.requirements)
          when "create"       : default_options.merge(conditions_for(method || :post)).merge(resource.requirements)
          when "show", "edit" : default_options.merge(conditions_for(method || :get)).merge(resource.requirements(require_id))
          when "update"       : default_options.merge(conditions_for(method || :put)).merge(resource.requirements(require_id))
          when "destroy"      : default_options.merge(conditions_for(method || :delete)).merge(resource.requirements(require_id))
          else                  default_options.merge(conditions_for(method)).merge(resource.requirements)
        end
      end
  end
end

ActionController::Routing::RouteSet::Mapper.send :include, ActionController::Resources
