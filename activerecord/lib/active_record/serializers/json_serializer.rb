module ActiveRecord #:nodoc:
  module Serialization
    extend ActiveSupport::Concern
    include ActiveModel::Serializers::JSON

    class JSONSerializer < ActiveModel::Serializers::JSON::Serializer
      include Serialization::RecordSerializer
    end

    def encode_json(encoder)
      JSONSerializer.new(self, encoder.options).to_s
    end
  end
end
