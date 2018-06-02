# frozen_string_literal: true

class Admin::Account < ActiveRecord::Base
  has_many :users
end
