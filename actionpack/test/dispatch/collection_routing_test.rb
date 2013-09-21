require 'abstract_unit'

class TestCollectionRouting < ActionDispatch::IntegrationTest
  test 'collection option' do
    draw do
      resources :posts, collection: true
    end

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