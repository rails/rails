# frozen_string_literal: true

require 'cases/helper'
require 'models/entry'
require 'models/message'
require 'models/comment'

class DelegatedTypeTest < ActiveRecord::TestCase
  fixtures :comments

  setup do
    @entry_with_message = Entry.create! entryable: Message.new(subject: 'Hello world!')
    @entry_with_comment = Entry.create! entryable: comments(:greetings)
  end

  test 'delegated class' do
    assert_equal Message, @entry_with_message.entryable_class
    assert_equal Comment, @entry_with_comment.entryable_class
  end

  test 'delegated type name' do
    assert_equal 'message', @entry_with_message.entryable_name
    assert @entry_with_message.entryable_name.message?

    assert_equal 'comment', @entry_with_comment.entryable_name
    assert @entry_with_comment.entryable_name.comment?
  end

  test 'delegated type predicates' do
    assert @entry_with_message.message?
    assert_not @entry_with_message.comment?

    assert @entry_with_comment.comment?
    assert_not @entry_with_comment.message?
  end

  test 'scope' do
    assert Entry.messages.first.message?
    assert Entry.comments.first.comment?
  end

  test 'accessor' do
    assert @entry_with_message.message.is_a?(Message)
    assert_nil @entry_with_message.comment

    assert @entry_with_comment.comment.is_a?(Comment)
    assert_nil @entry_with_comment.message
  end

  test 'association id' do
    assert_equal @entry_with_message.entryable_id, @entry_with_message.message_id
    assert_nil @entry_with_message.comment_id

    assert_equal @entry_with_comment.entryable_id, @entry_with_comment.comment_id
    assert_nil @entry_with_comment.message_id
  end
end
