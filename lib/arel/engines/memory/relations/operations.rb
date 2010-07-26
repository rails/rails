module Arel
  class From < Compound
    def eval
      unoperated_rows[sources..-1]
    end
  end

  class Alias < Compound
    include Recursion::BaseCase

    def eval
      unoperated_rows
    end
  end
end
