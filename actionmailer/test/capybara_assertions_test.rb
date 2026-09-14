# frozen_string_literal: true

require "abstract_unit"

class ActionMailer::CapybaraAssertionsTest < ActionMailer::TestCase
  class TestMailer < ActionMailer::Base
    def test(options)
      text, html = options.values_at(:text, :html)

      mail subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>" do |format|
        if text.present?
          format.text { render plain: text }
        end
        if html.present?
          format.html { render plain: html }
        end
      end
    end
  end

  include ActionView::CapybaraAssertions

  tests TestMailer

  test "assertions from last HTML delivery" do
    TestMailer.test(html: "<div><p>foo</p><p>bar</p></div>").deliver_now

    assert_part :html do
      assert_css "div" do |div|
        assert_css div, "p", text: "foo"
        assert_css div, "p", text: "bar"
      end
    end
  end

  test "assertions from HTML instance" do
    mail = TestMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "ignored")

    assert_part :html, mail do
      assert_css "div" do |div|
        assert_css div, "p", text: "foo"
        assert_css div, "p", text: "bar"
      end
    end
  end

  test "assertions from last multi-part delivery" do
    TestMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "ignored").deliver_now

    assert_part :html do
      assert_css "div" do |div|
        assert_css div, "p", text: "foo"
        assert_css div, "p", text: "bar"
      end
    end
  end

  test "assertions from multi-part instance" do
    mail = TestMailer.test(html: "<div><p>foo</p><p>bar</p></div>")

    assert_part :html, mail do
      assert_css "div" do |div|
        assert_css div, "p", text: "foo"
        assert_css div, "p", text: "bar"
      end
    end
  end

  test "fails when no HTML part" do
    mail = TestMailer.test(text: "ignored")

    assert_raises Minitest::Assertion, match: "expected part matching text/html in #{mail.inspect}" do
      assert_part :html, mail do
      end
    end
  end
end
