# frozen_string_literal: true

class Attachment < ActiveRecord::Base
  belongs_to :record, polymorphic: true

  has_one :translation
end
