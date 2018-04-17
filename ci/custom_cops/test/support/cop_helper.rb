# frozen_string_literal: true

require "rubocop"

module CopHelper
  def inspect_source(cop, source)
    processed_source = parse_source(source)
    raise "Error parsing example code" unless processed_source.valid_syntax?
    investigate(cop, processed_source)
    processed_source
  end

  def autocorrect_source(cop, source)
    cop.instance_variable_get(:@options)[:auto_correct] = true
    processed_source = inspect_source(cop, source)
    rewrite(cop, processed_source)
  end

  def assert_offense(cop, expected_message)
    assert_not_empty(
      cop.offenses,
      "Expected offense with message \"#{expected_message}\", but got no offense"
    )

    offense = cop.offenses.first
    carets = "^" * offense.column_length

    assert_equal expected_message, "#{carets} #{offense.message}"
  end

  private
    TARGET_RUBY_VERSION = 2.4

    def parse_source(source)
      RuboCop::ProcessedSource.new(source, TARGET_RUBY_VERSION)
    end

    def rewrite(cop, processed_source)
      RuboCop::Cop::Corrector.new(processed_source.buffer, cop.corrections)
        .rewrite
    end

    def investigate(cop, processed_source)
      RuboCop::Cop::Commissioner.new([cop], [], raise_error: true)
        .investigate(processed_source)
    end
end
