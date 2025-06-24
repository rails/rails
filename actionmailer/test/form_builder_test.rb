# frozen_string_literal: true

require "abstract_unit"
require "mailers/form_builder_mailer"

class MailerFormBuilderTest < ActiveSupport::TestCase
  def test_default_form_builder_assigned
    email = FormBuilderMailer.welcome
    assert_includes(email.body.encoded, "hi from SpecializedFormBuilder")
  end
end
