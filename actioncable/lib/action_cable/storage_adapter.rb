module ActionCable
  module StorageAdapter
    autoload :Base, 'action_cable/storage_adapter/base'
    autoload :Postgres, 'action_cable/storage_adapter/postgres'
    autoload :Redis, 'action_cable/storage_adapter/redis'
  end
end
