require 'cases/helper'
require 'models/contact'
require 'validators/namespace/email_validator'

class EmailValidatorTest < ActiveModel::TestCase
  setup :setup_contact
  teardown :reset_callbacks

  def setup_contact
    reset_callbacks
    Contact.validates :contact, email: true
  end

  def reset_callbacks
    Contact.clear_validators!
  end

  def test_validates_compliant_email
    c = Contact.new(contact: 'rawr/foo.bar+baz_bat@example.com')
    assert c.valid?
  end

  def test_validates_noncompliant_email
    c = Contact.new(contact: 'http://foo.bar+baz_bat@example.com')
    assert c.invalid?
  end
end
