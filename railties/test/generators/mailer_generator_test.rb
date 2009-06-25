require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/erb/mailer/mailer_generator'
require 'generators/rails/mailer/mailer_generator'
require 'generators/test_unit/mailer/mailer_generator'

class MailerGeneratorTest < GeneratorsTestCase

  def test_mailer_skeleton_is_created
    run_generator
    assert_file "app/models/notifier.rb", /class Notifier < ActionMailer::Base/
  end

  def test_check_class_collision
    content = capture(:stderr){ run_generator ["object"] }
    assert_match /The name 'Object' is either already used in your application or reserved/, content
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/unit/notifier_test.rb"
    assert_file "test/fixtures/notifier/foo"
    assert_file "test/fixtures/notifier/bar"
  end

  def test_invokes_default_template_engine
    run_generator
    assert_file "app/views/notifier/foo.erb"
    assert_file "app/views/notifier/bar.erb"
  end

  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["notifier"]
    assert_file "app/views/notifier"
  end

  def test_logs_if_the_template_engine_cannot_be_found
    content = run_generator ["notifier", "foo", "bar", "--template-engine=unknown"]
    assert_match /Could not find and invoke 'unknown:generators:mailer'/, content
  end

  def test_actions_are_turned_into_methods
    run_generator
    assert_file "app/models/notifier.rb", /def foo/
    assert_file "app/models/notifier.rb", /def bar/
  end

  protected

    def run_generator(args=["notifier", "foo", "bar"])
      silence(:stdout) { Rails::Generators::MailerGenerator.start args, :root => destination_root }
    end

end
