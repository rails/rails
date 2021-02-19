# frozen_string_literal: true

require "abstract_unit"

class AssertSelectEmailTest < ActionMailer::TestCase
  class AssertSelectMailer < ActionMailer::Base
    def test(html)
      mail body: html, content_type: "text/html",
        subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>"
    end
  end

  class AssertMultipartSelectMailer < ActionMailer::Base
    def test(options)
      mail subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>" do |format|
        format.text { render plain: options[:text] }
        format.html { render plain: options[:html] }
      end
    end
  end

  #
  # Test assert_dom_email
  #

  def test_assert_dom_email
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_dom_email { }
    end

    AssertSelectMailer.test("<div><p>foo</p><p>bar</p></div>").deliver_now
    assert_dom_email do
      assert_dom "div:root" do
        assert_dom "p:first-child", "foo"
        assert_dom "p:last-child", "bar"
      end
    end
  end

  def test_assert_dom_email_multipart
    AssertMultipartSelectMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "foo bar").deliver_now
    assert_dom_email do
      assert_dom "div:root" do
        assert_dom "p:first-child", "foo"
        assert_dom "p:last-child", "bar"
      end
    end
  end
end
