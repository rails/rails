module ActionCable
  module StorageAdapter
    autoload :Base, 'action_cable/storage_adapter/base'
    autoload :PostgreSQL, 'action_cable/storage_adapter/postgresql'
    autoload :Redis, 'action_cable/storage_adapter/redis'
  end
end
