module ActiveRecord::ConnectionAdapters::Type
  class Text < String
    def type
      :text
    end
  end
end
