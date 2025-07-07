# frozen_string_literal: true

require "abstract_unit"

class TraceToFileExtractorTest < ActionDispatch::IntegrationTest
  test "generate link to file in editor" do
    ActionDispatch::TraceToFileExtractor.stub :editor_name, :atom do
      traces = caller_locations(0)
      assert traces.size > 0
      traces.each do |trace|
        next if trace.to_s.include?("internal:numeric")

        assert_equal "atom://core/open/file?filename=#{trace.path}&line=#{trace.lineno}", ActionDispatch::TraceToFileExtractor.call(trace)
      end
    end
  end

  test "return nil if editor is not set" do
    ActionDispatch::TraceToFileExtractor.stub :editor_name, nil do
      traces = caller_locations(0)
      assert_nil ActionDispatch::TraceToFileExtractor.call(traces.first)
    end
  end

  test "return nil when no file exists" do
    ActionDispatch::TraceToFileExtractor.stub :editor_name, :atom do
      traces = caller_locations(0)
      trace = traces.detect { |t| t.to_s.include?("internal:numeric") }
      assert_nil ActionDispatch::TraceToFileExtractor.call(trace)
    end
  end
end
