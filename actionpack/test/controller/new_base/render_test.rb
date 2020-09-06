# frozen_string_literal: true

require 'abstract_unit'

module Render
  class BlankRenderController < ActionController::Base
    self.view_paths = [ActionView::FixtureResolver.new(
      'render/blank_render/index.html.erb'                  => 'Hello world!',
      'render/blank_render/access_request.html.erb'         => 'The request: <%= request.method.to_s.upcase %>',
      'render/blank_render/access_action_name.html.erb'     => 'Action Name: <%= action_name %>',
      'render/blank_render/access_controller_name.html.erb' => 'Controller Name: <%= controller_name %>',
      'render/blank_render/overridden_with_own_view_paths_appended.html.erb'  => 'parent content',
      'render/blank_render/overridden_with_own_view_paths_prepended.html.erb' => 'parent content',
      'render/blank_render/overridden.html.erb'             => 'parent content',
      'render/child_render/overridden.html.erb'             => 'child content'
    )]

    def index
      render
    end

    def access_request
      render action: 'access_request'
    end

    def render_action_name
      render action: 'access_action_name'
    end

    def overridden_with_own_view_paths_appended
    end

    def overridden_with_own_view_paths_prepended
    end

    def overridden
    end

    private
      def secretz
        render plain: 'FAIL WHALE!'
      end
  end

  class DoubleRenderController < ActionController::Base
    def index
      render plain: 'hello'
      render plain: 'world'
    end
  end

  class ChildRenderController < BlankRenderController
    append_view_path ActionView::FixtureResolver.new('render/child_render/overridden_with_own_view_paths_appended.html.erb' => 'child content')
    prepend_view_path ActionView::FixtureResolver.new('render/child_render/overridden_with_own_view_paths_prepended.html.erb' => 'child content')
  end

  class RenderTest < Rack::TestCase
    test 'render with blank' do
      with_routing do |set|
        set.draw do
          ActiveSupport::Deprecation.silence do
            get ':controller', action: 'index'
          end
        end

        get '/render/blank_render'

        assert_body 'Hello world!'
        assert_status 200
      end
    end

    test 'rendering more than once raises an exception' do
      with_routing do |set|
        set.draw do
          ActiveSupport::Deprecation.silence do
            get ':controller', action: 'index'
          end
        end

        assert_raises(AbstractController::DoubleRenderError) do
          get '/render/double_render', headers: { 'action_dispatch.show_exceptions' => false }
        end
      end
    end
  end

  class TestOnlyRenderPublicActions < Rack::TestCase
    # Only public methods on actual controllers are callable actions
    test 'raises an exception when a method of Object is called' do
      assert_raises(AbstractController::ActionNotFound) do
        get '/render/blank_render/clone', headers: { 'action_dispatch.show_exceptions' => false }
      end
    end

    test 'raises an exception when a private method is called' do
      assert_raises(AbstractController::ActionNotFound) do
        get '/render/blank_render/secretz', headers: { 'action_dispatch.show_exceptions' => false }
      end
    end
  end

  class TestVariousObjectsAvailableInView < Rack::TestCase
    test 'The request object is accessible in the view' do
      get '/render/blank_render/access_request'
      assert_body 'The request: GET'
    end

    test 'The action_name is accessible in the view' do
      get '/render/blank_render/render_action_name'
      assert_body 'Action Name: render_action_name'
    end

    test 'The controller_name is accessible in the view' do
      get '/render/blank_render/access_controller_name'
      assert_body 'Controller Name: blank_render'
    end
  end

  class TestViewInheritance < Rack::TestCase
    test 'Template from child controller gets picked over parent one' do
      get '/render/child_render/overridden'
      assert_body 'child content'
    end

    test 'Template from child controller with custom view_paths prepended gets picked over parent one' do
      get '/render/child_render/overridden_with_own_view_paths_prepended'
      assert_body 'child content'
    end

    test 'Template from child controller with custom view_paths appended gets picked over parent one' do
      get '/render/child_render/overridden_with_own_view_paths_appended'
      assert_body 'child content'
    end

    test 'Template from parent controller gets picked if missing in child controller' do
      get '/render/child_render/index'
      assert_body 'Hello world!'
    end
  end
end
