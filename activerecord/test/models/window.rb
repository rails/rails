# frozen_string_literal: true

class Window < ActiveRecord::Base
  has_many :panes
end
