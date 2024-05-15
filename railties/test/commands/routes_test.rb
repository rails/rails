# frozen_string_literal: true

require "isolation/abstract_unit"
require "rails/command"
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

    assert_equal <<~OUTPUT, run_routes_command([ "-c", "PostController" ])
                             Prefix Verb   URI Pattern                                                        Controller#Action
                           new_post GET    /post/new(.:format(+:variant))                                     posts#new
                          edit_post GET    /post/edit(.:format(+:variant))                                    posts#edit
                               post GET    /post(.:format(+:variant))                                         posts#show
                                    PATCH  /post(.:format(+:variant))                                         posts#update
                                    PUT    /post(.:format(+:variant))                                         posts#update
                                    DELETE /post(.:format(+:variant))                                         posts#destroy
                                    POST   /post(.:format(+:variant))                                         posts#create
      rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format(+:variant)) action_mailbox/ingresses/postmark/inbound_emails#create
    OUTPUT

    assert_equal <<~OUTPUT, run_routes_command([ "-c", "UserPermissionController" ])
                    Prefix Verb   URI Pattern                                Controller#Action
       new_user_permission GET    /user_permission/new(.:format(+:variant))  user_permissions#new
      edit_user_permission GET    /user_permission/edit(.:format(+:variant)) user_permissions#edit
           user_permission GET    /user_permission(.:format(+:variant))      user_permissions#show
                           PATCH  /user_permission(.:format(+:variant))      user_permissions#update
                           PUT    /user_permission(.:format(+:variant))      user_permissions#update
                           DELETE /user_permission(.:format(+:variant))      user_permissions#destroy
                           POST   /user_permission(.:format(+:variant))      user_permissions#create
    OUTPUT
  end

  test "rails routes with global search key" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get '/cart', to: 'cart#show'
        post '/cart', to: 'cart#create'
        get '/basketballs', to: 'basketball#index'
      end
    RUBY

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "show" ])
                         Prefix Verb URI Pattern                                                                                                  Controller#Action
                           cart GET  /cart(.:format(+:variant))                                                                                   cart#show
  rails_conductor_inbound_email GET  /rails/conductor/action_mailbox/inbound_emails/:id(.:format(+:variant))                                      rails/conductor/action_mailbox/inbound_emails#show
             rails_service_blob GET  /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format(+:variant))                               active_storage/blobs/redirect#show
       rails_service_blob_proxy GET  /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format(+:variant))                                  active_storage/blobs/proxy#show
                                GET  /rails/active_storage/blobs/:signed_id/*filename(.:format(+:variant))                                        active_storage/blobs/redirect#show
      rails_blob_representation GET  /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format(+:variant)) active_storage/representations/redirect#show
rails_blob_representation_proxy GET  /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format(+:variant))    active_storage/representations/proxy#show
                                GET  /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format(+:variant))          active_storage/representations/redirect#show
             rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format(+:variant))                                       active_storage/disk#show
    MESSAGE

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "POST" ])
                                     Prefix Verb URI Pattern                                                                       Controller#Action
                                            POST /cart(.:format(+:variant))                                                        cart#create
              rails_postmark_inbound_emails POST /rails/action_mailbox/postmark/inbound_emails(.:format(+:variant))                action_mailbox/ingresses/postmark/inbound_emails#create
                 rails_relay_inbound_emails POST /rails/action_mailbox/relay/inbound_emails(.:format(+:variant))                   action_mailbox/ingresses/relay/inbound_emails#create
              rails_sendgrid_inbound_emails POST /rails/action_mailbox/sendgrid/inbound_emails(.:format(+:variant))                action_mailbox/ingresses/sendgrid/inbound_emails#create
              rails_mandrill_inbound_emails POST /rails/action_mailbox/mandrill/inbound_emails(.:format(+:variant))                action_mailbox/ingresses/mandrill/inbound_emails#create
               rails_mailgun_inbound_emails POST /rails/action_mailbox/mailgun/inbound_emails/mime(.:format(+:variant))            action_mailbox/ingresses/mailgun/inbound_emails#create
                                            POST /rails/conductor/action_mailbox/inbound_emails(.:format(+:variant))               rails/conductor/action_mailbox/inbound_emails#create
      rails_conductor_inbound_email_sources POST /rails/conductor/action_mailbox/inbound_emails/sources(.:format(+:variant))       rails/conductor/action_mailbox/inbound_emails/sources#create
      rails_conductor_inbound_email_reroute POST /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format(+:variant))    rails/conductor/action_mailbox/reroutes#create
   rails_conductor_inbound_email_incinerate POST /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format(+:variant)) rails/conductor/action_mailbox/incinerates#create
                       rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format(+:variant))                         active_storage/direct_uploads#create
    MESSAGE

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "basketballs" ])
           Prefix Verb URI Pattern                       Controller#Action
      basketballs GET  /basketballs(.:format(+:variant)) basketball#index
    MESSAGE
  end

  test "rails routes with matching path" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        resources :photos
        get '/cart', to: 'cart#show'
        post '/cart', to: 'cart#create'
        get '/basketballs', to: 'basketball#index'
      end
    RUBY

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "/cart" ])
    Prefix Verb URI Pattern                Controller#Action
      cart GET  /cart(.:format(+:variant)) cart#show
           POST /cart(.:format(+:variant)) cart#create
    MESSAGE

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "basketballs" ])
           Prefix Verb URI Pattern                       Controller#Action
      basketballs GET  /basketballs(.:format(+:variant)) basketball#index
    MESSAGE

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "/photos/7" ])
    Prefix Verb   URI Pattern                      Controller#Action
     photo GET    /photos/:id(.:format(+:variant)) photos#show
           PATCH  /photos/:id(.:format(+:variant)) photos#update
           PUT    /photos/:id(.:format(+:variant)) photos#update
           DELETE /photos/:id(.:format(+:variant)) photos#destroy
    MESSAGE

    assert_equal <<~MESSAGE, run_routes_command([ "-g", "/cats" ])
    No routes were found for this grep pattern.
    For more information about routes, see the Rails guide: https://guides.rubyonrails.org/routing.html.
    MESSAGE
  end

  test "rails routes with controller search key" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get '/cart', to: 'cart#show'
        get '/basketball', to: 'basketball#index'
        get '/user_permission', to: 'user_permission#index'
      end
    RUBY

    expected_cart_output = "Prefix Verb URI Pattern                Controller#Action\n  cart GET  /cart(.:format(+:variant)) cart#show\n"
    output = run_routes_command(["-c", "cart"])
    assert_equal expected_cart_output, output

    output = run_routes_command(["-c", "Cart"])
    assert_equal expected_cart_output, output

    output = run_routes_command(["-c", "CartController"])
    assert_equal expected_cart_output, output

    expected_perm_output = ["         Prefix Verb URI Pattern                           Controller#Action",
                            "user_permission GET  /user_permission(.:format(+:variant)) user_permission#index\n"].join("\n")
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

    assert_equal <<~OUTPUT, run_routes_command([ "-c", "Admin::PostController" ])
               Prefix Verb   URI Pattern                           Controller#Action
       new_admin_post GET    /admin/post/new(.:format(+:variant))  admin/posts#new
      edit_admin_post GET    /admin/post/edit(.:format(+:variant)) admin/posts#edit
           admin_post GET    /admin/post(.:format(+:variant))      admin/posts#show
                      PATCH  /admin/post(.:format(+:variant))      admin/posts#update
                      PUT    /admin/post(.:format(+:variant))      admin/posts#update
                      DELETE /admin/post(.:format(+:variant))      admin/posts#destroy
                      POST   /admin/post(.:format(+:variant))      admin/posts#create
    OUTPUT

    assert_equal <<~OUTPUT, run_routes_command([ "-c", "PostController" ])
                             Prefix Verb   URI Pattern                                                        Controller#Action
                     new_admin_post GET    /admin/post/new(.:format(+:variant))                               admin/posts#new
                    edit_admin_post GET    /admin/post/edit(.:format(+:variant))                              admin/posts#edit
                         admin_post GET    /admin/post(.:format(+:variant))                                   admin/posts#show
                                    PATCH  /admin/post(.:format(+:variant))                                   admin/posts#update
                                    PUT    /admin/post(.:format(+:variant))                                   admin/posts#update
                                    DELETE /admin/post(.:format(+:variant))                                   admin/posts#destroy
                                    POST   /admin/post(.:format(+:variant))                                   admin/posts#create
      rails_postmark_inbound_emails POST   /rails/action_mailbox/postmark/inbound_emails(.:format(+:variant)) action_mailbox/ingresses/postmark/inbound_emails#create
    OUTPUT

    expected_permission_output = <<~OUTPUT
                          Prefix Verb   URI Pattern                                      Controller#Action
       new_admin_user_permission GET    /admin/user_permission/new(.:format(+:variant))  admin/user_permissions#new
      edit_admin_user_permission GET    /admin/user_permission/edit(.:format(+:variant)) admin/user_permissions#edit
           admin_user_permission GET    /admin/user_permission(.:format(+:variant))      admin/user_permissions#show
                                 PATCH  /admin/user_permission(.:format(+:variant))      admin/user_permissions#update
                                 PUT    /admin/user_permission(.:format(+:variant))      admin/user_permissions#update
                                 DELETE /admin/user_permission(.:format(+:variant))      admin/user_permissions#destroy
                                 POST   /admin/user_permission(.:format(+:variant))      admin/user_permissions#create
    OUTPUT

    assert_equal expected_permission_output, run_routes_command([ "-c", "Admin::UserPermissionController" ])
    assert_equal expected_permission_output, run_routes_command([ "-c", "UserPermissionController" ])
  end

  test "rails routes displays message when no routes are defined" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
      end
    RUBY

    assert_equal <<~MESSAGE, run_routes_command
                                  Prefix Verb URI Pattern                                                                                                  Controller#Action
           rails_postmark_inbound_emails POST /rails/action_mailbox/postmark/inbound_emails(.:format(+:variant))                                           action_mailbox/ingresses/postmark/inbound_emails#create
              rails_relay_inbound_emails POST /rails/action_mailbox/relay/inbound_emails(.:format(+:variant))                                              action_mailbox/ingresses/relay/inbound_emails#create
           rails_sendgrid_inbound_emails POST /rails/action_mailbox/sendgrid/inbound_emails(.:format(+:variant))                                           action_mailbox/ingresses/sendgrid/inbound_emails#create
     rails_mandrill_inbound_health_check GET  /rails/action_mailbox/mandrill/inbound_emails(.:format(+:variant))                                           action_mailbox/ingresses/mandrill/inbound_emails#health_check
           rails_mandrill_inbound_emails POST /rails/action_mailbox/mandrill/inbound_emails(.:format(+:variant))                                           action_mailbox/ingresses/mandrill/inbound_emails#create
            rails_mailgun_inbound_emails POST /rails/action_mailbox/mailgun/inbound_emails/mime(.:format(+:variant))                                       action_mailbox/ingresses/mailgun/inbound_emails#create
          rails_conductor_inbound_emails GET  /rails/conductor/action_mailbox/inbound_emails(.:format(+:variant))                                          rails/conductor/action_mailbox/inbound_emails#index
                                         POST /rails/conductor/action_mailbox/inbound_emails(.:format(+:variant))                                          rails/conductor/action_mailbox/inbound_emails#create
       new_rails_conductor_inbound_email GET  /rails/conductor/action_mailbox/inbound_emails/new(.:format(+:variant))                                      rails/conductor/action_mailbox/inbound_emails#new
           rails_conductor_inbound_email GET  /rails/conductor/action_mailbox/inbound_emails/:id(.:format(+:variant))                                      rails/conductor/action_mailbox/inbound_emails#show
new_rails_conductor_inbound_email_source GET  /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format(+:variant))                              rails/conductor/action_mailbox/inbound_emails/sources#new
   rails_conductor_inbound_email_sources POST /rails/conductor/action_mailbox/inbound_emails/sources(.:format(+:variant))                                  rails/conductor/action_mailbox/inbound_emails/sources#create
   rails_conductor_inbound_email_reroute POST /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format(+:variant))                               rails/conductor/action_mailbox/reroutes#create
rails_conductor_inbound_email_incinerate POST /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format(+:variant))                            rails/conductor/action_mailbox/incinerates#create
                      rails_service_blob GET  /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format(+:variant))                               active_storage/blobs/redirect#show
                rails_service_blob_proxy GET  /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format(+:variant))                                  active_storage/blobs/proxy#show
                                         GET  /rails/active_storage/blobs/:signed_id/*filename(.:format(+:variant))                                        active_storage/blobs/redirect#show
               rails_blob_representation GET  /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format(+:variant)) active_storage/representations/redirect#show
         rails_blob_representation_proxy GET  /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format(+:variant))    active_storage/representations/proxy#show
                                         GET  /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format(+:variant))          active_storage/representations/redirect#show
                      rails_disk_service GET  /rails/active_storage/disk/:encoded_key/*filename(.:format(+:variant))                                       active_storage/disk#show
               update_rails_disk_service PUT  /rails/active_storage/disk/:encoded_token(.:format(+:variant))                                               active_storage/disk#update
                    rails_direct_uploads POST /rails/active_storage/direct_uploads(.:format(+:variant))                                                    active_storage/direct_uploads#create
    MESSAGE
  end

  test "rails routes with expanded option" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
        get '/cart', to: 'cart#show'
      end
    RUBY

    output = IO.stub(:console_size, [0, 27]) do
      run_routes_command([ "--expanded" ])
    end

    rails_gem_root = File.expand_path("../../../../", __FILE__)

    assert_equal <<~MESSAGE, output
      --[ Route 1 ]--------------
      Prefix            | cart
      Verb              | GET
      URI               | /cart(.:format(+:variant))
      Controller#Action | cart#show
      Source Location   | #{app_path}/config/routes.rb:2
      --[ Route 2 ]--------------
      Prefix            | rails_postmark_inbound_emails
      Verb              | POST
      URI               | /rails/action_mailbox/postmark/inbound_emails(.:format(+:variant))
      Controller#Action | action_mailbox/ingresses/postmark/inbound_emails#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:5
      --[ Route 3 ]--------------
      Prefix            | rails_relay_inbound_emails
      Verb              | POST
      URI               | /rails/action_mailbox/relay/inbound_emails(.:format(+:variant))
      Controller#Action | action_mailbox/ingresses/relay/inbound_emails#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:6
      --[ Route 4 ]--------------
      Prefix            | rails_sendgrid_inbound_emails
      Verb              | POST
      URI               | /rails/action_mailbox/sendgrid/inbound_emails(.:format(+:variant))
      Controller#Action | action_mailbox/ingresses/sendgrid/inbound_emails#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:7
      --[ Route 5 ]--------------
      Prefix            | rails_mandrill_inbound_health_check
      Verb              | GET
      URI               | /rails/action_mailbox/mandrill/inbound_emails(.:format(+:variant))
      Controller#Action | action_mailbox/ingresses/mandrill/inbound_emails#health_check
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:10
      --[ Route 6 ]--------------
      Prefix            | rails_mandrill_inbound_emails
      Verb              | POST
      URI               | /rails/action_mailbox/mandrill/inbound_emails(.:format(+:variant))
      Controller#Action | action_mailbox/ingresses/mandrill/inbound_emails#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:11
      --[ Route 7 ]--------------
      Prefix            | rails_mailgun_inbound_emails
      Verb              | POST
      URI               | /rails/action_mailbox/mailgun/inbound_emails/mime(.:format(+:variant))
      Controller#Action | action_mailbox/ingresses/mailgun/inbound_emails#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:14
      --[ Route 8 ]--------------
      Prefix            | rails_conductor_inbound_emails
      Verb              | GET
      URI               | /rails/conductor/action_mailbox/inbound_emails(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/inbound_emails#index
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:19
      --[ Route 9 ]--------------
      Prefix            |#{" "}
      Verb              | POST
      URI               | /rails/conductor/action_mailbox/inbound_emails(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/inbound_emails#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:19
      --[ Route 10 ]-------------
      Prefix            | new_rails_conductor_inbound_email
      Verb              | GET
      URI               | /rails/conductor/action_mailbox/inbound_emails/new(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/inbound_emails#new
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:19
      --[ Route 11 ]-------------
      Prefix            | rails_conductor_inbound_email
      Verb              | GET
      URI               | /rails/conductor/action_mailbox/inbound_emails/:id(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/inbound_emails#show
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:19
      --[ Route 12 ]-------------
      Prefix            | new_rails_conductor_inbound_email_source
      Verb              | GET
      URI               | /rails/conductor/action_mailbox/inbound_emails/sources/new(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/inbound_emails/sources#new
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:20
      --[ Route 13 ]-------------
      Prefix            | rails_conductor_inbound_email_sources
      Verb              | POST
      URI               | /rails/conductor/action_mailbox/inbound_emails/sources(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/inbound_emails/sources#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:21
      --[ Route 14 ]-------------
      Prefix            | rails_conductor_inbound_email_reroute
      Verb              | POST
      URI               | /rails/conductor/action_mailbox/:inbound_email_id/reroute(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/reroutes#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:23
      --[ Route 15 ]-------------
      Prefix            | rails_conductor_inbound_email_incinerate
      Verb              | POST
      URI               | /rails/conductor/action_mailbox/:inbound_email_id/incinerate(.:format(+:variant))
      Controller#Action | rails/conductor/action_mailbox/incinerates#create
      Source Location   | #{rails_gem_root}/actionmailbox/config/routes.rb:24
      --[ Route 16 ]-------------
      Prefix            | rails_service_blob
      Verb              | GET
      URI               | /rails/active_storage/blobs/redirect/:signed_id/*filename(.:format(+:variant))
      Controller#Action | active_storage/blobs/redirect#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:5
      --[ Route 17 ]-------------
      Prefix            | rails_service_blob_proxy
      Verb              | GET
      URI               | /rails/active_storage/blobs/proxy/:signed_id/*filename(.:format(+:variant))
      Controller#Action | active_storage/blobs/proxy#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:6
      --[ Route 18 ]-------------
      Prefix            |#{" "}
      Verb              | GET
      URI               | /rails/active_storage/blobs/:signed_id/*filename(.:format(+:variant))
      Controller#Action | active_storage/blobs/redirect#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:7
      --[ Route 19 ]-------------
      Prefix            | rails_blob_representation
      Verb              | GET
      URI               | /rails/active_storage/representations/redirect/:signed_blob_id/:variation_key/*filename(.:format(+:variant))
      Controller#Action | active_storage/representations/redirect#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:9
      --[ Route 20 ]-------------
      Prefix            | rails_blob_representation_proxy
      Verb              | GET
      URI               | /rails/active_storage/representations/proxy/:signed_blob_id/:variation_key/*filename(.:format(+:variant))
      Controller#Action | active_storage/representations/proxy#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:10
      --[ Route 21 ]-------------
      Prefix            |#{" "}
      Verb              | GET
      URI               | /rails/active_storage/representations/:signed_blob_id/:variation_key/*filename(.:format(+:variant))
      Controller#Action | active_storage/representations/redirect#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:11
      --[ Route 22 ]-------------
      Prefix            | rails_disk_service
      Verb              | GET
      URI               | /rails/active_storage/disk/:encoded_key/*filename(.:format(+:variant))
      Controller#Action | active_storage/disk#show
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:13
      --[ Route 23 ]-------------
      Prefix            | update_rails_disk_service
      Verb              | PUT
      URI               | /rails/active_storage/disk/:encoded_token(.:format(+:variant))
      Controller#Action | active_storage/disk#update
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:14
      --[ Route 24 ]-------------
      Prefix            | rails_direct_uploads
      Verb              | POST
      URI               | /rails/active_storage/direct_uploads(.:format(+:variant))
      Controller#Action | active_storage/direct_uploads#create
      Source Location   | #{rails_gem_root}/activestorage/config/routes.rb:15
    MESSAGE
  end

  test "rails routes with unused option" do
    app_file "config/routes.rb", <<-RUBY
      Rails.application.routes.draw do
      end
    RUBY

    output = run_routes_command([ "--unused" ])

    assert_includes(output, "No unused routes found.")
  end

  private
    def run_routes_command(args = [])
      rails "routes", args
    end
end
