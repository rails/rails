# frozen_string_literal: true

require_relative '../../abstract_unit'
require 'active_support/core_ext/hash/indifferent_access'

class TransformValuesDeprecatedRequireTest < ActiveSupport::TestCase
  test 'requiring transform_values is deprecated' do
    assert_deprecated do
      require 'active_support/core_ext/hash/transform_values'
    end
  end
end

class IndifferentTransformValuesTest < ActiveSupport::TestCase
  test 'indifferent access is still indifferent after mapping values' do
    original = { a: 'a', b: 'b' }.with_indifferent_access
    mapped = original.transform_values { |v| v + '!' }

    assert_equal 'a!', mapped[:a]
    assert_equal 'a!', mapped['a']
  end
end
