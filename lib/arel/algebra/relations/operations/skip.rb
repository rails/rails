module Arel
  class Skip < Compound
    attr_reader :relation, :skipped

    def initialize relation, skipped
      super(relation)
      @skipped = skipped
    end

    def eval
      unoperated_rows[skipped..-1]
    end
  end
end
