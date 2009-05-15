require 'abstract_unit'

class OutputBufferTest < ActionController::TestCase
  class TestController < ActionController::Base
    def index
      render :text => 'foo'
    end
  end

  tests TestController

  def test_flush_output_buffer
    pending
      # TODO: This tests needs to be rewritten due
      # The @response is not the same response object assigned
      # to the @controller.template

      # Start with the default body parts
      # ---
      # get :index
      #       assert_equal ['foo'], @response.body_parts
      #       assert_nil @controller.template.output_buffer
      #
      #       # Nil output buffer is skipped
      #       @controller.template.flush_output_buffer
      #       assert_nil @controller.template.output_buffer
      #       assert_equal ['foo'], @response.body_parts
      #
      #       # Empty output buffer is skipped
      #       @controller.template.output_buffer = ''
      #       @controller.template.flush_output_buffer
      #       assert_equal '', @controller.template.output_buffer
      #       assert_equal ['foo'], @response.body_parts
      #
      #       # Flushing appends the output buffer to the body parts
      #       @controller.template.output_buffer = 'bar'
      #       @controller.template.flush_output_buffer
      #       assert_equal '', @controller.template.output_buffer
      #       assert_equal ['foo', 'bar'], @response.body_parts
  end
end
