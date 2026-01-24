# frozen_string_literal: true

class Room < ActiveRecord::Base
  belongs_to :user
  belongs_to :owner, class_name: "User"

  belongs_to :landlord, class_name: "User", dependent: :destroy, inverse_of: :let_room
  belongs_to :tenant, class_name: "User", dependent: :destroy, inverse_of: :rented_room
end
