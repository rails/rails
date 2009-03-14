module ActionController
  # == Overview
  #
  # ActionController::Resources are a way of defining RESTful \resources.  A RESTful \resource, in basic terms,
  # is something that can be pointed at and it will respond with a representation of the data requested.
  # In real terms this could mean a user with a browser requests an HTML page, or that a desktop application
  # requests XML data.
  #
  # RESTful design is based on the assumption that there are four generic verbs that a user of an
  # application can request from a \resource (the noun).
  #
  # \Resources can be requested using four basic HTTP verbs (GET, POST, PUT, DELETE), the method used
  # denotes the type of action that should take place.
  #
  # === The Different Methods and their Usage
  #
  # * GET    - Requests for a \resource, no saving or editing of a \resource should occur in a GET request.
  # * POST   - Creation of \resources.
  # * PUT    - Editing of attributes on a \resource.
  # * DELETE - Deletion of a \resource.
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
  #   POST /posts # with => { :post => { :title => "My Whizzy New Post", :body => "I've got a brand new combine harvester" } }
  #
  #   # A PUT request on a single Post resource is asking for a Post to be updated
  #   PUT /posts # with => { :id => 1, :post => { :title => "Changed Whizzy Title" } }
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
    INHERITABLE_OPTIONS = :namespace, :shallow

    class Resource #:nodoc:
      DEFAULT_ACTIONS = :index, :create, :new, :edit, :show, :update, :destroy

      attr_reader :collection_methods, :member_methods, :new_methods
      attr_reader :path_prefix, :name_prefix, :path_segment
      attr_reader :plural, :singular
      attr_reader :options

      def initialize(entities, options)
        @plural   ||= entities
        @singular ||= options[:singular] || plural.to_s.singularize
        @path_segment = options.delete(:as) || @plural

        @options = options

        arrange_actions
        add_default_actions
        set_allowed_actions
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

      def conditions
        @conditions ||= @options[:conditions] || {}
      end

      def path
        @path ||= "#{path_prefix}/#{path_segment}"
      end

      def new_path
        new_action   = self.options[:path_names][:new] if self.options[:path_names]
        new_action ||= Base.resources_path_names[:new]
        @new_path  ||= "#{path}/#{new_action}"
      end

      def shallow_path_prefix
        @shallow_path_prefix ||= @options[:shallow] ? @options[:namespace].try(:sub, /\/$/, '') : path_prefix
      end

      def member_path
        @member_path ||= "#{shallow_path_prefix}/#{path_segment}/:id"
      end

      def nesting_path_prefix
        @nesting_path_prefix ||= "#{shallow_path_prefix}/#{path_segment}/:#{singular}_id"
      end

      def shallow_name_prefix
        @shallow_name_prefix ||= @options[:shallow] ? @options[:namespace].try(:gsub, /\//, '_') : name_prefix
      end

      def nesting_name_prefix
        "#{shallow_name_prefix}#{singular}_"
      end

      def action_separator
        @action_separator ||= Base.resource_action_separator
      end

      def uncountable?
        @singular.to_s == @plural.to_s
      end

      def has_action?(action)
        !DEFAULT_ACTIONS.include?(action) || action_allowed?(action)
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

        def set_allowed_actions
          only, except = @options.values_at(:only, :except)
          @allowed_actions ||= {}

          if only == :all || except == :none
            only = nil
            except = []
          elsif only == :none || except == :all
            only = []
            except = nil
          end

          if only
            @allowed_actions[:only] = Array(only).map(&:to_sym)
          elsif except
            @allowed_actions[:except] = Array(except).map(&:to_sym)
          end
        end

        def action_allowed?(action)
          only, except = @allowed_actions.values_at(:only, :except)
          (!only || only.include?(action)) && (!except || !except.include?(action))
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

      alias_method :shallow_path_prefix, :path_prefix
      alias_method :shallow_name_prefix, :name_prefix
      alias_method :member_path,         :path
      alias_method :nesting_path_prefix, :path
    end

    # Creates named routes for implementing verb-oriented controllers
    # for a collection \resource.
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
    # Along with the routes themselves, +resources+ generates named routes for use in
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
    # You can use these helpers instead of +url_for+ or methods that take +url_for+ parameters. For example:
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
    # or
    #
    #   <% form_for @message do |f| %>
    #
    # which takes into account whether <tt>@message</tt> is a new record or not and generates the
    # path and method accordingly.
    #
    # The +resources+ method accepts the following options to customize the resulting routes:
    # * <tt>:collection</tt> - Add named routes for other actions that operate on the collection.
    #   Takes a hash of <tt>#{action} => #{method}</tt>, where method is <tt>:get</tt>/<tt>:post</tt>/<tt>:put</tt>/<tt>:delete</tt>,
    #   an array of any of the previous, or <tt>:any</tt> if the method does not matter.
    #   These routes map to a URL like /messages/rss, with a route of +rss_messages_url+.
    # * <tt>:member</tt> - Same as <tt>:collection</tt>, but for actions that operate on a specific member.
    # * <tt>:new</tt> - Same as <tt>:collection</tt>, but for actions that operate on the new \resource action.
    # * <tt>:controller</tt> - Specify the controller name for the routes.
    # * <tt>:singular</tt> - Specify the singular name used in the member routes.
    # * <tt>:requirements</tt> - Set custom routing parameter requirements; this is a hash of either 
    #     regular expressions (which must match for the route to match) or extra parameters. For example:
    #
    #       map.resource :profile, :path_prefix => ':name', :requirements => { :name => /[a-zA-Z]+/, :extra => 'value' }
    #
    #     will only match if the first part is alphabetic, and will pass the parameter :extra to the controller.
    # * <tt>:conditions</tt> - Specify custom routing recognition conditions.  \Resources sets the <tt>:method</tt> value for the method-specific routes.
    # * <tt>:as</tt> - Specify a different \resource name to use in the URL path. For example:
    #     # products_path == '/productos'
    #     map.resources :products, :as => 'productos' do |product|
    #       # product_reviews_path(product) == '/productos/1234/comentarios'
    #       product.resources :product_reviews, :as => 'comentarios'
    #     end
    #
    # * <tt>:has_one</tt> - Specify nested \resources, this is a shorthand for mapping singleton \resources beneath the current.
    # * <tt>:has_many</tt> - Same has <tt>:has_one</tt>, but for plural \resources.
    #
    #   You may directly specify the routing association with +has_one+ and +has_many+ like:
    #
    #     map.resources :notes, :has_one => :author, :has_many => [:comments, :attachments]
    #
    #   This is the same as:
    #
    #     map.resources :notes do |notes|
    #       notes.resource  :author
    #       notes.resources :comments
    #       notes.resources :attachments
    #     end
    #
    # * <tt>:path_names</tt> - Specify different names for the 'new' and 'edit' actions. For example:
    #     # new_products_path == '/productos/nuevo'
    #     map.resources :products, :as => 'productos', :path_names => { :new => 'nuevo', :edit => 'editar' }
    #
    #   You can also set default action names from an environment, like this:
    #     config.action_controller.resources_path_names = { :new => 'nuevo', :edit => 'editar' }
    #
    # * <tt>:path_prefix</tt> - Set a prefix to the routes with required route variables.
    #
    #   Weblog comments usually belong to a post, so you might use +resources+ like:
    #
    #     map.resources :articles
    #     map.resources :comments, :path_prefix => '/articles/:article_id'
    #
    #   You can nest +resources+ calls to set this automatically:
    #
    #     map.resources :articles do |article|
    #       article.resources :comments
    #     end
    #
    #   The comment \resources work the same, but must now include a value for <tt>:article_id</tt>.
    #
    #     article_comments_url(@article)
    #     article_comment_url(@article, @comment)
    #
    #     article_comments_url(:article_id => @article)
    #     article_comment_url(:article_id => @article, :id => @comment)
    #
    #   If you don't want to load all objects from the database you might want to use the <tt>article_id</tt> directly:
    #
    #     articles_comments_url(@comment.article_id, @comment)
    #
    # * <tt>:name_prefix</tt> - Define a prefix for all generated routes, usually ending in an underscore.
    #   Use this if you have named routes that may clash.
    #
    #     map.resources :tags, :path_prefix => '/books/:book_id', :name_prefix => 'book_'
    #     map.resources :tags, :path_prefix => '/toys/:toy_id',   :name_prefix => 'toy_'
    #
    # You may also use <tt>:name_prefix</tt> to override the generic named routes in a nested \resource:
    #
    #   map.resources :articles do |article|
    #     article.resources :comments, :name_prefix => nil
    #   end
    #
    # This will yield named \resources like so:
    #
    #   comments_url(@article)
    #   comment_url(@article, @comment)
    #
    # * <tt>:shallow</tt> - If true, paths for nested resources which reference a specific member
    #   (ie. those with an :id parameter) will not use the parent path prefix or name prefix.
    #
    # The <tt>:shallow</tt> option is inherited by any nested resource(s).
    #
    # For example, 'users', 'posts' and 'comments' all use shallow paths with the following nested resources:
    #
    #   map.resources :users, :shallow => true do |user|
    #     user.resources :posts do |post|
    #       post.resources :comments
    #     end
    #   end
    #   # --> GET /users/1/posts (maps to the PostsController#index action as usual)
    #   #     also adds the usual named route called "user_posts"
    #   # --> GET /posts/2 (maps to the PostsController#show action as if it were not nested)
    #   #     also adds the named route called "post"
    #   # --> GET /posts/2/comments (maps to the CommentsController#index action)
    #   #     also adds the named route called "post_comments"
    #   # --> GET /comments/2 (maps to the CommentsController#show action as if it were not nested)
    #   #     also adds the named route called "comment"
    #
    # You may also use <tt>:shallow</tt> in combination with the +has_one+ and +has_many+ shorthand notations like:
    #
    #   map.resources :users, :has_many => { :posts => :comments }, :shallow => true
    #
    # * <tt>:only</tt> and <tt>:except</tt> - Specify which of the seven default actions should be routed to.
    #
    # <tt>:only</tt> and <tt>:except</tt> may be set to <tt>:all</tt>, <tt>:none</tt>, an action name or a
    # list of action names. By default, routes are generated for all seven actions.
    #
    # For example:
    #
    #   map.resources :posts, :only => [:index, :show] do |post|
    #     post.resources :comments, :except => [:update, :destroy]
    #   end
    #   # --> GET /posts (maps to the PostsController#index action)
    #   # --> POST /posts (fails)
    #   # --> GET /posts/1 (maps to the PostsController#show action)
    #   # --> DELETE /posts/1 (fails)
    #   # --> POST /posts/1/comments (maps to the CommentsController#create action)
    #   # --> PUT /posts/1/comments/1 (fails)
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
    # The +resources+ method sets HTTP method restrictions on the routes it generates. For example, making an
    # HTTP POST on <tt>new_message_url</tt> will raise a RoutingError exception. The default route in
    # <tt>config/routes.rb</tt> overrides this and allows invalid HTTP methods for \resource routes.
    def resources(*entities, &block)
      options = entities.extract_options!
      entities.each { |entity| map_resource(entity, options.dup, &block) }
    end

    # Creates named routes for implementing verb-oriented controllers for a singleton \resource.
    # A singleton \resource is global to its current context.  For unnested singleton \resources,
    # the \resource is global to the current user visiting the application, such as a user's
    # <tt>/account</tt> profile.  For nested singleton \resources, the \resource is global to its parent
    # \resource, such as a <tt>projects</tt> \resource that <tt>has_one :project_manager</tt>.
    # The <tt>project_manager</tt> should be mapped as a singleton \resource under <tt>projects</tt>:
    #
    #   map.resources :projects do |project|
    #     project.resource :project_manager
    #   end
    #
    # See +resources+ for general conventions.  These are the main differences:
    # * A singular name is given to <tt>map.resource</tt>.  The default controller name is still taken from the plural name.
    # * To specify a custom plural name, use the <tt>:plural</tt> option.  There is no <tt>:singular</tt> option.
    # * No default index route is created for the singleton \resource controller.
    # * When nesting singleton \resources, only the singular name is used as the path prefix (example: 'account/messages/1')
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
    # Along with the routes themselves, +resource+ generates named routes for
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
      options = entities.extract_options!
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
            with_options(options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix), &block)
          end
        end
      end

      def map_singleton_resource(entities, options = {}, &block)
        resource = SingletonResource.new(entities, options)

        with_options :controller => resource.controller do |map|
          map_collection_actions(map, resource)
          map_new_actions(map, resource)
          map_member_actions(map, resource)
          map_default_singleton_actions(map, resource)

          map_associations(resource, options)

          if block_given?
            with_options(options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix), &block)
          end
        end
      end

      def map_associations(resource, options)
        map_has_many_associations(resource, options.delete(:has_many), options) if options[:has_many]

        path_prefix = "#{options.delete(:path_prefix)}#{resource.nesting_path_prefix}"
        name_prefix = "#{options.delete(:name_prefix)}#{resource.nesting_name_prefix}"

        Array(options[:has_one]).each do |association|
          resource(association, options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => path_prefix, :name_prefix => name_prefix))
        end
      end

      def map_has_many_associations(resource, associations, options)
        case associations
        when Hash
          associations.each do |association,has_many|
            map_has_many_associations(resource, association, options.merge(:has_many => has_many))
          end
        when Array
          associations.each do |association|
            map_has_many_associations(resource, association, options)
          end
        when Symbol, String
          resources(associations, options.slice(*INHERITABLE_OPTIONS).merge(:path_prefix => resource.nesting_path_prefix, :name_prefix => resource.nesting_name_prefix, :has_many => options[:has_many]))
        else
        end
      end

      def map_collection_actions(map, resource)
        resource.collection_methods.each do |method, actions|
          actions.each do |action|
            [method].flatten.each do |m|
              map_resource_routes(map, resource, action, "#{resource.path}#{resource.action_separator}#{action}", "#{action}_#{resource.name_prefix}#{resource.plural}", m)
            end
          end
        end
      end

      def map_default_collection_actions(map, resource)
        index_route_name = "#{resource.name_prefix}#{resource.plural}"

        if resource.uncountable?
          index_route_name << "_index"
        end

        map_resource_routes(map, resource, :index, resource.path, index_route_name)
        map_resource_routes(map, resource, :create, resource.path, index_route_name)
      end

      def map_default_singleton_actions(map, resource)
        map_resource_routes(map, resource, :create, resource.path, "#{resource.shallow_name_prefix}#{resource.singular}")
      end

      def map_new_actions(map, resource)
        resource.new_methods.each do |method, actions|
          actions.each do |action|
            route_path = resource.new_path
            route_name = "new_#{resource.name_prefix}#{resource.singular}"

            unless action == :new
              route_path = "#{route_path}#{resource.action_separator}#{action}"
              route_name = "#{action}_#{route_name}"
            end

            map_resource_routes(map, resource, action, route_path, route_name, method)
          end
        end
      end

      def map_member_actions(map, resource)
        resource.member_methods.each do |method, actions|
          actions.each do |action|
            [method].flatten.each do |m|
              action_path = resource.options[:path_names][action] if resource.options[:path_names].is_a?(Hash)
              action_path ||= Base.resources_path_names[action] || action

              map_resource_routes(map, resource, action, "#{resource.member_path}#{resource.action_separator}#{action_path}", "#{action}_#{resource.shallow_name_prefix}#{resource.singular}", m, { :force_id => true })
            end
          end
        end

        route_path = "#{resource.shallow_name_prefix}#{resource.singular}"
        map_resource_routes(map, resource, :show, resource.member_path, route_path)
        map_resource_routes(map, resource, :update, resource.member_path, route_path)
        map_resource_routes(map, resource, :destroy, resource.member_path, route_path)
      end

      def map_resource_routes(map, resource, action, route_path, route_name = nil, method = nil, resource_options = {} )
        if resource.has_action?(action)
          action_options = action_options_for(action, resource, method, resource_options)
          formatted_route_path = "#{route_path}.:format"

          if route_name && @set.named_routes[route_name.to_sym].nil?
            map.named_route(route_name, formatted_route_path, action_options)
          else
            map.connect(formatted_route_path, action_options)
          end
        end
      end

      def add_conditions_for(conditions, method)
        returning({:conditions => conditions.dup}) do |options|
          options[:conditions][:method] = method unless method == :any
        end
      end

      def action_options_for(action, resource, method = nil, resource_options = {})
        default_options = { :action => action.to_s }
        require_id = !resource.kind_of?(SingletonResource)
        force_id = resource_options[:force_id] && !resource.kind_of?(SingletonResource)

        case default_options[:action]
          when "index", "new"; default_options.merge(add_conditions_for(resource.conditions, method || :get)).merge(resource.requirements)
          when "create";       default_options.merge(add_conditions_for(resource.conditions, method || :post)).merge(resource.requirements)
          when "show", "edit"; default_options.merge(add_conditions_for(resource.conditions, method || :get)).merge(resource.requirements(require_id))
          when "update";       default_options.merge(add_conditions_for(resource.conditions, method || :put)).merge(resource.requirements(require_id))
          when "destroy";      default_options.merge(add_conditions_for(resource.conditions, method || :delete)).merge(resource.requirements(require_id))
          else                 default_options.merge(add_conditions_for(resource.conditions, method)).merge(resource.requirements(force_id))
        end
      end
  end
end
