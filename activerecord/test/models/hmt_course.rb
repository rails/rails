# frozen_string_literal: true

class HmtCourse < ActiveRecord::Base
  has_many :hmt_enrolments
  has_many :hmt_students, through: :hmt_enrolments
end
