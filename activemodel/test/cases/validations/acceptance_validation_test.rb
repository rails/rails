# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/reply'
require 'models/developer'
require 'models/person'

class AcceptanceValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase

  def teardown
    Topic.reset_callbacks(:validate)
  end

  def test_terms_of_service_agreement_no_acceptance
    Topic.validates_acceptance_of(:terms_of_service, :on => :create)

    t = Topic.create("title" => "We should not be confirmed")
    assert t.save
  end

  def test_terms_of_service_agreement
    Topic.validates_acceptance_of(:terms_of_service, :on => :create)

    t = Topic.create("title" => "We should be confirmed","terms_of_service" => "")
    assert !t.save
    assert_equal ["must be accepted"], t.errors[:terms_of_service]

    t.terms_of_service = "1"
    assert t.save
  end

  def test_eula
    Topic.validates_acceptance_of(:eula, :message => "must be abided", :on => :create)

    t = Topic.create("title" => "We should be confirmed","eula" => "")
    assert !t.save
    assert_equal ["must be abided"], t.errors[:eula]

    t.eula = "1"
    assert t.save
  end

  def test_terms_of_service_agreement_with_accept_value
    Topic.validates_acceptance_of(:terms_of_service, :on => :create, :accept => "I agree.")

    t = Topic.create("title" => "We should be confirmed", "terms_of_service" => "")
    assert !t.save
    assert_equal ["must be accepted"], t.errors[:terms_of_service]

    t.terms_of_service = "I agree."
    assert t.save
  end

  def test_validates_acceptance_of_for_ruby_class
    Person.validates_acceptance_of :karma

    p = Person.new
    p.karma = ""

    assert p.invalid?
    assert_equal ["must be accepted"], p.errors[:karma]

    p.karma = "1"
    assert p.valid?
  ensure
    Person.reset_callbacks(:validate)
  end
end
