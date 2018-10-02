# frozen_string_literal: true

module ActiveRecord
  module CollectionCacheKey
    def collection_cache_key(collection = all, timestamp_column = :updated_at) # :nodoc:
      query_signature = ActiveSupport::Digest.hexdigest(collection.to_sql)
      key = "#{collection.model_name.cache_key}/query-#{query_signature}"

      if collection.loaded? || collection.distinct_value
        size = collection.records.size
        if size > 0
          timestamp = collection.max_by(&timestamp_column)._read_attribute(timestamp_column)
        end
      else
        if collection.eager_loading?
          collection = collection.send(:apply_join_dependency)
        end
        column_type = type_for_attribute(timestamp_column)
        column = connection.visitor.compile(collection.arel_attribute(timestamp_column))
        select_values = "COUNT(*) AS #{connection.quote_column_name("size")}, MAX(%s) AS timestamp"

        if collection.has_limit_or_offset?
          query = collection.select(column)
          subquery_alias = "subquery_for_cache_key"
          subquery_column = "#{subquery_alias}.#{timestamp_column}"
          subquery = query.arel.as(subquery_alias)
          arel = Arel::SelectManager.new(subquery).project(select_values % subquery_column)
        else
          query = collection.unscope(:order)
          query.select_values = [select_values % column]
          arel = query.arel
        end

        result = connection.select_one(arel, nil)

        if result.blank?
          size = 0
          timestamp = nil
        else
          size = result["size"]
          timestamp = column_type.deserialize(result["timestamp"])
        end

      end

      if timestamp
        "#{key}-#{size}-#{timestamp.utc.to_s(cache_timestamp_format)}"
      else
        "#{key}-#{size}"
      end
    end
  end
end
