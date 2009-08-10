require 'abstract_unit'

class BodyPartsTest < ActionController::TestCase
  RENDERINGS = [Object.new, Object.new, Object.new]

  class TestController < ActionController::Base
    def response_body() "" end

    def index
      RENDERINGS.each do |rendering|
        @template.punctuate_body! rendering
      end
      @performed_render = true
    end
  end

  tests TestController

  def test_body_parts
    get :index
    # TestProcess buffers body_parts into body
    # TODO: Rewrite test w/o going through process
    assert_equal RENDERINGS, @response.body_parts
    assert_equal RENDERINGS.join, @response.body
  end
end
