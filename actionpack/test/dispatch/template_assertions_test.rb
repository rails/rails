require 'abstract_unit'

class AssertTemplateController < ActionController::Base
  def render_with_partial
    render partial: 'test/partial'
  end

  def render_with_template
    render 'test/hello_world'
  end

  def render_with_layout
    @variable_for_layout = 'hello'
    render 'test/hello_world', layout: "layouts/standard"
  end

  def render_with_file
    render file: 'README.rdoc'
  end

  def render_nothing
    head :ok
  end
end

class AssertTemplateControllerTest < ActionDispatch::IntegrationTest
  def test_template_reset_between_requests
    get '/assert_template/render_with_template'
    assert_template 'test/hello_world'

    get '/assert_template/render_nothing'
    assert_template nil
  end

  def test_partial_reset_between_requests
    get '/assert_template/render_with_partial'
    assert_template partial: 'test/_partial'

    get '/assert_template/render_nothing'
    assert_template partial: nil
  end

  def test_layout_reset_between_requests
    get '/assert_template/render_with_layout'
    assert_template layout: 'layouts/standard'

    get '/assert_template/render_nothing'
    assert_template layout: nil
  end

  def test_file_reset_between_requests
    get '/assert_template/render_with_file'
    assert_template file: 'README.rdoc'

    get '/assert_template/render_nothing'
    assert_template file: nil
  end

  def test_template_reset_between_requests_when_opening_a_session
    open_session do |session|
      session.get '/assert_template/render_with_template'
      session.assert_template 'test/hello_world'

      session.get '/assert_template/render_nothing'
      session.assert_template nil
    end
  end

  def test_partial_reset_between_requests_when_opening_a_session
    open_session do |session|
      session.get '/assert_template/render_with_partial'
      session.assert_template partial: 'test/_partial'

      session.get '/assert_template/render_nothing'
      session.assert_template partial: nil
    end
  end

  def test_layout_reset_between_requests_when_opening_a_session
    open_session do |session|
      session.get '/assert_template/render_with_layout'
      session.assert_template layout: 'layouts/standard'

      session.get '/assert_template/render_nothing'
      session.assert_template layout: nil
    end
  end

  def test_file_reset_between_requests_when_opening_a_session
    open_session do |session|
      session.get '/assert_template/render_with_file'
      session.assert_template file: 'README.rdoc'

      session.get '/assert_template/render_nothing'
      session.assert_template file: nil
    end
  end

  def test_assigns_do_not_reset_template_assertion
    get '/assert_template/render_with_layout'
    assert_equal 'hello', assigns(:variable_for_layout)
    assert_template layout: 'layouts/standard'
  end

  def test_cookies_do_not_reset_template_assertion
    get '/assert_template/render_with_layout'
    cookies
    assert_template layout: 'layouts/standard'
  end
end
