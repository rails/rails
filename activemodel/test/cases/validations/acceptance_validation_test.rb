# encoding: utf-8
require 'cases/helper'
require 'cases/tests_database'

require 'models/topic'
require 'models/reply'
require 'models/developer'

class AcceptanceValidationTest < ActiveModel::TestCase
  include ActiveModel::TestsDatabase
  include ActiveModel::ValidationsRepairHelper

  repair_validations(Topic)

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

  def test_validates_acceptance_of_as_database_column
    repair_validations(Reply) do
      Reply.validates_acceptance_of(:author_name)

      reply = Reply.create("author_name" => "Dan Brown")
      assert_equal "Dan Brown", reply["author_name"]
    end
  end

  def test_validates_acceptance_of_with_custom_error_using_quotes
    repair_validations(Developer) do
      Developer.validates_acceptance_of :salary, :message=> "This string contains 'single' and \"double\" quotes"
      d = Developer.new
      d.salary = "0"
      assert !d.valid?
      assert_equal "This string contains 'single' and \"double\" quotes", d.errors[:salary].last
    end
  end
end
