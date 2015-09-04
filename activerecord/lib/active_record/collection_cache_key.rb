module ActiveRecord
  module CollectionCacheKey

    def collection_cache_key(collection = all, timestamp_column = :updated_at) # :nodoc:
      model_signature = collection.model_name.cache_key
      unique_signature = collection.pluck(primary_key, timestamp_column).flatten.join("-")

      "#{model_signature}/collection-digest-#{Digest::SHA256.hexdigest(unique_signature)}"
    end
  end
end
