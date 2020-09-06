# frozen_string_literal: true

require 'cases/helper'

require 'models/topic'
require 'models/reply'
require 'models/person'

class AcceptanceValidationTest < ActiveModel::TestCase
  teardown do
    self.class.send(:remove_const, :TestClass)
  end

  def test_terms_of_service_agreement_no_acceptance
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)

    t = klass.new('title' => 'We should not be confirmed')
    assert_predicate t, :valid?
  end

  def test_terms_of_service_agreement
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)

    t = klass.new('title' => 'We should be confirmed', 'terms_of_service' => '')
    assert_predicate t, :invalid?
    assert_equal ['must be accepted'], t.errors[:terms_of_service]

    t.terms_of_service = '1'
    assert_predicate t, :valid?
  end

  def test_eula
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:eula, message: 'must be abided')

    t = klass.new('title' => 'We should be confirmed', 'eula' => '')
    assert_predicate t, :invalid?
    assert_equal ['must be abided'], t.errors[:eula]

    t.eula = '1'
    assert_predicate t, :valid?
  end

  def test_terms_of_service_agreement_with_accept_value
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service, accept: 'I agree.')

    t = klass.new('title' => 'We should be confirmed', 'terms_of_service' => '')
    assert_predicate t, :invalid?
    assert_equal ['must be accepted'], t.errors[:terms_of_service]

    t.terms_of_service = 'I agree.'
    assert_predicate t, :valid?
  end

  def test_terms_of_service_agreement_with_multiple_accept_values
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service, accept: [1, 'I concur.'])

    t = klass.new('title' => 'We should be confirmed', 'terms_of_service' => '')
    assert_predicate t, :invalid?
    assert_equal ['must be accepted'], t.errors[:terms_of_service]

    t.terms_of_service = 1
    assert_predicate t, :valid?

    t.terms_of_service = 'I concur.'
    assert_predicate t, :valid?
  end

  def test_validates_acceptance_of_for_ruby_class
    klass = define_test_class(Person)
    klass.validates_acceptance_of :karma

    p = klass.new
    p.karma = ''

    assert_predicate p, :invalid?
    assert_equal ['must be accepted'], p.errors[:karma]

    p.karma = '1'
    assert_predicate p, :valid?
  end

  def test_validates_acceptance_of_true
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)

    assert_predicate klass.new(terms_of_service: true), :valid?
  end

  def test_lazy_attribute_module_included_only_once
    klass = define_test_class(Topic)
    assert_difference -> { klass.ancestors.count }, 2 do
      2.times do
        klass.validates_acceptance_of(:something_to_accept)
        assert klass.new.respond_to?(:something_to_accept)
      end
      2.times do
        klass.validates_acceptance_of(:something_else_to_accept)
        assert klass.new.respond_to?(:something_else_to_accept)
      end
    end
  end

  def test_lazy_attributes_module_included_again_if_needed
    klass = define_test_class(Topic)
    assert_difference -> { klass.ancestors.count }, 1 do
      klass.validates_acceptance_of(:something_to_accept)
    end
    topic = klass.new
    topic.something_to_accept
    assert_difference -> { klass.ancestors.count }, 1 do
      klass.validates_acceptance_of(:something_else_to_accept)
    end
    assert topic.respond_to?(:something_else_to_accept)
  end

  def test_lazy_attributes_respond_to?
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)
    topic = klass.new
    threads = []
    2.times do
      threads << Thread.new do
        assert topic.respond_to?(:terms_of_service)
      end
    end
    threads.each(&:join)
  end

  private
    def define_test_class(parent)
      self.class.const_set(:TestClass, Class.new(parent))
    end
end
