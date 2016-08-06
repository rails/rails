require "generators/generators_test_helper"
require "rails/generators/mailer/mailer_generator"

class MailerGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  arguments %w(notifier foo bar)

  def test_mailer_skeleton_is_created
    run_generator
    assert_file "app/mailers/notifier_mailer.rb" do |mailer|
      assert_match(/class NotifierMailer < ApplicationMailer/, mailer)
      assert_no_match(/default from: "from@example.com"/, mailer)
      assert_no_match(/layout :mailer_notifier/, mailer)
    end

    assert_file "app/mailers/application_mailer.rb" do |mailer|
      assert_match(/class ApplicationMailer < ActionMailer::Base/, mailer)
      assert_match(/default from: 'from@example.com'/, mailer)
      assert_match(/layout 'mailer'/, mailer)
    end
  end

  def test_mailer_with_i18n_helper
    run_generator
    assert_file "app/mailers/notifier_mailer.rb" do |mailer|
      assert_match(/en\.notifier_mailer\.foo\.subject/, mailer)
      assert_match(/en\.notifier_mailer\.bar\.subject/, mailer)
    end
  end

  def test_check_class_collision
    Object.send :const_set, :NotifierMailer, Class.new
    content = capture(:stderr){ run_generator }
    assert_match(/The name 'NotifierMailer' is either already used in your application or reserved/, content)
  ensure
    Object.send :remove_const, :NotifierMailer
  end

  def test_invokes_default_test_framework
    run_generator
    assert_file "test/mailers/notifier_mailer_test.rb" do |test|
      assert_match(/class NotifierMailerTest < ActionMailer::TestCase/, test)
      assert_match(/test "foo"/, test)
      assert_match(/test "bar"/, test)
    end
    assert_file "test/mailers/previews/notifier_mailer_preview.rb" do |preview|
      assert_match(/\# Preview all emails at http:\/\/localhost\:3000\/rails\/mailers\/notifier_mailer/, preview)
      assert_match(/class NotifierMailerPreview < ActionMailer::Preview/, preview)
      assert_match(/\# Preview this email at http:\/\/localhost\:3000\/rails\/mailers\/notifier_mailer\/foo/, preview)
      assert_instance_method :foo, preview do |foo|
        assert_match(/NotifierMailer.foo/, foo)
      end
      assert_match(/\# Preview this email at http:\/\/localhost\:3000\/rails\/mailers\/notifier_mailer\/bar/, preview)
      assert_instance_method :bar, preview do |bar|
        assert_match(/NotifierMailer.bar/, bar)
      end
    end
  end

  def test_check_test_class_collision
    Object.send :const_set, :NotifierMailerTest, Class.new
    content = capture(:stderr){ run_generator }
    assert_match(/The name 'NotifierMailerTest' is either already used in your application or reserved/, content)
  ensure
    Object.send :remove_const, :NotifierMailerTest
  end

  def test_check_preview_class_collision
    Object.send :const_set, :NotifierMailerPreview, Class.new
    content = capture(:stderr){ run_generator }
    assert_match(/The name 'NotifierMailerPreview' is either already used in your application or reserved/, content)
  ensure
    Object.send :remove_const, :NotifierMailerPreview
  end

  def test_invokes_default_text_template_engine
    run_generator
    assert_file "app/views/notifier_mailer/foo.text.erb" do |view|
      assert_match(%r(\sapp/views/notifier_mailer/foo\.text\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end

    assert_file "app/views/notifier_mailer/bar.text.erb" do |view|
      assert_match(%r(\sapp/views/notifier_mailer/bar\.text\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end

    assert_file "app/views/layouts/mailer.text.erb" do |view|
      assert_match(/<%= yield %>/, view)
    end
  end

  def test_invokes_default_html_template_engine
    run_generator
    assert_file "app/views/notifier_mailer/foo.html.erb" do |view|
      assert_match(%r(\sapp/views/notifier_mailer/foo\.html\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end

    assert_file "app/views/notifier_mailer/bar.html.erb" do |view|
      assert_match(%r(\sapp/views/notifier_mailer/bar\.html\.erb), view)
      assert_match(/<%= @greeting %>/, view)
    end

    assert_file "app/views/layouts/mailer.html.erb" do |view|
      assert_match(%r{<body>\n    <%= yield %>\n  </body>}, view)
    end
  end

  def test_invokes_default_template_engine_even_with_no_action
    run_generator ["notifier"]
    assert_file "app/views/notifier_mailer"
  end

  def test_logs_if_the_template_engine_cannot_be_found
    content = run_generator ["notifier", "foo", "bar", "--template-engine=haml"]
    assert_match(/haml \[not found\]/, content)
  end

  def test_mailer_with_namedspaced_mailer
    run_generator ["Farm::Animal", "moos"]
    assert_file "app/mailers/farm/animal_mailer.rb" do |mailer|
      assert_match(/class Farm::AnimalMailer < ApplicationMailer/, mailer)
      assert_match(/en\.farm\.animal_mailer\.moos\.subject/, mailer)
    end
    assert_file "test/mailers/previews/farm/animal_mailer_preview.rb" do |preview|
      assert_match(/\# Preview all emails at http:\/\/localhost\:3000\/rails\/mailers\/farm\/animal_mailer/, preview)
      assert_match(/class Farm::AnimalMailerPreview < ActionMailer::Preview/, preview)
      assert_match(/\# Preview this email at http:\/\/localhost\:3000\/rails\/mailers\/farm\/animal_mailer\/moos/, preview)
    end
    assert_file "app/views/farm/animal_mailer/moos.text.erb"
    assert_file "app/views/farm/animal_mailer/moos.html.erb"
  end

  def test_actions_are_turned_into_methods
    run_generator

    assert_file "app/mailers/notifier_mailer.rb" do |mailer|
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

  def test_mailer_on_revoke
    run_generator
    run_generator ["notifier"], behavior: :revoke

    assert_no_file "app/mailers/notifier.rb"
    assert_no_file "app/views/notifier/foo.text.erb"
    assert_no_file "app/views/notifier/bar.text.erb"
    assert_no_file "app/views/notifier/foo.html.erb"
    assert_no_file "app/views/notifier/bar.html.erb"
  end

  def test_mailer_suffix_is_not_duplicated
    run_generator ["notifier_mailer"]

    assert_no_file "app/mailers/notifier_mailer_mailer.rb"
    assert_file "app/mailers/notifier_mailer.rb"

    assert_no_file "app/views/notifier_mailer_mailer/"
    assert_file "app/views/notifier_mailer/"

    assert_no_file "test/mailers/notifier_mailer_mailer_test.rb"
    assert_file "test/mailers/notifier_mailer_test.rb"

    assert_no_file "test/mailers/previews/notifier_mailer_mailer_preview.rb"
    assert_file "test/mailers/previews/notifier_mailer_preview.rb"
  end
end
