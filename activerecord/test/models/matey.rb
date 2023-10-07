# frozen_string_literal: true

class Matey < ActiveRecord::Base
  belongs_to :pirate, optional: true
  belongs_to :target, class_name: "Pirate", optional: true
end
