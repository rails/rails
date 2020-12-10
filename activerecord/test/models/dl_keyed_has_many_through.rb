# frozen_string_literal: true

class DlKeyedHasManyThrough < ActiveRecord::Base
  self.primary_key = :through_key
end
