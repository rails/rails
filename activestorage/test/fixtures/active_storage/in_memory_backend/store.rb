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

      define_model_callbacks :save, :destroy, :commit, :rollback

      class_attribute :store, instance_accessor: false, default: Concurrent::Map.new
      class_attribute :id_sequence, instance_accessor: false, default: Concurrent::AtomicFixnum.new(0)
      class_attribute :storage_attributes, instance_accessor: false, default: %i[id created_at]

      attr_accessor :id, :created_at
    end

    class_methods do
      def records
        store.values.map { |attributes| new(attributes.deep_dup) }
      end

      def reset
        store.clear
        self.id_sequence = Concurrent::AtomicFixnum.new(0)
      end

      def find(id)
        attributes = store.fetch(id.to_i) { raise ActiveStorage::RecordNotFound, "#{name} not found: #{id}" }
        new(attributes.deep_dup)
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
      return false unless valid?
      Transaction.enlist(self)
      saved = run_callbacks(:save) do
        self.id ||= self.class.id_sequence.increment
        self.created_at ||= Time.current
        self.class.store[id] = attributes_for_persistence.deep_dup
        true
      end
      return false unless saved

      Transaction.committed(self)
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
      Transaction.enlist(self)
      @previously_persisted = persisted?
      destroyed = run_callbacks(:destroy) do
        self.class.store.delete(id)
        true
      end
      return false unless destroyed

      Transaction.committed(self)
      true
    end

    def delete
      Transaction.enlist(self)
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

    def reload
      assign_attributes(self.class.find(id).send(:attributes_for_persistence))
      self
    end

    def ==(other)
      other.instance_of?(self.class) && id.present? && id == other.id
    end

    private
      def attributes_for_persistence
        self.class.storage_attributes.index_with { |attribute| public_send(attribute) }
      end
  end
end
