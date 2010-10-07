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
        current[[class_name, primary_key.to_s]]
      end

      def add(record)
        current[[record.class.name, record.id.to_s]] = record
      end

      def remove(record)
        current.delete([record.class.name, record.id.to_s])
      end

      def clear
        current.clear
      end

      alias enabled? enabled
      alias identity_map= enabled=
    end

    self.repositories ||= Hash.new
    self.current_repository_name ||= :default
    self.enabled = false

    module InstanceMethods
      # Reinitialize an Identity Map model object from +coder+.
      # +coder+ must contain the attributes necessary for initializing an empty
      # model object.
      def reinit_with(coder)
        @attributes_cache = {}
        dirty = @changed_attributes.keys
        @attributes.update(coder['attributes'].except(*dirty))
        @changed_attributes.update(coder['attributes'].slice(*dirty))
        @changed_attributes.delete_if{|k,v| v.eql? @attributes[k]}

        _run_find_callbacks

        self
      end
    end

    module ClassMethods
      def identity_map
        ActiveRecord::IdentityMap
      end
    end
  end
end
