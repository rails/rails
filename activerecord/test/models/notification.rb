# frozen_string_literal: true

class Notification < ActiveRecord::Base
  validates_presence_of :message
end
