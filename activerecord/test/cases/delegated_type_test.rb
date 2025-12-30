# frozen_string_literal: true

require "cases/helper"
require "models/account"
require "models/entry"
require "models/message"
require "models/recipient"
require "models/comment"
require "models/uuid_entry"
require "models/uuid_message"
require "models/uuid_comment"

class DelegatedTypeTest < ActiveRecord::TestCase
  fixtures :comments, :accounts, :posts

  setup do
    @entry_with_message = Entry.create! entryable: Message.new(subject: "Hello world!"), account: accounts(:signals37)
    @entry_with_comment = Entry.create! entryable: comments(:greetings), account: accounts(:signals37)
    @entry_with_post = Entry.create! thing: posts(:welcome), account: accounts(:signals37)

    if current_adapter?(:PostgreSQLAdapter)
      @uuid_entry_with_message = UuidEntry.create! uuid: SecureRandom.uuid, entryable: UuidMessage.new(uuid: SecureRandom.uuid, subject: "Hello world!")
      @uuid_entry_with_comment = UuidEntry.create! uuid: SecureRandom.uuid, entryable: UuidComment.new(uuid: SecureRandom.uuid, content: "comment")
    end
  end

  test "delegated types" do
    assert_equal ["Message", "Comment"], Entry.entryable_types
  end

  test "delegated class" do
    assert_equal Message, @entry_with_message.entryable_class
    assert_equal Comment, @entry_with_comment.entryable_class
  end

  test "delegated class with custom foreign_type" do
    assert_equal Message, @entry_with_message.thing_class
    assert_equal Comment, @entry_with_comment.thing_class
    assert_equal Post, @entry_with_post.thing_class
  end

  test "delegated type name" do
    assert_equal "message", @entry_with_message.entryable_name
    assert_predicate @entry_with_message.entryable_name, :message?

    assert_equal "comment", @entry_with_comment.entryable_name
    assert_predicate @entry_with_comment.entryable_name, :comment?
  end

  test "delegated type predicates" do
    assert_predicate @entry_with_message, :message?
    assert_not @entry_with_message.comment?

    assert_predicate @entry_with_comment, :comment?
    assert_not @entry_with_comment.message?
  end

  test "delegated type predicates with custom foreign_type" do
    assert_predicate @entry_with_post, :post?
    assert_not @entry_with_message.post?
    assert_not @entry_with_comment.post?
  end

  test "scope" do
    assert_predicate Entry.messages.first, :message?
    assert_predicate Entry.comments.first, :comment?
  end

  test "scope with custom foreign_type" do
    assert_predicate Entry.posts.first, :post?
  end

  test "accessor" do
    assert @entry_with_message.message.is_a?(Message)
    assert_nil @entry_with_message.comment

    assert @entry_with_comment.comment.is_a?(Comment)
    assert_nil @entry_with_comment.message
  end

  test "association id" do
    assert_equal @entry_with_message.entryable_id, @entry_with_message.message_id
    assert_nil @entry_with_message.comment_id

    assert_equal @entry_with_comment.entryable_id, @entry_with_comment.comment_id
    assert_nil @entry_with_comment.message_id
  end

  test "association uuid" do
    skip unless current_adapter?(:PostgreSQLAdapter)

    assert_equal @uuid_entry_with_message.entryable_uuid, @uuid_entry_with_message.uuid_message_uuid
    assert_nil @uuid_entry_with_message.uuid_comment_uuid

    assert_equal @uuid_entry_with_comment.entryable_uuid, @uuid_entry_with_comment.uuid_comment_uuid
    assert_nil @uuid_entry_with_comment.uuid_message_uuid
  end

  test "touch account" do
    previous_account_updated_at  = @entry_with_message.account.updated_at
    previous_entry_updated_at    = @entry_with_message.updated_at
    previous_message_updated_at  = @entry_with_message.entryable.updated_at

    travel 5.seconds do
      Recipient.create! message: @entry_with_message.entryable, email_address: "test@test.com"
    end

    assert_not_equal @entry_with_message.reload.account.updated_at, previous_account_updated_at
    assert_not_equal @entry_with_message.reload.updated_at, previous_entry_updated_at
    assert_not_equal @entry_with_message.reload.entryable.updated_at, previous_message_updated_at
  end

  test "builder method" do
    assert_respond_to Entry.new, :build_entryable
    assert_equal Message, Entry.new(entryable_type: "Message").build_entryable.class
  end
end
