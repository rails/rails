require 'abstract_unit'

class BodyPartsTest < ActionController::TestCase
  RENDERINGS = [Object.new, Object.new, Object.new]

  class TestController < ActionController::Base
    def index
      RENDERINGS.each do |rendering|
        response.template.punctuate_body! rendering
      end
      @performed_render = true
    end
  end

  tests TestController

  def test_body_parts
    get :index
    assert_equal RENDERINGS, @response.body_parts
    assert_equal RENDERINGS.join, @response.body
  end
end
