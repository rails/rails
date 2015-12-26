require 'abstract_unit'

class TestTestMailer < ActionMailer::Base
end

class CrazyNameMailerTest < ActionMailer::TestCase
  tests TestTestMailer

  def test_set_mailer_class_manual
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class CrazySymbolNameMailerTest < ActionMailer::TestCase
  tests :test_test_mailer

  def test_set_mailer_class_manual_using_symbol
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class CrazyStringNameMailerTest < ActionMailer::TestCase
  tests 'test_test_mailer'

  def test_set_mailer_class_manual_using_string
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

class MailerFixturePathTest < ActionMailer::TestCase
  tests BaseMailer

  def test_default_fixture_path
    assert_equal ["Welcome"], read_fixture('welcome')
  end
end

class MailerCustomFixturePathTest < ActionMailer::TestCase
  tests BaseMailer
  self.fixture_path = FIXTURE_LOAD_PATH + "/another.path"

  def test_custom_fixture_path
    assert_equal ["Welcome from another path"], read_fixture('welcome')
  end
end
