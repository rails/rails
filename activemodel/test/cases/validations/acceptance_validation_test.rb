# frozen_string_literal: true

require "cases/helper"

require "models/topic"
require "models/reply"
require "models/person"

class AcceptanceValidationTest < ActiveModel::TestCase
  teardown do
    self.class.send(:remove_const, :TestClass)
  end

  def test_terms_of_service_agreement_no_acceptance
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)

    t = klass.new("title" => "We should not be confirmed")
    assert_predicate t, :valid?
  end

  def test_terms_of_service_agreement
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)

    t = klass.new("title" => "We should be confirmed", "terms_of_service" => "")
    assert_predicate t, :invalid?
    assert_equal ["must be accepted"], t.errors[:terms_of_service]

    t.terms_of_service = "1"
    assert_predicate t, :valid?
  end

  def test_eula
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:eula, message: "must be abided")

    t = klass.new("title" => "We should be confirmed", "eula" => "")
    assert_predicate t, :invalid?
    assert_equal ["must be abided"], t.errors[:eula]

    t.eula = "1"
    assert_predicate t, :valid?
  end

  def test_terms_of_service_agreement_with_accept_value
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service, accept: "I agree.")

    t = klass.new("title" => "We should be confirmed", "terms_of_service" => "")
    assert_predicate t, :invalid?
    assert_equal ["must be accepted"], t.errors[:terms_of_service]

    t.terms_of_service = "I agree."
    assert_predicate t, :valid?
  end

  def test_terms_of_service_agreement_with_multiple_accept_values
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service, accept: [1, "I concur."])

    t = klass.new("title" => "We should be confirmed", "terms_of_service" => "")
    assert_predicate t, :invalid?
    assert_equal ["must be accepted"], t.errors[:terms_of_service]

    t.terms_of_service = 1
    assert_predicate t, :valid?

    t.terms_of_service = "I concur."
    assert_predicate t, :valid?
  end

  def test_validates_acceptance_of_for_ruby_class
    klass = define_test_class(Person)
    klass.validates_acceptance_of :karma

    p = klass.new
    p.karma = ""

    assert_predicate p, :invalid?
    assert_equal ["must be accepted"], p.errors[:karma]

    p.karma = "1"
    assert_predicate p, :valid?
  end

  def test_validates_acceptance_of_true
    klass = define_test_class(Topic)
    klass.validates_acceptance_of(:terms_of_service)

    assert_predicate klass.new(terms_of_service: true), :valid?
  end

  private
    # Acceptance validator includes anonymous module into class, which cannot
    # be cleared, so to avoid multiple inclusions we use a named subclass which
    # we can remove in teardown.
    def define_test_class(parent)
      self.class.const_set(:TestClass, Class.new(parent))
    end
end
