# frozen_string_literal: true

require_relative 'abstract_unit'
require 'active_support/secure_compare_rotator'

class SecureCompareRotatorTest < ActiveSupport::TestCase
  test '#secure_compare! works correctly after rotation' do
    wrapper = ActiveSupport::SecureCompareRotator.new('old_secret')
    wrapper.rotate('new_secret')

    assert_equal(true, wrapper.secure_compare!('new_secret'))
  end

  test '#secure_compare! works correctly after multiple rotation' do
    wrapper = ActiveSupport::SecureCompareRotator.new('old_secret')
    wrapper.rotate('new_secret')
    wrapper.rotate('another_secret')
    wrapper.rotate('and_another_one')

    assert_equal(true, wrapper.secure_compare!('and_another_one'))
  end

  test '#secure_compare! fails correctly when credential is not part of the rotation' do
    wrapper = ActiveSupport::SecureCompareRotator.new('old_secret')
    wrapper.rotate('new_secret')

    assert_raises(ActiveSupport::SecureCompareRotator::InvalidMatch) do
      wrapper.secure_compare!('different_secret')
    end
  end

  test '#secure_compare! calls the on_rotation proc' do
    wrapper = ActiveSupport::SecureCompareRotator.new('old_secret')
    wrapper.rotate('new_secret')
    wrapper.rotate('another_secret')
    wrapper.rotate('and_another_one')

    @witness = nil

    assert_changes(:@witness, from: nil, to: true) do
      assert_equal(true, wrapper.secure_compare!('and_another_one', on_rotation: -> { @witness = true }))
    end
  end

  test '#secure_compare! calls the on_rotation proc that given in constructor' do
    @witness = nil

    wrapper = ActiveSupport::SecureCompareRotator.new('old_secret', on_rotation: -> { @witness = true })
    wrapper.rotate('new_secret')
    wrapper.rotate('another_secret')
    wrapper.rotate('and_another_one')

    assert_changes(:@witness, from: nil, to: true) do
      assert_equal(true, wrapper.secure_compare!('and_another_one'))
    end
  end
end
