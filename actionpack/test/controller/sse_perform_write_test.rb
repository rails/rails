# frozen_string_literal: true

require "abstract_unit"

module ActionController
  # Unit tests for ActionController::Live::SSE focusing on underlying write semantics.
  # These tests ensure that each call to SSE#write results in exactly one call to the
  # underlying stream#write, even when multiple options (event, retry, id) are supplied
  # and when multiline data requires transformation.
  class SSEPerformWriteTest < ActiveSupport::TestCase
    class FakeStream
      attr_reader :writes

      def initialize
        @writes = []
      end

      def write(chunk)
        @writes << chunk
      end

      def close; end
    end

    def test_single_underlying_write_with_options_and_object_payload
      stream = FakeStream.new
      sse = Live::SSE.new(stream, event: "base", retry: 100)

      sse.write({ name: "John" }, id: 123, event: "override", retry: 500)

      assert_equal 1, stream.writes.size, "Expected exactly one underlying write call"
      payload = stream.writes.first

      assert_match(/event: override/, payload)
      assert_match(/retry: 500/, payload)
      assert_match(/id: 123/, payload)
      assert_match(/data: {"name":"John"}/, payload)
      assert_match(/\n\n\z/, payload, "Payload should terminate with a blank line per SSE spec")
    end

    def test_single_underlying_write_with_preencoded_string
      stream = FakeStream.new
      sse = Live::SSE.new(stream)

      sse.write("{\"a\":1}")

      assert_equal 1, stream.writes.size
      assert_match(/data: {"a":1}/, stream.writes.first)
    end

    def test_single_underlying_write_with_multiline_string
      stream = FakeStream.new
      sse = Live::SSE.new(stream)

      sse.write("line1\nline2", event: "multi")

      assert_equal 1, stream.writes.size
      payload = stream.writes.first
      # Each newline becomes a new data: line (after the first) but still one underlying write
      assert_match(/event: multi/, payload)
      assert_match(/data: line1/, payload)
      assert_match(/data: line2/, payload)
    end

    def test_number_of_underlying_writes_matches_number_of_sse_writes
      stream = FakeStream.new
      sse = Live::SSE.new(stream)

      sse.write(a: 1)
      sse.write(b: 2, id: 10)
      sse.write({ c: 3 }, event: "evt", retry: 2500)

      assert_equal 3, stream.writes.size, "Each SSE#write should map to exactly one stream.write"
    end
  end
end
