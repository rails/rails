module ActiveRecord::ConnectionAdapters::Type
  class DateTime < Timestamp
    def type
      :datetime
    end
  end
end
