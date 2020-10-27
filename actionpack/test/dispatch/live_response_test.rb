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
        header = @response.header.merge("Foo" => "Bar")
        assert_kind_of(ActionController::Live::Response::Header, header)
        assert_not_equal header, @response.header
      end

      def test_initialize_with_default_headers
        r = Class.new(Live::Response) do
          def self.default_headers
            { "omg" => "g" }
          end
        end

        header = r.new.header
        assert_kind_of(ActionController::Live::Response::Header, header)
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

      def test_cache_control_no_store_is_respected
        @response.set_header("Cache-Control", "private, no-store")
        @response.stream.write "omg"
        assert_equal "no-store", @response.headers["Cache-Control"]
      end

      def test_cache_control_proxy_revalidate_is_respected
        @response.set_header("Cache-Control", "proxy-revalidate")
        @response.stream.write "omg"
        assert_equal "private, proxy-revalidate", @response.headers["Cache-Control"]
      end

      def test_content_length_is_removed
        @response.headers["Content-Length"] = "1234"
        @response.stream.write "omg"
        assert_nil @response.headers["Content-Length"]
      end

      def test_headers_cannot_be_written_after_web_server_reads
        @response.stream.write "omg"
        latch = Concurrent::CountDownLatch.new

        t = Thread.new {
          @response.each do
            latch.count_down
          end
        }

        latch.wait
        assert_predicate @response.headers, :frozen?
        e = assert_raises(ActionDispatch::IllegalStateError) do
          @response.headers["Content-Length"] = "zomg"
        end

        assert_equal "header already sent", e.message
        @response.stream.close
        t.join
      end

      def test_headers_cannot_be_written_after_close
        @response.stream.close
        # we can add data until it's actually written, which happens on `each`
        @response.each { |x| }

        e = assert_raises(ActionDispatch::IllegalStateError) do
          @response.headers["Content-Length"] = "zomg"
        end
        assert_equal "header already sent", e.message
      end
    end
  end
end
