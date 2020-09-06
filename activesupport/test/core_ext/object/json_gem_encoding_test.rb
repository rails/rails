# frozen_string_literal: true

require_relative '../../abstract_unit'
require 'json'
require_relative '../../json/encoding_test_cases'

# These test cases were added to test that we do not interfere with json gem's
# output when the AS encoder is loaded, primarily for problems reported in
# #20775. They need to be executed in isolation to reproduce the scenario
# correctly, because other test cases might have already loaded additional
# dependencies.

# The AS::JSON encoder requires the BigDecimal core_ext, which, unfortunately,
# changes the BigDecimal#to_s output, and consequently the JSON gem output. So
# we need to require this upfront to ensure we don't get a false failure, but
# ideally we should just fix the BigDecimal core_ext to not change to_s without
# arguments.
require 'active_support/core_ext/big_decimal'

class JsonGemEncodingTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  JSONTest::EncodingTestCases.constants.each_with_index do |name|
    JSONTest::EncodingTestCases.const_get(name).each_with_index do |(subject, _), i|
      test("#{name[0..-6]} #{i}") do
        assert_same_with_or_without_active_support(subject)
      end
    end
  end

  class CustomToJson
    def to_json(*)
      '"custom"'
    end
  end

  test 'custom to_json' do
    assert_same_with_or_without_active_support(CustomToJson.new)
  end

  private
    def require_or_skip(file)
      require(file) || skip("'#{file}' was already loaded")
    end

    def assert_same_with_or_without_active_support(subject)
      begin
        expected = JSON.generate(subject, quirks_mode: true)
      rescue JSON::GeneratorError => e
        exception = e
      end

      require_or_skip 'active_support/core_ext/object/json'

      if exception
        assert_raises_with_message JSON::GeneratorError, e.message do
          JSON.generate(subject, quirks_mode: true)
        end
      else
        assert_equal expected, JSON.generate(subject, quirks_mode: true)
      end
    end

    def assert_raises_with_message(exception_class, message, &block)
      err = assert_raises(exception_class) { block.call }
      assert_match message, err.message
    end
end
