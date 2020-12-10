# frozen_string_literal: true

require "models/zine"

class StrictZine < Zine
  self.strict_loading_by_default = true
end
