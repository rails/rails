module ActiveRecord::ConnectionAdapters::Type
  class Binary < Value
    def type
      :binary
    end

    def klass
      ::String
    end

    def binary?
      true
    end
  end
end
