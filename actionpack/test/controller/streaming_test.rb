require 'abstract_unit'

module ActionController
  class StreamingResponseTest < ActionController::TestCase
    class TestController < ActionController::Base
      def self.controller_path
        'test'
      end

      def basic_stream
        %w{ hello world }.each do |word|
          response.stream.write word
          response.stream.write "\n"
        end
        response.stream.close
      end
    end

    tests TestController

    def test_write_to_stream
      get :basic_stream
      assert_equal "hello\nworld\n", @response.body
    end
  end
end
