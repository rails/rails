module Arel
  class Take < Compound
    attr_reader :taken

    def initialize relation, taken
      super(relation)
      @taken = taken
    end

    def externalizable?
      true
    end

    def eval
      unoperated_rows[0, taken]
    end
  end
end
