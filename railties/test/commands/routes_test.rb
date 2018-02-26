# frozen_string_literal: true

require "isolation/abstract_unit"
require "env_helpers"
require "rails/command"
require "rails/commands/routes/routes_command"

class Rails::Command::RoutesTest < ActiveSupport::TestCase
  setup :build_app
  teardown :teardown_app

  test "test singular resource output in rake routes" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        resource :post
      end
    RUBY

    expected_output = ["   Prefix Verb   URI Pattern          Controller#Action",
                       " new_post GET    /post/new(.:format)  posts#new",
                       "edit_post GET    /post/edit(.:format) posts#edit",
                       "     post GET    /post(.:format)      posts#show",
                       "          PATCH  /post(.:format)      posts#update",
                       "          PUT    /post(.:format)      posts#update",
                       "          DELETE /post(.:format)      posts#destroy",
                       "          POST   /post(.:format)      posts#create\n"].join("\n")

    output = run_routes_command(["-c", "PostController"])
    assert_equal expected_output, output
  end

  test "test rails routes with global search key" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get '/cart', to: 'cart#show'
        post '/cart', to: 'cart#create'
        get '/basketballs', to: 'basketball#index'
      end
    RUBY

    output = run_routes_command(["-g", "show"])
    assert_equal <<~MESSAGE, output
                            Prefix Verb URI Pattern                                                                       Controller#Action
                              cart GET  /cart(.:format)                                                                   cart#show
                rails_service_blob GET  /rails/active_storage/blobs/:signed_id/*filename(.:format)                        active_storage/blobs#show
              rails_blob_variation GET  /rails/active_storage/variants/:signed_blob_id/:variation_key/*filename(.:format) active_storage/variants#show
                rails_blob_preview GET  /rails/active_storage/previews/:signed_blob_id/:variation_key/*filename(.:format) active_storage/previews#show
                rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format)                       active_storage/disk#show
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

  test "test rails routes with controller search_key" do
    app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          get '/cart', to: 'cart#show'
          get '/basketball', to: 'basketball#index'
        end
    RUBY

    output = run_routes_command(["-c", "cart"])
    assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output

    output = run_routes_command(["routes", "-c", "Cart"])
    assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output

    output = run_routes_command(["-c", "CartController"])
    assert_equal "Prefix Verb URI Pattern     Controller#Action\n  cart GET  /cart(.:format) cart#show\n", output
  end

  test "test rails routes with namespaced controller search key" do
    app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
          namespace :admin do
            resource :post
          end
        end
    RUBY
    expected_output = ["         Prefix Verb   URI Pattern                Controller#Action",
                       " new_admin_post GET    /admin/post/new(.:format)  admin/posts#new",
                       "edit_admin_post GET    /admin/post/edit(.:format) admin/posts#edit",
                       "     admin_post GET    /admin/post(.:format)      admin/posts#show",
                       "                PATCH  /admin/post(.:format)      admin/posts#update",
                       "                PUT    /admin/post(.:format)      admin/posts#update",
                       "                DELETE /admin/post(.:format)      admin/posts#destroy",
                       "                POST   /admin/post(.:format)      admin/posts#create\n"].join("\n")

    output = run_routes_command(["-c", "Admin::PostController"])
    assert_equal expected_output, output

    output = run_routes_command(["-c", "PostController"])
    assert_equal expected_output, output
  end

  test "test rails routes displays message when no routes are defined" do
    app_file "config/routes.rb", <<-RUBY
        Rails.application.routes.draw do
        end
    RUBY

    assert_equal <<~MESSAGE, run_routes_command
                              Prefix Verb URI Pattern                                                                       Controller#Action
                  rails_service_blob GET  /rails/active_storage/blobs/:signed_id/*filename(.:format)                        active_storage/blobs#show
                rails_blob_variation GET  /rails/active_storage/variants/:signed_blob_id/:variation_key/*filename(.:format) active_storage/variants#show
                  rails_blob_preview GET  /rails/active_storage/previews/:signed_blob_id/:variation_key/*filename(.:format) active_storage/previews#show
                  rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format)                       active_storage/disk#show
           update_rails_disk_service PUT  /rails/active_storage/disk/:encoded_token(.:format)                               active_storage/disk#update
                rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format)                                    active_storage/direct_uploads#create
    MESSAGE
  end

  private

    def run_routes_command(args = [])
      rails "routes", args
    end
end
