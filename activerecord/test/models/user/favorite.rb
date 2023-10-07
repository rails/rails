# frozen_string_literal: true

class User::Favorite < ActiveRecord::Base
  belongs_to :user
  belongs_to :favorable, polymorphic: true
end
