# frozen_string_literal: true

class Reply < ActiveRecord::Base
  scope :base, -> { all }
  belongs_to :topic, -> { includes(:replies) }
  belongs_to :developer

  validates_presence_of :content
end
