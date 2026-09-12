# frozen_string_literal: true

class ActiveStorage::Attached::Collection # :nodoc:
  include ActiveStorage::Attached::EnumerableCollection

  delegate :each, :to_a, :size, :count, :empty?, :first, :last,
    :include?, :as_json, :+, :map, :select, :reject, to: :attachments
  delegate_missing_to :to_a

  def initialize(record, name)
    @record = record
    @name = name
  end

  def reload
    @attachments = nil
    self
  end

  def delete_all
    return @attachments = [] unless @record.persisted?

    ActiveStorage.attachment_class.where(
      record_type: polymorphic_owner_type,
      record_id: @record.id,
      name: @name
    ).delete_all.tap { reset }
  end

  def includes(*)
    self
  end

  def with_all_variant_records
    self
  end

  private
    def attachments
      return @attachments ||= [] unless @record.persisted?

      @attachments ||= ActiveStorage.attachment_class.where(
        record_type: polymorphic_owner_type,
        record_id: @record.id,
        name: @name
      ).order(:created_at, :id).to_a
    end

    def polymorphic_owner_type
      ActiveStorage::Attached::Changes.polymorphic_name(@record)
    end

    def query_unsupported_message(method)
      "#{method} chaining is not supported on Attached::Collection for non-ActiveRecord owners. " \
        "To run ad-hoc queries, call `#{ActiveStorage.attachment_class.name}.where(...)` directly on your attachment class."
    end
end
