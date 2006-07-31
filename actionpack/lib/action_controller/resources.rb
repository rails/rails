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
        "#{path_prefix}/#{plural}/:#{singular}_id"
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
          arrayize_values(flip_keys_and_values(actions || {}))
        end
        
        def add_default_action(collection, method, action)
          (collection[method] ||= []).unshift(action)
        end

        def flip_keys_and_values(hash)
          hash.inject({}) do |flipped_hash, (key, value)|
            flipped_hash[value] = key
            flipped_hash
          end
        end

        def arrayize_values(hash)
          hash.each do |(key, value)|
            unless value.is_a?(Array)
              hash[key] = []
              hash[key] << value
            end
          end
        end
    end
    
    def resources(*entities)
      options = entities.last.is_a?(Hash) ? entities.pop : { }
      entities.each { |entity| map_resource(entity, options) { yield if block_given? } }
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
            name = "new_#{resource.plural}"
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
          map.named_route("#{resource.name_prefix}#{resource.singular}", resource.member_path, :action => "show", :conditions => { :method => :get })
          map.named_route("formatted_#{resource.name_prefix}#{resource.singular}", "#{resource.member_path}.:format", :action => "show", :conditions => { :method => :get })
        end
      end
    
      def requirements_for(method)
        method == :any ? {} : { :conditions => { :method => method } }
      end
  end
end

ActionController::Routing::RouteSet::Mapper.send :include, ActionController::Resources