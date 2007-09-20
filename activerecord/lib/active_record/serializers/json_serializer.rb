module ActiveRecord #:nodoc:
  module Serialization
    def to_json(options = {}, &block)
      JsonSerializer.new(self, options).to_s
    end

    def from_json(json)
      self.attributes = ActiveSupport::JSON.decode(json)
      self
    end

    class JsonSerializer < ActiveRecord::Serialization::Serializer #:nodoc:
      def serialize
        serializable_record.to_json
      end
    end
  end
end
