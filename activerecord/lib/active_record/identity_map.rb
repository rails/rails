module ActiveRecord
  module IdentityMap
    extend ActiveSupport::Concern

    class << self
      attr_accessor :repositories
      attr_accessor :current_repository_name
      attr_accessor :enabled

      def current
        repositories[current_repository_name] ||= Weakling::WeakHash.new
      end

      def with_repository(name = :default)
        old_repository = self.current_repository_name
        self.current_repository_name = name

        yield if block_given?
      ensure
        self.current_repository_name = old_repository
      end

      def without
        old, self.enabled = self.enabled, false

        yield if block_given?
      ensure
        self.enabled = old
      end

      def get(class_name, primary_key)
        current[[class_name, primary_key]]
      end

      def add(record)
        current[[record.class.name, record.id]] = record
      end

      def remove(record)
        current.delete([record.class.name, record.id])
      end

      def clear
        current.clear
      end

      alias enabled? enabled
    end

    self.repositories ||= Hash.new
    self.current_repository_name ||= :default
    self.enabled = true

    module InstanceMethods

    end

    module ClassMethods
      def identity_map
        ActiveRecord::IdentityMap
      end
    end
  end
end
