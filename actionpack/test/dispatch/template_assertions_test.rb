require 'abstract_unit'

class AssertTemplateController < ActionController::Base
  def render_with_partial
    render partial: 'test/partial'
  end

  def render_with_template
    render 'test/hello_world'
  end

  def render_with_layout
    @variable_for_layout = nil
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
  def test_assert_template_reset_between_requests
    get '/assert_template/render_with_template'
    assert_template 'test/hello_world'

    get '/assert_template/render_nothing'
    assert_template nil
  end

  def test_assert_partial_reset_between_requests
    get '/assert_template/render_with_partial'
    assert_template partial: 'test/_partial'

    get '/assert_template/render_nothing'
    assert_template partial: nil
  end

  def test_assert_layout_reset_between_requests
    get '/assert_template/render_with_layout'
    assert_template layout: 'layouts/standard'

    get '/assert_template/render_nothing'
    assert_template layout: nil
  end

  def test_assert_file_reset_between_requests
    get '/assert_template/render_with_file'
    assert_template file: 'README.rdoc'

    get '/assert_template/render_nothing'
    assert_template file: nil
  end
end
