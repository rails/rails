# frozen_string_literal: true

class EssayDestroyAsync < ActiveRecord::Base
  self.table_name = "essays"
  belongs_to :book, dependent: :destroy_async, class_name: "BookDestroyAsync"
  belongs_to :writer, polymorphic: true, dependent: :destroy_async

  def self.destroyed_ids
    @destroyed_ids ||= []
  end

  before_destroy { |essay| EssayDestroyAsync.destroyed_ids << essay.id }
end

class LongEssayDestroyAsync < EssayDestroyAsync
end

class ShortEssayDestroyAsync < EssayDestroyAsync
end
