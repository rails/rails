# frozen_string_literal: true

class Project < ActiveRecord::Base
  has_and_belongs_to_many :developers, -> { uniq }

  def self.collection_cache_key(collection = all, _timestamp_column = :updated_at)
    "projects-#{collection.count}"
  end
end
