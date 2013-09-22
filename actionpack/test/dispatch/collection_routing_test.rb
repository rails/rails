require 'abstract_unit'

class TestCollectionRouting < ActionDispatch::IntegrationTest
  test 'collection option' do
    draw do
      resources :posts, :blogs, collection: true
    end

    get '/posts'
    assert_equal 'posts#index', @response.body
    assert_equal '/posts', posts_path

    get '/posts/1..10,15'
    assert_equal 'posts#index', @response.body
    assert_equal '/posts/1..10,15', posts_path(ids: '1..10,15')

    post '/posts'
    assert_equal 'posts#create', @response.body

    patch '/posts/1..10'
    assert_equal 'posts#update_many', @response.body

    put '/posts/1..10'
    assert_equal 'posts#replace', @response.body

    delete '/posts/1..10'
    assert_equal 'posts#destroy_many', @response.body

    get '/posts/1..10,15/edit'
    assert_equal 'posts#edit_many', @response.body
    assert_equal '/posts/1..10,15/edit', edit_posts_path(ids: '1..10,15')


    get '/blogs'
    assert_equal 'blogs#index', @response.body
    assert_equal '/blogs', blogs_path

    get '/blogs/1..10,15'
    assert_equal 'blogs#index', @response.body
    assert_equal '/blogs/1..10,15', blogs_path(ids: '1..10,15')

    post '/blogs'
    assert_equal 'blogs#create', @response.body

    patch '/blogs/1..10'
    assert_equal 'blogs#update_many', @response.body

    put '/blogs/1..10'
    assert_equal 'blogs#replace', @response.body

    delete '/blogs/1..10'
    assert_equal 'blogs#destroy_many', @response.body

    get '/blogs/1..10,15/edit'
    assert_equal 'blogs#edit_many', @response.body
    assert_equal '/blogs/1..10,15/edit', edit_blogs_path(ids: '1..10,15')
  end

  test 'nested collection resources' do
    draw do
      resources :posts, collection: true do
        resources :comments, collection: true
      end
    end

    get '/posts/1/comments/4..6'
    assert_equal 'comments#index', @response.body
    assert_equal '/posts/1/comments/1..10,15', post_comments_path(post_id: '1', ids: '1..10,15')

    post '/posts/1/comments'
    assert_equal 'comments#create', @response.body

    patch '/posts/1/comments/4..6'
    assert_equal 'comments#update_many', @response.body

    put '/posts/1/comments/4..6'
    assert_equal 'comments#replace', @response.body

    delete '/posts/1/comments/4..6'
    assert_equal 'comments#destroy_many', @response.body

    get '/posts/1/comments/1..10,15/edit'
    assert_equal 'comments#edit_many', @response.body
    assert_equal '/posts/1/comments/1..10,15/edit', edit_post_comments_path(post_id: '1', ids: '1..10,15')
  end

  test 'regular resource nested inside collection resource' do
    draw do
      resources :posts, collection: true do
        resources :comments
      end
    end

    get '/posts/1/comments'
    assert_equal 'comments#index', @response.body
    assert_equal '/posts/1/comments', post_comments_path(post_id: '1')

    get '/posts/1/comments/4'
    assert_equal 'comments#show', @response.body

    post '/posts/1/comments'
    assert_equal 'comments#create', @response.body

    patch '/posts/1/comments/4'
    assert_equal 'comments#update', @response.body

    put '/posts/1/comments/4'
    assert_equal 'comments#update', @response.body

    delete '/posts/1/comments/4'
    assert_equal 'comments#destroy', @response.body

    get '/posts/1/comments/15/edit'
    assert_equal 'comments#edit', @response.body
    assert_equal '/posts/1/comments/15/edit', edit_post_comment_path(post_id: '1', id: '15')
  end

  test 'namespaced collection resource' do
    draw do
      namespace :admin do
        resources :posts, collection: true
      end
    end

    get '/admin/posts/3..5'
    assert_equal 'admin/posts#index', @response.body
    assert_equal '/admin/posts/3..5', admin_posts_path(ids: '3..5')

    post '/admin/posts'
    assert_equal 'admin/posts#create', @response.body

    patch '/admin/posts/3..5'
    assert_equal 'admin/posts#update_many', @response.body

    put '/admin/posts/3..5'
    assert_equal 'admin/posts#replace', @response.body

    delete '/admin/posts/3..5'
    assert_equal 'admin/posts#destroy_many', @response.body

    get '/admin/posts/3..5/edit'
    assert_equal 'admin/posts#edit_many', @response.body
    assert_equal '/admin/posts/3..5/edit', edit_admin_posts_path(ids: '3..5')
  end

  test 'scoped collection resource' do
    draw do
      scope '/admin' do
        resources :posts, collection: true
      end
    end

    get '/admin/posts/3..5'
    assert_equal 'posts#index', @response.body
    assert_equal '/admin/posts/3..5', posts_path(ids: '3..5')

    post '/admin/posts'
    assert_equal 'posts#create', @response.body

    patch '/admin/posts/3..5'
    assert_equal 'posts#update_many', @response.body

    put '/admin/posts/3..5'
    assert_equal 'posts#replace', @response.body

    delete '/admin/posts/3..5'
    assert_equal 'posts#destroy_many', @response.body

    get '/admin/posts/3..5/edit'
    assert_equal 'posts#edit_many', @response.body
    assert_equal '/admin/posts/3..5/edit', edit_posts_path(ids: '3..5')
  end

  test 'shallow collection routes' do
    draw do
      shallow do
        resources :posts do
          resources :comments, collection: true
        end
      end
    end

    get '/posts/1/comments'
    assert_equal 'comments#index', @response.body
    assert_equal '/posts/1/comments', post_comments_path(post_id: '1')

    get '/posts/1/comments/4'
    assert_equal 'comments#index', @response.body
    assert_equal '/posts/1/comments/4..5,7', post_comments_path(post_id: '1', ids: '4..5,7')

    post '/posts/1/comments'
    assert_equal 'comments#create', @response.body

    patch '/posts/1/comments/4'
    assert_equal 'comments#update_many', @response.body

    put '/posts/1/comments/4'
    assert_equal 'comments#replace', @response.body

    delete '/posts/1/comments/4'
    assert_equal 'comments#destroy_many', @response.body

    get '/posts/1/comments/15/edit'
    assert_equal 'comments#edit_many', @response.body
    assert_equal '/posts/1/comments/15/edit', edit_post_comments_path(post_id: '1', ids: '15')


    get '/comments/4'
    assert_equal 'comments#show', @response.body

    patch '/comments/4'
    assert_equal 'comments#update', @response.body

    put '/comments/4'
    assert_equal 'comments#update', @response.body

    delete '/comments/4'
    assert_equal 'comments#destroy', @response.body

    get '/comments/15/edit'
    assert_equal 'comments#edit', @response.body
    assert_equal '/comments/15/edit', edit_comment_path(id: '15')
  end

  test 'custom collection parameter' do
    draw do
      resources :posts, collection: true, :collection_param: :ujjwal
    end

    get '/posts'
    assert_equal 'posts#index', @response.body
    assert_equal '/posts', posts_path

    get '/posts/1..10,15'
    assert_equal 'posts#index', @response.body
    assert_equal '/posts/1..10,15', posts_path(ujjwal: '1..10,15')

    get '/posts/1..10,15/edit'
    assert_equal 'posts#edit_many', @response.body
    assert_equal '/posts/1..10,15/edit', edit_posts_path(ujjwal: '1..10,15')
  end

  private

    def draw(&block)
      self.class.stub_controllers do |routes|
        @app = routes
        @app.default_url_options = { host: 'www.example.com' }
        @app.draw(&block)
      end
    end

    def url_for(options = {})
      @app.url_helpers.url_for(options)
    end

    def method_missing(method, *args, &block)
      if method.to_s =~ /_(path|url)$/
        @app.url_helpers.send(method, *args, &block)
      else
        super
      end
    end

end
