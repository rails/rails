# frozen_string_literal: true

require "models/entryable"

class Message < ActiveRecord::Base
  include Entryable

  has_many :recipients
end
