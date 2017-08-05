# frozen_string_literal: true

class SubClassConflict
end

class Prepend
  module PrependedModule
  end
  prepend PrependedModule
end
