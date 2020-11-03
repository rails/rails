# frozen_string_literal: true

module ActiveRecord
  class DisableJoinsAssociationRelation < Relation # :nodoc:
    TOO_MANY_RECORDS = 5000

    attr_reader :ids, :key

    def initialize(klass, key, ids)
      @ids = ids.uniq
      @key = key
      super(klass)
    end

    def limit(value)
      records.take(value)
    end

    def first(limit = nil)
      if limit
        records.limit(limit).first
      else
        records.first
      end
    end

    def load
      super
      records = @records

      records_by_id = records.group_by do |record|
        record[key]
      end

      records = ids.flat_map { |id| records_by_id[id.to_i] }
      records.compact!

      @records = records
    end
  end
end
