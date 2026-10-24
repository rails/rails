# frozen_string_literal: true

module ActiveSupport
  # = Null File Update Checker
  #
  # This class is used by \Rails when file watching is disabled in certain environments
  # like console.
  class DisabledFileUpdateChecker
    def initialize(files, dirs = {}, &block)
      unless block
        raise ArgumentError, "A block is required to initialize a DisabledFileUpdateChecker"
      end

      @block = block
    end

    def updated?
      false
    end

    def execute
      @block.call
    end

    def execute_if_updated
      false
    end
  end
end
