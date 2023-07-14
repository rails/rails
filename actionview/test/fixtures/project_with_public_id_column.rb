# frozen_string_literal: true

class ProjectWithPublicIdColumn < ActiveRecord::Base
  has_and_belongs_to_many :developers, -> { uniq }

  validates :public_id, presence: true, uniqueness: {case_sensitive: false}

  before_validation :set_public_id, on: :create

  def set_public_id
    self.public_id = "#{SecureRandom.hex(3)}-#{Time.now.to_i}"
  end

  def to_param
    public_id
  end
end
