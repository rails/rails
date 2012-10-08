require 'generators/generators_test_helper'
require 'rails/generators/mailer/mailer_generator'


class MailerGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(notifier foo bar)

  def test_mailer_skeleton_is_created
    run_generator
    assert_file "app/mailers/notifier.rb" do |mailer|
      assert_match(/class Notifier < ActionMailer::Base/, mailer)
      assert_match(/default from: "from@example.com"/, mailer)
    end
  end

  def test_mailer_with_i18n_helper
    run_generator
    assert_file "app/mailers/notifier.rb" do |mailer|
      assert_match(/en\.notifier\.foo\.subject/, mailer)
      assert_match(/en\.notifier\.bar\.subject/, mailer)
    end
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match(/The name 'Object' is either already used in your application or reserved/, content)
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/mailers/notifier_test.rb" do |test|
      assert_match(/class NotifierTest < ActionMailer::TestCase/, test)
      assert_match(/test "foo"/, test)
      assert_match(/test "bar"/, test)
    end
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/notifier/foo.text.erb" do |view|
      assert_match(%r(app/views/notifier/foo\.text\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end

    assert_file "app/views/notifier/bar.text.erb" do |view|
      assert_match(%r(app/views/notifier/bar\.text\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end
  end

  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["notifier"]
    assert_file "app/views/notifier"
  end

  def test_logs_if_the_template_engine_cannot_be_found
    content = run_generator ["notifier", "foo", "bar", "--template-engine=haml"]
    assert_match(/haml \[not found\]/, content)
  end

  def test_mailer_with_namedspaced_mailer
    run_generator ["Farm::Animal", "moos"]
    assert_file "app/mailers/farm/animal.rb" do |mailer|
      assert_match(/class Farm::Animal < ActionMailer::Base/, mailer)
      assert_match(/en\.farm\.animal\.moos\.subject/, mailer)
    end
    assert_file "app/views/farm/animal/moos.text.erb"
  end

  def test_actions_are_turned_into_methods
    run_generator

    assert_file "app/mailers/notifier.rb" do |mailer|
      assert_instance_method :foo, mailer do |foo|
        assert_match(/mail to: "to@example.org"/, foo)
        assert_match(/@greeting = "Hi"/, foo)
      end

      assert_instance_method :bar, mailer do |bar|
        assert_match(/mail to: "to@example.org"/, bar)
        assert_match(/@greeting = "Hi"/, bar)
      end
    end
  end
end
