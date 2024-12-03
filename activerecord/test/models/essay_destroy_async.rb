# frozen_string_literal: true

class EssayDestroyAsync < ActiveRecord::Base
  self.table_name = "essays"
  belongs_to :book, dependent: :destroy_async, class_name: "BookDestroyAsync"
  belongs_to :writer, polymorphic: true, dependent: :destroy_async
end

class LongEssayDestroyAsync < EssayDestroyAsync
end

class ShortEssayDestroyAsync < EssayDestroyAsync
end
