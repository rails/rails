# frozen_string_literal: true

class Library::StaffMember < ActiveRecord::Base
  has_many :reviews, as: :reviewable
end
