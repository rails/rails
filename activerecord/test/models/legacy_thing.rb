# frozen_string_literal: true

class LegacyThing < ActiveRecord::Base
  self.locking_column = :version
end
