require 'test_helper'

class ActionText::ContentTest < ActiveSupport::TestCase
  test "equality" do
    html = %Q(<div>test</div>)
    content = ActionText::Content.new(html)
    assert_equal content, ActionText::Content.new(html)
    assert_not_equal content, html
  end

  test "marshal serialization" do
    content = ActionText::Content.new("Hello!")
    assert_equal content, Marshal.load(Marshal.dump(content))
  end

  test "roundtrips HTML without additional newlines" do
    html = %Q(<div>a<br></div>)
    content = ActionText::Content.new(html)
    assert_equal html, content.to_html
  end

  test "extracts links" do
    html = %Q(<a href="http://example.com/1">1</a><br><a href="http://example.com/1">1</a>)
    content = ActionText::Content.new(html)
    assert_equal ["http://example.com/1"], content.links
  end

  test "extracts attachables" do
    attachable = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}" caption="Captioned"></action-text-attachment>)

    content = ActionText::Content.new(html)
    assert_equal 1, content.attachments.size

    attachment = content.attachments.first
    assert_equal "Captioned", attachment.caption
    assert_equal attachable, attachment.attachable
  end

  test "extracts remote image attachables" do
    html = %Q(<action-text-attachment content-type="image" url="http://example.com/cat.jpg" width="100" height="100" caption="Captioned"></action-text-attachment>)

    content = ActionText::Content.new(html)
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
    attachable = create_file_blob(filename: "racecar.jpg", content_type: "image/jpg")
    html = %Q(<action-text-attachment sgid="#{attachable.attachable_sgid}"></action-text-attachment>)
    attachable.destroy!
    content = ActionText::Content.new(html)
    assert_equal 1, content.attachments.size
    assert_equal ActionText::Attachables::MissingAttachable, content.attachments.first.attachable
  end

  # test "extracts missing attachables" do
  #   html = %Q(<action-text-attachment sgid="missing"></action-text-attachment>)
  #   content = ActionText::Content.new(html)
  #   assert_equal 1, content.attachments.size
  #   assert_equal ActionText::Attachables::MissingAttachable, content.attachments.first.attachable
  # end
  #
  # test "converts Trix-formatted attachments" do
  #   html = %Q(<figure data-trix-attachment='{"sgid":"123","contentType":"text/plain","width":100,"height":100}' data-trix-attributes='{"caption":"Captioned"}'></figure>)
  #   content = ActionText::Content.new(html)
  #   assert_equal 1, content.attachments.size
  #   assert_equal %Q(<action-text-attachment sgid="123" content-type="text/plain" width="100" height="100" caption="Captioned"></action-text-attachment>), content.to_html
  # end
  #
  # test "ignores Trix-formatted attachments with malformed JSON" do
  #   html = %Q(<div data-trix-attachment='{"sgid":"garbage...'></div>)
  #   content = ActionText::Content.new(html)
  #   assert_equal 0, content.attachments.size
  # end
  #
  # test "minifies attachment markup" do
  #   html = %Q(<action-text-attachment sgid="123"><div>HTML</div></action-text-attachment>)
  #   assert_equal %Q(<action-text-attachment sgid="123"></action-text-attachment>), ActionText::Content.new(html).to_html
  # end
  #
  # test "canonicalizes attachment gallery markup" do
  #   attachment_html = %Q(<action-text-attachment sgid="1" presentation="gallery"></action-text-attachment><action-text-attachment sgid="2" presentation="gallery"></action-text-attachment>)
  #   html = %Q(<div class="attachment-gallery attachment-gallery--2">#{attachment_html}</div>)
  #   assert_equal %Q(<div>#{attachment_html}</div>), ActionText::Content.new(html).to_html
  # end
  #
  # test "canonicalizes attachment gallery markup with whitespace" do
  #   attachment_html = %Q(\n  <action-text-attachment sgid="1" presentation="gallery"></action-text-attachment>\n  <action-text-attachment sgid="2" presentation="gallery"></action-text-attachment>\n)
  #   html = %Q(<div class="attachment-gallery attachment-gallery--2">#{attachment_html}</div>)
  #   assert_equal %Q(<div>#{attachment_html}</div>), ActionText::Content.new(html).to_html
  # end
  #
  # test "canonicalizes nested attachment gallery markup" do
  #   attachment_html = %Q(<action-text-attachment sgid="1" presentation="gallery"></action-text-attachment><action-text-attachment sgid="2" presentation="gallery"></action-text-attachment>)
  #   html = %Q(<blockquote><div class="attachment-gallery attachment-gallery--2">#{attachment_html}</div></blockquote>)
  #   assert_equal %Q(<blockquote><div>#{attachment_html}</div></blockquote>), ActionText::Content.new(html).to_html
  # end
end
