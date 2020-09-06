# frozen_string_literal: true

class Content < ActiveRecord::Base
  self.table_name = 'content'
  has_one :content_position, dependent: :destroy

  def self.destroyed_ids
    @destroyed_ids ||= []
  end

  before_destroy do |object|
    Content.destroyed_ids << object.id
  end
end

class ContentWhichRequiresTwoDestroyCalls < ActiveRecord::Base
  self.table_name = 'content'
  has_one :content_position, foreign_key: 'content_id', dependent: :destroy

  after_initialize do
    @destroy_count = 0
  end

  before_destroy do
    @destroy_count += 1
    if @destroy_count == 1
      throw :abort
    end
  end
end

class ContentPosition < ActiveRecord::Base
  belongs_to :content, dependent: :destroy

  def self.destroyed_ids
    @destroyed_ids ||= []
  end

  before_destroy do |object|
    ContentPosition.destroyed_ids << object.id
  end
end
