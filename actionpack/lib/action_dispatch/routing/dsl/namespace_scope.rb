module ActionDispatch
  module Routing
    class Mapper
      module DSL
        module Scoping
          # Scopes routes to a specific namespace. For example:
          #
          #   namespace :admin do
          #     resources :posts
          #   end
          #
          # This generates the following routes:
          #
          #       admin_posts GET       /admin/posts(.:format)          admin/posts#index
          #       admin_posts POST      /admin/posts(.:format)          admin/posts#create
          #    new_admin_post GET       /admin/posts/new(.:format)      admin/posts#new
          #   edit_admin_post GET       /admin/posts/:id/edit(.:format) admin/posts#edit
          #        admin_post GET       /admin/posts/:id(.:format)      admin/posts#show
          #        admin_post PATCH/PUT /admin/posts/:id(.:format)      admin/posts#update
          #        admin_post DELETE    /admin/posts/:id(.:format)      admin/posts#destroy
          #
          # === Options
          #
          # The +:path+, +:as+, +:module+, +:shallow_path+ and +:shallow_prefix+
          # options all default to the name of the namespace.
          #
          # For options, see <tt>Base#match</tt>. For +:shallow_path+ option, see
          # <tt>Resources#resources</tt>.
          #
          #   # accessible through /sekret/posts rather than /admin/posts
          #   namespace :admin, path: "sekret" do
          #     resources :posts
          #   end
          #
          #   # maps to <tt>Sekret::PostsController</tt> rather than <tt>Admin::PostsController</tt>
          #   namespace :admin, module: "sekret" do
          #     resources :posts
          #   end
          #
          #   # generates +sekret_posts_path+ rather than +admin_posts_path+
          #   namespace :admin, as: "sekret" do
          #     resources :posts
          #   end
          def namespace(path, options = {})
            path = path.to_s

            defaults = {
              module:         path,
              path:           options.fetch(:path, path),
              as:             options.fetch(:as, path),
              shallow_path:   options.fetch(:path, path),
              shallow_prefix: options.fetch(:as, path)
            }

            scope(defaults.merge!(options)) { yield }
          end
        end
      end
    end
  end
end
