require 'abstract_unit'


class RenderOtherTest < ActionController::TestCase
  class TestController < ActionController::Base
    def render_simon_says
      render :simon => "foo"
    end
  end

  tests TestController

  def test_using_custom_render_option
    ActionController.add_renderer :simon do |says, options|
      self.content_type  = Mime::TEXT
      self.response_body = "Simon says: #{says}"
    end

    get :render_simon_says
    assert_equal "Simon says: foo", @response.body
  ensure
    ActionController.remove_renderer :simon
  end
end
