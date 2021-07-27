# frozen_string_literal: true

class Review < ActiveRecord::Base
  belongs_to :reviewable, polymorphic: true, types: %w( Album Show Manga Restaurant Restaurant::Menu Library Library::StaffMember )
end
