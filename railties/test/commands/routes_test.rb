# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
require "rails/commands/routes/routes_command"
require "io/console/size"

class Rails::Command::RoutesTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "singular resource output in rails routes" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        resource :post
        resource :user_permission
      end
    RUBY

    expected_post_output = ["   Prefix Verb   URI Pattern          Controller#Action",
                            " new_post GET    /post/new(.:format)  posts#new",
                            "edit_post GET    /post/edit(.:format) posts#edit",
                            "     post GET    /post(.:format)      posts#show",
                            "          PATCH  /post(.:format)      posts#update",
                            "          PUT    /post(.:format)      posts#update",
                            "          DELETE /post(.:format)      posts#destroy",
                            "          POST   /post(.:format)      posts#create\n"].join("\n")

    output = run_routes_command(["-c", "PostController"])
    assert_equal expected_post_output, output

    expected_perm_output = ["              Prefix Verb   URI Pattern                     Controller#Action",
                            " new_user_permission GET    /user_permission/new(.:format)  user_permissions#new",
                            "edit_user_permission GET    /user_permission/edit(.:format) user_permissions#edit",
                            "     user_permission GET    /user_permission(.:format)      user_permissions#show",
                            "                     PATCH  /user_permission(.:format)      user_permissions#update",
                            "                     PUT    /user_permission(.:format)      user_permissions#update",
                            "                     DELETE /user_permission(.:format)      user_permissions#destroy",
                            "                     POST   /user_permission(.:format)      user_permissions#create\n"].join("\n")

    output = run_routes_command(["-c", "UserPermissionController"])
    assert_equal expected_perm_output, output
  end

  test "rails routes with global search key" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get '/cart', to: 'cart#show'
        post '/cart', to: 'cart#create'
        get '/basketballs', to: 'basketball#index'
      end
    RUBY

    output = run_routes_command(["-g", "show"])
    assert_equal <<~MESSAGE, output
                         Prefix Verb URI Pattern                                                                              Controller#Action
                           cart GET  /cart(.:format)                                                                          cart#show
             rails_service_blob GET  /rails/active_storage/blobs/:signed_id/*filename(.:format)                               active_storage/blobs#show
      rails_blob_representation GET  /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations#show
             rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format)                              active_storage/disk#show
    MESSAGE

    output = run_routes_command(["-g", "POST"])
    assert_equal <<~MESSAGE, output
                    Prefix Verb URI Pattern                                    Controller#Action
                           POST /cart(.:format)                                cart#create
      rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format) active_storage/direct_uploads#create
    MESSAGE

    output = run_routes_command(["-g", "basketballs"])
    assert_equal "     Prefix Verb URI Pattern            Controller#Action\n" \
                 "basketballs GET  /basketballs(.:format) basketball#index\n", output
  end

  test "rails routes with controller search key" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get '/cart', to: 'cart#show'
        get '/basketball', to: 'basketball#index'
        get '/user_permission', to: 'user_permission#index'
      end
    RUBY

    expected_cart_output = "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n"
    output = run_routes_command(["-c", "cart"])
    assert_equal expected_cart_output, output

    output = run_routes_command(["-c", "Cart"])
    assert_equal expected_cart_output, output

    output = run_routes_command(["-c", "CartController"])
    assert_equal expected_cart_output, output

    expected_perm_output = ["         Prefix Verb URI Pattern                Controller#Action",
                            "user_permission GET  /user_permission(.:format) user_permission#index\n"].join("\n")
    output = run_routes_command(["-c", "user_permission"])
    assert_equal expected_perm_output, output

    output = run_routes_command(["-c", "UserPermission"])
    assert_equal expected_perm_output, output

    output = run_routes_command(["-c", "UserPermissionController"])
    assert_equal expected_perm_output, output
  end

  test "rails routes with namespaced controller search key" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        namespace :admin do
          resource :post
          resource :user_permission
        end
      end
    RUBY

    expected_post_output = ["         Prefix Verb   URI Pattern                Controller#Action",
                            " new_admin_post GET    /admin/post/new(.:format)  admin/posts#new",
                            "edit_admin_post GET    /admin/post/edit(.:format) admin/posts#edit",
                            "     admin_post GET    /admin/post(.:format)      admin/posts#show",
                            "                PATCH  /admin/post(.:format)      admin/posts#update",
                            "                PUT    /admin/post(.:format)      admin/posts#update",
                            "                DELETE /admin/post(.:format)      admin/posts#destroy",
                            "                POST   /admin/post(.:format)      admin/posts#create\n"].join("\n")

    output = run_routes_command(["-c", "Admin::PostController"])
    assert_equal expected_post_output, output

    output = run_routes_command(["-c", "PostController"])
    assert_equal expected_post_output, output

    expected_perm_output = ["                    Prefix Verb   URI Pattern                           Controller#Action",
                            " new_admin_user_permission GET    /admin/user_permission/new(.:format)  admin/user_permissions#new",
                            "edit_admin_user_permission GET    /admin/user_permission/edit(.:format) admin/user_permissions#edit",
                            "     admin_user_permission GET    /admin/user_permission(.:format)      admin/user_permissions#show",
                            "                           PATCH  /admin/user_permission(.:format)      admin/user_permissions#update",
                            "                           PUT    /admin/user_permission(.:format)      admin/user_permissions#update",
                            "                           DELETE /admin/user_permission(.:format)      admin/user_permissions#destroy",
                            "                           POST   /admin/user_permission(.:format)      admin/user_permissions#create\n"].join("\n")

    output = run_routes_command(["-c", "Admin::UserPermissionController"])
    assert_equal expected_perm_output, output

    output = run_routes_command(["-c", "UserPermissionController"])
    assert_equal expected_perm_output, output
  end

  test "rails routes displays message when no routes are defined" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
      end
    RUBY

    assert_equal <<~MESSAGE, run_routes_command
                         Prefix Verb URI Pattern                                                                              Controller#Action
             rails_service_blob GET  /rails/active_storage/blobs/:signed_id/*filename(.:format)                               active_storage/blobs#show
      rails_blob_representation GET  /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format) active_storage/representations#show
             rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format)                              active_storage/disk#show
      update_rails_disk_service PUT  /rails/active_storage/disk/:encoded_token(.:format)                                      active_storage/disk#update
           rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format)                                           active_storage/direct_uploads#create
    MESSAGE
  end

  test "rails routes with expanded option" do
    begin
      previous_console_winsize = IO.console.winsize
      IO.console.winsize = [0, 27]

      app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/cart', to: 'cart#show'
        end
      RUBY

      output = run_routes_command(["--expanded"])

      assert_equal <<~MESSAGE, output
        --[ Route 1 ]--------------
        Prefix            | cart
        Verb              | GET
        URI               | /cart(.:format)
        Controller#Action | cart#show
        --[ Route 2 ]--------------
        Prefix            | rails_service_blob
        Verb              | GET
        URI               | /rails/active_storage/blobs/:signed_id/*filename(.:format)
        Controller#Action | active_storage/blobs#show
        --[ Route 3 ]--------------
        Prefix            | rails_blob_representation
        Verb              | GET
        URI               | /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format)
        Controller#Action | active_storage/representations#show
        --[ Route 4 ]--------------
        Prefix            | rails_disk_service
        Verb              | GET
        URI               | /rails/active_storage/disk/:encoded_key/*filename(.:format)
        Controller#Action | active_storage/disk#show
        --[ Route 5 ]--------------
        Prefix            | update_rails_disk_service
        Verb              | PUT
        URI               | /rails/active_storage/disk/:encoded_token(.:format)
        Controller#Action | active_storage/disk#update
        --[ Route 6 ]--------------
        Prefix            | rails_direct_uploads
        Verb              | POST
        URI               | /rails/active_storage/direct_uploads(.:format)
        Controller#Action | active_storage/direct_uploads#create
      MESSAGE
    ensure
      IO.console.winsize = previous_console_winsize
    end
  end

  private
    def run_routes_command(args = [])
      rails "routes", args
    end
end
