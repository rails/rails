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
    Routes.draw do
      controller :sessions do
        get  'login' => :new, :as => :login
        post 'login' => :create

        delete 'logout' => :destroy, :as => :logout
      end

      resource :session do
        get :create
      end

      match 'account/logout' => redirect("/logout"), :as => :logout_redirect
      match 'account/login', :to => redirect("/login")

      match 'account/overview'

      match 'account/modulo/:name', :to => redirect("/%{name}s")
      match 'account/proc/:name', :to => redirect {|params| "/#{params[:name].pluralize}" }
      match 'account/google' => redirect('http://www.google.com/')

      match 'openid/login', :via => [:get, :post], :to => "openid#login"

      controller(:global) do
        get   'global/hide_notice'
        match 'global/export',      :to => :export, :as => :export_request
        match '/export/:id/:file',  :to => :export, :as => :export_download, :constraints => { :file => /.*/ }
        match 'global/:action'
      end

      constraints(:ip => /192\.168\.1\.\d\d\d/) do
        get 'admin' => "queenbee#index"
      end

      constraints ::TestRoutingMapper::IpRestrictor do
        get 'admin/accounts' => "queenbee#accounts"
      end

      scope 'es' do
        resources :projects, :path_names => { :edit => 'cambiar' }, :as => 'projeto'
      end

      resources :projects, :controller => :project do
        resources :involvements, :attachments

        resources :participants do
          put :update_all, :on => :collection
        end

        resources :companies do
          resources :people
          resource  :avatar, :controller => :avatar
        end

        resources :images do
          post :revise, :on => :member
        end

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

        resources :posts do
          get  :archive, :toggle_view, :on => :collection
          post :preview, :on => :member

          resource :subscription

          resources :comments do
            post :preview, :on => :collection
          end
        end
      end

      resources :replies do
        member do
          put :answer, :to => :mark_as_answer
          delete :answer, :to => :unmark_as_answer
        end
      end

      resources :posts, :only => [:index, :show]

      match 'sprockets.js' => ::TestRoutingMapper::SprocketsApp

      match 'people/:id/update', :to => 'people#update', :as => :update_person
      match '/projects/:project_id/people/:id/update', :to => 'people#update', :as => :update_project_person

      # misc
      match 'articles/:year/:month/:day/:title', :to => "articles#show", :as => :article

      namespace :account do
        match 'description', :to => "account#description", :as => "description"
        resource :subscription, :credit, :credit_card

        root :to => "account#index"

        namespace :admin do
          resource :subscription
        end
      end

      namespace :forum do
        resources :products, :as => '' do
          resources :questions
        end
      end

      controller :articles do
        scope '/articles', :name_prefix => 'article' do
          scope :path => '/:title', :title => /[a-z]+/, :as => :with_title do
            match '/:id', :to => :with_id
          end
        end
      end

      scope ':access_token', :constraints => { :access_token => /\w{5,5}/ } do
        resources :rooms
      end

      match '/info' => 'projects#info', :as => 'info'

      namespace :admin do
        scope '(:locale)', :locale => /en|pl/ do
          resources :descriptions
        end
      end

      scope '(:locale)', :locale => /en|pl/ do
        resources :descriptions
        root :to => 'projects#index'
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

  def test_logout_redirect_without_to
    with_test_routes do
      assert_equal '/account/logout', logout_redirect_path
      get '/account/logout'
      assert_equal 301, @response.status
      assert_equal 'http://www.example.com/logout', @response.headers['Location']
      assert_equal 'Moved Permanently', @response.body
    end
  end

  def test_session_singleton_resource
    with_test_routes do
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
    end
  end

  def test_redirect_modulo
    with_test_routes do
      get '/account/modulo/name'
      assert_equal 301, @response.status
      assert_equal 'http://www.example.com/names', @response.headers['Location']
      assert_equal 'Moved Permanently', @response.body
    end
  end

  def test_redirect_proc
    with_test_routes do
      get '/account/proc/person'
      assert_equal 301, @response.status
      assert_equal 'http://www.example.com/people', @response.headers['Location']
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

  def test_admin
    with_test_routes do
      get '/admin', {}, {'REMOTE_ADDR' => '192.168.1.100'}
      assert_equal 'queenbee#index', @response.body

      assert_raise(ActionController::RoutingError) { get '/admin', {}, {'REMOTE_ADDR' => '10.0.0.100'} }

      get '/admin/accounts', {}, {'REMOTE_ADDR' => '192.168.1.100'}
      assert_equal 'queenbee#accounts', @response.body

      assert_raise(ActionController::RoutingError) { get '/admin/accounts', {}, {'REMOTE_ADDR' => '10.0.0.100'} }
    end
  end

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
      assert_equal '/global/hide_notice', global_hide_notice_path
      assert_equal '/export/123/foo.txt', export_download_path(:id => 123, :file => 'foo.txt')
    end
  end

  def test_projects
    with_test_routes do
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
  end

  def test_projects_involvements
    with_test_routes do
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
  end

  def test_projects_attachments
    with_test_routes do
      get '/projects/1/attachments'
      assert_equal 'attachments#index', @response.body
      assert_equal '/projects/1/attachments', project_attachments_path(:project_id => '1')
    end
  end

  def test_projects_participants
    with_test_routes do
      get '/projects/1/participants'
      assert_equal 'participants#index', @response.body
      assert_equal '/projects/1/participants', project_participants_path(:project_id => '1')

      put '/projects/1/participants/update_all'
      assert_equal 'participants#update_all', @response.body
      assert_equal '/projects/1/participants/update_all', update_all_project_participants_path(:project_id => '1')
    end
  end

  def test_projects_companies
    with_test_routes do
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
  end

  def test_project_images
    with_test_routes do
      get '/projects/1/images'
      assert_equal 'images#index', @response.body
      assert_equal '/projects/1/images', project_images_path(:project_id => '1')

      post '/projects/1/images/1/revise'
      assert_equal 'images#revise', @response.body
      assert_equal '/projects/1/images/1/revise', revise_project_image_path(:project_id => '1', :id => '1')
    end
  end

  def test_projects_people
    with_test_routes do
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
  end

  def test_projects_posts
    with_test_routes do
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
  end

  def test_replies
    with_test_routes do
      put '/replies/1/answer'
      assert_equal 'replies#mark_as_answer', @response.body

      delete '/replies/1/answer'
      assert_equal 'replies#unmark_as_answer', @response.body
    end
  end

  def test_posts
    with_test_routes do
      get '/posts'
      assert_equal 'posts#index', @response.body
      assert_equal '/posts', posts_path

      get '/posts/1'
      assert_equal 'posts#show', @response.body
      assert_equal '/posts/1', post_path(:id => 1)

      assert_raise(ActionController::RoutingError) { post '/posts' }
      assert_raise(ActionController::RoutingError) { put '/posts/1' }
      assert_raise(ActionController::RoutingError) { delete '/posts/1' }
    end
  end

  def test_path_names
    with_test_routes do
      get '/es/projeto'
      assert_equal 'projects#index', @response.body

      get '/es/projeto/1/cambiar'
      assert_equal 'projects#edit', @response.body
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

  def test_forum_products
    with_test_routes do
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
      assert_equal 'account/subscriptions#show', @response.body
      assert_equal '/account/subscription', account_subscription_path

      get '/account/credit'
      assert_equal 'account/credits#show', @response.body
      assert_equal '/account/credit', account_credit_path

      get '/account/credit_card'
      assert_equal 'account/credit_cards#show', @response.body
      assert_equal '/account/credit_card', account_credit_card_path
    end
  end

  def test_nested_namespace
    with_test_routes do
      get '/account/admin/subscription'
      assert_equal 'account/admin/subscriptions#show', @response.body
      assert_equal '/account/admin/subscription', account_admin_subscription_path
    end
  end

  def test_articles_with_id
    with_test_routes do
      get '/articles/rails/1'
      assert_equal 'articles#with_id', @response.body

      assert_raise(ActionController::RoutingError) { get '/articles/123/1' }

      assert_equal '/articles/rails/1', article_with_title_path(:title => 'rails', :id => 1)
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

  def test_root
    with_test_routes do
      assert_equal '/', root_path
      get '/'
      assert_equal 'projects#index', @response.body
    end
  end

  def test_index
    with_test_routes do
      assert_equal '/info', info_path
      get '/info'
      assert_equal 'projects#info', @response.body
    end
  end

  def test_index
    with_test_routes do
      assert_equal '/info', info_path
      get '/info'
      assert_equal 'projects#info', @response.body
    end
  end

  def test_convention_match_with_no_scope
    with_test_routes do
      assert_equal '/account/overview', account_overview_path
      get '/account/overview'
      assert_equal 'account#overview', @response.body
    end
  end

  def test_redirect_with_complete_url
    with_test_routes do
      get '/account/google'
      assert_equal 301, @response.status
      assert_equal 'http://www.google.com/', @response.headers['Location']
      assert_equal 'Moved Permanently', @response.body
    end
  end

  def test_redirect_with_port
    previous_host, self.host = self.host, 'www.example.com:3000'
    with_test_routes do
      get '/account/login'
      assert_equal 301, @response.status
      assert_equal 'http://www.example.com:3000/login', @response.headers['Location']
      assert_equal 'Moved Permanently', @response.body
    end
  ensure
    self.host = previous_host
  end

  def test_normalize_namespaced_matches
    with_test_routes do
      assert_equal '/account/description', account_description_path

      get '/account/description'
      assert_equal 'account#description', @response.body
    end
  end

  def test_namespaced_roots
    with_test_routes do
      assert_equal '/account', account_root_path
      get '/account'
      assert_equal 'account#index', @response.body
    end
  end

  def test_optional_scoped_root
    with_test_routes do
      assert_equal '/en', root_path("en")
      get '/en'
      assert_equal 'projects#index', @response.body
    end
  end

  def test_optional_scoped_path
    with_test_routes do
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
  end

  def test_nested_optional_scoped_path
    with_test_routes do
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
