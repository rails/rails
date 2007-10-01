module ActionController
  module Resources
    class Resource #:nodoc:
      attr_reader :collection_methods, :member_methods, :new_methods
      attr_reader :path_prefix, :new_name_prefix
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
        @controller ||= (options[:controller] || plural).to_s
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

      def deprecate_name_prefix?
        @name_prefix.blank? && !@new_name_prefix.blank?
      end

      def name_prefix
        deprecate_name_prefix? ? @new_name_prefix : @name_prefix
      end

      def old_name_prefix
        @name_prefix
      end

      def nesting_name_prefix
        "#{new_name_prefix}#{singular}_"
      end

      def action_separator
        @action_separator ||= Base.resource_action_separator
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
          @new_name_prefix = options.delete(:new_name_prefix)
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
        @plural = @singular = entity
        @options = options
        arrange_actions
        add_default_actions
        set_prefixes
      end

      alias_method :member_path,         :path
      alias_method :nesting_path_prefix, :path
    end

    # Creates named routes for implementing verb-oriented controllers. This is
    # useful for implementing REST API's, where a single resource has different
    # behavior based on the HTTP verb (method) used to access it.
    # 
    # Example:
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
    # The #resources method sets HTTP method restrictions on the routes it generates. For example, making an
    # HTTP POST on <tt>new_message_url</tt> will raise a RoutingError exception. The default route in 
    # <tt>config/routes.rb</tt> overrides this and allows invalid HTTP methods for resource routes.
    # 
    # Along with the routes themselves, #resources generates named routes for use in
    # controllers and views. <tt>map.resources :messages</tt> produces the following named routes and helpers:
    # 
    #   Named Route   Helpers
    #   messages      messages_url, hash_for_messages_url, 
    #                 messages_path, hash_for_messages_path
    #   message       message_url(id), hash_for_message_url(id), 
    #                 message_path(id), hash_for_message_path(id)
    #   new_message   new_message_url, hash_for_new_message_url, 
    #                 new_message_path, hash_for_new_message_path
    #   edit_message  edit_message_url(id), hash_for_edit_message_url(id),
    #                 edit_message_path(id), hash_for_edit_message_path(id)
    #
    # You can use these helpers instead of #url_for or methods that take #url_for parameters:
    # 
    #   redirect_to :controller => 'messages', :action => 'index'
    #   # becomes
    #   redirect_to messages_url
    #
    #   <%= link_to "edit this message", :controller => 'messages', :action => 'edit', :id => @message.id %>
    #   # becomes
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
    # The #resources method accepts various options, too, to customize the resulting
    # routes:
    # * <tt>:controller</tt> -- specify the controller name for the routes.
    # * <tt>:singular</tt> -- specify the singular name used in the member routes.
    # * <tt>:path_prefix</tt> -- set a prefix to the routes with required route variables.
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
    #     article_comments_url(@article)
    #     article_comment_url(@article, @comment)
    #
    #     article_comments_url(:article_id => @article)
    #     article_comment_url(:article_id => @article, :id => @comment)
    #
    # * <tt>:name_prefix</tt> -- define a prefix for all generated routes, usually ending in an underscore.
    #   Use this if you have named routes that may clash.
    #
    #     map.resources :tags, :path_prefix => '/books/:book_id', :name_prefix => 'book_'
    #     map.resources :tags, :path_prefix => '/toys/:toy_id',   :name_prefix => 'toy_'
    #
    # * <tt>:collection</tt> -- add named routes for other actions that operate on the collection.
    #   Takes a hash of <tt>#{action} => #{method}</tt>, where method is <tt>:get</tt>/<tt>:post</tt>/<tt>:put</tt>/<tt>:delete</tt>
    #   or <tt>:any</tt> if the method does not matter.  These routes map to a URL like /messages/rss, with a route of rss_messages_url.
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
    def resources(*entities, &block)
      options = entities.last.is_a?(Hash) ? entities.pop : { }
      entities.each { |entity| map_resource entity, options.dup, &block }
    end

    # Creates named routes for implementing verb-oriented controllers for a singleton resource. 
    # A singleton resource is global to the current user visiting the application, such as a user's
    # /account profile.
    # 
    # See map.resources for general conventions.  These are the main differences:
    #   - A singular name is given to map.resource.  The default controller name is taken from the singular name.
    #   - There is no <tt>:collection</tt> option as there is only the singleton resource.
    #   - There is no <tt>:singular</tt> option as the singular name is passed to map.resource.
    #   - No default index route is created for the singleton resource controller.
    #   - When nesting singleton resources, only the singular name is used as the path prefix (example: 'account/messages/1')
    #
    # Example:
    #
    #   map.resource :account 
    #
    #   class AccountController < ActionController::Base
    #     # POST account_url
    #     def create
    #       # create an account
    #     end
    #
    #     # GET new_account_url
    #     def new
    #       # return an HTML form for describing the new account
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
    # Along with the routes themselves, #resource generates named routes for use in
    # controllers and views. <tt>map.resource :account</tt> produces the following named routes and helpers:
    # 
    #   Named Route   Helpers
    #   account       account_url, hash_for_account_url, 
    #                 account_path, hash_for_account_path
    #   edit_account  edit_account_url, hash_for_edit_account_url,
    #                 edit_account_path, hash_for_edit_account_path
    def resource(*entities, &block)
      options = entities.last.is_a?(Hash) ? entities.pop : { }
      entities.each { |entity| map_singleton_resource entity, options.dup, &block }
    end

    private
      def map_resource(entities, options = {}, &block)
        resource = Resource.new(entities, options)

        with_options :controller => resource.controller do |map|
          map_collection_actions(map, resource)
          map_default_collection_actions(map, resource)
          map_new_actions(map, resource)
          map_member_actions(map, resource)

          if block_given?
            with_options(:path_prefix => resource.nesting_path_prefix, :new_name_prefix => resource.nesting_name_prefix, &block)
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

          if block_given?
            with_options(:path_prefix => resource.nesting_path_prefix, :new_name_prefix => resource.nesting_name_prefix, &block)
          end
        end
      end

      def map_collection_actions(map, resource)
        resource.collection_methods.each do |method, actions|
          actions.each do |action|
            action_options = action_options_for(action, resource, method)

            unless resource.old_name_prefix.blank?
              map.deprecated_named_route("#{action}_#{resource.name_prefix}#{resource.plural}", "#{resource.old_name_prefix}#{action}_#{resource.plural}")
              map.deprecated_named_route("formatted_#{action}_#{resource.name_prefix}#{resource.plural}", "formatted_#{resource.old_name_prefix}#{action}_#{resource.plural}")
            end

            if resource.deprecate_name_prefix?
              map.deprecated_named_route("#{action}_#{resource.name_prefix}#{resource.plural}", "#{action}_#{resource.plural}")
              map.deprecated_named_route("formatted_#{action}_#{resource.name_prefix}#{resource.plural}", "formatted_#{action}_#{resource.plural}")
            end

            map.named_route("#{action}_#{resource.name_prefix}#{resource.plural}", "#{resource.path}#{resource.action_separator}#{action}", action_options)
            map.connect("#{resource.path};#{action}", action_options)
            map.connect("#{resource.path}.:format;#{action}", action_options)
            map.named_route("formatted_#{action}_#{resource.name_prefix}#{resource.plural}", "#{resource.path}#{resource.action_separator}#{action}.:format", action_options)
          end
        end
      end

      def map_default_collection_actions(map, resource)
        index_action_options = action_options_for("index", resource)
        map.named_route("#{resource.name_prefix}#{resource.plural}", resource.path, index_action_options)
        map.named_route("formatted_#{resource.name_prefix}#{resource.plural}", "#{resource.path}.:format", index_action_options)

        if resource.deprecate_name_prefix?
          map.deprecated_named_route("#{resource.name_prefix}#{resource.plural}", "#{resource.plural}")
          map.deprecated_named_route("formatted_#{resource.name_prefix}#{resource.plural}", "formatted_#{resource.plural}")
        end

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

              unless resource.old_name_prefix.blank?
                map.deprecated_named_route("new_#{resource.name_prefix}#{resource.singular}", "#{resource.old_name_prefix}new_#{resource.singular}")
                map.deprecated_named_route("formatted_new_#{resource.name_prefix}#{resource.singular}", "formatted_#{resource.old_name_prefix}new_#{resource.singular}")
              end

              if resource.deprecate_name_prefix?
                map.deprecated_named_route("new_#{resource.name_prefix}#{resource.singular}", "new_#{resource.singular}")
                map.deprecated_named_route("formatted_new_#{resource.name_prefix}#{resource.singular}", "formatted_new_#{resource.singular}")
              end

              map.named_route("new_#{resource.name_prefix}#{resource.singular}", resource.new_path, action_options)
              map.named_route("formatted_new_#{resource.name_prefix}#{resource.singular}", "#{resource.new_path}.:format", action_options)

            else

              unless resource.old_name_prefix.blank?
                map.deprecated_named_route("#{action}_new_#{resource.name_prefix}#{resource.singular}", "#{resource.old_name_prefix}#{action}_new_#{resource.singular}")
                map.deprecated_named_route("formatted_#{action}_new_#{resource.name_prefix}#{resource.singular}", "formatted_#{resource.old_name_prefix}#{action}_new_#{resource.singular}")
              end

              if resource.deprecate_name_prefix?
                map.deprecated_named_route("#{action}_new_#{resource.name_prefix}#{resource.singular}", "#{action}_new_#{resource.singular}")
                map.deprecated_named_route("formatted_#{action}_new_#{resource.name_prefix}#{resource.singular}", "formatted_#{action}_new_#{resource.singular}")
              end

              map.named_route("#{action}_new_#{resource.name_prefix}#{resource.singular}", "#{resource.new_path}#{resource.action_separator}#{action}", action_options)
              map.connect("#{resource.new_path};#{action}", action_options)
              map.connect("#{resource.new_path}.:format;#{action}", action_options)
              map.named_route("formatted_#{action}_new_#{resource.name_prefix}#{resource.singular}", "#{resource.new_path}#{resource.action_separator}#{action}.:format", action_options)

            end
          end
        end
      end

      def map_member_actions(map, resource)
        resource.member_methods.each do |method, actions|
          actions.each do |action|
            action_options = action_options_for(action, resource, method)

            unless resource.old_name_prefix.blank?
              map.deprecated_named_route("#{action}_#{resource.name_prefix}#{resource.singular}", "#{resource.old_name_prefix}#{action}_#{resource.singular}")
              map.deprecated_named_route("formatted_#{action}_#{resource.name_prefix}#{resource.singular}", "formatted_#{resource.old_name_prefix}#{action}_#{resource.singular}")
            end

            if resource.deprecate_name_prefix?
              map.deprecated_named_route("#{action}_#{resource.name_prefix}#{resource.singular}", "#{action}_#{resource.singular}")
              map.deprecated_named_route("formatted_#{action}_#{resource.name_prefix}#{resource.singular}", "formatted_#{action}_#{resource.singular}")
            end

            map.named_route("#{action}_#{resource.name_prefix}#{resource.singular}", "#{resource.member_path}#{resource.action_separator}#{action}", action_options)
            map.connect("#{resource.member_path};#{action}", action_options)
            map.connect("#{resource.member_path}.:format;#{action}", action_options)
            map.named_route("formatted_#{action}_#{resource.name_prefix}#{resource.singular}", "#{resource.member_path}#{resource.action_separator}#{action}.:format", action_options)

          end
        end

        show_action_options = action_options_for("show", resource)
        map.named_route("#{resource.name_prefix}#{resource.singular}", resource.member_path, show_action_options)
        map.named_route("formatted_#{resource.name_prefix}#{resource.singular}", "#{resource.member_path}.:format", show_action_options)

        if resource.deprecate_name_prefix?
          map.deprecated_named_route("#{resource.name_prefix}#{resource.singular}", "#{resource.singular}")
          map.deprecated_named_route("formatted_#{resource.name_prefix}#{resource.singular}", "formatted_#{resource.singular}")
        end

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
        require_id = resource.kind_of?(SingletonResource) ? {} : { :requirements => { :id => Regexp.new("[^#{Routing::SEPARATORS.join}]+") } }
        case default_options[:action]
          when "index", "new" : default_options.merge(conditions_for(method || :get))
          when "create"       : default_options.merge(conditions_for(method || :post))
          when "show", "edit" : default_options.merge(conditions_for(method || :get)).merge(require_id)
          when "update"       : default_options.merge(conditions_for(method || :put)).merge(require_id)
          when "destroy"      : default_options.merge(conditions_for(method || :delete)).merge(require_id)
          else                  default_options.merge(conditions_for(method))
        end
      end
  end
end

ActionController::Routing::RouteSet::Mapper.send :include, ActionController::Resources
