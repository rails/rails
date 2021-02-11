# frozen_string_literal: true

class HmtEnrolment < ActiveRecord::Base
  belongs_to :hmt_course
  belongs_to :hmt_student
end
