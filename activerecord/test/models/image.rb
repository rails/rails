# frozen_string_literal: true

class Image < ActiveRecord::Base
  belongs_to :imageable, foreign_key: :imageable_identifier, foreign_type: :imageable_class, polymorphic: true
end
