require 'erb'
require 'abstract_unit'
require 'controller/fake_controllers'

class TestRoutingMapper < ActionDispatch::IntegrationTest
  SprocketsApp = lambda { |env|
    [200, {"Content-Type" => "text/html"}, ["javascripts"]]
  }

  class IpRestrictor
    def self.matches?(request)
      request.ip =~ /192\.168\.1\.1\d\d/
    end
  end

  class GrumpyRestrictor
    def self.matches?(request)
      false
    end
  end

  class YoutubeFavoritesRedirector
    def self.call(params, request)
      "http://www.youtube.com/watch?v=#{params[:youtube_id]}"
    end
  end

  def test_logout
    draw do
      controller :sessions do
        delete 'logout' => :destroy
      end
    end

    delete '/logout'
    assert_equal 'sessions#destroy', @response.body

    assert_equal '/logout', logout_path
    assert_equal '/logout', url_for(:controller => 'sessions', :action => 'destroy', :only_path => true)
  end

  def test_login
    draw do
      default_url_options :host => "rubyonrails.org"

      controller :sessions do
        get  'login' => :new
        post 'login' => :create
      end
    end

    get '/login'
    assert_equal 'sessions#new', @response.body
    assert_equal '/login', login_path

    post '/login'
    assert_equal 'sessions#create', @response.body

    assert_equal '/login', url_for(:controller => 'sessions', :action => 'create', :only_path => true)
    assert_equal '/login', url_for(:controller => 'sessions', :action => 'new', :only_path => true)

    assert_equal 'http://rubyonrails.org/login', url_for(:controller => 'sessions', :action => 'create')
    assert_equal 'http://rubyonrails.org/login', login_url
  end

  def test_login_redirect
    draw do
      get 'account/login', :to => redirect("/login")
    end

    get '/account/login'
    verify_redirect 'http://www.example.com/login'
  end

  def test_logout_redirect_without_to
    draw do
      get 'account/logout' => redirect("/logout"), :as => :logout_redirect
    end

    assert_equal '/account/logout', logout_redirect_path
    get '/account/logout'
    verify_redirect 'http://www.example.com/logout'
  end

  def test_namespace_redirect
    draw do
      namespace :private do
        root :to => redirect('/private/index')
        get "index", :to => 'private#index'
      end
    end

    get '/private'
    verify_redirect 'http://www.example.com/private/index'
  end

  def test_redirect_with_failing_constraint
    draw do
      get 'hi', to: redirect("/foo"), constraints: ::TestRoutingMapper::GrumpyRestrictor
    end

    get '/hi'
    assert_equal 404, status
  end

  def test_redirect_with_passing_constraint
    draw do
      get 'hi', to: redirect("/foo"), constraints: ->(req) { true }
    end

    get '/hi'
    assert_equal 301, status
  end

  def test_namespace_with_controller_segment
    assert_raise(ArgumentError) do
      draw do
        namespace :admin do
          ActiveSupport::Deprecation.silence do
            get '/:controller(/:action(/:id(.:format)))'
          end
        end
      end
    end
  end

  def test_namespace_without_controller_segment
    draw do
      namespace :admin do
        ActiveSupport::Deprecation.silence do
          get 'hello/:controllers/:action'
        end
      end
    end
    get '/admin/hello/foo/new'
    assert_equal 'foo', @request.params["controllers"]
  end

  def test_session_singleton_resource
    draw do
      resource :session do
        get :create
        post :reset
      end
    end

    get '/session'
    assert_equal 'sessions#create', @response.body
    assert_equal '/session', session_path

    post '/session'
    assert_equal 'sessions#create', @response.body

    put '/session'
    assert_equal 'sessions#update', @response.body

    delete '/session'
    assert_equal 'sessions#destroy', @response.body

    get '/session/new'
    assert_equal 'sessions#new', @response.body
    assert_equal '/session/new', new_session_path

    get '/session/edit'
    assert_equal 'sessions#edit', @response.body
    assert_equal '/session/edit', edit_session_path

    post '/session/reset'
    assert_equal 'sessions#reset', @response.body
    assert_equal '/session/reset', reset_session_path
  end

  def test_session_singleton_resource_for_api_app
    config = ActionDispatch::Routing::RouteSet::Config.new
    config.api_only = true

    self.class.stub_controllers(config) do |routes|
      routes.draw do
        resource :session do
          get :create
          post :reset
        end
      end
      @app = RoutedRackApp.new routes
    end

    get '/session'
    assert_equal 'sessions#create', @response.body
    assert_equal '/session', session_path

    post '/session'
    assert_equal 'sessions#create', @response.body

    put '/session'
    assert_equal 'sessions#update', @response.body

    delete '/session'
    assert_equal 'sessions#destroy', @response.body

    post '/session/reset'
    assert_equal 'sessions#reset', @response.body
    assert_equal '/session/reset', reset_session_path

    get '/session/new'
    assert_equal 'Not Found', @response.body

    get '/session/edit'
    assert_equal 'Not Found', @response.body
  end

  def test_session_info_nested_singleton_resource
    draw do
      resource :session do
        resource :info
      end
    end

    get '/session/info'
    assert_equal 'infos#show', @response.body
    assert_equal '/session/info', session_info_path
  end

  def test_member_on_resource
    draw do
      resource :session do
        member do
          get :crush
        end
      end
    end

    get '/session/crush'
    assert_equal 'sessions#crush', @response.body
    assert_equal '/session/crush', crush_session_path
  end

  def test_redirect_modulo
    draw do
      get 'account/modulo/:name', :to => redirect("/%{name}s")
    end

    get '/account/modulo/name'
    verify_redirect 'http://www.example.com/names'
  end

  def test_redirect_proc
    draw do
      get 'account/proc/:name', :to => redirect {|params, req| "/#{params[:name].pluralize}" }
    end

    get '/account/proc/person'
    verify_redirect 'http://www.example.com/people'
  end

  def test_redirect_proc_with_request
    draw do
      get 'account/proc_req' => redirect {|params, req| "/#{req.method}" }
    end

    get '/account/proc_req'
    verify_redirect 'http://www.example.com/GET'
  end

  def test_redirect_hash_with_subdomain
    draw do
      get 'mobile', :to => redirect(:subdomain => 'mobile')
    end

    get '/mobile'
    verify_redirect 'http://mobile.example.com/mobile'
  end

  def test_redirect_hash_with_domain_and_path
    draw do
      get 'documentation', :to => redirect(:domain => 'example-documentation.com', :path => '')
    end

    get '/documentation'
    verify_redirect 'http://www.example-documentation.com'
  end

  def test_redirect_hash_with_path
    draw do
      get 'new_documentation', :to => redirect(:path => '/documentation/new')
    end

    get '/new_documentation'
    verify_redirect 'http://www.example.com/documentation/new'
  end

  def test_redirect_hash_with_host
    draw do
      get 'super_new_documentation', :to => redirect(:host => 'super-docs.com')
    end

    get '/super_new_documentation?section=top'
    verify_redirect 'http://super-docs.com/super_new_documentation?section=top'
  end

  def test_redirect_hash_path_substitution
    draw do
      get 'stores/:name', :to => redirect(:subdomain => 'stores', :path => '/%{name}')
    end

    get '/stores/iernest'
    verify_redirect 'http://stores.example.com/iernest'
  end

  def test_redirect_hash_path_substitution_with_catch_all
    draw do
      get 'stores/:name(*rest)', :to => redirect(:subdomain => 'stores', :path => '/%{name}%{rest}')
    end

    get '/stores/iernest/products'
    verify_redirect 'http://stores.example.com/iernest/products'
  end

  def test_redirect_class
    draw do
      get 'youtube_favorites/:youtube_id/:name', :to => redirect(YoutubeFavoritesRedirector)
    end

    get '/youtube_favorites/oHg5SJYRHA0/rick-rolld'
    verify_redirect 'http://www.youtube.com/watch?v=oHg5SJYRHA0'
  end

  def test_openid
    draw do
      match 'openid/login', :via => [:get, :post], :to => "openid#login"
    end

    get '/openid/login'
    assert_equal 'openid#login', @response.body

    post '/openid/login'
    assert_equal 'openid#login', @response.body
  end

  def test_bookmarks
    draw do
      scope "bookmark", :controller => "bookmarks", :as => :bookmark do
        get  :new, :path => "build"
        post :create, :path => "create", :as => ""
        put  :update
        get  :remove, :action => :destroy, :as => :remove
      end
    end

    get '/bookmark/build'
    assert_equal 'bookmarks#new', @response.body
    assert_equal '/bookmark/build', bookmark_new_path

    post '/bookmark/create'
    assert_equal 'bookmarks#create', @response.body
    assert_equal '/bookmark/create', bookmark_path

    put '/bookmark/update'
    assert_equal 'bookmarks#update', @response.body
    assert_equal '/bookmark/update', bookmark_update_path

    get '/bookmark/remove'
    assert_equal 'bookmarks#destroy', @response.body
    assert_equal '/bookmark/remove', bookmark_remove_path
  end

  def test_pagemarks
    tc = self
    draw do
      scope "pagemark", :controller => "pagemarks", :as => :pagemark do
        tc.assert_deprecated do
          get  "new", :path => "build"
        end
        post "create", :as => ""
        put  "update"
        get  "remove", :action => :destroy, :as => :remove
        tc.assert_deprecated do
          get action: :show, as: :show
        end
      end
    end

    get '/pagemark/build'
    assert_equal 'pagemarks#new', @response.body
    assert_equal '/pagemark/build', pagemark_new_path

    post '/pagemark/create'
    assert_equal 'pagemarks#create', @response.body
    assert_equal '/pagemark/create', pagemark_path

    put '/pagemark/update'
    assert_equal 'pagemarks#update', @response.body
    assert_equal '/pagemark/update', pagemark_update_path

    get '/pagemark/remove'
    assert_equal 'pagemarks#destroy', @response.body
    assert_equal '/pagemark/remove', pagemark_remove_path

    get '/pagemark'
    assert_equal 'pagemarks#show', @response.body
    assert_equal '/pagemark', pagemark_show_path
  end

  def test_admin
    draw do
      constraints(:ip => /192\.168\.1\.\d\d\d/) do
        get 'admin' => "queenbee#index"
      end

      constraints ::TestRoutingMapper::IpRestrictor do
        get 'admin/accounts' => "queenbee#accounts"
      end

      get 'admin/passwords' => "queenbee#passwords", :constraints => ::TestRoutingMapper::IpRestrictor
    end

    get '/admin', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
    assert_equal 'queenbee#index', @response.body

    get '/admin', headers: { 'REMOTE_ADDR' => '10.0.0.100' }
    assert_equal 'pass', @response.headers['X-Cascade']

    get '/admin/accounts', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
    assert_equal 'queenbee#accounts', @response.body

    get '/admin/accounts', headers: { 'REMOTE_ADDR' => '10.0.0.100' }
    assert_equal 'pass', @response.headers['X-Cascade']

    get '/admin/passwords', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
    assert_equal 'queenbee#passwords', @response.body

    get '/admin/passwords', headers: { 'REMOTE_ADDR' => '10.0.0.100' }
    assert_equal 'pass', @response.headers['X-Cascade']
  end

  def test_global
    draw do
      controller(:global) do
        get 'global/hide_notice'
        get 'global/export',      :action => :export, :as => :export_request
        get '/export/:id/:file',  :action => :export, :as => :export_download, :constraints => { :file => /.*/ }

        ActiveSupport::Deprecation.silence do
          get 'global/:action'
        end
      end
    end

    get '/global/dashboard'
    assert_equal 'global#dashboard', @response.body

    get '/global/export'
    assert_equal 'global#export', @response.body

    get '/global/hide_notice'
    assert_equal 'global#hide_notice', @response.body

    get '/export/123/foo.txt'
    assert_equal 'global#export', @response.body

    assert_equal '/global/export', export_request_path
    assert_equal '/global/hide_notice', global_hide_notice_path
    assert_equal '/export/123/foo.txt', export_download_path(:id => 123, :file => 'foo.txt')
  end

  def test_local
    draw do
      ActiveSupport::Deprecation.silence do
        get "/local/:action", :controller => "local"
      end
    end

    get '/local/dashboard'
    assert_equal 'local#dashboard', @response.body
  end

  # tests the use of dup in url_for
  def test_url_for_with_no_side_effects
    draw do
      get "/projects/status(.:format)"
    end

    # without dup, additional (and possibly unwanted) values will be present in the options (eg. :host)
    original_options = {:controller => 'projects', :action => 'status'}
    options = original_options.dup

    url_for options

    # verify that the options passed in have not changed from the original ones
    assert_equal original_options, options
  end

  def test_url_for_does_not_modify_controller
    draw do
      get "/projects/status(.:format)"
    end

    controller = '/projects'
    options = {:controller => controller, :action => 'status', :only_path => true}
    url = url_for(options)

    assert_equal '/projects/status', url
    assert_equal '/projects', controller
  end

  # tests the arguments modification free version of define_hash_access
  def test_named_route_with_no_side_effects
    draw do
      resources :customers do
        get "profile", :on => :member
      end
    end

    original_options = { :host => 'test.host' }
    options = original_options.dup

    profile_customer_url("customer_model", options)

    # verify that the options passed in have not changed from the original ones
    assert_equal original_options, options
  end

  def test_projects_status
    draw do
      get "/projects/status(.:format)"
    end

    assert_equal '/projects/status', url_for(:controller => 'projects', :action => 'status', :only_path => true)
    assert_equal '/projects/status.json', url_for(:controller => 'projects', :action => 'status', :format => 'json', :only_path => true)
  end

  def test_projects
    draw do
      resources :projects, :controller => :project
    end

    get '/projects'
    assert_equal 'project#index', @response.body
    assert_equal '/projects', projects_path

    post '/projects'
    assert_equal 'project#create', @response.body

    get '/projects.xml'
    assert_equal 'project#index', @response.body
    assert_equal '/projects.xml', projects_path(:format => 'xml')

    get '/projects/new'
    assert_equal 'project#new', @response.body
    assert_equal '/projects/new', new_project_path

    get '/projects/new.xml'
    assert_equal 'project#new', @response.body
    assert_equal '/projects/new.xml', new_project_path(:format => 'xml')

    get '/projects/1'
    assert_equal 'project#show', @response.body
    assert_equal '/projects/1', project_path(:id => '1')

    get '/projects/1.xml'
    assert_equal 'project#show', @response.body
    assert_equal '/projects/1.xml', project_path(:id => '1', :format => 'xml')

    get '/projects/1/edit'
    assert_equal 'project#edit', @response.body
    assert_equal '/projects/1/edit', edit_project_path(:id => '1')
  end

  def test_projects_for_api_app
    config = ActionDispatch::Routing::RouteSet::Config.new
    config.api_only = true

    self.class.stub_controllers(config) do |routes|
      routes.draw do
        resources :projects, controller: :project
      end
      @app = RoutedRackApp.new routes
    end

    get '/projects'
    assert_equal 'project#index', @response.body
    assert_equal '/projects', projects_path

    post '/projects'
    assert_equal 'project#create', @response.body

    get '/projects.xml'
    assert_equal 'project#index', @response.body
    assert_equal '/projects.xml', projects_path(format: 'xml')

    get '/projects/1'
    assert_equal 'project#show', @response.body
    assert_equal '/projects/1', project_path(id: '1')

    get '/projects/1.xml'
    assert_equal 'project#show', @response.body
    assert_equal '/projects/1.xml', project_path(id: '1', format: 'xml')

    get '/projects/1/edit'
    assert_equal 'Not Found', @response.body
  end

  def test_projects_with_post_action_and_new_path_on_collection
    draw do
      resources :projects, :controller => :project do
        post 'new', :action => 'new', :on => :collection, :as => :new
      end
    end

    post '/projects/new'
    assert_equal "project#new", @response.body
    assert_equal "/projects/new", new_projects_path
  end

  def test_projects_involvements
    draw do
      resources :projects, :controller => :project do
        resources :involvements, :attachments
      end
    end

    get '/projects/1/involvements'
    assert_equal 'involvements#index', @response.body
    assert_equal '/projects/1/involvements', project_involvements_path(:project_id => '1')

    get '/projects/1/involvements/new'
    assert_equal 'involvements#new', @response.body
    assert_equal '/projects/1/involvements/new', new_project_involvement_path(:project_id => '1')

    get '/projects/1/involvements/1'
    assert_equal 'involvements#show', @response.body
    assert_equal '/projects/1/involvements/1', project_involvement_path(:project_id => '1', :id => '1')

    put '/projects/1/involvements/1'
    assert_equal 'involvements#update', @response.body

    delete '/projects/1/involvements/1'
    assert_equal 'involvements#destroy', @response.body

    get '/projects/1/involvements/1/edit'
    assert_equal 'involvements#edit', @response.body
    assert_equal '/projects/1/involvements/1/edit', edit_project_involvement_path(:project_id => '1', :id => '1')
  end

  def test_projects_attachments
    draw do
      resources :projects, :controller => :project do
        resources :involvements, :attachments
      end
    end

    get '/projects/1/attachments'
    assert_equal 'attachments#index', @response.body
    assert_equal '/projects/1/attachments', project_attachments_path(:project_id => '1')
  end

  def test_projects_participants
    draw do
      resources :projects, :controller => :project do
        resources :participants do
          put :update_all, :on => :collection
        end
      end
    end

    get '/projects/1/participants'
    assert_equal 'participants#index', @response.body
    assert_equal '/projects/1/participants', project_participants_path(:project_id => '1')

    put '/projects/1/participants/update_all'
    assert_equal 'participants#update_all', @response.body
    assert_equal '/projects/1/participants/update_all', update_all_project_participants_path(:project_id => '1')
  end

  def test_projects_companies
    draw do
      resources :projects, :controller => :project do
        resources :companies do
          resources :people
          resource  :avatar, :controller => :avatar
        end
      end
    end

    get '/projects/1/companies'
    assert_equal 'companies#index', @response.body
    assert_equal '/projects/1/companies', project_companies_path(:project_id => '1')

    get '/projects/1/companies/1/people'
    assert_equal 'people#index', @response.body
    assert_equal '/projects/1/companies/1/people', project_company_people_path(:project_id => '1', :company_id => '1')

    get '/projects/1/companies/1/avatar'
    assert_equal 'avatar#show', @response.body
    assert_equal '/projects/1/companies/1/avatar', project_company_avatar_path(:project_id => '1', :company_id => '1')
  end

  def test_project_manager
    draw do
      resources :projects do
        resource :manager, :as => :super_manager do
          post :fire
        end
      end
    end

    get '/projects/1/manager'
    assert_equal 'managers#show', @response.body
    assert_equal '/projects/1/manager', project_super_manager_path(:project_id => '1')

    get '/projects/1/manager/new'
    assert_equal 'managers#new', @response.body
    assert_equal '/projects/1/manager/new', new_project_super_manager_path(:project_id => '1')

    post '/projects/1/manager/fire'
    assert_equal 'managers#fire', @response.body
    assert_equal '/projects/1/manager/fire', fire_project_super_manager_path(:project_id => '1')
  end

  def test_project_images
    draw do
      resources :projects do
        resources :images, :as => :funny_images do
          post :revise, :on => :member
        end
      end
    end

    get '/projects/1/images'
    assert_equal 'images#index', @response.body
    assert_equal '/projects/1/images', project_funny_images_path(:project_id => '1')

    get '/projects/1/images/new'
    assert_equal 'images#new', @response.body
    assert_equal '/projects/1/images/new', new_project_funny_image_path(:project_id => '1')

    post '/projects/1/images/1/revise'
    assert_equal 'images#revise', @response.body
    assert_equal '/projects/1/images/1/revise', revise_project_funny_image_path(:project_id => '1', :id => '1')
  end

  def test_projects_people
    draw do
      resources :projects do
        resources :people do
          nested do
            scope "/:access_token" do
              resource :avatar
            end
          end

          member do
            put  :accessible_projects
            post :resend, :generate_new_password
          end
        end
      end
    end

    get '/projects/1/people'
    assert_equal 'people#index', @response.body
    assert_equal '/projects/1/people', project_people_path(:project_id => '1')

    get '/projects/1/people/1'
    assert_equal 'people#show', @response.body
    assert_equal '/projects/1/people/1', project_person_path(:project_id => '1', :id => '1')

    get '/projects/1/people/1/7a2dec8/avatar'
    assert_equal 'avatars#show', @response.body
    assert_equal '/projects/1/people/1/7a2dec8/avatar', project_person_avatar_path(:project_id => '1', :person_id => '1', :access_token => '7a2dec8')

    put '/projects/1/people/1/accessible_projects'
    assert_equal 'people#accessible_projects', @response.body
    assert_equal '/projects/1/people/1/accessible_projects', accessible_projects_project_person_path(:project_id => '1', :id => '1')

    post '/projects/1/people/1/resend'
    assert_equal 'people#resend', @response.body
    assert_equal '/projects/1/people/1/resend', resend_project_person_path(:project_id => '1', :id => '1')

    post '/projects/1/people/1/generate_new_password'
    assert_equal 'people#generate_new_password', @response.body
    assert_equal '/projects/1/people/1/generate_new_password', generate_new_password_project_person_path(:project_id => '1', :id => '1')
  end

  def test_projects_with_resources_path_names
    draw do
      resources_path_names :correlation_indexes => "info_about_correlation_indexes"

      resources :projects do
        get :correlation_indexes, :on => :collection
      end
    end

    get '/projects/info_about_correlation_indexes'
    assert_equal 'projects#correlation_indexes', @response.body
    assert_equal '/projects/info_about_correlation_indexes', correlation_indexes_projects_path
  end

  def test_projects_posts
    draw do
      resources :projects do
        resources :posts do
          get  :archive, :toggle_view, :on => :collection
          post :preview, :on => :member

          resource :subscription

          resources :comments do
            post :preview, :on => :collection
          end
        end
      end
    end

    get '/projects/1/posts'
    assert_equal 'posts#index', @response.body
    assert_equal '/projects/1/posts', project_posts_path(:project_id => '1')

    get '/projects/1/posts/archive'
    assert_equal 'posts#archive', @response.body
    assert_equal '/projects/1/posts/archive', archive_project_posts_path(:project_id => '1')

    get '/projects/1/posts/toggle_view'
    assert_equal 'posts#toggle_view', @response.body
    assert_equal '/projects/1/posts/toggle_view', toggle_view_project_posts_path(:project_id => '1')

    post '/projects/1/posts/1/preview'
    assert_equal 'posts#preview', @response.body
    assert_equal '/projects/1/posts/1/preview', preview_project_post_path(:project_id => '1', :id => '1')

    get '/projects/1/posts/1/subscription'
    assert_equal 'subscriptions#show', @response.body
    assert_equal '/projects/1/posts/1/subscription', project_post_subscription_path(:project_id => '1', :post_id => '1')

    get '/projects/1/posts/1/comments'
    assert_equal 'comments#index', @response.body
    assert_equal '/projects/1/posts/1/comments', project_post_comments_path(:project_id => '1', :post_id => '1')

    post '/projects/1/posts/1/comments/preview'
    assert_equal 'comments#preview', @response.body
    assert_equal '/projects/1/posts/1/comments/preview', preview_project_post_comments_path(:project_id => '1', :post_id => '1')
  end

  def test_replies
    draw do
      resources :replies do
        member do
          put :answer, :action => :mark_as_answer
          delete :answer, :action => :unmark_as_answer
        end
      end
    end

    put '/replies/1/answer'
    assert_equal 'replies#mark_as_answer', @response.body

    delete '/replies/1/answer'
    assert_equal 'replies#unmark_as_answer', @response.body
  end

  def test_resource_routes_with_only_and_except
    draw do
      resources :posts, :only => [:index, :show] do
        resources :comments, :except => :destroy
      end
    end

    get '/posts'
    assert_equal 'posts#index', @response.body
    assert_equal '/posts', posts_path

    get '/posts/1'
    assert_equal 'posts#show', @response.body
    assert_equal '/posts/1', post_path(:id => 1)

    get '/posts/1/comments'
    assert_equal 'comments#index', @response.body
    assert_equal '/posts/1/comments', post_comments_path(:post_id => 1)

    post '/posts'
    assert_equal 'pass', @response.headers['X-Cascade']
    put '/posts/1'
    assert_equal 'pass', @response.headers['X-Cascade']
    delete '/posts/1'
    assert_equal 'pass', @response.headers['X-Cascade']
    delete '/posts/1/comments'
    assert_equal 'pass', @response.headers['X-Cascade']
  end

  def test_resource_routes_only_create_update_destroy
    draw do
      resource  :past, :only => :destroy
      resource  :present, :only => :update
      resource  :future, :only => :create
    end

    delete '/past'
    assert_equal 'pasts#destroy', @response.body
    assert_equal '/past', past_path

    patch '/present'
    assert_equal 'presents#update', @response.body
    assert_equal '/present', present_path

    put '/present'
    assert_equal 'presents#update', @response.body
    assert_equal '/present', present_path

    post '/future'
    assert_equal 'futures#create', @response.body
    assert_equal '/future', future_path
  end

  def test_resources_routes_only_create_update_destroy
    draw do
      resources :relationships, :only => [:create, :destroy]
      resources :friendships,   :only => [:update]
    end

    post '/relationships'
    assert_equal 'relationships#create', @response.body
    assert_equal '/relationships', relationships_path

    delete '/relationships/1'
    assert_equal 'relationships#destroy', @response.body
    assert_equal '/relationships/1', relationship_path(1)

    patch '/friendships/1'
    assert_equal 'friendships#update', @response.body
    assert_equal '/friendships/1', friendship_path(1)

    put '/friendships/1'
    assert_equal 'friendships#update', @response.body
    assert_equal '/friendships/1', friendship_path(1)
  end

  def test_resource_with_slugs_in_ids
    draw do
      resources :posts
    end

    get '/posts/rails-rocks'
    assert_equal 'posts#show', @response.body
    assert_equal '/posts/rails-rocks', post_path(:id => 'rails-rocks')
  end

  def test_resources_for_uncountable_names
    draw do
      resources :sheep do
        get "_it", :on => :member
      end
    end

    assert_equal '/sheep', sheep_index_path
    assert_equal '/sheep/1', sheep_path(1)
    assert_equal '/sheep/new', new_sheep_path
    assert_equal '/sheep/1/edit', edit_sheep_path(1)
    assert_equal '/sheep/1/_it', _it_sheep_path(1)
  end

  def test_resource_does_not_modify_passed_options
    options = {:id => /.+?/, :format => /json|xml/}
    draw { resource :user, options }
    assert_equal({:id => /.+?/, :format => /json|xml/}, options)
  end

  def test_resources_does_not_modify_passed_options
    options = {:id => /.+?/, :format => /json|xml/}
    draw { resources :users, options }
    assert_equal({:id => /.+?/, :format => /json|xml/}, options)
  end

  def test_path_names
    draw do
      scope 'pt', :as => 'pt' do
        resources :projects, :path_names => { :edit => 'editar', :new => 'novo' }, :path => 'projetos'
        resource  :admin, :path_names => { :new => 'novo', :activate => 'ativar' }, :path => 'administrador' do
          put :activate, :on => :member
        end
      end
    end

    get '/pt/projetos'
    assert_equal 'projects#index', @response.body
    assert_equal '/pt/projetos', pt_projects_path

    get '/pt/projetos/1/editar'
    assert_equal 'projects#edit', @response.body
    assert_equal '/pt/projetos/1/editar', edit_pt_project_path(1)

    get '/pt/administrador'
    assert_equal 'admins#show', @response.body
    assert_equal '/pt/administrador', pt_admin_path

    get '/pt/administrador/novo'
    assert_equal 'admins#new', @response.body
    assert_equal '/pt/administrador/novo', new_pt_admin_path

    put '/pt/administrador/ativar'
    assert_equal 'admins#activate', @response.body
    assert_equal '/pt/administrador/ativar', activate_pt_admin_path
  end

  def test_path_option_override
    draw do
      scope 'pt', :as => 'pt' do
        resources :projects, :path_names => { :new => 'novo' }, :path => 'projetos' do
          put :close, :on => :member, :path => 'fechar'
          get :open, :on => :new, :path => 'abrir'
        end
      end
    end

    get '/pt/projetos/novo/abrir'
    assert_equal 'projects#open', @response.body
    assert_equal '/pt/projetos/novo/abrir', open_new_pt_project_path

    put '/pt/projetos/1/fechar'
    assert_equal 'projects#close', @response.body
    assert_equal '/pt/projetos/1/fechar', close_pt_project_path(1)
  end

  def test_sprockets
    draw do
      get 'sprockets.js' => ::TestRoutingMapper::SprocketsApp
    end

    get '/sprockets.js'
    assert_equal 'javascripts', @response.body
  end

  def test_update_person_route
    draw do
      get 'people/:id/update', :to => 'people#update', :as => :update_person
    end

    get '/people/1/update'
    assert_equal 'people#update', @response.body

    assert_equal '/people/1/update', update_person_path(:id => 1)
  end

  def test_update_project_person
    draw do
      get '/projects/:project_id/people/:id/update', :to => 'people#update', :as => :update_project_person
    end

    get '/projects/1/people/2/update'
    assert_equal 'people#update', @response.body

    assert_equal '/projects/1/people/2/update', update_project_person_path(:project_id => 1, :id => 2)
  end

  def test_forum_products
    draw do
      namespace :forum do
        resources :products, :path => '' do
          resources :questions
        end
      end
    end

    get '/forum'
    assert_equal 'forum/products#index', @response.body
    assert_equal '/forum', forum_products_path

    get '/forum/basecamp'
    assert_equal 'forum/products#show', @response.body
    assert_equal '/forum/basecamp', forum_product_path(:id => 'basecamp')

    get '/forum/basecamp/questions'
    assert_equal 'forum/questions#index', @response.body
    assert_equal '/forum/basecamp/questions', forum_product_questions_path(:product_id => 'basecamp')

    get '/forum/basecamp/questions/1'
    assert_equal 'forum/questions#show', @response.body
    assert_equal '/forum/basecamp/questions/1', forum_product_question_path(:product_id => 'basecamp', :id => 1)
  end

  def test_articles_perma
    draw do
      get 'articles/:year/:month/:day/:title', :to => "articles#show", :as => :article
    end

    get '/articles/2009/08/18/rails-3'
    assert_equal 'articles#show', @response.body

    assert_equal '/articles/2009/8/18/rails-3', article_path(:year => 2009, :month => 8, :day => 18, :title => 'rails-3')
  end

  def test_account_namespace
    draw do
      namespace :account do
        resource :subscription, :credit, :credit_card
      end
    end

    get '/account/subscription'
    assert_equal 'account/subscriptions#show', @response.body
    assert_equal '/account/subscription', account_subscription_path

    get '/account/credit'
    assert_equal 'account/credits#show', @response.body
    assert_equal '/account/credit', account_credit_path

    get '/account/credit_card'
    assert_equal 'account/credit_cards#show', @response.body
    assert_equal '/account/credit_card', account_credit_card_path
  end

  def test_nested_namespace
    draw do
      namespace :account do
        namespace :admin do
          resource :subscription
        end
      end
    end

    get '/account/admin/subscription'
    assert_equal 'account/admin/subscriptions#show', @response.body
    assert_equal '/account/admin/subscription', account_admin_subscription_path
  end

  def test_namespace_nested_in_resources
    draw do
      resources :clients do
        namespace :google do
          resource :account do
            namespace :secret do
              resource :info
            end
          end
        end
      end
    end

    get '/clients/1/google/account'
    assert_equal '/clients/1/google/account', client_google_account_path(1)
    assert_equal 'google/accounts#show', @response.body

    get '/clients/1/google/account/secret/info'
    assert_equal '/clients/1/google/account/secret/info', client_google_account_secret_info_path(1)
    assert_equal 'google/secret/infos#show', @response.body
  end

  def test_namespace_with_options
    draw do
      namespace :users, :path => 'usuarios' do
        root :to => 'home#index'
      end
    end

    get '/usuarios'
    assert_equal '/usuarios', users_root_path
    assert_equal 'users/home#index', @response.body
  end

  def test_namespaced_shallow_routes_with_module_option
    draw do
      namespace :foo, module: 'bar' do
        resources :posts, only: [:index, :show] do
          resources :comments, only: [:index, :show], shallow: true
        end
      end
    end

    get '/foo/posts'
    assert_equal '/foo/posts', foo_posts_path
    assert_equal 'bar/posts#index', @response.body

    get '/foo/posts/1'
    assert_equal '/foo/posts/1', foo_post_path('1')
    assert_equal 'bar/posts#show', @response.body

    get '/foo/posts/1/comments'
    assert_equal '/foo/posts/1/comments', foo_post_comments_path('1')
    assert_equal 'bar/comments#index', @response.body

    get '/foo/comments/2'
    assert_equal '/foo/comments/2', foo_comment_path('2')
    assert_equal 'bar/comments#show', @response.body
  end

  def test_namespaced_shallow_routes_with_path_option
    draw do
      namespace :foo, path: 'bar' do
        resources :posts, only: [:index, :show] do
          resources :comments, only: [:index, :show], shallow: true
        end
      end
    end

    get '/bar/posts'
    assert_equal '/bar/posts', foo_posts_path
    assert_equal 'foo/posts#index', @response.body

    get '/bar/posts/1'
    assert_equal '/bar/posts/1', foo_post_path('1')
    assert_equal 'foo/posts#show', @response.body

    get '/bar/posts/1/comments'
    assert_equal '/bar/posts/1/comments', foo_post_comments_path('1')
    assert_equal 'foo/comments#index', @response.body

    get '/bar/comments/2'
    assert_equal '/bar/comments/2', foo_comment_path('2')
    assert_equal 'foo/comments#show', @response.body
  end

  def test_namespaced_shallow_routes_with_as_option
    draw do
      namespace :foo, as: 'bar' do
        resources :posts, only: [:index, :show] do
          resources :comments, only: [:index, :show], shallow: true
        end
      end
    end

    get '/foo/posts'
    assert_equal '/foo/posts', bar_posts_path
    assert_equal 'foo/posts#index', @response.body

    get '/foo/posts/1'
    assert_equal '/foo/posts/1', bar_post_path('1')
    assert_equal 'foo/posts#show', @response.body

    get '/foo/posts/1/comments'
    assert_equal '/foo/posts/1/comments', bar_post_comments_path('1')
    assert_equal 'foo/comments#index', @response.body

    get '/foo/comments/2'
    assert_equal '/foo/comments/2', bar_comment_path('2')
    assert_equal 'foo/comments#show', @response.body
  end

  def test_namespaced_shallow_routes_with_shallow_path_option
    draw do
      namespace :foo, shallow_path: 'bar' do
        resources :posts, only: [:index, :show] do
          resources :comments, only: [:index, :show], shallow: true
        end
      end
    end

    get '/foo/posts'
    assert_equal '/foo/posts', foo_posts_path
    assert_equal 'foo/posts#index', @response.body

    get '/foo/posts/1'
    assert_equal '/foo/posts/1', foo_post_path('1')
    assert_equal 'foo/posts#show', @response.body

    get '/foo/posts/1/comments'
    assert_equal '/foo/posts/1/comments', foo_post_comments_path('1')
    assert_equal 'foo/comments#index', @response.body

    get '/bar/comments/2'
    assert_equal '/bar/comments/2', foo_comment_path('2')
    assert_equal 'foo/comments#show', @response.body
  end

  def test_namespaced_shallow_routes_with_shallow_prefix_option
    draw do
      namespace :foo, shallow_prefix: 'bar' do
        resources :posts, only: [:index, :show] do
          resources :comments, only: [:index, :show], shallow: true
        end
      end
    end

    get '/foo/posts'
    assert_equal '/foo/posts', foo_posts_path
    assert_equal 'foo/posts#index', @response.body

    get '/foo/posts/1'
    assert_equal '/foo/posts/1', foo_post_path('1')
    assert_equal 'foo/posts#show', @response.body

    get '/foo/posts/1/comments'
    assert_equal '/foo/posts/1/comments', foo_post_comments_path('1')
    assert_equal 'foo/comments#index', @response.body

    get '/foo/comments/2'
    assert_equal '/foo/comments/2', bar_comment_path('2')
    assert_equal 'foo/comments#show', @response.body
  end

  def test_namespace_containing_numbers
    draw do
      namespace :v2 do
        resources :subscriptions
      end
    end

    get '/v2/subscriptions'
    assert_equal 'v2/subscriptions#index', @response.body
    assert_equal '/v2/subscriptions', v2_subscriptions_path
  end

  def test_articles_with_id
    draw do
      controller :articles do
        scope '/articles', :as => 'article' do
          scope :path => '/:title', :title => /[a-z]+/, :as => :with_title do
            get '/:id', :action => :with_id, :as => ""
          end
        end
      end
    end

    get '/articles/rails/1'
    assert_equal 'articles#with_id', @response.body

    get '/articles/123/1'
    assert_equal 'pass', @response.headers['X-Cascade']

    assert_equal '/articles/rails/1', article_with_title_path(:title => 'rails', :id => 1)
  end

  def test_access_token_rooms
    draw do
      scope ':access_token', :constraints => { :access_token => /\w{5,5}/ } do
        resources :rooms
      end
    end

    get '/12345/rooms'
    assert_equal 'rooms#index', @response.body

    get '/12345/rooms/1'
    assert_equal 'rooms#show', @response.body

    get '/12345/rooms/1/edit'
    assert_equal 'rooms#edit', @response.body
  end

  def test_root
    draw do
      root :to => 'projects#index'
    end

    assert_equal '/', root_path
    get '/'
    assert_equal 'projects#index', @response.body
  end

  def test_scoped_root
    draw do
      scope '(:locale)', :locale => /en|pl/ do
        root :to => 'projects#index'
      end
    end

    assert_equal '/en', root_path(:locale => 'en')
    get '/en'
    assert_equal 'projects#index', @response.body
  end

  def test_scoped_root_as_name
    draw do
      scope '(:locale)', :locale => /en|pl/ do
        root :to => 'projects#index', :as => 'projects'
      end
    end

    assert_equal '/en', projects_path(:locale => 'en')
    assert_equal '/', projects_path
    get '/en'
    assert_equal 'projects#index', @response.body
  end

  def test_scope_with_format_option
    draw do
      get "direct/index", as: :no_format_direct, format: false

      scope format: false do
        get "scoped/index", as: :no_format_scoped
      end
    end

    assert_equal "/direct/index", no_format_direct_path
    assert_equal "/direct/index?format=html", no_format_direct_path(format: "html")

    assert_equal "/scoped/index", no_format_scoped_path
    assert_equal "/scoped/index?format=html", no_format_scoped_path(format: "html")

    get '/scoped/index'
    assert_equal "scoped#index", @response.body

    get '/scoped/index.html'
    assert_equal "Not Found", @response.body
  end

  def test_resources_with_format_false_from_scope
    draw do
      scope format: false do
        resources :posts
        resource :user
      end
    end

    get "/posts"
    assert_response :success
    assert_equal "posts#index", @response.body
    assert_equal "/posts", posts_path

    get "/posts.html"
    assert_response :not_found
    assert_equal "Not Found", @response.body
    assert_equal "/posts?format=html", posts_path(format: "html")

    get "/user"
    assert_response :success
    assert_equal "users#show", @response.body
    assert_equal "/user", user_path

    get "/user.html"
    assert_response :not_found
    assert_equal "Not Found", @response.body
    assert_equal "/user?format=html", user_path(format: "html")
  end

  def test_index
    draw do
      get '/info' => 'projects#info', :as => 'info'
    end

    assert_equal '/info', info_path
    get '/info'
    assert_equal 'projects#info', @response.body
  end

  def test_match_with_many_paths_containing_a_slash
    draw do
      get 'get/first', 'get/second', 'get/third', :to => 'get#show'
    end

    get '/get/first'
    assert_equal 'get#show', @response.body

    get '/get/second'
    assert_equal 'get#show', @response.body

    get '/get/third'
    assert_equal 'get#show', @response.body
  end

  def test_match_shorthand_with_no_scope
    draw do
      get 'account/overview'
    end

    assert_equal '/account/overview', account_overview_path
    get '/account/overview'
    assert_equal 'account#overview', @response.body
  end

  def test_match_shorthand_inside_namespace
    draw do
      namespace :account do
        get 'shorthand'
      end
    end

    assert_equal '/account/shorthand', account_shorthand_path
    get '/account/shorthand'
    assert_equal 'account#shorthand', @response.body
  end

  def test_match_shorthand_with_multiple_paths_inside_namespace
    draw do
      namespace :proposals do
        put 'activate', 'inactivate'
      end
    end

    put '/proposals/activate'
    assert_equal 'proposals#activate', @response.body

    put '/proposals/inactivate'
    assert_equal 'proposals#inactivate', @response.body
  end

  def test_match_shorthand_inside_namespace_with_controller
    draw do
      namespace :api do
        get "products/list"
      end
    end

    assert_equal '/api/products/list', api_products_list_path
    get '/api/products/list'
    assert_equal 'api/products#list', @response.body
  end

  def test_match_shorthand_inside_scope_with_variables_with_controller
    draw do
      scope ':locale' do
        match 'questions/new', via: [:get]
      end
    end

    get '/de/questions/new'
    assert_equal 'questions#new', @response.body
    assert_equal 'de', @request.params[:locale]
  end

  def test_match_shorthand_inside_nested_namespaces_and_scopes_with_controller
    draw do
      namespace :api do
        namespace :v3 do
          scope ':locale' do
            get "products/list"
          end
        end
      end
    end

    get '/api/v3/en/products/list'
    assert_equal 'api/v3/products#list', @response.body
  end

  def test_not_matching_shorthand_with_dynamic_parameters
    draw do
      ActiveSupport::Deprecation.silence do
        get ':controller/:action/admin'
      end
    end

    get '/finances/overview/admin'
    assert_equal 'finances#overview', @response.body
  end

  def test_controller_option_with_nesting_and_leading_slash
    draw do
      scope '/job', controller: 'job' do
        scope ':id', action: 'manage_applicant' do
          get "/active"
        end
      end
    end

    get '/job/5/active'
    assert_equal 'job#manage_applicant', @response.body
  end

  def test_dynamically_generated_helpers_on_collection_do_not_clobber_resources_url_helper
    draw do
      resources :replies do
        collection do
          get 'page/:page' => 'replies#index', :page => %r{\d+}
          get ':page' => 'replies#index', :page => %r{\d+}
        end
      end
    end

    assert_equal '/replies', replies_path
  end

  def test_scoped_controller_with_namespace_and_action
    draw do
      namespace :account do
        ActiveSupport::Deprecation.silence do
          get ':action/callback', :action => /twitter|github/, :controller => "callbacks", :as => :callback
        end
      end
    end

    assert_equal '/account/twitter/callback', account_callback_path("twitter")
    get '/account/twitter/callback'
    assert_equal 'account/callbacks#twitter', @response.body

    get '/account/whatever/callback'
    assert_equal 'Not Found', @response.body
  end

  def test_convention_match_nested_and_with_leading_slash
    draw do
      get '/account/nested/overview'
    end

    assert_equal '/account/nested/overview', account_nested_overview_path
    get '/account/nested/overview'
    assert_equal 'account/nested#overview', @response.body
  end

  def test_convention_with_explicit_end
    draw do
      get 'sign_in' => "sessions#new"
    end

    get '/sign_in'
    assert_equal 'sessions#new', @response.body
    assert_equal '/sign_in', sign_in_path
  end

  def test_redirect_with_complete_url_and_status
    draw do
      get 'account/google' => redirect('http://www.google.com/', :status => 302)
    end

    get '/account/google'
    verify_redirect 'http://www.google.com/', 302
  end

  def test_redirect_with_port
    draw do
      get 'account/login', :to => redirect("/login")
    end

    previous_host, self.host = self.host, 'www.example.com:3000'

    get '/account/login'
    verify_redirect 'http://www.example.com:3000/login'
  ensure
    self.host = previous_host
  end

  def test_normalize_namespaced_matches
    draw do
      namespace :account do
        get 'description', :action => :description, :as => "description"
      end
    end

    assert_equal '/account/description', account_description_path

    get '/account/description'
    assert_equal 'account#description', @response.body
  end

  def test_namespaced_roots
    draw do
      namespace :account do
        root :to => "account#index"
      end
    end

    assert_equal '/account', account_root_path
    get '/account'
    assert_equal 'account/account#index', @response.body
  end

  def test_optional_scoped_root
    draw do
      scope '(:locale)', :locale => /en|pl/ do
        root :to => 'projects#index'
      end
    end

    assert_equal '/en', root_path("en")
    get '/en'
    assert_equal 'projects#index', @response.body
  end

  def test_optional_scoped_path
    draw do
      scope '(:locale)', :locale => /en|pl/ do
        resources :descriptions
      end
    end

    assert_equal '/en/descriptions', descriptions_path("en")
    assert_equal '/descriptions', descriptions_path(nil)
    assert_equal '/en/descriptions/1', description_path("en", 1)
    assert_equal '/descriptions/1', description_path(nil, 1)

    get '/en/descriptions'
    assert_equal 'descriptions#index', @response.body

    get '/descriptions'
    assert_equal 'descriptions#index', @response.body

    get '/en/descriptions/1'
    assert_equal 'descriptions#show', @response.body

    get '/descriptions/1'
    assert_equal 'descriptions#show', @response.body
  end

  def test_nested_optional_scoped_path
    draw do
      namespace :admin do
        scope '(:locale)', :locale => /en|pl/ do
          resources :descriptions
        end
      end
    end

    assert_equal '/admin/en/descriptions', admin_descriptions_path("en")
    assert_equal '/admin/descriptions', admin_descriptions_path(nil)
    assert_equal '/admin/en/descriptions/1', admin_description_path("en", 1)
    assert_equal '/admin/descriptions/1', admin_description_path(nil, 1)

    get '/admin/en/descriptions'
    assert_equal 'admin/descriptions#index', @response.body

    get '/admin/descriptions'
    assert_equal 'admin/descriptions#index', @response.body

    get '/admin/en/descriptions/1'
    assert_equal 'admin/descriptions#show', @response.body

    get '/admin/descriptions/1'
    assert_equal 'admin/descriptions#show', @response.body
  end

  def test_nested_optional_path_shorthand
    draw do
      scope '(:locale)', :locale => /en|pl/ do
        get "registrations/new"
      end
    end

    get '/registrations/new'
    assert_nil @request.params[:locale]

    get '/en/registrations/new'
    assert_equal 'en', @request.params[:locale]
  end

  def test_default_string_params
    draw do
      get 'inline_pages/(:id)', :to => 'pages#show', :id => 'home'
      get 'default_pages/(:id)', :to => 'pages#show', :defaults => { :id => 'home' }

      defaults :id => 'home' do
        get 'scoped_pages/(:id)', :to => 'pages#show'
      end
    end

    get '/inline_pages'
    assert_equal 'home', @request.params[:id]

    get '/default_pages'
    assert_equal 'home', @request.params[:id]

    get '/scoped_pages'
    assert_equal 'home', @request.params[:id]
  end

  def test_default_integer_params
    draw do
      get 'inline_pages/(:page)', to: 'pages#show', page: 1
      get 'default_pages/(:page)', to: 'pages#show', defaults: { page: 1 }

      defaults page: 1 do
        get 'scoped_pages/(:page)', to: 'pages#show'
      end
    end

    get '/inline_pages'
    assert_equal 1, @request.params[:page]

    get '/default_pages'
    assert_equal 1, @request.params[:page]

    get '/scoped_pages'
    assert_equal 1, @request.params[:page]
  end

  def test_resource_constraints
    draw do
      resources :products, :constraints => { :id => /\d{4}/ } do
        root :to => "products#root"
        get :favorite, :on => :collection
        resources :images
      end

      resource :dashboard, :constraints => { :ip => /192\.168\.1\.\d{1,3}/ }
    end

    get '/products/1'
    assert_equal 'pass', @response.headers['X-Cascade']
    get '/products'
    assert_equal 'products#root', @response.body
    get '/products/favorite'
    assert_equal 'products#favorite', @response.body
    get '/products/0001'
    assert_equal 'products#show', @response.body

    get '/products/1/images'
    assert_equal 'pass', @response.headers['X-Cascade']
    get '/products/0001/images'
    assert_equal 'images#index', @response.body
    get '/products/0001/images/0001'
    assert_equal 'images#show', @response.body

    get '/dashboard', headers: { 'REMOTE_ADDR' => '10.0.0.100' }
    assert_equal 'pass', @response.headers['X-Cascade']
    get '/dashboard', headers: { 'REMOTE_ADDR' => '192.168.1.100' }
    assert_equal 'dashboards#show', @response.body
  end

  def test_root_works_in_the_resources_scope
    draw do
      resources :products do
        root :to => "products#root"
      end
    end

    get '/products'
    assert_equal 'products#root', @response.body
    assert_equal '/products', products_root_path
  end

  def test_module_scope
    draw do
      resource :token, :module => :api
    end

    get '/token'
    assert_equal 'api/tokens#show', @response.body
    assert_equal '/token', token_path
  end

  def test_path_scope
    draw do
      scope :path => 'api' do
        resource :me
        get '/' => 'mes#index'
      end
    end

    get '/api/me'
    assert_equal 'mes#show', @response.body
    assert_equal '/api/me', me_path

    get '/api'
    assert_equal 'mes#index', @response.body
  end

  def test_symbol_scope
    draw do
      scope :path => 'api' do
        scope :v2 do
          resource :me, as: 'v2_me'
          get '/' => 'mes#index'
        end

        scope :v3, :admin do
          resource :me, as: 'v3_me'
        end
      end
    end

    get '/api/v2/me'
    assert_equal 'mes#show', @response.body
    assert_equal '/api/v2/me', v2_me_path

    get '/api/v2'
    assert_equal 'mes#index', @response.body

    get '/api/v3/admin/me'
    assert_equal 'mes#show', @response.body
  end

  def test_url_generator_for_generic_route
    draw do
      ActiveSupport::Deprecation.silence do
        get "whatever/:controller(/:action(/:id))"
      end
    end

    get '/whatever/foo/bar'
    assert_equal 'foo#bar', @response.body

    assert_equal 'http://www.example.com/whatever/foo/bar/1',
      url_for(:controller => "foo", :action => "bar", :id => 1)
  end

  def test_url_generator_for_namespaced_generic_route
    draw do
      ActiveSupport::Deprecation.silence do
        get "whatever/:controller(/:action(/:id))", :id => /\d+/
      end
    end

    get '/whatever/foo/bar/show'
    assert_equal 'foo/bar#show', @response.body

    get '/whatever/foo/bar/show/1'
    assert_equal 'foo/bar#show', @response.body

    assert_equal 'http://www.example.com/whatever/foo/bar/show',
      url_for(:controller => "foo/bar", :action => "show")

    assert_equal 'http://www.example.com/whatever/foo/bar/show/1',
      url_for(:controller => "foo/bar", :action => "show", :id => '1')
  end

  def test_resource_new_actions
    draw do
      resources :replies do
        new do
          post :preview
        end
      end

      scope 'pt', :as => 'pt' do
        resources :projects, :path_names => { :new => 'novo' }, :path => 'projetos' do
          post :preview, :on => :new
        end

        resource  :admin, :path_names => { :new => 'novo' }, :path => 'administrador' do
          post :preview, :on => :new
        end

        resources :products, :path_names => { :new => 'novo' } do
          new do
            post :preview
          end
        end
      end

      resource :profile do
        new do
          post :preview
        end
      end
    end

    assert_equal '/replies/new/preview', preview_new_reply_path
    assert_equal '/pt/projetos/novo/preview', preview_new_pt_project_path
    assert_equal '/pt/administrador/novo/preview', preview_new_pt_admin_path
    assert_equal '/pt/products/novo/preview', preview_new_pt_product_path
    assert_equal '/profile/new/preview', preview_new_profile_path

    post '/replies/new/preview'
    assert_equal 'replies#preview', @response.body

    post '/pt/projetos/novo/preview'
    assert_equal 'projects#preview', @response.body

    post '/pt/administrador/novo/preview'
    assert_equal 'admins#preview', @response.body

    post '/pt/products/novo/preview'
    assert_equal 'products#preview', @response.body

    post '/profile/new/preview'
    assert_equal 'profiles#preview', @response.body
  end

  def test_resource_merges_options_from_scope
    draw do
      scope :only => :show do
        resource :account
      end
    end

    assert_raise(NoMethodError) { new_account_path }

    get '/account/new'
    assert_equal 404, status
  end

  def test_resources_merges_options_from_scope
    draw do
      scope :only => [:index, :show] do
        resources :products do
          resources :images
        end
      end
    end

    assert_raise(NoMethodError) { edit_product_path('1') }

    get '/products/1/edit'
    assert_equal 404, status

    assert_raise(NoMethodError) { edit_product_image_path('1', '2') }

    post '/products/1/images/2/edit'
    assert_equal 404, status
  end

  def test_shallow_nested_resources
    draw do
      shallow do
        namespace :api do
          resources :teams do
            resources :players
            resource :captain
          end
        end
      end

      resources :threads, :shallow => true do
        resource :owner
        resources :messages do
          resources :comments do
            member do
              post :preview
            end
          end
        end
      end
    end

    get '/api/teams'
    assert_equal 'api/teams#index', @response.body
    assert_equal '/api/teams', api_teams_path

    get '/api/teams/new'
    assert_equal 'api/teams#new', @response.body
    assert_equal '/api/teams/new', new_api_team_path

    get '/api/teams/1'
    assert_equal 'api/teams#show', @response.body
    assert_equal '/api/teams/1', api_team_path(:id => '1')

    get '/api/teams/1/edit'
    assert_equal 'api/teams#edit', @response.body
    assert_equal '/api/teams/1/edit', edit_api_team_path(:id => '1')

    get '/api/teams/1/players'
    assert_equal 'api/players#index', @response.body
    assert_equal '/api/teams/1/players', api_team_players_path(:team_id => '1')

    get '/api/teams/1/players/new'
    assert_equal 'api/players#new', @response.body
    assert_equal '/api/teams/1/players/new', new_api_team_player_path(:team_id => '1')

    get '/api/players/2'
    assert_equal 'api/players#show', @response.body
    assert_equal '/api/players/2', api_player_path(:id => '2')

    get '/api/players/2/edit'
    assert_equal 'api/players#edit', @response.body
    assert_equal '/api/players/2/edit', edit_api_player_path(:id => '2')

    get '/api/teams/1/captain'
    assert_equal 'api/captains#show', @response.body
    assert_equal '/api/teams/1/captain', api_team_captain_path(:team_id => '1')

    get '/api/teams/1/captain/new'
    assert_equal 'api/captains#new', @response.body
    assert_equal '/api/teams/1/captain/new', new_api_team_captain_path(:team_id => '1')

    get '/api/teams/1/captain/edit'
    assert_equal 'api/captains#edit', @response.body
    assert_equal '/api/teams/1/captain/edit', edit_api_team_captain_path(:team_id => '1')

    get '/threads'
    assert_equal 'threads#index', @response.body
    assert_equal '/threads', threads_path

    get '/threads/new'
    assert_equal 'threads#new', @response.body
    assert_equal '/threads/new', new_thread_path

    get '/threads/1'
    assert_equal 'threads#show', @response.body
    assert_equal '/threads/1', thread_path(:id => '1')

    get '/threads/1/edit'
    assert_equal 'threads#edit', @response.body
    assert_equal '/threads/1/edit', edit_thread_path(:id => '1')

    get '/threads/1/owner'
    assert_equal 'owners#show', @response.body
    assert_equal '/threads/1/owner', thread_owner_path(:thread_id => '1')

    get '/threads/1/messages'
    assert_equal 'messages#index', @response.body
    assert_equal '/threads/1/messages', thread_messages_path(:thread_id => '1')

    get '/threads/1/messages/new'
    assert_equal 'messages#new', @response.body
    assert_equal '/threads/1/messages/new', new_thread_message_path(:thread_id => '1')

    get '/messages/2'
    assert_equal 'messages#show', @response.body
    assert_equal '/messages/2', message_path(:id => '2')

    get '/messages/2/edit'
    assert_equal 'messages#edit', @response.body
    assert_equal '/messages/2/edit', edit_message_path(:id => '2')

    get '/messages/2/comments'
    assert_equal 'comments#index', @response.body
    assert_equal '/messages/2/comments', message_comments_path(:message_id => '2')

    get '/messages/2/comments/new'
    assert_equal 'comments#new', @response.body
    assert_equal '/messages/2/comments/new', new_message_comment_path(:message_id => '2')

    get '/comments/3'
    assert_equal 'comments#show', @response.body
    assert_equal '/comments/3', comment_path(:id => '3')

    get '/comments/3/edit'
    assert_equal 'comments#edit', @response.body
    assert_equal '/comments/3/edit', edit_comment_path(:id => '3')

    post '/comments/3/preview'
    assert_equal 'comments#preview', @response.body
    assert_equal '/comments/3/preview', preview_comment_path(:id => '3')
  end

  def test_shallow_nested_resources_inside_resource
    draw do
      resource :membership, shallow: true do
        resources :cards
      end
    end

    get '/membership/cards'
    assert_equal 'cards#index', @response.body
    assert_equal '/membership/cards', membership_cards_path

    get '/membership/cards/new'
    assert_equal 'cards#new', @response.body
    assert_equal '/membership/cards/new', new_membership_card_path

    post '/membership/cards'
    assert_equal 'cards#create', @response.body

    get '/cards/1'
    assert_equal 'cards#show', @response.body
    assert_equal '/cards/1', card_path('1')

    get '/cards/1/edit'
    assert_equal 'cards#edit', @response.body
    assert_equal '/cards/1/edit', edit_card_path('1')

    put '/cards/1'
    assert_equal 'cards#update', @response.body

    patch '/cards/1'
    assert_equal 'cards#update', @response.body

    delete '/cards/1'
    assert_equal 'cards#destroy', @response.body
  end

  def test_shallow_deeply_nested_resources
    draw do
      resources :blogs do
        resources :posts do
          resources :comments, shallow: true
        end
      end
    end

    get '/comments/1'
    assert_equal 'comments#show', @response.body

    assert_equal '/comments/1', comment_path('1')
    assert_equal '/blogs/new', new_blog_path
    assert_equal '/blogs/1/posts/new', new_blog_post_path(:blog_id => 1)
    assert_equal '/blogs/1/posts/2/comments/new', new_blog_post_comment_path(:blog_id => 1, :post_id => 2)
  end

  def test_direct_children_of_shallow_resources
    draw do
      resources :blogs do
        resources :posts, shallow: true do
          resources :comments
        end
      end
    end

    post '/posts/1/comments'
    assert_equal 'comments#create', @response.body
    assert_equal '/posts/1/comments', post_comments_path('1')

    get '/posts/2/comments/new'
    assert_equal 'comments#new', @response.body
    assert_equal '/posts/2/comments/new', new_post_comment_path('2')

    get '/posts/1/comments'
    assert_equal 'comments#index', @response.body
    assert_equal '/posts/1/comments', post_comments_path('1')
  end

  def test_shallow_nested_resources_within_scope
    draw do
      scope '/hello' do
        shallow do
          resources :notes do
            resources :trackbacks
          end
        end
      end
    end

    get '/hello/notes/1/trackbacks'
    assert_equal 'trackbacks#index', @response.body
    assert_equal '/hello/notes/1/trackbacks', note_trackbacks_path(:note_id => 1)

    get '/hello/notes/1/edit'
    assert_equal 'notes#edit', @response.body
    assert_equal '/hello/notes/1/edit', edit_note_path(:id => '1')

    get '/hello/notes/1/trackbacks/new'
    assert_equal 'trackbacks#new', @response.body
    assert_equal '/hello/notes/1/trackbacks/new', new_note_trackback_path(:note_id => 1)

    get '/hello/trackbacks/1'
    assert_equal 'trackbacks#show', @response.body
    assert_equal '/hello/trackbacks/1', trackback_path(:id => '1')

    get '/hello/trackbacks/1/edit'
    assert_equal 'trackbacks#edit', @response.body
    assert_equal '/hello/trackbacks/1/edit', edit_trackback_path(:id => '1')

    put '/hello/trackbacks/1'
    assert_equal 'trackbacks#update', @response.body

    post '/hello/notes/1/trackbacks'
    assert_equal 'trackbacks#create', @response.body

    delete '/hello/trackbacks/1'
    assert_equal 'trackbacks#destroy', @response.body

    get '/hello/notes'
    assert_equal 'notes#index', @response.body

    post '/hello/notes'
    assert_equal 'notes#create', @response.body

    get '/hello/notes/new'
    assert_equal 'notes#new', @response.body
    assert_equal '/hello/notes/new', new_note_path

    get '/hello/notes/1'
    assert_equal 'notes#show', @response.body
    assert_equal '/hello/notes/1', note_path(:id => 1)

    put '/hello/notes/1'
    assert_equal 'notes#update', @response.body

    delete '/hello/notes/1'
    assert_equal 'notes#destroy', @response.body
  end

  def test_shallow_option_nested_resources_within_scope
    draw do
      scope '/hello' do
        resources :notes, :shallow => true do
          resources :trackbacks
        end
      end
    end

    get '/hello/notes/1/trackbacks'
    assert_equal 'trackbacks#index', @response.body
    assert_equal '/hello/notes/1/trackbacks', note_trackbacks_path(:note_id => 1)

    get '/hello/notes/1/edit'
    assert_equal 'notes#edit', @response.body
    assert_equal '/hello/notes/1/edit', edit_note_path(:id => '1')

    get '/hello/notes/1/trackbacks/new'
    assert_equal 'trackbacks#new', @response.body
    assert_equal '/hello/notes/1/trackbacks/new', new_note_trackback_path(:note_id => 1)

    get '/hello/trackbacks/1'
    assert_equal 'trackbacks#show', @response.body
    assert_equal '/hello/trackbacks/1', trackback_path(:id => '1')

    get '/hello/trackbacks/1/edit'
    assert_equal 'trackbacks#edit', @response.body
    assert_equal '/hello/trackbacks/1/edit', edit_trackback_path(:id => '1')

    put '/hello/trackbacks/1'
    assert_equal 'trackbacks#update', @response.body

    post '/hello/notes/1/trackbacks'
    assert_equal 'trackbacks#create', @response.body

    delete '/hello/trackbacks/1'
    assert_equal 'trackbacks#destroy', @response.body

    get '/hello/notes'
    assert_equal 'notes#index', @response.body

    post '/hello/notes'
    assert_equal 'notes#create', @response.body

    get '/hello/notes/new'
    assert_equal 'notes#new', @response.body
    assert_equal '/hello/notes/new', new_note_path

    get '/hello/notes/1'
    assert_equal 'notes#show', @response.body
    assert_equal '/hello/notes/1', note_path(:id => 1)

    put '/hello/notes/1'
    assert_equal 'notes#update', @response.body

    delete '/hello/notes/1'
    assert_equal 'notes#destroy', @response.body
  end

  def test_custom_resource_routes_are_scoped
    draw do
      resources :customers do
        get :recent, :on => :collection
        get "profile", :on => :member
        get "secret/profile" => "customers#secret", :on => :member
        post "preview" => "customers#preview", :as => :another_preview, :on => :new
        resource :avatar do
          get "thumbnail" => "avatars#thumbnail", :as => :thumbnail, :on => :member
        end
        resources :invoices do
          get "outstanding" => "invoices#outstanding", :on => :collection
          get "overdue", :action => :overdue, :on => :collection
          get "print" => "invoices#print", :as => :print, :on => :member
          post "preview" => "invoices#preview", :as => :preview, :on => :new
        end
        resources :notes, :shallow => true do
          get "preview" => "notes#preview", :as => :preview, :on => :new
          get "print" => "notes#print", :as => :print, :on => :member
        end
      end

      namespace :api do
        resources :customers do
          get "recent" => "customers#recent", :as => :recent, :on => :collection
          get "profile" => "customers#profile", :as => :profile, :on => :member
          post "preview" => "customers#preview", :as => :preview, :on => :new
        end
      end
    end

    assert_equal '/customers/recent', recent_customers_path
    assert_equal '/customers/1/profile', profile_customer_path(:id => '1')
    assert_equal '/customers/1/secret/profile', secret_profile_customer_path(:id => '1')
    assert_equal '/customers/new/preview', another_preview_new_customer_path
    assert_equal '/customers/1/avatar/thumbnail.jpg', thumbnail_customer_avatar_path(:customer_id => '1', :format => :jpg)
    assert_equal '/customers/1/invoices/outstanding', outstanding_customer_invoices_path(:customer_id => '1')
    assert_equal '/customers/1/invoices/2/print', print_customer_invoice_path(:customer_id => '1', :id => '2')
    assert_equal '/customers/1/invoices/new/preview', preview_new_customer_invoice_path(:customer_id => '1')
    assert_equal '/customers/1/notes/new/preview', preview_new_customer_note_path(:customer_id => '1')
    assert_equal '/notes/1/print', print_note_path(:id => '1')
    assert_equal '/api/customers/recent', recent_api_customers_path
    assert_equal '/api/customers/1/profile', profile_api_customer_path(:id => '1')
    assert_equal '/api/customers/new/preview', preview_new_api_customer_path

    get '/customers/1/invoices/overdue'
    assert_equal 'invoices#overdue', @response.body

    get '/customers/1/secret/profile'
    assert_equal 'customers#secret', @response.body
  end

  def test_shallow_nested_routes_ignore_module
    draw do
      scope :module => :api do
        resources :errors, :shallow => true do
          resources :notices
        end
      end
    end

    get '/errors/1/notices'
    assert_equal 'api/notices#index', @response.body
    assert_equal '/errors/1/notices', error_notices_path(:error_id => '1')

    get '/notices/1'
    assert_equal 'api/notices#show', @response.body
    assert_equal '/notices/1', notice_path(:id => '1')
  end

  def test_non_greedy_regexp
    draw do
      namespace :api do
        scope(':version', :version => /.+/) do
          resources :users, :id => /.+?/, :format => /json|xml/
        end
      end
    end

    get '/api/1.0/users'
    assert_equal 'api/users#index', @response.body
    assert_equal '/api/1.0/users', api_users_path(:version => '1.0')

    get '/api/1.0/users.json'
    assert_equal 'api/users#index', @response.body
    assert_equal true, @request.format.json?
    assert_equal '/api/1.0/users.json', api_users_path(:version => '1.0', :format => :json)

    get '/api/1.0/users/first.last'
    assert_equal 'api/users#show', @response.body
    assert_equal 'first.last', @request.params[:id]
    assert_equal '/api/1.0/users/first.last', api_user_path(:version => '1.0', :id => 'first.last')

    get '/api/1.0/users/first.last.xml'
    assert_equal 'api/users#show', @response.body
    assert_equal 'first.last', @request.params[:id]
    assert_equal true, @request.format.xml?
    assert_equal '/api/1.0/users/first.last.xml', api_user_path(:version => '1.0', :id => 'first.last', :format => :xml)
  end

  def test_match_without_via
    assert_raises(ArgumentError) do
      draw do
        match '/foo/bar', :to => 'files#show'
      end
    end
  end

  def test_match_with_empty_via
    assert_raises(ArgumentError) do
      draw do
        match '/foo/bar', :to => 'files#show', :via => []
      end
    end
  end

  def test_glob_parameter_accepts_regexp
    draw do
      get '/:locale/*file.:format', :to => 'files#show', :file => /path\/to\/existing\/file/
    end

    get '/en/path/to/existing/file.html'
    assert_equal 200, @response.status
  end

  def test_resources_controller_name_is_not_pluralized
    draw do
      resources :content
    end

    get '/content'
    assert_equal 'content#index', @response.body
  end

  def test_url_generator_for_optional_prefix_dynamic_segment
    draw do
      get "(/:username)/followers" => "followers#index"
    end

    get '/bob/followers'
    assert_equal 'followers#index', @response.body
    assert_equal 'http://www.example.com/bob/followers',
      url_for(:controller => "followers", :action => "index", :username => "bob")

    get '/followers'
    assert_equal 'followers#index', @response.body
    assert_equal 'http://www.example.com/followers',
      url_for(:controller => "followers", :action => "index", :username => nil)
  end

  def test_url_generator_for_optional_suffix_static_and_dynamic_segment
    draw do
      get "/groups(/user/:username)" => "groups#index"
    end

    get '/groups/user/bob'
    assert_equal 'groups#index', @response.body
    assert_equal 'http://www.example.com/groups/user/bob',
      url_for(:controller => "groups", :action => "index", :username => "bob")

    get '/groups'
    assert_equal 'groups#index', @response.body
    assert_equal 'http://www.example.com/groups',
      url_for(:controller => "groups", :action => "index", :username => nil)
  end

  def test_url_generator_for_optional_prefix_static_and_dynamic_segment
    draw do
      get "(/user/:username)/photos" => "photos#index"
    end

    get '/user/bob/photos'
    assert_equal 'photos#index', @response.body
    assert_equal 'http://www.example.com/user/bob/photos',
      url_for(:controller => "photos", :action => "index", :username => "bob")

    get '/photos'
    assert_equal 'photos#index', @response.body
    assert_equal 'http://www.example.com/photos',
      url_for(:controller => "photos", :action => "index", :username => nil)
  end

  def test_url_recognition_for_optional_static_segments
    draw do
      scope '(groups)' do
        scope '(discussions)' do
          resources :messages
        end
      end
    end

    get '/groups/discussions/messages'
    assert_equal 'messages#index', @response.body

    get '/groups/discussions/messages/1'
    assert_equal 'messages#show', @response.body

    get '/groups/messages'
    assert_equal 'messages#index', @response.body

    get '/groups/messages/1'
    assert_equal 'messages#show', @response.body

    get '/discussions/messages'
    assert_equal 'messages#index', @response.body

    get '/discussions/messages/1'
    assert_equal 'messages#show', @response.body

    get '/messages'
    assert_equal 'messages#index', @response.body

    get '/messages/1'
    assert_equal 'messages#show', @response.body
  end

  def test_router_removes_invalid_conditions
    draw do
      scope :constraints => { :id => /\d+/ } do
        get '/tickets', :to => 'tickets#index', :as => :tickets
      end
    end

    get '/tickets'
    assert_equal 'tickets#index', @response.body
    assert_equal '/tickets', tickets_path
  end

  def test_constraints_are_merged_from_scope
    draw do
      scope :constraints => { :id => /\d{4}/ } do
        resources :movies do
          resources :reviews
          resource :trailer
        end
      end
    end

    get '/movies/0001'
    assert_equal 'movies#show', @response.body
    assert_equal '/movies/0001', movie_path(:id => '0001')

    get '/movies/00001'
    assert_equal 'Not Found', @response.body
    assert_raises(ActionController::UrlGenerationError){ movie_path(:id => '00001') }

    get '/movies/0001/reviews'
    assert_equal 'reviews#index', @response.body
    assert_equal '/movies/0001/reviews', movie_reviews_path(:movie_id => '0001')

    get '/movies/00001/reviews'
    assert_equal 'Not Found', @response.body
    assert_raises(ActionController::UrlGenerationError){ movie_reviews_path(:movie_id => '00001') }

    get '/movies/0001/reviews/0001'
    assert_equal 'reviews#show', @response.body
    assert_equal '/movies/0001/reviews/0001', movie_review_path(:movie_id => '0001', :id => '0001')

    get '/movies/00001/reviews/0001'
    assert_equal 'Not Found', @response.body
    assert_raises(ActionController::UrlGenerationError){ movie_path(:movie_id => '00001', :id => '00001') }

    get '/movies/0001/trailer'
    assert_equal 'trailers#show', @response.body
    assert_equal '/movies/0001/trailer', movie_trailer_path(:movie_id => '0001')

    get '/movies/00001/trailer'
    assert_equal 'Not Found', @response.body
    assert_raises(ActionController::UrlGenerationError){ movie_trailer_path(:movie_id => '00001') }
  end

  def test_only_should_be_read_from_scope
    draw do
      scope :only => [:index, :show] do
        namespace :only do
          resources :clubs do
            resources :players
            resource  :chairman
          end
        end
      end
    end

    get '/only/clubs'
    assert_equal 'only/clubs#index', @response.body
    assert_equal '/only/clubs', only_clubs_path

    get '/only/clubs/1/edit'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { edit_only_club_path(:id => '1') }

    get '/only/clubs/1/players'
    assert_equal 'only/players#index', @response.body
    assert_equal '/only/clubs/1/players', only_club_players_path(:club_id => '1')

    get '/only/clubs/1/players/2/edit'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { edit_only_club_player_path(:club_id => '1', :id => '2') }

    get '/only/clubs/1/chairman'
    assert_equal 'only/chairmen#show', @response.body
    assert_equal '/only/clubs/1/chairman', only_club_chairman_path(:club_id => '1')

    get '/only/clubs/1/chairman/edit'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { edit_only_club_chairman_path(:club_id => '1') }
  end

  def test_except_should_be_read_from_scope
    draw do
      scope :except => [:new, :create, :edit, :update, :destroy] do
        namespace :except do
          resources :clubs do
            resources :players
            resource  :chairman
          end
        end
      end
    end

    get '/except/clubs'
    assert_equal 'except/clubs#index', @response.body
    assert_equal '/except/clubs', except_clubs_path

    get '/except/clubs/1/edit'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { edit_except_club_path(:id => '1') }

    get '/except/clubs/1/players'
    assert_equal 'except/players#index', @response.body
    assert_equal '/except/clubs/1/players', except_club_players_path(:club_id => '1')

    get '/except/clubs/1/players/2/edit'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { edit_except_club_player_path(:club_id => '1', :id => '2') }

    get '/except/clubs/1/chairman'
    assert_equal 'except/chairmen#show', @response.body
    assert_equal '/except/clubs/1/chairman', except_club_chairman_path(:club_id => '1')

    get '/except/clubs/1/chairman/edit'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { edit_except_club_chairman_path(:club_id => '1') }
  end

  def test_only_option_should_override_scope
    draw do
      scope :only => :show do
        namespace :only do
          resources :sectors, :only => :index
        end
      end
    end

    get '/only/sectors'
    assert_equal 'only/sectors#index', @response.body
    assert_equal '/only/sectors', only_sectors_path

    get '/only/sectors/1'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { only_sector_path(:id => '1') }
  end

  def test_only_option_should_not_inherit
    draw do
      scope :only => :show do
        namespace :only do
          resources :sectors, :only => :index do
            resources :companies
            resource  :leader
          end
        end
      end
    end

    get '/only/sectors/1/companies/2'
    assert_equal 'only/companies#show', @response.body
    assert_equal '/only/sectors/1/companies/2', only_sector_company_path(:sector_id => '1', :id => '2')

    get '/only/sectors/1/leader'
    assert_equal 'only/leaders#show', @response.body
    assert_equal '/only/sectors/1/leader', only_sector_leader_path(:sector_id => '1')
  end

  def test_except_option_should_override_scope
    draw do
      scope :except => :index do
        namespace :except do
          resources :sectors, :except => [:show, :update, :destroy]
        end
      end
    end

    get '/except/sectors'
    assert_equal 'except/sectors#index', @response.body
    assert_equal '/except/sectors', except_sectors_path

    get '/except/sectors/1'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { except_sector_path(:id => '1') }
  end

  def test_except_option_should_not_inherit
    draw do
      scope :except => :index do
        namespace :except do
          resources :sectors, :except => [:show, :update, :destroy] do
            resources :companies
            resource  :leader
          end
        end
      end
    end

    get '/except/sectors/1/companies/2'
    assert_equal 'except/companies#show', @response.body
    assert_equal '/except/sectors/1/companies/2', except_sector_company_path(:sector_id => '1', :id => '2')

    get '/except/sectors/1/leader'
    assert_equal 'except/leaders#show', @response.body
    assert_equal '/except/sectors/1/leader', except_sector_leader_path(:sector_id => '1')
  end

  def test_except_option_should_override_scoped_only
    draw do
      scope :only => :show do
        namespace :only do
          resources :sectors, :only => :index do
            resources :managers, :except => [:show, :update, :destroy]
          end
        end
      end
    end

    get '/only/sectors/1/managers'
    assert_equal 'only/managers#index', @response.body
    assert_equal '/only/sectors/1/managers', only_sector_managers_path(:sector_id => '1')

    get '/only/sectors/1/managers/2'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { only_sector_manager_path(:sector_id => '1', :id => '2') }
  end

  def test_only_option_should_override_scoped_except
    draw do
      scope :except => :index do
        namespace :except do
          resources :sectors, :except => [:show, :update, :destroy] do
            resources :managers, :only => :index
          end
        end
      end
    end

    get '/except/sectors/1/managers'
    assert_equal 'except/managers#index', @response.body
    assert_equal '/except/sectors/1/managers', except_sector_managers_path(:sector_id => '1')

    get '/except/sectors/1/managers/2'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { except_sector_manager_path(:sector_id => '1', :id => '2') }
  end

  def test_only_scope_should_override_parent_scope
    draw do
      scope :only => :show do
        namespace :only do
          resources :sectors, :only => :index do
            resources :companies do
              scope :only => :index do
                resources :divisions
              end
            end
          end
        end
      end
    end

    get '/only/sectors/1/companies/2/divisions'
    assert_equal 'only/divisions#index', @response.body
    assert_equal '/only/sectors/1/companies/2/divisions', only_sector_company_divisions_path(:sector_id => '1', :company_id => '2')

    get '/only/sectors/1/companies/2/divisions/3'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { only_sector_company_division_path(:sector_id => '1', :company_id => '2', :id => '3') }
  end

  def test_except_scope_should_override_parent_scope
    draw do
      scope :except => :index do
        namespace :except do
          resources :sectors, :except => [:show, :update, :destroy] do
            resources :companies do
              scope :except => [:show, :update, :destroy] do
                resources :divisions
              end
            end
          end
        end
      end
    end

    get '/except/sectors/1/companies/2/divisions'
    assert_equal 'except/divisions#index', @response.body
    assert_equal '/except/sectors/1/companies/2/divisions', except_sector_company_divisions_path(:sector_id => '1', :company_id => '2')

    get '/except/sectors/1/companies/2/divisions/3'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { except_sector_company_division_path(:sector_id => '1', :company_id => '2', :id => '3') }
  end

  def test_except_scope_should_override_parent_only_scope
    draw do
      scope :only => :show do
        namespace :only do
          resources :sectors, :only => :index do
            resources :companies do
              scope :except => [:show, :update, :destroy] do
                resources :departments
              end
            end
          end
        end
      end
    end

    get '/only/sectors/1/companies/2/departments'
    assert_equal 'only/departments#index', @response.body
    assert_equal '/only/sectors/1/companies/2/departments', only_sector_company_departments_path(:sector_id => '1', :company_id => '2')

    get '/only/sectors/1/companies/2/departments/3'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { only_sector_company_department_path(:sector_id => '1', :company_id => '2', :id => '3') }
  end

  def test_only_scope_should_override_parent_except_scope
    draw do
      scope :except => :index do
        namespace :except do
          resources :sectors, :except => [:show, :update, :destroy] do
            resources :companies do
              scope :only => :index do
                resources :departments
              end
            end
          end
        end
      end
    end

    get '/except/sectors/1/companies/2/departments'
    assert_equal 'except/departments#index', @response.body
    assert_equal '/except/sectors/1/companies/2/departments', except_sector_company_departments_path(:sector_id => '1', :company_id => '2')

    get '/except/sectors/1/companies/2/departments/3'
    assert_equal 'Not Found', @response.body
    assert_raise(NoMethodError) { except_sector_company_department_path(:sector_id => '1', :company_id => '2', :id => '3') }
  end

  def test_resources_are_not_pluralized
    draw do
      namespace :transport do
        resources :taxis
      end
    end

    get '/transport/taxis'
    assert_equal 'transport/taxis#index', @response.body
    assert_equal '/transport/taxis', transport_taxis_path

    get '/transport/taxis/new'
    assert_equal 'transport/taxis#new', @response.body
    assert_equal '/transport/taxis/new', new_transport_taxi_path

    post '/transport/taxis'
    assert_equal 'transport/taxis#create', @response.body

    get '/transport/taxis/1'
    assert_equal 'transport/taxis#show', @response.body
    assert_equal '/transport/taxis/1', transport_taxi_path(:id => '1')

    get '/transport/taxis/1/edit'
    assert_equal 'transport/taxis#edit', @response.body
    assert_equal '/transport/taxis/1/edit', edit_transport_taxi_path(:id => '1')

    put '/transport/taxis/1'
    assert_equal 'transport/taxis#update', @response.body

    delete '/transport/taxis/1'
    assert_equal 'transport/taxis#destroy', @response.body
  end

  def test_singleton_resources_are_not_singularized
    draw do
      namespace :medical do
        resource :taxis
      end
    end

    get '/medical/taxis/new'
    assert_equal 'medical/taxis#new', @response.body
    assert_equal '/medical/taxis/new', new_medical_taxis_path

    post '/medical/taxis'
    assert_equal 'medical/taxis#create', @response.body

    get '/medical/taxis'
    assert_equal 'medical/taxis#show', @response.body
    assert_equal '/medical/taxis', medical_taxis_path

    get '/medical/taxis/edit'
    assert_equal 'medical/taxis#edit', @response.body
    assert_equal '/medical/taxis/edit', edit_medical_taxis_path

    put '/medical/taxis'
    assert_equal 'medical/taxis#update', @response.body

    delete '/medical/taxis'
    assert_equal 'medical/taxis#destroy', @response.body
  end

  def test_greedy_resource_id_regexp_doesnt_match_edit_and_custom_action
    draw do
      resources :sections, :id => /.+/ do
        get :preview, :on => :member
      end
    end

    get '/sections/1/edit'
    assert_equal 'sections#edit', @response.body
    assert_equal '/sections/1/edit', edit_section_path(:id => '1')

    get '/sections/1/preview'
    assert_equal 'sections#preview', @response.body
    assert_equal '/sections/1/preview', preview_section_path(:id => '1')
  end

  def test_resource_constraints_are_pushed_to_scope
    draw do
      namespace :wiki do
        resources :articles, :id => /[^\/]+/ do
          resources :comments, :only => [:create, :new]
        end
      end
    end

    get '/wiki/articles/Ruby_on_Rails_3.0'
    assert_equal 'wiki/articles#show', @response.body
    assert_equal '/wiki/articles/Ruby_on_Rails_3.0', wiki_article_path(:id => 'Ruby_on_Rails_3.0')

    get '/wiki/articles/Ruby_on_Rails_3.0/comments/new'
    assert_equal 'wiki/comments#new', @response.body
    assert_equal '/wiki/articles/Ruby_on_Rails_3.0/comments/new', new_wiki_article_comment_path(:article_id => 'Ruby_on_Rails_3.0')

    post '/wiki/articles/Ruby_on_Rails_3.0/comments'
    assert_equal 'wiki/comments#create', @response.body
    assert_equal '/wiki/articles/Ruby_on_Rails_3.0/comments', wiki_article_comments_path(:article_id => 'Ruby_on_Rails_3.0')
  end

  def test_resources_path_can_be_a_symbol
    draw do
      resources :wiki_pages, :path => :pages
      resource :wiki_account, :path => :my_account
    end

    get '/pages'
    assert_equal 'wiki_pages#index', @response.body
    assert_equal '/pages', wiki_pages_path

    get '/pages/Ruby_on_Rails'
    assert_equal 'wiki_pages#show', @response.body
    assert_equal '/pages/Ruby_on_Rails', wiki_page_path(:id => 'Ruby_on_Rails')

    get '/my_account'
    assert_equal 'wiki_accounts#show', @response.body
    assert_equal '/my_account', wiki_account_path
  end

  def test_redirect_https
    draw do
      get 'secure', :to => redirect("/secure/login")
    end

    with_https do
      get '/secure'
      verify_redirect 'https://www.example.com/secure/login'
    end
  end

  def test_path_parameters_is_not_stale
    draw do
      scope '/countries/:country', :constraints => lambda { |params, req| %w(all France).include?(params[:country]) } do
        get '/',       :to => 'countries#index'
        get '/cities', :to => 'countries#cities'
      end

      get '/countries/:country/(*other)', :to => redirect{ |params, req| params[:other] ? "/countries/all/#{params[:other]}" : '/countries/all' }
    end

    get '/countries/France'
    assert_equal 'countries#index', @response.body

    get '/countries/France/cities'
    assert_equal 'countries#cities', @response.body

    get '/countries/UK'
    verify_redirect 'http://www.example.com/countries/all'

    get '/countries/UK/cities'
    verify_redirect 'http://www.example.com/countries/all/cities'
  end

  def test_constraints_block_not_carried_to_following_routes
    draw do
      scope '/italians' do
        get '/writers', :to => 'italians#writers', :constraints => ::TestRoutingMapper::IpRestrictor
        get '/sculptors', :to => 'italians#sculptors'
        get '/painters/:painter', :to => 'italians#painters', :constraints => {:painter => /michelangelo/}
      end
    end

    get '/italians/writers'
    assert_equal 'Not Found', @response.body

    get '/italians/sculptors'
    assert_equal 'italians#sculptors', @response.body

    get '/italians/painters/botticelli'
    assert_equal 'Not Found', @response.body

    get '/italians/painters/michelangelo'
    assert_equal 'italians#painters', @response.body
  end

  def test_custom_resource_actions_defined_using_string
    draw do
      resources :customers do
        resources :invoices do
          get "aged/:months", :on => :collection, :action => :aged, :as => :aged
        end

        get "inactive", :on => :collection
        post "deactivate", :on => :member
        get "old", :on => :collection, :as => :stale
      end
    end

    get '/customers/inactive'
    assert_equal 'customers#inactive', @response.body
    assert_equal '/customers/inactive', inactive_customers_path

    post '/customers/1/deactivate'
    assert_equal 'customers#deactivate', @response.body
    assert_equal '/customers/1/deactivate', deactivate_customer_path(:id => '1')

    get '/customers/old'
    assert_equal 'customers#old', @response.body
    assert_equal '/customers/old', stale_customers_path

    get '/customers/1/invoices/aged/3'
    assert_equal 'invoices#aged', @response.body
    assert_equal '/customers/1/invoices/aged/3', aged_customer_invoices_path(:customer_id => '1', :months => '3')
  end

  def test_route_defined_in_resources_scope_level
    draw do
      resources :customers do
        get "export"
      end
    end

    get '/customers/1/export'
    assert_equal 'customers#export', @response.body
    assert_equal '/customers/1/export', customer_export_path(:customer_id => '1')
  end

  def test_named_character_classes_in_regexp_constraints
    draw do
      get '/purchases/:token/:filename',
        :to => 'purchases#fetch',
        :token => /[[:alnum:]]{10}/,
        :filename => /(.+)/,
        :as => :purchase
    end

    get '/purchases/315004be7e/Ruby_on_Rails_3.pdf'
    assert_equal 'purchases#fetch', @response.body
    assert_equal '/purchases/315004be7e/Ruby_on_Rails_3.pdf', purchase_path(:token => '315004be7e', :filename => 'Ruby_on_Rails_3.pdf')
  end

  def test_nested_resource_constraints
    draw do
      resources :lists, :id => /([A-Za-z0-9]{25})|default/ do
        resources :todos, :id => /\d+/
      end
    end

    get '/lists/01234012340123401234fffff'
    assert_equal 'lists#show', @response.body
    assert_equal '/lists/01234012340123401234fffff', list_path(:id => '01234012340123401234fffff')

    get '/lists/01234012340123401234fffff/todos/1'
    assert_equal 'todos#show', @response.body
    assert_equal '/lists/01234012340123401234fffff/todos/1', list_todo_path(:list_id => '01234012340123401234fffff', :id => '1')

    get '/lists/2/todos/1'
    assert_equal 'Not Found', @response.body
    assert_raises(ActionController::UrlGenerationError){ list_todo_path(:list_id => '2', :id => '1') }
  end

  def test_redirect_argument_error
    routes = Class.new { include ActionDispatch::Routing::Redirection }.new
    assert_raises(ArgumentError) { routes.redirect Object.new }
  end

  def test_named_route_check
    before, after = nil

    draw do
      before = has_named_route?(:hello)
      get "/hello", as: :hello, to: "hello#world"
      after = has_named_route?(:hello)
    end

    assert !before, "expected to not have named route :hello before route definition"
    assert after, "expected to have named route :hello after route definition"
  end

  def test_explicitly_avoiding_the_named_route
    draw do
      scope :as => "routes" do
        get "/c/:id", :as => :collision, :to => "collision#show"
        get "/collision", :to => "collision#show"
        get "/no_collision", :to => "collision#show", :as => nil
      end
    end

    assert !respond_to?(:routes_no_collision_path)
  end

  def test_controller_name_with_leading_slash_raise_error
    assert_raise(ArgumentError) do
      draw { get '/feeds/:service', :to => '/feeds#show' }
    end

    assert_raise(ArgumentError) do
      draw { get '/feeds/:service', :controller => '/feeds', :action => 'show' }
    end

    assert_raise(ArgumentError) do
      draw { get '/api/feeds/:service', :to => '/api/feeds#show' }
    end

    assert_raise(ArgumentError) do
      draw { resources :feeds, :controller => '/feeds' }
    end
  end

  def test_invalid_route_name_raises_error
    assert_raise(ArgumentError) do
      draw { get '/products', :to => 'products#index', :as => 'products ' }
    end

    assert_raise(ArgumentError) do
      draw { get '/products', :to => 'products#index', :as => ' products' }
    end

    assert_raise(ArgumentError) do
      draw { get '/products', :to => 'products#index', :as => 'products!' }
    end

    assert_raise(ArgumentError) do
      draw { get '/products', :to => 'products#index', :as => 'products index' }
    end

    assert_raise(ArgumentError) do
      draw { get '/products', :to => 'products#index', :as => '1products' }
    end
  end

  def test_duplicate_route_name_raises_error
    assert_raise(ArgumentError) do
      draw do
        get '/collision', :to => 'collision#show', :as => 'collision'
        get '/duplicate', :to => 'duplicate#show', :as => 'collision'
      end
    end
  end

  def test_duplicate_route_name_via_resources_raises_error
    assert_raise(ArgumentError) do
      draw do
        resources :collisions
        get '/collision', :to => 'collision#show', :as => 'collision'
      end
    end
  end

  def test_nested_route_in_nested_resource
    draw do
      resources :posts, :only => [:index, :show] do
        resources :comments, :except => :destroy do
          get "views" => "comments#views", :as => :views
        end
      end
    end

    get "/posts/1/comments/2/views"
    assert_equal "comments#views", @response.body
    assert_equal "/posts/1/comments/2/views", post_comment_views_path(:post_id => '1', :comment_id => '2')
  end

  def test_root_in_deeply_nested_scope
    draw do
      resources :posts, :only => [:index, :show] do
        namespace :admin do
          root :to => "index#index"
        end
      end
    end

    get "/posts/1/admin"
    assert_equal "admin/index#index", @response.body
    assert_equal "/posts/1/admin", post_admin_root_path(:post_id => '1')
  end

  def test_custom_param
    draw do
      resources :profiles, :param => :username do
        get :details, :on => :member
        resources :messages
      end
    end

    get '/profiles/bob'
    assert_equal 'profiles#show', @response.body
    assert_equal 'bob', @request.params[:username]

    get '/profiles/bob/details'
    assert_equal 'bob', @request.params[:username]

    get '/profiles/bob/messages/34'
    assert_equal 'bob', @request.params[:profile_username]
    assert_equal '34', @request.params[:id]
  end

  def test_custom_param_constraint
    draw do
      resources :profiles, :param => :username, :username => /[a-z]+/ do
        get :details, :on => :member
        resources :messages
      end
    end

    get '/profiles/bob1'
    assert_equal 404, @response.status

    get '/profiles/bob1/details'
    assert_equal 404, @response.status

    get '/profiles/bob1/messages/34'
    assert_equal 404, @response.status
  end

  def test_shallow_custom_param
    draw do
      resources :orders do
        constraints :download => /[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}/ do
          resources :downloads, :param => :download, :shallow => true
        end
      end
    end

    get '/downloads/0c0c0b68-d24b-11e1-a861-001ff3fffe6f.zip'
    assert_equal 'downloads#show', @response.body
    assert_equal '0c0c0b68-d24b-11e1-a861-001ff3fffe6f', @request.params[:download]
  end

  def test_action_from_path_is_not_frozen
    draw do
      get 'search' => 'search'
    end

    get '/search'
    assert !@request.params[:action].frozen?
  end

  def test_multiple_positional_args_with_the_same_name
    draw do
      get '/downloads/:id/:id.tar' => 'downloads#show', as: :download, format: false
    end

    expected_params = {
      controller: 'downloads',
      action:     'show',
      id:         '1'
    }

    get '/downloads/1/1.tar'
    assert_equal 'downloads#show', @response.body
    assert_equal expected_params, @request.path_parameters
    assert_equal '/downloads/1/1.tar', download_path('1')
    assert_equal '/downloads/1/1.tar', download_path('1', '1')
  end

  def test_absolute_controller_namespace
    draw do
      namespace :foo do
        get '/', to: '/bar#index', as: 'root'
      end
    end

    get '/foo'
    assert_equal 'bar#index', @response.body
    assert_equal '/foo', foo_root_path
  end

  def test_namespace_as_controller
    draw do
      namespace :foo do
        get '/', to: '/bar#index', as: 'root'
      end
    end

    get '/foo'
    assert_equal 'bar#index', @response.body
    assert_equal '/foo', foo_root_path
  end

  def test_trailing_slash
    draw do
      resources :streams
    end

    get '/streams'
    assert @response.ok?, 'route without trailing slash should work'

    get '/streams/'
    assert @response.ok?, 'route with trailing slash should work'

    get '/streams?foobar'
    assert @response.ok?, 'route without trailing slash and with QUERY_STRING should work'

    get '/streams/?foobar'
    assert @response.ok?, 'route with trailing slash and with QUERY_STRING should work'
  end

  def test_route_with_dashes_in_path
    draw do
      get '/contact-us', to: 'pages#contact_us'
    end

    get '/contact-us'
    assert_equal 'pages#contact_us', @response.body
    assert_equal '/contact-us', contact_us_path
  end

  def test_shorthand_route_with_dashes_in_path
    draw do
      get '/about-us/index'
    end

    get '/about-us/index'
    assert_equal 'about_us#index', @response.body
    assert_equal '/about-us/index', about_us_index_path
  end

  def test_resource_routes_with_dashes_in_path
    draw do
      resources :photos, only: [:show] do
        get 'user-favorites', on: :collection
        get 'preview-photo', on: :member
        get 'summary-text'
      end
    end

    get '/photos/user-favorites'
    assert_equal 'photos#user_favorites', @response.body
    assert_equal '/photos/user-favorites', user_favorites_photos_path

    get '/photos/1/preview-photo'
    assert_equal 'photos#preview_photo', @response.body
    assert_equal '/photos/1/preview-photo', preview_photo_photo_path('1')

    get '/photos/1/summary-text'
    assert_equal 'photos#summary_text', @response.body
    assert_equal '/photos/1/summary-text', photo_summary_text_path('1')

    get '/photos/1'
    assert_equal 'photos#show', @response.body
    assert_equal '/photos/1', photo_path('1')
  end

  def test_shallow_path_inside_namespace_is_not_added_twice
    draw do
      namespace :admin do
        shallow do
          resources :posts do
            resources :comments
          end
        end
      end
    end

    get '/admin/posts/1/comments'
    assert_equal 'admin/comments#index', @response.body
    assert_equal '/admin/posts/1/comments', admin_post_comments_path('1')
  end

  def test_mix_string_to_controller_action
    draw do
      get '/projects', controller: 'project_files',
                       action: 'index',
                       to: 'comments#index'
    end
    get '/projects'
    assert_equal 'comments#index', @response.body
  end

  def test_mix_string_to_controller
    draw do
      get '/projects', controller: 'project_files',
                       to: 'comments#index'
    end
    get '/projects'
    assert_equal 'comments#index', @response.body
  end

  def test_mix_string_to_action
    draw do
      get '/projects', action: 'index',
                       to: 'comments#index'
    end
    get '/projects'
    assert_equal 'comments#index', @response.body
  end

  def test_shallow_path_and_prefix_are_not_added_to_non_shallow_routes
    draw do
      scope shallow_path: 'projects', shallow_prefix: 'project' do
        resources :projects do
          resources :files, controller: 'project_files', shallow: true
        end
      end
    end

    get '/projects'
    assert_equal 'projects#index', @response.body
    assert_equal '/projects', projects_path

    get '/projects/new'
    assert_equal 'projects#new', @response.body
    assert_equal '/projects/new', new_project_path

    post '/projects'
    assert_equal 'projects#create', @response.body

    get '/projects/1'
    assert_equal 'projects#show', @response.body
    assert_equal '/projects/1', project_path('1')

    get '/projects/1/edit'
    assert_equal 'projects#edit', @response.body
    assert_equal '/projects/1/edit', edit_project_path('1')

    patch '/projects/1'
    assert_equal 'projects#update', @response.body

    delete '/projects/1'
    assert_equal 'projects#destroy', @response.body

    get '/projects/1/files'
    assert_equal 'project_files#index', @response.body
    assert_equal '/projects/1/files', project_files_path('1')

    get '/projects/1/files/new'
    assert_equal 'project_files#new', @response.body
    assert_equal '/projects/1/files/new', new_project_file_path('1')

    post '/projects/1/files'
    assert_equal 'project_files#create', @response.body

    get '/projects/files/2'
    assert_equal 'project_files#show', @response.body
    assert_equal '/projects/files/2', project_file_path('2')

    get '/projects/files/2/edit'
    assert_equal 'project_files#edit', @response.body
    assert_equal '/projects/files/2/edit', edit_project_file_path('2')

    patch '/projects/files/2'
    assert_equal 'project_files#update', @response.body

    delete '/projects/files/2'
    assert_equal 'project_files#destroy', @response.body
  end

  def test_scope_path_is_copied_to_shallow_path
    draw do
      scope path: 'foo' do
        resources :posts do
          resources :comments, shallow: true
        end
      end
    end

    assert_equal '/foo/comments/1', comment_path('1')
  end

  def test_scope_as_is_copied_to_shallow_prefix
    draw do
      scope as: 'foo' do
        resources :posts do
          resources :comments, shallow: true
        end
      end
    end

    assert_equal '/comments/1', foo_comment_path('1')
  end

  def test_scope_shallow_prefix_is_not_overwritten_by_as
    draw do
      scope as: 'foo', shallow_prefix: 'bar' do
        resources :posts do
          resources :comments, shallow: true
        end
      end
    end

    assert_equal '/comments/1', bar_comment_path('1')
  end

  def test_scope_shallow_path_is_not_overwritten_by_path
    draw do
      scope path: 'foo', shallow_path: 'bar' do
        resources :posts do
          resources :comments, shallow: true
        end
      end
    end

    assert_equal '/bar/comments/1', comment_path('1')
  end

  def test_resource_where_as_is_empty
    draw do
      resource :post, as: ''

      scope 'post', as: 'post' do
        resource :comment, as: ''
      end
    end

    assert_equal '/post/new', new_path
    assert_equal '/post/comment/new', new_post_path
  end

  def test_resources_where_as_is_empty
    draw do
      resources :posts, as: ''

      scope 'posts', as: 'posts' do
        resources :comments, as: ''
      end
    end

    assert_equal '/posts/new', new_path
    assert_equal '/posts/comments/new', new_posts_path
  end

  def test_scope_where_as_is_empty
    draw do
      scope 'post', as: '' do
        resource :user
        resources :comments
      end
    end

    assert_equal '/post/user/new', new_user_path
    assert_equal '/post/comments/new', new_comment_path
  end

  def test_head_fetch_with_mount_on_root
    draw do
      get '/home' => 'test#index'
      mount lambda { |env| [200, {}, [env['REQUEST_METHOD']]] }, at: '/'
    end

    # HEAD request should match `get /home` rather than the
    # lower-precedence Rack app mounted at `/`.
    head '/home'
    assert_response :ok
    assert_equal 'test#index', @response.body

    # But the Rack app can still respond to its own HEAD requests.
    head '/foobar'
    assert_response :ok
    assert_equal 'HEAD', @response.body
  end

  def test_passing_action_parameters_to_url_helpers_raises_error_if_parameters_are_not_permitted
    draw do
      root :to => 'projects#index'
    end
    params = ActionController::Parameters.new(id: '1')

    assert_raises ArgumentError do
      root_path(params)
    end
  end

  def test_passing_action_parameters_to_url_helpers_is_allowed_if_parameters_are_permitted
    draw do
      root :to => 'projects#index'
    end
    params = ActionController::Parameters.new(id: '1')
    params.permit!

    assert_equal '/?id=1', root_path(params)
  end

  def test_dynamic_controller_segments_are_deprecated
    assert_deprecated do
      draw do
        get '/:controller', action: 'index'
      end
    end
  end

  def test_dynamic_action_segments_are_deprecated
    assert_deprecated do
      draw do
        get '/pages/:action', controller: 'pages'
      end
    end
  end

private

  def draw(&block)
    self.class.stub_controllers do |routes|
      routes.default_url_options = { host: 'www.example.com' }
      routes.draw(&block)
      @app = RoutedRackApp.new routes
    end
  end

  def url_for(options = {})
    @app.routes.url_helpers.url_for(options)
  end

  def method_missing(method, *args, &block)
    if method.to_s =~ /_(path|url)$/
      @app.routes.url_helpers.send(method, *args, &block)
    else
      super
    end
  end

  def with_https
    old_https = https?
    https!
    yield
  ensure
    https!(old_https)
  end

  def verify_redirect(url, status=301)
    assert_equal status, @response.status
    assert_equal url, @response.headers['Location']
    assert_equal expected_redirect_body(url), @response.body
  end

  def expected_redirect_body(url)
    %(<html><body>You are being <a href="#{ERB::Util.h(url)}">redirected</a>.</body></html>)
  end
end

class TestAltApp < ActionDispatch::IntegrationTest
  class AltRequest < ActionDispatch::Request
    attr_accessor :path_parameters, :path_info, :script_name
    attr_reader :env

    def initialize(env)
      @path_parameters = {}
      @env = env
      @path_info = "/"
      @script_name = ""
      super
    end

    def request_method
      "GET"
    end

    def ip
      "127.0.0.1"
    end

    def x_header
      @env["HTTP_X_HEADER"] || ""
    end
  end

  class XHeader
    def call(env)
      [200, {"Content-Type" => "text/html"}, ["XHeader"]]
    end
  end

  class AltApp
    def call(env)
      [200, {"Content-Type" => "text/html"}, ["Alternative App"]]
    end
  end

  AltRoutes = Class.new(ActionDispatch::Routing::RouteSet) {
    def request_class
      AltRequest
    end
  }.new
  AltRoutes.draw do
    get "/" => TestAltApp::XHeader.new, :constraints => {:x_header => /HEADER/}
    get "/" => TestAltApp::AltApp.new
  end

  APP = build_app AltRoutes

  def app
    APP
  end

  def test_alt_request_without_header
    get "/"
    assert_equal "Alternative App", @response.body
  end

  def test_alt_request_with_matched_header
    get "/", headers: { "HTTP_X_HEADER" => "HEADER" }
    assert_equal "XHeader", @response.body
  end

  def test_alt_request_with_unmatched_header
    get "/", headers: { "HTTP_X_HEADER" => "NON_MATCH" }
    assert_equal "Alternative App", @response.body
  end
end

class TestAppendingRoutes < ActionDispatch::IntegrationTest
  def simple_app(resp)
    lambda { |e| [ 200, { 'Content-Type' => 'text/plain' }, [resp] ] }
  end

  def setup
    super
    s = self
    routes = ActionDispatch::Routing::RouteSet.new
    routes.append do
      get '/hello'   => s.simple_app('fail')
      get '/goodbye' => s.simple_app('goodbye')
    end

    routes.draw do
      get '/hello' => s.simple_app('hello')
    end
    @app = self.class.build_app routes
  end

  def test_goodbye_should_be_available
    get '/goodbye'
    assert_equal 'goodbye', @response.body
  end

  def test_hello_should_not_be_overwritten
    get '/hello'
    assert_equal 'hello', @response.body
  end

  def test_missing_routes_are_still_missing
    get '/random'
    assert_equal 404, @response.status
  end
end

class TestNamespaceWithControllerOption < ActionDispatch::IntegrationTest
  module ::Admin
    class StorageFilesController < ActionController::Base
      def index
        render plain: "admin/storage_files#index"
      end
    end
  end

  def draw(&block)
    routes = ActionDispatch::Routing::RouteSet.new
    routes.draw(&block)
    @app = self.class.build_app routes
  end

  def test_missing_controller
    ex = assert_raises(ArgumentError) {
      draw do
        get '/foo/bar', :action => :index
      end
    }
    assert_match(/Missing :controller/, ex.message)
  end

  def test_missing_controller_with_to
    ex = assert_raises(ArgumentError) {
      draw do
        get '/foo/bar', :to => 'foo'
      end
    }
    assert_match(/Missing :controller/, ex.message)
  end

  def test_missing_action_on_hash
    ex = assert_raises(ArgumentError) {
      draw do
        get '/foo/bar', :to => 'foo#'
      end
    }
    assert_match(/Missing :action/, ex.message)
  end

  def test_valid_controller_options_inside_namespace
    draw do
      namespace :admin do
        resources :storage_files, :controller => "storage_files"
      end
    end

    get '/admin/storage_files'
    assert_equal "admin/storage_files#index", @response.body
  end

  def test_resources_with_valid_namespaced_controller_option
    draw do
      resources :storage_files, :controller => 'admin/storage_files'
    end

    get '/storage_files'
    assert_equal "admin/storage_files#index", @response.body
  end

  def test_warn_with_ruby_constant_syntax_controller_option
    e = assert_raise(ArgumentError) do
      draw do
        namespace :admin do
          resources :storage_files, :controller => "StorageFiles"
        end
      end
    end

    assert_match "'admin/StorageFiles' is not a supported controller name", e.message
  end

  def test_warn_with_ruby_constant_syntax_namespaced_controller_option
    e = assert_raise(ArgumentError) do
      draw do
        resources :storage_files, :controller => 'Admin::StorageFiles'
      end
    end

    assert_match "'Admin::StorageFiles' is not a supported controller name", e.message
  end

  def test_warn_with_ruby_constant_syntax_no_colons
    e = assert_raise(ArgumentError) do
      draw do
        resources :storage_files, :controller => 'Admin'
      end
    end

    assert_match "'Admin' is not a supported controller name", e.message
  end
end

class TestDefaultScope < ActionDispatch::IntegrationTest
  module ::Blog
    class PostsController < ActionController::Base
      def index
        render plain: "blog/posts#index"
      end
    end
  end

  DefaultScopeRoutes = ActionDispatch::Routing::RouteSet.new
  DefaultScopeRoutes.default_scope = {:module => :blog}
  DefaultScopeRoutes.draw do
    resources :posts
  end

  APP = build_app DefaultScopeRoutes

  def app
    APP
  end

  include DefaultScopeRoutes.url_helpers

  def test_default_scope
    get '/posts'
    assert_equal "blog/posts#index", @response.body
  end
end

class TestHttpMethods < ActionDispatch::IntegrationTest
  RFC2616 = %w(OPTIONS GET HEAD POST PUT DELETE TRACE CONNECT)
  RFC2518 = %w(PROPFIND PROPPATCH MKCOL COPY MOVE LOCK UNLOCK)
  RFC3253 = %w(VERSION-CONTROL REPORT CHECKOUT CHECKIN UNCHECKOUT MKWORKSPACE UPDATE LABEL MERGE BASELINE-CONTROL MKACTIVITY)
  RFC3648 = %w(ORDERPATCH)
  RFC3744 = %w(ACL)
  RFC5323 = %w(SEARCH)
  RFC4791 = %w(MKCALENDAR)
  RFC5789 = %w(PATCH)

  def simple_app(response)
    lambda { |env| [ 200, { 'Content-Type' => 'text/plain' }, [response] ] }
  end

  attr_reader :app

  def setup
    s = self
    routes = ActionDispatch::Routing::RouteSet.new
    @app = RoutedRackApp.new routes

    routes.draw do
      (RFC2616 + RFC2518 + RFC3253 + RFC3648 + RFC3744 + RFC5323 + RFC4791 + RFC5789).each do |method|
        match '/' => s.simple_app(method), :via => method.underscore.to_sym
      end
    end
  end

  (RFC2616 + RFC2518 + RFC3253 + RFC3648 + RFC3744 + RFC5323 + RFC4791 + RFC5789).each do |method|
    test "request method #{method.underscore} can be matched" do
      get '/', headers: { 'REQUEST_METHOD' => method }
      assert_equal method, @response.body
    end
  end
end

class TestUriPathEscaping < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      get '/:segment' => lambda { |env|
        path_params = env['action_dispatch.request.path_parameters']
        [200, { 'Content-Type' => 'text/plain' }, [path_params[:segment]]]
      }, :as => :segment

      get '/*splat' => lambda { |env|
        path_params = env['action_dispatch.request.path_parameters']
        [200, { 'Content-Type' => 'text/plain' }, [path_params[:splat]]]
      }, :as => :splat
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  test 'escapes slash in generated path segment' do
    assert_equal '/a%20b%2Fc+d', segment_path(:segment => 'a b/c+d')
  end

  test 'unescapes recognized path segment' do
    get '/a%20b%2Fc+d'
    assert_equal 'a b/c+d', @response.body
  end

  test 'does not escape slash in generated path splat' do
    assert_equal '/a%20b/c+d', splat_path(:splat => 'a b/c+d')
  end

  test 'unescapes recognized path splat' do
    get '/a%20b/c+d'
    assert_equal 'a b/c+d', @response.body
  end
end

class TestUnicodePaths < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      get "/ほげ" => lambda { |env|
        [200, { 'Content-Type' => 'text/plain' }, []]
      }, :as => :unicode_path
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  test 'recognizes unicode path' do
    get "/#{Rack::Utils.escape("ほげ")}"
    assert_equal "200", @response.code
  end
end

class TestMultipleNestedController < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      namespace :foo do
        namespace :bar do
          get "baz" => "baz#index"
        end
      end
      get "pooh" => "pooh#index"
    end
  end

  module ::Foo
    module Bar
      class BazController < ActionController::Base
        include Routes.url_helpers

        def index
          render :inline => "<%= url_for :controller => '/pooh', :action => 'index' %>"
        end
      end
    end
  end

  APP = build_app Routes
  def app; APP end

  test "controller option which starts with '/' from multiple nested controller" do
    get "/foo/bar/baz"
    assert_equal "/pooh", @response.body
  end
end

class TestTildeAndMinusPaths < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get "/~user" => ok
      get "/young-and-fine" => ok
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  test 'recognizes tilde path' do
    get "/~user"
    assert_equal "200", @response.code
  end

  test 'recognizes minus path' do
    get "/young-and-fine"
    assert_equal "200", @response.code
  end

end

class TestRedirectInterpolation < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get "/foo/:id" => redirect("/foo/bar/%{id}")
      get "/bar/:id" => redirect(:path => "/foo/bar/%{id}")
      get "/baz/:id" => redirect("/baz?id=%{id}&foo=?&bar=1#id-%{id}")
      get "/foo/bar/:id" => ok
      get "/baz" => ok
    end
  end

  APP = build_app Routes
  def app; APP end

  test "redirect escapes interpolated parameters with redirect proc" do
    get "/foo/1%3E"
    verify_redirect "http://www.example.com/foo/bar/1%3E"
  end

  test "redirect escapes interpolated parameters with option proc" do
    get "/bar/1%3E"
    verify_redirect "http://www.example.com/foo/bar/1%3E"
  end

  test "path redirect escapes interpolated parameters correctly" do
    get "/foo/1%201"
    verify_redirect "http://www.example.com/foo/bar/1%201"

    get "/baz/1%201"
    verify_redirect "http://www.example.com/baz?id=1+1&foo=?&bar=1#id-1%201"
  end

private
  def verify_redirect(url, status=301)
    assert_equal status, @response.status
    assert_equal url, @response.headers['Location']
    assert_equal expected_redirect_body(url), @response.body
  end

  def expected_redirect_body(url)
    %(<html><body>You are being <a href="#{ERB::Util.h(url)}">redirected</a>.</body></html>)
  end
end

class TestConstraintsAccessingParameters < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get "/:foo" => ok, :constraints => lambda { |r| r.params[:foo] == 'foo' }
      get "/:bar" => ok
    end
  end

  APP = build_app Routes
  def app; APP end

  test "parameters are reset between constraint checks" do
    get "/bar"
    assert_equal nil, @request.params[:foo]
    assert_equal "bar", @request.params[:bar]
  end
end

class TestGlobRoutingMapper < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get "/*id" => redirect("/not_cars"), :constraints => {id: /dummy/}
      get "/cars" => ok
    end
  end

  #include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  def test_glob_constraint
    get "/dummy"
    assert_equal "301", @response.code
    assert_equal "/not_cars", @response.header['Location'].match('/[^/]+$')[0]
  end

  def test_glob_constraint_skip_route
    get "/cars"
    assert_equal "200", @response.code
  end
  def test_glob_constraint_skip_all
    get "/missing"
    assert_equal "404", @response.code
  end
end

class TestOptimizedNamedRoutes < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }
      get '/foo' => ok, as: :foo

      ActiveSupport::Deprecation.silence do
        get '/post(/:action(/:id))' => ok, as: :posts
      end

      get '/:foo/:foo_type/bars/:id' => ok, as: :bar
      get '/projects/:id.:format' => ok, as: :project
      get '/pages/:id' => ok, as: :page
      get '/wiki/*page' => ok, as: :wiki
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  test 'enabled when not mounted and default_url_options is empty' do
    assert Routes.url_helpers.optimize_routes_generation?
  end

  test 'named route called as singleton method' do
    assert_equal '/foo', Routes.url_helpers.foo_path
  end

  test 'named route called on included module' do
    assert_equal '/foo', foo_path
  end

  test 'nested optional segments are removed' do
    assert_equal '/post', Routes.url_helpers.posts_path
    assert_equal '/post', posts_path
  end

  test 'segments with same prefix are replaced correctly' do
    assert_equal '/foo/baz/bars/1', Routes.url_helpers.bar_path('foo', 'baz', '1')
    assert_equal '/foo/baz/bars/1', bar_path('foo', 'baz', '1')
  end

  test 'segments separated with a period are replaced correctly' do
    assert_equal '/projects/1.json', Routes.url_helpers.project_path(1, :json)
    assert_equal '/projects/1.json', project_path(1, :json)
  end

  test 'segments with question marks are escaped' do
    assert_equal '/pages/foo%3Fbar', Routes.url_helpers.page_path('foo?bar')
    assert_equal '/pages/foo%3Fbar', page_path('foo?bar')
  end

  test 'segments with slashes are escaped' do
    assert_equal '/pages/foo%2Fbar', Routes.url_helpers.page_path('foo/bar')
    assert_equal '/pages/foo%2Fbar', page_path('foo/bar')
  end

  test 'glob segments with question marks are escaped' do
    assert_equal '/wiki/foo%3Fbar', Routes.url_helpers.wiki_path('foo?bar')
    assert_equal '/wiki/foo%3Fbar', wiki_path('foo?bar')
  end

  test 'glob segments with slashes are not escaped' do
    assert_equal '/wiki/foo/bar', Routes.url_helpers.wiki_path('foo/bar')
    assert_equal '/wiki/foo/bar', wiki_path('foo/bar')
  end
end

class TestNamedRouteUrlHelpers < ActionDispatch::IntegrationTest
  class CategoriesController < ActionController::Base
    def show
      render plain: "categories#show"
    end
  end

  class ProductsController < ActionController::Base
    def show
      render plain: "products#show"
    end
  end

  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      scope :module => "test_named_route_url_helpers" do
        get "/categories/:id" => 'categories#show', :as => :category
        get "/products/:id" => 'products#show', :as => :product
      end
    end
  end

  APP = build_app Routes
  def app; APP end

  include Routes.url_helpers

  test "url helpers do not ignore nil parameters when using non-optimized routes" do
    Routes.stub :optimize_routes_generation?, false do
      get "/categories/1"
      assert_response :success
      assert_raises(ActionController::UrlGenerationError) { product_path(nil) }
    end
  end
end

class TestUrlConstraints < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      constraints :subdomain => 'admin' do
        get '/' => ok, :as => :admin_root
      end

      scope :constraints => { :protocol => 'https://' } do
        get '/' => ok, :as => :secure_root
      end

      get '/' => ok, :as => :alternate_root, :constraints => { :port => 8080 }

      get '/search' => ok, :constraints => { :subdomain => false }

      get '/logs' => ok, :constraints => { :subdomain => true }
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  test "constraints are copied to defaults when using constraints method" do
    assert_equal 'http://admin.example.com/', admin_root_url

    get 'http://admin.example.com/'
    assert_response :success
  end

  test "constraints are copied to defaults when using scope constraints hash" do
    assert_equal 'https://www.example.com/', secure_root_url

    get 'https://www.example.com/'
    assert_response :success
  end

  test "constraints are copied to defaults when using route constraints hash" do
    assert_equal 'http://www.example.com:8080/', alternate_root_url

    get 'http://www.example.com:8080/'
    assert_response :success
  end

  test "false constraint expressions check for absence of values" do
    get 'http://example.com/search'
    assert_response :success
    assert_equal 'http://example.com/search', search_url

    get 'http://api.example.com/search'
    assert_response :not_found
  end

  test "true constraint expressions check for presence of values" do
    get 'http://api.example.com/logs'
    assert_response :success
    assert_equal 'http://api.example.com/logs', logs_url

    get 'http://example.com/logs'
    assert_response :not_found
  end
end

class TestInvalidUrls < ActionDispatch::IntegrationTest
  class FooController < ActionController::Base
    def show
      render plain: "foo#show"
    end
  end

  test "invalid UTF-8 encoding returns a 400 Bad Request" do
    with_routing do |set|
      set.draw do
        get "/bar/:id", :to => redirect("/foo/show/%{id}")
        get "/foo/show(/:id)", :to => "test_invalid_urls/foo#show"

        ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }
        get '/foobar/:id', to: ok

        ActiveSupport::Deprecation.silence do
          get "/foo(/:action(/:id))", :controller => "test_invalid_urls/foo"
          get "/:controller(/:action(/:id))"
        end
      end

      get "/%E2%EF%BF%BD%A6"
      assert_response :bad_request

      get "/foo/%E2%EF%BF%BD%A6"
      assert_response :bad_request

      get "/foo/show/%E2%EF%BF%BD%A6"
      assert_response :bad_request

      get "/bar/%E2%EF%BF%BD%A6"
      assert_response :bad_request

      get "/foobar/%E2%EF%BF%BD%A6"
      assert_response :bad_request
    end
  end
end

class TestOptionalRootSegments < ActionDispatch::IntegrationTest
  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      get '/(page/:page)', :to => 'pages#index', :as => :root
    end
  end

  APP = build_app Routes
  def app
    APP
  end

  include Routes.url_helpers

  def test_optional_root_segments
    get '/'
    assert_equal 'pages#index', @response.body
    assert_equal '/', root_path

    get '/page/1'
    assert_equal 'pages#index', @response.body
    assert_equal '1', @request.params[:page]
    assert_equal '/page/1', root_path('1')
    assert_equal '/page/1', root_path(:page => '1')
  end
end

class TestPortConstraints < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get '/integer', to: ok, constraints: { :port =>  8080  }
      get '/string',  to: ok, constraints: { :port => '8080' }
      get '/array',   to: ok, constraints: { :port => [8080] }
      get '/regexp',  to: ok, constraints: { :port => /8080/ }
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  def test_integer_port_constraints
    get 'http://www.example.com/integer'
    assert_response :not_found

    get 'http://www.example.com:8080/integer'
    assert_response :success
  end

  def test_string_port_constraints
    get 'http://www.example.com/string'
    assert_response :not_found

    get 'http://www.example.com:8080/string'
    assert_response :success
  end

  def test_array_port_constraints
    get 'http://www.example.com/array'
    assert_response :not_found

    get 'http://www.example.com:8080/array'
    assert_response :success
  end

  def test_regexp_port_constraints
    get 'http://www.example.com/regexp'
    assert_response :not_found

    get 'http://www.example.com:8080/regexp'
    assert_response :success
  end
end

class TestFormatConstraints < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

      get '/string', to: ok, constraints: { format: 'json'  }
      get '/regexp',  to: ok, constraints: { format: /json/ }
      get '/json_only', to: ok, format: true, constraints: { format: /json/ }
      get '/xml_only', to: ok, format: 'xml'
    end
  end

  include Routes.url_helpers
  APP = build_app Routes
  def app; APP end

  def test_string_format_constraints
    get 'http://www.example.com/string'
    assert_response :success

    get 'http://www.example.com/string.json'
    assert_response :success

    get 'http://www.example.com/string.html'
    assert_response :not_found
  end

  def test_regexp_format_constraints
    get 'http://www.example.com/regexp'
    assert_response :success

    get 'http://www.example.com/regexp.json'
    assert_response :success

    get 'http://www.example.com/regexp.html'
    assert_response :not_found
  end

  def test_enforce_with_format_true_with_constraint
    get 'http://www.example.com/json_only.json'
    assert_response :success

    get 'http://www.example.com/json_only.html'
    assert_response :not_found

    get 'http://www.example.com/json_only'
    assert_response :not_found
  end

  def test_enforce_with_string
    get 'http://www.example.com/xml_only.xml'
    assert_response :success

    get 'http://www.example.com/xml_only'
    assert_response :success

    get 'http://www.example.com/xml_only.json'
    assert_response :not_found
  end
end

class TestCallableConstraintValidation < ActionDispatch::IntegrationTest
  def test_constraint_with_object_not_callable
    assert_raises(ArgumentError) do
      ActionDispatch::Routing::RouteSet.new.draw do
        ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }
        get '/test', to: ok, constraints: Object.new
      end
    end
  end
end

class TestRouteDefaults < ActionDispatch::IntegrationTest
  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      resources :posts, bucket_type: 'post'
      resources :projects, defaults: { bucket_type: 'project' }
    end
  end

  APP = build_app Routes
  def app
    APP
  end

  include Routes.url_helpers

  def test_route_options_are_required_for_url_for
    assert_raises(ActionController::UrlGenerationError) do
      assert_equal '/posts/1', url_for(controller: 'posts', action: 'show', id: 1, only_path: true)
    end

    assert_equal '/posts/1', url_for(controller: 'posts', action: 'show', id: 1, bucket_type: 'post', only_path: true)
  end

  def test_route_defaults_are_not_required_for_url_for
    assert_equal '/projects/1', url_for(controller: 'projects', action: 'show', id: 1, only_path: true)
  end
end

class TestRackAppRouteGeneration < ActionDispatch::IntegrationTest
  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      rack_app = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }
      mount rack_app, at: '/account', as: 'account'
      mount rack_app, at: '/:locale/account', as: 'localized_account'
    end
  end

  APP = build_app Routes
  def app
    APP
  end

  include Routes.url_helpers

  def test_mounted_application_doesnt_match_unnamed_route
    assert_raise(ActionController::UrlGenerationError) do
      assert_equal '/account?controller=products', url_for(controller: 'products', action: 'index', only_path: true)
    end

    assert_raise(ActionController::UrlGenerationError) do
      assert_equal '/de/account?controller=products', url_for(controller: 'products', action: 'index', :locale => 'de', only_path: true)
    end
  end
end

class TestRedirectRouteGeneration < ActionDispatch::IntegrationTest
  stub_controllers do |routes|
    Routes = routes
    Routes.draw do
      get '/account', to: redirect('/myaccount'), as: 'account'
      get '/:locale/account', to: redirect('/%{locale}/myaccount'), as: 'localized_account'
    end
  end

  APP = build_app Routes
  def app
    APP
  end

  include Routes.url_helpers

  def test_redirect_doesnt_match_unnamed_route
    assert_raise(ActionController::UrlGenerationError) do
      assert_equal '/account?controller=products', url_for(controller: 'products', action: 'index', only_path: true)
    end

    assert_raise(ActionController::UrlGenerationError) do
      assert_equal '/de/account?controller=products', url_for(controller: 'products', action: 'index', :locale => 'de', only_path: true)
    end
  end
end

class TestUrlGenerationErrors < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      get "/products/:id" => 'products#show', :as => :product
    end
  end

  APP = build_app Routes
  def app; APP end

  include Routes.url_helpers

  test "url helpers raise a helpful error message when generation fails" do
    url, missing = { action: 'show', controller: 'products', id: nil }, [:id]
    message = "No route matches #{url.inspect} missing required keys: #{missing.inspect}"

    # Optimized url helper
    error = assert_raises(ActionController::UrlGenerationError){ product_path(nil) }
    assert_equal message, error.message

    # Non-optimized url helper
    error = assert_raises(ActionController::UrlGenerationError, message){ product_path(id: nil) }
    assert_equal message, error.message
  end

  test "url helpers raise message with mixed parameters when generation fails " do
    url, missing = { action: 'show', controller: 'products', id: nil, "id"=>"url-tested"}, [:id]
    message = "No route matches #{url.inspect} missing required keys: #{missing.inspect}"

    # Optimized url helper
    error = assert_raises(ActionController::UrlGenerationError){ product_path(nil, 'id'=>'url-tested') }
    assert_equal message, error.message

    # Non-optimized url helper
    error = assert_raises(ActionController::UrlGenerationError, message){ product_path(id: nil, 'id'=>'url-tested') }
    assert_equal message, error.message
  end
end

class TestDefaultUrlOptions < ActionDispatch::IntegrationTest
  class PostsController < ActionController::Base
    def archive
      render plain: "posts#archive"
    end
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    default_url_options locale: 'en'
    scope ':locale', format: false do
      get '/posts/:year/:month/:day', to: 'posts#archive', as: 'archived_posts'
    end
  end

  APP = build_app Routes

  def app
    APP
  end

  include Routes.url_helpers

  def test_positional_args_with_format_false
    assert_equal '/en/posts/2014/12/13', archived_posts_path(2014, 12, 13)
  end
end

class TestErrorsInController < ActionDispatch::IntegrationTest
  class ::PostsController < ActionController::Base
    def foo
      nil.i_do_not_exist
    end

    def bar
      NonExistingClass.new
    end
  end

  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    ActiveSupport::Deprecation.silence do
      get '/:controller(/:action)'
    end
  end

  APP = build_app Routes

  def app
    APP
  end

  def test_legit_no_method_errors_are_not_caught
    get '/posts/foo'
    assert_equal 500, response.status
  end

  def test_legit_name_errors_are_not_caught
    get '/posts/bar'
    assert_equal 500, response.status
  end

  def test_legit_routing_not_found_responses
    get '/posts/baz'
    assert_equal 404, response.status

    get '/i_do_not_exist'
    assert_equal 404, response.status
  end
end

class TestPartialDynamicPathSegments < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new
  Routes.draw do
    ok = lambda { |env| [200, { 'Content-Type' => 'text/plain' }, []] }

    get '/songs/song-:song', to: ok
    get '/songs/:song-song', to: ok
    get '/:artist/song-:song', to: ok
    get '/:artist/:song-song', to: ok

    get '/optional/songs(/song-:song)', to: ok
    get '/optional/songs(/:song-song)', to: ok
    get '/optional/:artist(/song-:song)', to: ok
    get '/optional/:artist(/:song-song)', to: ok
  end

  APP = build_app Routes

  def app
    APP
  end

  def test_paths_with_partial_dynamic_segments_are_recognised
    get '/david-bowie/changes-song'
    assert_equal 200, response.status
    assert_params artist: 'david-bowie', song: 'changes'

    get '/david-bowie/song-changes'
    assert_equal 200, response.status
    assert_params artist: 'david-bowie', song: 'changes'

    get '/songs/song-changes'
    assert_equal 200, response.status
    assert_params song: 'changes'

    get '/songs/changes-song'
    assert_equal 200, response.status
    assert_params song: 'changes'

    get '/optional/songs/song-changes'
    assert_equal 200, response.status
    assert_params song: 'changes'

    get '/optional/songs/changes-song'
    assert_equal 200, response.status
    assert_params song: 'changes'

    get '/optional/david-bowie/changes-song'
    assert_equal 200, response.status
    assert_params artist: 'david-bowie', song: 'changes'

    get '/optional/david-bowie/song-changes'
    assert_equal 200, response.status
    assert_params artist: 'david-bowie', song: 'changes'
  end

  private

  def assert_params(params)
    assert_equal(params, request.path_parameters)
  end
end

class TestPathParameters < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      scope module: 'test_path_parameters' do
        scope ':locale', locale: /en|ar/ do
          root to: 'home#index'
          get '/about', to: 'pages#about'
        end
      end

      ActiveSupport::Deprecation.silence do
        get ':controller(/:action/(:id))'
      end
    end
  end

  class HomeController < ActionController::Base
    include Routes.url_helpers

    def index
      render inline: "<%= root_path %>"
    end
  end

  class PagesController < ActionController::Base
    include Routes.url_helpers

    def about
      render inline: "<%= root_path(locale: :ar) %> | <%= url_for(locale: :ar) %>"
    end
  end

  APP = build_app Routes
  def app; APP end

  def test_path_parameters_are_not_mutated
    get '/en/about'
    assert_equal "/ar | /ar/about", @response.body
  end
end

class TestInternalRoutingParams < ActionDispatch::IntegrationTest
  Routes = ActionDispatch::Routing::RouteSet.new.tap do |app|
    app.draw do
      get '/test_internal/:internal' => 'internal#internal'
    end
  end

  class ::InternalController < ActionController::Base
    def internal
      head :ok
    end
  end

  APP = build_app Routes

  def app
    APP
  end

  def test_paths_with_partial_dynamic_segments_are_recognised
    get '/test_internal/123'
    assert_equal 200, response.status

    assert_equal(
      { controller: 'internal', action: 'internal', internal: '123' },
      request.path_parameters
    )
  end
end
