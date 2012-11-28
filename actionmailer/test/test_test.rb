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

describe TestTestMailer do
  it "gets the mailer from the test name" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe TestTestMailer, :action do
  it "gets the mailer from the test name" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe TestTestMailer do
  describe "nested" do
    it "gets the mailer from the test name" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe TestTestMailer, :action do
  describe "nested" do
    it "gets the mailer from the test name" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "TestTestMailer" do
  it "gets the mailer from the test name" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "TestTestMailerTest" do
  it "gets the mailer from the test name" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "TestTestMailer" do
  describe "nested" do
    it "gets the mailer from the test name" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "TestTestMailerTest" do
  describe "nested" do
    it "gets the mailer from the test name" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "AnotherCrazySymbolNameMailerTest" do
  tests :test_test_mailer

  it "gets the mailer after setting it with a symbol" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "AnotherCrazyStringNameMailerTest" do
  tests 'test_test_mailer'

  it "gets the mailer after setting it with a string" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "Another Crazy Name Mailer Test" do
  tests TestTestMailer

  it "gets the mailer after setting it manually" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "Another Crazy Symbol Name Mailer Test" do
  tests :test_test_mailer

  it "gets the mailer after setting it with a symbol" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "Another Crazy String Name Mailer Test" do
  tests 'test_test_mailer'

  it "gets the mailer after setting it with a string" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end

describe "AnotherCrazySymbolNameMailerTest" do
  tests :test_test_mailer

  describe "nested" do
    it "gets the mailer after setting it with a symbol" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "AnotherCrazyStringNameMailerTest" do
  tests 'test_test_mailer'

  describe "nested" do
    it "gets the mailer after setting it with a string" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "Another Crazy Name Mailer Test" do
  tests TestTestMailer

  describe "nested" do
    it "gets the mailer after setting it manually" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "Another Crazy Symbol Name Mailer Test" do
  tests :test_test_mailer

  describe "nested" do
    it "gets the mailer after setting it with a symbol" do
      assert_equal TestTestMailer, self.class.mailer_class
    end
  end
end

describe "Another Crazy String Name Mailer Test" do
  tests 'test_test_mailer'

  it "gets the mailer after setting it with a string" do
    assert_equal TestTestMailer, self.class.mailer_class
  end
end
