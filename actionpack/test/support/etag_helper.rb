# frozen_string_literal: true

module EtagHelper
  def weak_etag(record)
    "W/#{strong_etag record}"
  end

  def strong_etag(record)
    %("#{ActiveSupport::Digest.hexdigest(ActiveSupport::Cache.expand_cache_key(record))}")
  end
end
