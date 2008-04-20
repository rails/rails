require 'generators/generator_test_helper'

class RailsMailerGeneratorTest < GeneratorTestCase

  def test_generates_mailer
    run_generator('mailer', %w(Notifier reset_password))

    assert_generated_model_for :notifier, 'ActionMailer::Base' do |model|
      assert_has_method model, :reset_password do |name, body|
        assert_equal [
            "subject    'Notifier#reset_password'",
            "recipients ''",
            "from       ''",
            "sent_on    sent_at",
            "",
            "body       :greeting => 'Hi,'"
          ],
          body.split("\n").map{|line| line.sub(' '*4, '') }
      end

      assert_match /^  default_url_options\[:host\] = 'example.com'$/m, model,
        'model should include default_url_options :host declaration'
    end
    
    assert_generated_views_for :notifier, 'reset_password.erb'
    assert_generated_unit_test_for :notifier, 'ActionMailer::TestCase'
    assert_generated_file "test/fixtures/notifier/reset_password"
  end
end
