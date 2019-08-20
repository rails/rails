# frozen_string_literal: true

class UuidChild < ActiveRecord::Base
  belongs_to :uuid_parent
end
