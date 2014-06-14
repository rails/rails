module ActionDispatch
  module Routing
    class Mapper
      module DSL
        # You may wish to organize groups of controllers under a namespace.
        # Most commonly, you might group a number of administrative controllers
        # under an +admin+ namespace. You would place these controllers under
        # the <tt>app/controllers/admin</tt> directory, and you can group them
        # together in your router:
        #
        #   namespace "admin" do
        #     resources :posts, :comments
        #   end
        #
        # This will create a number of routes for each of the posts and comments
        # controller. For <tt>Admin::PostsController</tt>, Rails will create:
        #
        #   GET       /admin/posts
        #   GET       /admin/posts/new
        #   POST      /admin/posts
        #   GET       /admin/posts/1
        #   GET       /admin/posts/1/edit
        #   PATCH/PUT /admin/posts/1
        #   DELETE    /admin/posts/1
        #
        # If you want to route /posts (without the prefix /admin) to
        # <tt>Admin::PostsController</tt>, you could use
        #
        #   scope module: "admin" do
        #     resources :posts
        #   end
        #
        # or, for a single case
        #
        #   resources :posts, module: "admin"
        #
        # If you want to route /admin/posts to +PostsController+
        # (without the Admin:: module prefix), you could use
        #
        #   scope "/admin" do
        #     resources :posts
        #   end
        #
        # or, for a single case
        #
        #   resources :posts, path: "/admin/posts"
        #
        # In each of these cases, the named routes remain the same as if you did
        # not use scope. In the last case, the following paths map to
        # +PostsController+:
        #
        #   GET       /admin/posts
        #   GET       /admin/posts/new
        #   POST      /admin/posts
        #   GET       /admin/posts/1
        #   GET       /admin/posts/1/edit
        #   PATCH/PUT /admin/posts/1
        #   DELETE    /admin/posts/1
        module Scoping
          # Scopes a set of routes to the given default options.
          #
          # Take the following route definition as an example:
          #
          #   scope path: ":account_id", as: "account" do
          #     resources :projects
          #   end
          #
          # This generates helpers such as +account_projects_path+, just like +resources+ does.
          # The difference here being that the routes generated are like /:account_id/projects,
          # rather than /accounts/:account_id/projects.
          #
          # === Options
          #
          # Takes same options as <tt>Base#match</tt> and <tt>Resources#resources</tt>.
          #
          #   # route /posts (without the prefix /admin) to <tt>Admin::PostsController</tt>
          #   scope module: "admin" do
          #     resources :posts
          #   end
          #
          #   # prefix the posts resource's requests with '/admin'
          #   scope path: "/admin" do
          #     resources :posts
          #   end
          #
          #   # prefix the routing helper name: +sekret_posts_path+ instead of +posts_path+
          #   scope as: "sekret" do
          #     resources :posts
          #   end
          def scope(*args)
            options = args.extract_options!.dup
            recover = {}

            options[:path] = args.flatten.join('/') if args.any?
            options[:constraints] ||= {}

            unless nested_scope?
              options[:shallow_path] ||= options[:path] if options.key?(:path)
              options[:shallow_prefix] ||= options[:as] if options.key?(:as)
            end

            if options[:constraints].is_a?(Hash)
              defaults = options[:constraints].select do
                |k, v| URL_OPTIONS.include?(k) && (v.is_a?(String) || v.is_a?(Fixnum))
              end

              (options[:defaults] ||= {}).reverse_merge!(defaults)
            else
              block, options[:constraints] = options[:constraints], {}
            end

            SCOPE_OPTIONS.each do |option|
              if option == :blocks
                value = block
              elsif option == :options
                value = options
              else
                value = options.delete(option)
              end

              if value
                recover[option] = @scope[option]
                @scope[option]  = send("merge_#{option}_scope", @scope[option], value)
              end
            end

            yield
            self
          ensure
            @scope.merge!(recover)
          end

          # Scopes routes to a specific controller
          #
          #   controller "food" do
          #     match "bacon", action: "bacon"
          #   end
          def controller(controller, options={})
            options[:controller] = controller
            scope(options) { yield }
          end

          # Allows you to set default parameters for a route, such as this:
          #   defaults id: 'home' do
          #     match 'scoped_pages/(:id)', to: 'pages#show'
          #   end
          # Using this, the +:id+ parameter here will default to 'home'.
          def defaults(defaults = {})
            scope(:defaults => defaults) { yield }
          end

          private
            def merge_path_scope(parent, child) #:nodoc:
              Mapper.normalize_path("#{parent}/#{child}")
            end

            def merge_shallow_path_scope(parent, child) #:nodoc:
              Mapper.normalize_path("#{parent}/#{child}")
            end

            def merge_as_scope(parent, child) #:nodoc:
              parent ? "#{parent}_#{child}" : child
            end

            def merge_shallow_prefix_scope(parent, child) #:nodoc:
              parent ? "#{parent}_#{child}" : child
            end

            def merge_module_scope(parent, child) #:nodoc:
              parent ? "#{parent}/#{child}" : child
            end

            def merge_controller_scope(parent, child) #:nodoc:
              child
            end

            def merge_action_scope(parent, child) #:nodoc:
              child
            end

            def merge_path_names_scope(parent, child) #:nodoc:
              merge_options_scope(parent, child)
            end

            def merge_constraints_scope(parent, child) #:nodoc:
              merge_options_scope(parent, child)
            end

            def merge_defaults_scope(parent, child) #:nodoc:
              merge_options_scope(parent, child)
            end

            def merge_blocks_scope(parent, child) #:nodoc:
              merged = parent ? parent.dup : []
              merged << child if child
              merged
            end

            def merge_options_scope(parent, child) #:nodoc:
              (parent || {}).except(*override_keys(child)).merge!(child)
            end

            def merge_shallow_scope(parent, child) #:nodoc:
              child ? true : false
            end

            def override_keys(child) #:nodoc:
              child.key?(:only) || child.key?(:except) ? [:only, :except] : []
            end
        end
      end
    end
  end
end
