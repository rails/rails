# frozen_string_literal: true

class User::Device < ActiveRecord::Base
  belongs_to :user
end
