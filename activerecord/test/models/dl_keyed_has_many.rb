# frozen_string_literal: true

class DlKeyedHasMany < ActiveRecord::Base
  self.primary_key = "many_key"
end
