module ActiveRecord
  module CollectionCacheKey
    def collection_cache_key(collection = all, timestamp_column = :updated_at) # :nodoc:
      model_signature = collection.model_name.cache_key

      original_sql = collection.to_sql
      unscope_order_sql = collection.unscope(:order).to_sql

      order_fields = (original_sql.split(" ") - unscope_order_sql.split(" ")).delete_if { |i| ["ORDER", "BY", "desc", "asc", "desc,", "asc,"].include?(i) }
      unique_signature = collection.pluck(*([primary_key, timestamp_column] + order_fields)).map { |c| c.slice(0, 2) }.flatten.join("-".freeze)

      "#{model_signature}/collection-digest-#{Digest::SHA256.hexdigest(unique_signature)}"
    end
  end
end
