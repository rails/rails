module ActiveRecord
  module CollectionCacheKey

    def collection_cache_key(collection = all, timestamp_column = :updated_at) # :nodoc:
      query_signature = Digest::MD5.hexdigest(collection.to_sql)
      key = "#{collection.model_name.cache_key}/query-#{query_signature}"

      if collection.loaded?
        size = collection.size
        if size > 0
          timestamp = collection.max_by(&timestamp_column)._read_attribute(timestamp_column)
        end
      else
        column_type = type_for_attribute(timestamp_column.to_s)
        column = "#{connection.quote_table_name(collection.table_name)}.#{connection.quote_column_name(timestamp_column)}"
        select_values = "COUNT(*) AS #{connection.quote_column_name("size")}, MAX(%s) AS timestamp"

        if collection.limit_value || collection.offset_value
          query = collection.spawn
          query.select_values = [column]
          subquery_alias = "subquery_for_cache_key"
          subquery_column = "#{subquery_alias}.#{timestamp_column}"
          subquery = query.arel.as(subquery_alias)
          arel = Arel::SelectManager.new(query.engine).project(select_values % subquery_column).from(subquery)
        else
          query = collection.unscope(:order)
          query.select_values = [select_values % column]
          arel = query.arel
        end

        result = connection.select_one(arel, nil, query.bound_attributes)

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
