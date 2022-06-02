# frozen_string_literal: true

class Room < ActiveRecord::Base
  belongs_to :user
  belongs_to :owner, class_name: "User"
end
