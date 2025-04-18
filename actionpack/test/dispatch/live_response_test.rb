# frozen_string_literal: true

require "abstract_unit"
require "concurrent/atomic/count_down_latch"

module ActionController
  module Live
    class ResponseTest < ActiveSupport::TestCase
      def setup
        @response = Live::Response.new
        @response.request = ActionDispatch::Request.empty
      end

      def test_header_merge
        headers = @response.headers.merge("Foo" => "Bar")
        assert_kind_of(ActionController::Live::Response::Headers, headers)
        assert_not_equal headers, @response.headers
      end

      def test_initialize_with_default_headers
        r = Class.new(Live::Response) do
          def self.default_headers
            { "omg" => "g" }
          end
        end

        headers = r.create.headers
        assert_kind_of(ActionController::Live::Response::Headers, headers)
        assert_equal "g", headers["omg"]
      end

      def test_parallel
        latch = Concurrent::CountDownLatch.new

        t = Thread.new {
          @response.stream.write "foo"
          latch.wait
          @response.stream.close
        }

        @response.await_commit
        @response.each do |part|
          assert_equal "foo", part
          latch.count_down
        end
        assert t.join
      end

      def test_setting_body_populates_buffer
        @response.body = "omg"
        @response.close
        assert_equal ["omg"], @response.body_parts
      end

      def test_cache_control_is_set_by_default
        @response.stream.write "omg"
        assert_equal "no-cache", @response.headers["Cache-Control"]
      end

      def test_cache_control_is_set_manually
        @response.set_header("Cache-Control", "public")
        @response.stream.write "omg"
        assert_equal "public", @response.headers["Cache-Control"]
      end

      def test_cache_control_no_store_default_standalone
        @response.set_header("Cache-Control", "no-store")
        @response.stream.write "omg"
        assert_equal "no-store", @response.headers["Cache-Control"]
      end

      def test_cache_control_no_store_is_respected
        @response.set_header("Cache-Control", "public, no-store")
        @response.stream.write "omg"
        assert_equal "no-store", @response.headers["Cache-Control"]
      end

      def test_cache_control_no_store_private
        @response.set_header("Cache-Control", "private, no-store")
        @response.stream.write "omg"
        assert_equal "private, no-store", @response.headers["Cache-Control"]
      end

      def test_content_length_is_removed
        @response.headers["Content-Length"] = "1234"
        @response.stream.write "omg"
        assert_nil @response.headers["Content-Length"]
      end
    end
  end
end
