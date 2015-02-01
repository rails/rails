require 'abstract_unit'

class RendererTest < ActiveSupport::TestCase
  test 'creating with a controller' do
    controller = CommentsController
    renderer   = ActionController::Renderer.for controller

    assert_equal controller, renderer.controller
  end

  test 'creating from a controller' do
    controller = AccountsController
    renderer   = controller.renderer

    assert_equal controller, renderer.controller
  end

  test 'rendering with a class renderer' do
    renderer = ApplicationController.renderer
    content  = renderer.render template: 'ruby_template'

    assert_equal 'Hello from Ruby code', content
  end

  test 'rendering with an instance renderer' do
    renderer = ApplicationController.renderer.new
    content  = renderer.render file: 'test/hello_world'

    assert_equal 'Hello world!', content
  end

  test 'rendering with a controller class' do
    assert_equal 'Hello world!', ApplicationController.render('test/hello_world')
  end

  test 'rendering with locals' do
    renderer = ApplicationController.renderer
    content  = renderer.render template: 'test/render_file_with_locals',
                               locals: { secret: 'bar' }

    assert_equal "The secret is bar\n", content
  end

  test 'rendering with assigns' do
    renderer = ApplicationController.renderer
    content  = renderer.render template: 'test/render_file_with_ivar',
                               assigns: { secret: 'foo' }

    assert_equal "The secret is foo\n", content
  end

  test 'rendering with custom env' do
    renderer = ApplicationController.renderer.new method: 'post'
    content  = renderer.render inline: '<%= request.post? %>'

    assert_equal 'true', content
  end

  test 'rendering with defaults' do
    renderer = ApplicationController.renderer
    renderer.defaults[:https] = true
    content = renderer.render inline: '<%= request.ssl? %>'

    assert_equal 'true', content
  end

  test 'same defaults from the same controller' do
    renderer_defaults = ->(controller) { controller.renderer.defaults }

    assert renderer_defaults[AccountsController].equal? renderer_defaults[AccountsController]
    assert_not renderer_defaults[AccountsController].equal? renderer_defaults[CommentsController]
  end

  test 'rendering with different formats' do
    html = 'Hello world!'
    xml  = "<p>Hello world!</p>\n"

    assert_equal html, render['respond_to/using_defaults']
    assert_equal xml,  render['respond_to/using_defaults.xml.builder']
    assert_equal xml,  render['respond_to/using_defaults', formats: :xml]
  end

  test 'rendering with helpers' do
    assert_equal "<p>1\n<br />2</p>", render[inline: '<%= simple_format "1\n2" %>']
  end
  
  test 'rendering from inherited renderer' do
    inherited = Class.new ApplicationController.renderer do
      defaults[:script_name] = 'script'
      def render(options)
        super options.merge(locals: { param: :value })
      end
    end

    template = '<%= url_for controller: :foo, action: :bar, param: param %>'
    assert_equal 'script/foo/bar?param=value', inherited.render(inline: template)
  end

  private
    def render
      @render ||= ApplicationController.renderer.method(:render)
    end
end
