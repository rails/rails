# frozen_string_literal: true

class Room < ActiveRecord::Base
  belongs_to :user, optional: true
  belongs_to :owner, class_name: "User", optional: true
end
