# frozen_string_literal: true

class DlKeyedHasOne < ActiveRecord::Base
  self.primary_key = "has_one_key"
end
