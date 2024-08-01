# frozen_string_literal: true

class Recipient < ActiveRecord::Base
  belongs_to :message, touch: true
end
