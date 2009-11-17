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

  stub_controllers do |routes|
    Routes = routes
    Routes.draw do |map|
      controller :sessions do
        get  'login', :to => :new, :as => :login
        post 'login', :to => :create

        delete 'logout', :to => :destroy, :as => :logout
      end

      match 'account/login', :to => redirect("/login")

      match 'openid/login', :via => [:get, :post], :to => "openid#login"

      controller(:global) do
        match 'global/:action'
        match 'global/export',      :to => :export, :as => :export_request
        match 'global/hide_notice', :to => :hide_notice, :as => :hide_notice
        match '/export/:id/:file',  :to => :export, :as => :export_download, :constraints => { :file => /.*/ }
      end

      constraints(:ip => /192\.168\.1\.\d\d\d/) do
        get 'admin', :to => "queenbee#index"
      end

      constraints ::TestRoutingMapper::IpRestrictor do
        get 'admin/accounts', :to => "queenbee#accounts"
      end

      resources :projects, :controller => :project do
        resources :involvements, :attachments

        resources :participants do
          put :update_all, :on => :collection
        end

        resources :companies do
          resources :people
          resource  :avatar
        end

        resources :images do
          post :revise, :on => :member
        end

        resources :people do
          namespace ":access_token" do
            resource :avatar
          end

          member do
            put  :accessible_projects
            post :resend, :generate_new_password
          end
        end

        resources :posts do
          get  :archive, :toggle_view, :on => :collection
          post :preview, :on => :member

          resource :subscription

          resources :comments do
            post :preview, :on => :collection
          end
        end
      end

      match 'sprockets.js', :to => ::TestRoutingMapper::SprocketsApp

      match 'people/:id/update', :to => 'people#update', :as => :update_person
      match '/projects/:project_id/people/:id/update', :to => 'people#update', :as => :update_project_person

      # misc
      match 'articles/:year/:month/:day/:title', :to => "articles#show", :as => :article

      namespace :account do
        resource :subscription, :credit, :credit_card
      end

      controller :articles do
        scope 'articles' do
          scope ':title', :title => /[a-z]+/, :as => :with_title do
            match ':id', :to => :with_id
          end
        end
      end

      scope ':access_token', :constraints => { :access_token => /\w{5,5}/ } do
        resources :rooms
      end
    end
  end

  def app
    Routes
  end

  def test_logout
    with_test_routes do
      delete '/logout'
      assert_equal 'sessions#destroy', @response.body

      assert_equal '/logout', logout_path
      assert_equal '/logout', url_for(:controller => 'sessions', :action => 'destroy', :only_path => true)
    end
  end

  def test_login
    with_test_routes do
      get '/login'
      assert_equal 'sessions#new', @response.body
      assert_equal '/login', login_path

      post '/login'
      assert_equal 'sessions#create', @response.body

      assert_equal '/login', url_for(:controller => 'sessions', :action => 'create', :only_path => true)
      assert_equal '/login', url_for(:controller => 'sessions', :action => 'new', :only_path => true)
    end
  end

  def test_login_redirect
    with_test_routes do
      get '/account/login'
      assert_equal 301, @response.status
      assert_equal 'http://www.example.com/login', @response.headers['Location']
      assert_equal 'Moved Permanently', @response.body
    end
  end

  def test_openid
    with_test_routes do
      get '/openid/login'
      assert_equal 'openid#login', @response.body

      post '/openid/login'
      assert_equal 'openid#login', @response.body
    end
  end

  # TODO: rackmount is broken
  # def test_admin
  #   with_test_routes do
  #     get '/admin', {}, {'REMOTE_ADDR' => '192.168.1.100'}
  #     assert_equal 'queenbee#index', @response.body
  #
  #     assert_raise(ActionController::RoutingError) { get '/admin', {}, {'REMOTE_ADDR' => '10.0.0.100'} }
  #
  #     get '/admin/accounts', {}, {'REMOTE_ADDR' => '192.168.1.100'}
  #     assert_equal 'queenbee#accounts', @response.body
  #
  #     assert_raise(ActionController::RoutingError) { get '/admin/accounts', {}, {'REMOTE_ADDR' => '10.0.0.100'} }
  #   end
  # end

  def test_global
    with_test_routes do
      get '/global/dashboard'
      assert_equal 'global#dashboard', @response.body

      get '/global/export'
      assert_equal 'global#export', @response.body

      get '/global/hide_notice'
      assert_equal 'global#hide_notice', @response.body

      get '/export/123/foo.txt'
      assert_equal 'global#export', @response.body

      assert_equal '/global/export', export_request_path
      assert_equal '/global/hide_notice', hide_notice_path
      assert_equal '/export/123/foo.txt', export_download_path(:id => 123, :file => 'foo.txt')
    end
  end

  def test_projects
    with_test_routes do
      get '/projects'
      assert_equal 'projects#index', @response.body
      assert_equal '/projects', projects_path

      get '/projects/new'
      assert_equal 'projects#new', @response.body
      assert_equal '/projects/new', new_project_path

      get '/projects/1'
      assert_equal 'projects#show', @response.body
      assert_equal '/projects/1', project_path(:id => '1')

      get '/projects/1/edit'
      assert_equal 'projects#edit', @response.body
      assert_equal '/projects/1/edit', edit_project_path(:id => '1')
    end
  end

  def test_projects_involvements
    with_test_routes do
      get '/projects/1/involvements'
      assert_equal 'involvements#index', @response.body

      get '/projects/1/involvements/1'
      assert_equal 'involvements#show', @response.body
    end
  end

  def test_projects_attachments
    with_test_routes do
      get '/projects/1/attachments'
      assert_equal 'attachments#index', @response.body
    end
  end

  def test_projects_participants
    with_test_routes do
      get '/projects/1/participants'
      assert_equal 'participants#index', @response.body

      put '/projects/1/participants/update_all'
      assert_equal 'participants#update_all', @response.body
    end
  end

  def test_projects_companies
    with_test_routes do
      get '/projects/1/companies'
      assert_equal 'companies#index', @response.body

      get '/projects/1/companies/1/people'
      assert_equal 'people#index', @response.body

      get '/projects/1/companies/1/avatar'
      assert_equal 'avatars#show', @response.body
    end
  end

  def test_project_images
    with_test_routes do
      get '/projects/1/images'
      assert_equal 'images#index', @response.body

      post '/projects/1/images/1/revise'
      assert_equal 'images#revise', @response.body
    end
  end

  def test_projects_people
    with_test_routes do
      get '/projects/1/people'
      assert_equal 'people#index', @response.body

      get '/projects/1/people/1'
      assert_equal 'people#show', @response.body

      get '/projects/1/people/1/7a2dec8/avatar'
      assert_equal 'avatars#show', @response.body

      put '/projects/1/people/1/accessible_projects'
      assert_equal 'people#accessible_projects', @response.body

      post '/projects/1/people/1/resend'
      assert_equal 'people#resend', @response.body

      post '/projects/1/people/1/generate_new_password'
      assert_equal 'people#generate_new_password', @response.body
    end
  end

  def test_projects_posts
    with_test_routes do
      get '/projects/1/posts'
      assert_equal 'posts#index', @response.body

      get '/projects/1/posts/archive'
      assert_equal 'posts#archive', @response.body

      get '/projects/1/posts/toggle_view'
      assert_equal 'posts#toggle_view', @response.body

      post '/projects/1/posts/1/preview'
      assert_equal 'posts#preview', @response.body

      get '/projects/1/posts/1/subscription'
      assert_equal 'subscriptions#show', @response.body

      get '/projects/1/posts/1/comments'
      assert_equal 'comments#index', @response.body

      post '/projects/1/posts/1/comments/preview'
      assert_equal 'comments#preview', @response.body
    end
  end

  def test_sprockets
    with_test_routes do
      get '/sprockets.js'
      assert_equal 'javascripts', @response.body
    end
  end

  def test_update_person_route
    with_test_routes do
      get '/people/1/update'
      assert_equal 'people#update', @response.body

      assert_equal '/people/1/update', update_person_path(:id => 1)
    end
  end

  def test_update_project_person
    with_test_routes do
      get '/projects/1/people/2/update'
      assert_equal 'people#update', @response.body

      assert_equal '/projects/1/people/2/update', update_project_person_path(:project_id => 1, :id => 2)
    end
  end

  def test_articles_perma
    with_test_routes do
      get '/articles/2009/08/18/rails-3'
      assert_equal 'articles#show', @response.body

      assert_equal '/articles/2009/8/18/rails-3', article_path(:year => 2009, :month => 8, :day => 18, :title => 'rails-3')
    end
  end

  def test_account_namespace
    with_test_routes do
      get '/account/subscription'
      assert_equal 'subscriptions#show', @response.body

      get '/account/credit'
      assert_equal 'credits#show', @response.body

      get '/account/credit_card'
      assert_equal 'credit_cards#show', @response.body
    end
  end

  def test_articles_with_id
    with_test_routes do
      get '/articles/rails/1'
      assert_equal 'articles#with_id', @response.body

      assert_raise(ActionController::RoutingError) { get '/articles/123/1' }

      assert_equal '/articles/rails/1', with_title_path(:title => 'rails', :id => 1)
    end
  end

  def test_access_token_rooms
    with_test_routes do
      get '/12345/rooms'
      assert_equal 'rooms#index', @response.body

      get '/12345/rooms/1'
      assert_equal 'rooms#show', @response.body

      get '/12345/rooms/1/edit'
      assert_equal 'rooms#edit', @response.body
    end
  end

  private
    def with_test_routes
      real_routes, temp_routes = ActionController::Routing::Routes, Routes

      ActionController::Routing.module_eval { remove_const :Routes }
      ActionController::Routing.module_eval { const_set :Routes, temp_routes }

      yield
    ensure
      ActionController::Routing.module_eval { remove_const :Routes }
      ActionController::Routing.const_set(:Routes, real_routes)
    end
end
