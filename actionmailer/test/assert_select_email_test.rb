require 'abstract_unit'
require 'rails-dom-testing'

class AssertSelectEmailTest < ActionMailer::TestCase
  Assertion = ActiveSupport::TestCase::Assertion

  include Rails::Dom::Testing::Assertions::SelectorAssertions

  class AssertSelectMailer < ActionMailer::Base
    def test(html)
      mail body: html, content_type: "text/html",
        subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>"
    end
  end

  class AssertMultipartSelectMailer < ActionMailer::Base
    def test(options)
      mail subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>" do |format|
        format.text { render text: options[:text] }
        format.html { render text: options[:html] }
      end
    end
  end

  #
  # Test assert_select_email
  #

  def setup
    @response = FakeResponse.new(:html, 'some body text')
  end

  def test_assert_select_email
    assert_raise(Assertion) { assert_select_email {} }
    AssertSelectMailer.test("<div><p>foo</p><p>bar</p></div>").deliver
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  def test_assert_select_email_multipart
    AssertMultipartSelectMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: 'foo bar').deliver
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  protected

    class FakeResponse
      attr_accessor :content_type, :body

      def initialize(content_type, body)
        @content_type, @body = content_type, body
      end
    end
end