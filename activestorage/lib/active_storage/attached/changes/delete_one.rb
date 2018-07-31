# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DeleteOne #:nodoc:
    attr_reader :name, :record

    def initialize(name, record)
      @name, @record = name, record
    end

    def attachment
      nil
    end

    def save
      record.public_send("#{name}_attachment=", nil)
    end
  end
end
