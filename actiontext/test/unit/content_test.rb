# frozen_string_literal: true

require "test_helper"

class ActionText::ContentTest < ActiveSupport::TestCase
  test "equality" do
    html = "<div>test</div>"
    content = content_from_html(html)
    assert_equal content, content_from_html(html)
    assert_not_equal content, html
  end

  test "marshal serialization" do
    content = content_from_html("Hello!")
    assert_equal content, Marshal.load(Marshal.dump(content))
  end

  test "roundtrips HTML without additional newlines" do
    html = "<div>a<br></div>"
    content = content_from_html(html)
    assert_equal html, content.to_html
  end

  test "extracts links" do
    html = '<a href="http://example.com/1">1</a><br><a href="http://example.com/1">1</a>'
    content = content_from_html(html)
    assert_equal ["http://example.com/1"], content.links
  end

  test "extracts attachables" do
    attachable = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}" caption="Captioned"></action-text-attachment>)

    content = content_from_html(html)
    assert_equal 1, content.attachments.size

    attachment = content.attachments.first
    assert_equal "Captioned", attachment.caption
    assert_equal attachable, attachment.attachable
  end

  test "extracts remote image attachables" do
    html = '<action-text-attachment content-type="image" url="http://example.com/cat.jpg" width="100" height="100" caption="Captioned"></action-text-attachment>'

    content = content_from_html(html)
    assert_equal 1, content.attachments.size

    attachment = content.attachments.first
    assert_equal "Captioned", attachment.caption

    attachable = attachment.attachable
    assert_kind_of ActionText::Attachables::RemoteImage, attachable
    assert_equal "http://example.com/cat.jpg", attachable.url
    assert_equal "100", attachable.width
    assert_equal "100", attachable.height
  end

  test "identifies destroyed attachables as missing" do
    attachable = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}"></action-text-attachment>)
    attachable.destroy!
    content = content_from_html(html)
    assert_equal 1, content.attachments.size
    assert_equal ActionText::Attachables::MissingAttachable, content.attachments.first.attachable
  end

  test "extracts missing attachables" do
    html = '<action-text-attachment sgid="missing"></action-text-attachment>'
    content = content_from_html(html)
    assert_equal 1, content.attachments.size
    assert_equal ActionText::Attachables::MissingAttachable, content.attachments.first.attachable
  end

  test "converts Trix-formatted attachments" do
    html = %Q(<figure data-trix-attachment='{"sgid":"123","contentType":"text/plain","width":100,"height":100}' data-trix-attributes='{"caption":"Captioned"}'></figure>)
    content = content_from_html(html)
    assert_equal 1, content.attachments.size
    assert_equal '<action-text-attachment sgid="123" content-type="text/plain" width="100" height="100" caption="Captioned"></action-text-attachment>', content.to_html
  end

  test "ignores Trix-formatted attachments with malformed JSON" do
    html = %Q(<div data-trix-attachment='{"sgid":"garbage...'></div>)
    content = content_from_html(html)
    assert_equal 0, content.attachments.size
  end

  test "minifies attachment markup" do
    html = '<action-text-attachment sgid="123"><div>HTML</div></action-text-attachment>'
    assert_equal '<action-text-attachment sgid="123"></action-text-attachment>', content_from_html(html).to_html
  end

  test "canonicalizes attachment gallery markup" do
    attachment_html = '<action-text-attachment sgid="1" presentation="gallery"></action-text-attachment><action-text-attachment sgid="2" presentation="gallery"></action-text-attachment>'
    html = %Q(<div class="attachment-gallery attachment-gallery--2">#{attachment_html}</div>)
    assert_equal "<div>#{attachment_html}</div>", content_from_html(html).to_html
  end

  test "canonicalizes attachment gallery markup with whitespace" do
    attachment_html = %Q(\n  <action-text-attachment sgid="1" presentation="gallery"></action-text-attachment>\n  <action-text-attachment sgid="2" presentation="gallery"></action-text-attachment>\n)
    html = %Q(<div class="attachment-gallery attachment-gallery--2">#{attachment_html}</div>)
    assert_equal "<div>#{attachment_html}</div>", content_from_html(html).to_html
  end

  test "canonicalizes nested attachment gallery markup" do
    attachment_html = '<action-text-attachment sgid="1" presentation="gallery"></action-text-attachment><action-text-attachment sgid="2" presentation="gallery"></action-text-attachment>'
    html = %Q(<blockquote><div class="attachment-gallery attachment-gallery--2">#{attachment_html}</div></blockquote>)
    assert_equal "<blockquote><div>#{attachment_html}</div></blockquote>", content_from_html(html).to_html
  end

  test "renders with layout when ApplicationController is not defined" do
    html = "<h1>Hello world</h1>"
    rendered = content_from_html(html).to_rendered_html_with_layout

    assert_includes rendered, html
    assert_match %r/\A#{Regexp.escape '<div class="trix-content">'}/, rendered
    assert_not defined?(::ApplicationController)
  end

  test "renders with layout when in a new thread" do
    html = "<h1>Hello world</h1>"
    rendered = nil
    Thread.new { rendered = content_from_html(html).to_rendered_html_with_layout }.join

    assert_includes rendered, html
    assert_match %r/\A#{Regexp.escape '<div class="trix-content">'}/, rendered
  end

  private
    def content_from_html(html)
      ActionText::Content.new(html).tap do |content|
        assert_nothing_raised { content.to_s }
      end
    end
end
