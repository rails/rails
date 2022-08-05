# frozen_string_literal: true

module JobBuffer
  class << self
    def clear
      values.clear
    end

    def add(value)
      values << value
    end

    def values
      @values ||= []
    end

    def last_value
      values.last
    end
  end
end

class ActiveSupport::TestCase
  teardown do
    JobBuffer.clear
  end
end
