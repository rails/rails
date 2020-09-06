# frozen_string_literal: true

require 'test_helper'

class ActionText::ModelTest < ActiveSupport::TestCase
  test 'html conversion' do
    message = Message.new(subject: 'Greetings', content: '<h1>Hello world</h1>')
    assert_equal %Q(<div class="trix-content">\n  <h1>Hello world</h1>\n</div>\n), "#{message.content}"
  end

  test 'plain text conversion' do
    message = Message.new(subject: 'Greetings', content: '<h1>Hello world</h1>')
    assert_equal 'Hello world', message.content.to_plain_text
  end

  test 'without content' do
    message = Message.create!(subject: 'Greetings')
    assert message.content.nil?
    assert message.content.blank?
    assert message.content.empty?
    assert_not message.content?
    assert_not message.content.present?
  end

  test 'with blank content' do
    message = Message.create!(subject: 'Greetings', content: '')
    assert_not message.content.nil?
    assert message.content.blank?
    assert message.content.empty?
    assert_not message.content?
    assert_not message.content.present?
  end

  test 'embed extraction' do
    blob = create_file_blob(filename: 'racecar.jpg', content_type: 'image/jpg')
    message = Message.create!(subject: 'Greetings', content: ActionText::Content.new('Hello world').append_attachables(blob))
    assert_equal 'racecar.jpg', message.content.embeds.first.filename.to_s
  end

  test 'embed extraction only extracts file attachments' do
    remote_image_html = '<action-text-attachment content-type="image" url="http://example.com/cat.jpg"></action-text-attachment>'
    blob = create_file_blob(filename: 'racecar.jpg', content_type: 'image/jpg')
    content = ActionText::Content.new(remote_image_html).append_attachables(blob)
    message = Message.create!(subject: 'Greetings', content: content)
    assert_equal [ActionText::Attachables::RemoteImage, ActiveStorage::Blob], message.content.body.attachables.map(&:class)
    assert_equal [ActiveStorage::Attachment], message.content.embeds.map(&:class)
  end

  test 'embed extraction deduplicates file attachments' do
    blob = create_file_blob(filename: 'racecar.jpg', content_type: 'image/jpg')
    content = ActionText::Content.new('Hello world').append_attachables([ blob, blob ])

    assert_nothing_raised do
      Message.create!(subject: 'Greetings', content: content)
    end
  end

  test 'saving content' do
    message = Message.create!(subject: 'Greetings', content: '<h1>Hello world</h1>')
    assert_equal 'Hello world', message.content.to_plain_text
  end

  test 'saving body' do
    message = Message.create(subject: 'Greetings', body: '<h1>Hello world</h1>')
    assert_equal 'Hello world', message.body.to_plain_text
  end

  test 'saving content via nested attributes' do
    message = Message.create! subject: 'Greetings', content: '<h1>Hello world</h1>',
      review_attributes: { author_name: 'Marcia', content: 'Nice work!' }
    assert_equal 'Nice work!', message.review.content.to_plain_text
  end

  test 'updating content via nested attributes' do
    message = Message.create! subject: 'Greetings', content: '<h1>Hello world</h1>',
      review_attributes: { author_name: 'Marcia', content: 'Nice work!' }

    message.update! review_attributes: { id: message.review.id, content: 'Great work!' }
    assert_equal 'Great work!', message.review.reload.content.to_plain_text
  end

  test 'building content lazily on existing record' do
    message = Message.create!(subject: 'Greetings')

    assert_no_difference -> { ActionText::RichText.count } do
      assert_kind_of ActionText::RichText, message.content
    end
  end
end
