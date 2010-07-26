module Arel
  class Alias < Compound
    include Recursion::BaseCase

    def eval
      unoperated_rows
    end
  end
end
