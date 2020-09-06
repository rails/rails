# frozen_string_literal: true

require 'abstract_unit'

module RenderBody
  class MinimalController < ActionController::Metal
    include AbstractController::Rendering
    include ActionController::Rendering

    def index
      render body: 'Hello World!'
    end
  end

  class SimpleController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new]

    def index
      render body: 'hello david'
    end
  end

  class WithLayoutController < ::ApplicationController
    self.view_paths = [ActionView::FixtureResolver.new(
      'layouts/application.erb' => "<%= yield %>, I'm here!",
      'layouts/greetings.erb'   => '<%= yield %>, I wish thee well.',
      'layouts/ivar.erb'        => '<%= yield %>, <%= @ivar %>'
    )]

    def index
      render body: 'hello david'
    end

    def custom_code
      render body: 'hello world', status: 404
    end

    def with_custom_code_as_string
      render body: 'hello world', status: '404 Not Found'
    end

    def with_nil
      render body: nil
    end

    def with_nil_and_status
      render body: nil, status: 403
    end

    def with_false
      render body: false
    end

    def with_layout_true
      render body: 'hello world', layout: true
    end

    def with_layout_false
      render body: 'hello world', layout: false
    end

    def with_layout_nil
      render body: 'hello world', layout: nil
    end

    def with_custom_layout
      render body: 'hello world', layout: 'greetings'
    end

    def with_custom_content_type
      response.headers['Content-Type'] = 'application/json'
      render body: '["troll","face"]'
    end

    def with_ivar_in_layout
      @ivar = 'hello world'
      render body: 'hello world', layout: 'ivar'
    end
  end

  class RenderBodyTest < Rack::TestCase
    test 'rendering body from a minimal controller' do
      get '/render_body/minimal/index'
      assert_body 'Hello World!'
      assert_status 200
    end

    test 'rendering body from an action with default options renders the body with the layout' do
      with_routing do |set|
        set.draw { ActiveSupport::Deprecation.silence { get ':controller', action: 'index' } }

        get '/render_body/simple'
        assert_body 'hello david'
        assert_status 200
      end
    end

    test 'rendering body from an action with default options renders the body without the layout' do
      with_routing do |set|
        set.draw { ActiveSupport::Deprecation.silence { get ':controller', action: 'index' } }

        get '/render_body/with_layout'

        assert_body 'hello david'
        assert_status 200
      end
    end

    test 'rendering body, while also providing a custom status code' do
      get '/render_body/with_layout/custom_code'

      assert_body 'hello world'
      assert_status 404
    end

    test 'rendering body with nil returns an empty body' do
      get '/render_body/with_layout/with_nil'

      assert_body ''
      assert_status 200
    end

    test 'Rendering body with nil and custom status code returns an empty body and the status' do
      get '/render_body/with_layout/with_nil_and_status'

      assert_body ''
      assert_status 403
    end

    test "rendering body with false returns the string 'false'" do
      get '/render_body/with_layout/with_false'

      assert_body 'false'
      assert_status 200
    end

    test 'rendering body with layout: true' do
      get '/render_body/with_layout/with_layout_true'

      assert_body "hello world, I'm here!"
      assert_status 200
    end

    test "rendering body with layout: 'greetings'" do
      get '/render_body/with_layout/with_custom_layout'

      assert_body 'hello world, I wish thee well.'
      assert_status 200
    end

    test 'specified content type should not be removed' do
      get '/render_body/with_layout/with_custom_content_type'

      assert_equal %w{ troll face }, JSON.parse(response.body)
      assert_equal 'application/json', response.headers['Content-Type']
    end

    test 'rendering body with layout: false' do
      get '/render_body/with_layout/with_layout_false'

      assert_body 'hello world'
      assert_status 200
    end

    test 'rendering body with layout: nil' do
      get '/render_body/with_layout/with_layout_nil'

      assert_body 'hello world'
      assert_status 200
    end
  end
end
