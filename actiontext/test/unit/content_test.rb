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
    file = create_file_blob(filename: "racecar.jpg", content_type: "image/jpeg")
    html = %Q(<action-text-attachment sgid="#{file.attachable_sgid}"></action-text-attachment>)
    file.destroy!
    content = content_from_html(html)
    assert_equal 1, content.attachments.size

    attachable = content.attachments.first.attachable
    assert_kind_of ActionText::Attachables::MissingAttachable, attachable
    assert_equal file.class, attachable.model
    assert_equal ActionText::Attachables::MissingAttachable::DEFAULT_PARTIAL_PATH, attachable.to_partial_path
  end

  test "extracts missing attachables" do
    html = '<action-text-attachment sgid="missing"></action-text-attachment>'
    content = content_from_html(html)
    assert_equal 1, content.attachments.size

    attachable = content.attachments.first.attachable
    assert_kind_of ActionText::Attachables::MissingAttachable, attachable
    assert_nil attachable.model
  end

  test "converts Trix-formatted attachments" do
    html = %Q(<figure data-trix-attachment='{"sgid":"123","contentType":"text/plain","width":100,"height":100}' data-trix-attributes='{"caption":"Captioned"}'></figure>)
    content = content_from_html(html)
    assert_equal 1, content.attachments.size
    assert_equal '<action-text-attachment sgid="123" content-type="text/plain" width="100" height="100" caption="Captioned"></action-text-attachment>', content.to_html
  end

  test "converts Trix-formatted attachments with custom tag name" do
    with_attachment_tag_name("arbitrary-tag") do
      html = %Q(<figure data-trix-attachment='{"sgid":"123","contentType":"text/plain","width":100,"height":100}' data-trix-attributes='{"caption":"Captioned"}'></figure>)
      content = content_from_html(html)
      assert_equal 1, content.attachments.size
      assert_equal '<arbitrary-tag sgid="123" content-type="text/plain" width="100" height="100" caption="Captioned"></arbitrary-tag>', content.to_html
    end
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

  test "does basic sanitization" do
    html = "<div onclick='action()'>safe<script>unsafe</script></div>"
    rendered = content_from_html(html).to_rendered_html_with_layout

    assert_not_includes rendered, "<script>"
    assert_not_includes rendered, "action"
  end

  test "does custom tag sanitization" do
    old_tags = ActionText::ContentHelper.allowed_tags
    old_attrs = ActionText::ContentHelper.allowed_attributes
    ActionText::ContentHelper.allowed_tags = ["div"] # not 'span'
    ActionText::ContentHelper.allowed_attributes = ["size"] # not 'class'

    html = "<div size='large' class='high'>safe<span>unsafe</span></div>"
    rendered = content_from_html(html).to_rendered_html_with_layout

    assert_includes rendered, "<div"
    assert_not_includes rendered, "<span"
    assert_includes rendered, "large"
    assert_not_includes rendered, "high"
  ensure
    ActionText::ContentHelper.allowed_tags = old_tags
    ActionText::ContentHelper.allowed_attributes = old_attrs
  end

  test "sanitizes attachment markup for Trix" do
    html = '<action-text-attachment content="<img src=\&quot;.\&quot; onerror=alert>"></action-text-attachment>'
    trix_html = '<figure data-trix-attachment="{&quot;content&quot;:&quot;<img src=\\&quot;\\\\%22.\\\\%22\\&quot;>&quot;}"></figure>'
    assert_equal trix_html, content_from_html(html).to_trix_html.strip
  end

  test "removes content attribute if it's value is empty" do
    html = '<action-text-attachment sgid="123" content=""></action-text-attachment>'
    trix_html = '<figure data-trix-attachment="{&quot;sgid&quot;:&quot;123&quot;}"></figure>'
    assert_equal trix_html, content_from_html(html).to_trix_html.strip
  end

  test "removes content attribute if it's value is empty after sanitization" do
    html = '<action-text-attachment sgid="123" content="<script></script>"></action-text-attachment>'
    trix_html = '<figure data-trix-attachment="{&quot;sgid&quot;:&quot;123&quot;}"></figure>'
    assert_equal trix_html, content_from_html(html).to_trix_html.strip
  end

  test "does not add missing content attribute" do
    html = '<action-text-attachment sgid="123"></action-text-attachment>'
    trix_html = '<figure data-trix-attachment="{&quot;sgid&quot;:&quot;123&quot;}"></figure>'
    assert_equal trix_html, content_from_html(html).to_trix_html.strip
  end

  test "renders with layout when in a new thread" do
    html = "<h1>Hello world</h1>"
    rendered = nil
    Thread.new { rendered = content_from_html(html).to_rendered_html_with_layout }.join

    assert_includes rendered, html
    assert_match %r/\A#{Regexp.escape '<div class="trix-content">'}/, rendered
  end

  test "replace certain nodes" do
    html = <<~HTML
      <div>
        <p>replace me</p>
        <p>ignore me</p>
      </div>
    HTML

    expected_html = <<~HTML
      <div>
        <p>replaced</p>
        <p>ignore me</p>
      </div>
    HTML

    content = content_from_html(html)
    replaced_fragment = content.fragment.replace("p") do |node|
      if node.text =~ /replace me/
        "<p>replaced</p>"
      else
        node
      end
    end

    assert_equal expected_html.strip, replaced_fragment.to_html
  end

  test "delegates pattern matching to Nokogiri" do
    content = ActionText::Content.new <<~HTML
      <h1 id="hello-world">Hello, world</h1>

      <div>The body</div>
    HTML

    content => [h1, div]

    assert_pattern { h1 => { name: "h1", content: "Hello, world", attributes: [{ name: "id", value: "hello-world" }] } }
    refute_pattern { h1 => { name: "h1", content: "Goodbye, world" } }
    assert_pattern { div => { content: "The body" } }
  end

  private
    def content_from_html(html)
      ActionText::Content.new(html).tap do |content|
        assert_nothing_raised { content.to_s }
      end
    end

    def with_attachment_tag_name(tag_name)
      previous_tag_name = ActionText::Attachment.tag_name
      ActionText::Attachment.tag_name = tag_name

      yield
    ensure
      ActionText::Attachment.tag_name = previous_tag_name
    end
end
