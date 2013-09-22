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
    assert_equal '/posts/1..10,15', posts_path(ids: "1..10,15")

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
    assert_equal '/posts/1..10,15/edit', edit_posts_path(ids: "1..10,15")


    get '/blogs'
    assert_equal 'blogs#index', @response.body
    assert_equal '/blogs', blogs_path

    get '/blogs/1..10,15'
    assert_equal 'blogs#index', @response.body
    assert_equal '/blogs/1..10,15', blogs_path(ids: "1..10,15")

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
    assert_equal '/blogs/1..10,15/edit', edit_blogs_path(ids: "1..10,15")
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
