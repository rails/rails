# frozen_string_literal: true

module ActiveStorage::InMemoryBackend
  module Store
    extend ActiveSupport::Concern

    module Persistence
      def persisted?
        id.present? && self.class.store.key?(id)
      end

      def new_record?
        !persisted?
      end
    end

    included do
      include ActiveModel::Model
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks
      include GlobalID::Identification
      extend ActiveModel::Callbacks
      prepend Persistence

      define_model_callbacks :save, :destroy, :commit

      class_attribute :store, instance_accessor: false, default: Concurrent::Map.new
      class_attribute :id_sequence, instance_accessor: false, default: Concurrent::AtomicFixnum.new(0)

      attr_accessor :id, :created_at
    end

    class_methods do
      def records
        store.values
      end

      def reset
        store.clear
        self.id_sequence = Concurrent::AtomicFixnum.new(0)
      end

      def find(id)
        store.fetch(id.to_i) { raise ActiveStorage::RecordNotFound, "#{name} not found: #{id}" }
      end

      def find_by(attributes)
        where(attributes).first
      end

      def where(attributes = {})
        Relation.new(self).where(attributes)
      end

      def transaction
        yield
      end
    end

    def save
      self.id ||= self.class.id_sequence.increment
      self.created_at ||= Time.current
      run_callbacks(:save) { self.class.store[id] = self }
      run_callbacks(:commit) { true }
      true
    end

    def save!
      save || raise(ActiveStorage::RecordNotSaved.new("Failed to save #{self.class.name}", self))
    end

    def update!(attributes)
      assign_attributes(attributes)
      save!
    end

    def destroy
      @previously_persisted = persisted?
      run_callbacks(:destroy) { self.class.store.delete(id) }
      run_callbacks(:commit) { true }
      true
    end

    def delete
      @previously_persisted = persisted?
      self.class.store.delete(id)
      true
    end

    def previously_persisted?
      @previously_persisted
    end

    def assign_attributes(attributes)
      attributes.each { |name, value| public_send("#{name}=", value) }
    end

    def ==(other)
      other.instance_of?(self.class) && id.present? && id == other.id
    end
  end
end
