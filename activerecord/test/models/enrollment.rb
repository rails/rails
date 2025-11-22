# frozen_string_literal: true

class Enrollment < ActiveRecord::Base
  belongs_to :program
  belongs_to :member, class_name: "SimpleMember"
end
