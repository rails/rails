class SubClassConflict
end

class Prepend
  module PrependedModule
  end
  prepend PrependedModule
end
