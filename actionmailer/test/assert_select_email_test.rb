# frozen_string_literal: true

require "abstract_unit"

class AssertSelectEmailTest < ActionMailer::TestCase
  class AssertSelectMailer < ActionMailer::Base
    def test(html)
      mail body: html, content_type: "text/html",
        subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>"
    end
  end

  tests AssertSelectMailer

  #
  # Test assert_select_email
  #

  def test_assert_select_email
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_select_email { }
    end

    AssertSelectMailer.test("<div><p>foo</p><p>bar</p></div>").deliver_now
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  def test_assert_part_last_mail_delivery
    AssertSelectMailer.test("<div><p>foo</p><p>bar</p></div>").deliver_now

    assert_part :html do |html|
      assert_kind_of Rails::Dom::Testing.html_document, html

      assert_dom html, "div" do
        assert_dom "p:first-child", "foo"
        assert_dom "p:last-child", "bar"
      end
    end
  end

  def test_assert_part_with_mail_argument
    mail = AssertSelectMailer.test("<div><p>foo</p><p>bar</p></div>")

    assert_part :html, mail do |html|
      assert_kind_of Rails::Dom::Testing.html_document, html

      assert_dom html, "div" do
        assert_dom "p:first-child", "foo"
        assert_dom "p:last-child", "bar"
      end
    end
  end
end

class AssertMultipartSelectEmailTest < ActionMailer::TestCase
  class AssertMultipartSelectMailer < ActionMailer::Base
    def test(options)
      mail subject: "Test e-mail", from: "test@test.host", to: "test <test@test.host>" do |format|
        format.text { render plain: options[:text] } if options.key?(:text)
        format.html { render plain: options[:html] } if options.key?(:html)
      end
    end
  end

  tests AssertMultipartSelectMailer

  #
  # Test assert_select_email
  #

  def test_assert_select_email
    assert_raise ActiveSupport::TestCase::Assertion do
      assert_select_email { }
    end

    AssertMultipartSelectMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "foo bar").deliver_now
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  def test_assert_select_email_multipart
    AssertMultipartSelectMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "foo bar").deliver_now
    assert_select_email do
      assert_select "div:root" do
        assert_select "p:first-child", "foo"
        assert_select "p:last-child", "bar"
      end
    end
  end

  def test_assert_part_last_mail_delivery
    AssertMultipartSelectMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "foo bar").deliver_now

    assert_part :text do |text|
      assert_includes text, "foo bar"
    end
    assert_part :html do |html|
      assert_kind_of Rails::Dom::Testing.html_document, html

      assert_dom html, "div" do
        assert_dom "p:first-child", "foo"
        assert_dom "p:last-child", "bar"
      end
    end
  end

  def test_assert_part_with_mail_argument
    mail = AssertMultipartSelectMailer.test(html: "<div><p>foo</p><p>bar</p></div>", text: "foo bar")

    assert_part :text, mail do |text|
      assert_includes text, "foo bar"
    end
    assert_part :html, mail do |html|
      assert_kind_of Rails::Dom::Testing.html_document, html

      assert_dom html, "div" do
        assert_dom "p:first-child", "foo"
        assert_dom "p:last-child", "bar"
      end
    end
  end

  def test_assert_part_without_block
    assert_part :html, AssertMultipartSelectMailer.test(html: "html")
    assert_part :text, AssertMultipartSelectMailer.test(text: "text")

    assert_raises Minitest::Assertion, match: "expected part matching text/html" do
      assert_part :html, AssertMultipartSelectMailer.test(text: "text")
    end
    assert_raises Minitest::Assertion, match: "expected part matching text/plain" do
      assert_part :text, AssertMultipartSelectMailer.test(html: "html")
    end
  end

  def test_assert_no_part
    assert_no_part :html, AssertMultipartSelectMailer.test(text: "text")
    assert_no_part :text, AssertMultipartSelectMailer.test(html: "html")

    assert_raises Minitest::Assertion, match: "expected no part matching text/html" do
      assert_no_part :html, AssertMultipartSelectMailer.test(html: "html")
    end
    assert_raises Minitest::Assertion, match: "expected no part matching text/plain" do
      assert_no_part :text, AssertMultipartSelectMailer.test(text: "text")
    end
  end
end
