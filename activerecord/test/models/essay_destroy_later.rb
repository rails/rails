# frozen_string_literal: true

class EssayDestroyLater < ActiveRecord::Base
  self.table_name = "essays"
  belongs_to :book, dependent: :destroy_later, class_name: "BookDestroyLater"
end
