# frozen_string_literal: true

require "active_model"

module ActiveStorage::ActiveModelOwnerFixture
  def self.define!(name: "ActiveModelOwner", commit_callbacks: true, rollback_callbacks: false, dirty: true)
    # Tests call this from one process at a time; constant replacement is not
    # intended to be used concurrently across parallel test workers.
    Object.send(:remove_const, name) if Object.const_defined?(name, false)

    owner_class = Class.new do
      include ActiveModel::Model
      include ActiveModel::Validations
      include ActiveModel::Validations::Callbacks
      include ActiveModel::Attributes
      include ActiveStorage::Attached::Model
      include ActiveModel::Dirty if dirty
      extend ActiveModel::Callbacks

      define_model_callbacks :save, :destroy
      define_model_callbacks :commit if commit_callbacks
      define_model_callbacks :rollback if rollback_callbacks

      attribute :id, :integer
      attribute :name, :string
      attribute :region, :string

      define_attribute_methods :name if dirty

      validates :name, presence: true

      class << self
        attr_accessor :store, :id_sequence

        def find(id)
          attributes = store.fetch(id.to_i) { raise ActiveStorage::RecordNotFound, "#{name} not found: #{id}" }
          new(attributes.deep_dup).tap do |owner|
            owner.instance_variable_set(:@persisted, true)
            owner.clear_changes_information if owner.respond_to?(:clear_changes_information)
          end
        end

        def reset
          self.store = Concurrent::Map.new
          self.id_sequence = Concurrent::AtomicFixnum.new(0)
        end
      end

      def name=(value)
        name_will_change! if respond_to?(:name_will_change!) && value != name
        super
      end

      def persisted?
        @persisted == true && id.present? && self.class.store.key?(id)
      end

      def save
        return false unless valid?

        ActiveStorage::InMemoryBackend::Transaction.enlist(self)
        saved = run_callbacks(:save) do
          self.id ||= self.class.id_sequence.increment
          self.class.store[id] = attributes.deep_dup
          @persisted = true
          changes_applied if respond_to?(:changes_applied)
          true
        end
        return false unless saved

        ActiveStorage::InMemoryBackend::Transaction.committed(self)
        true
      end

      def save!
        save || raise(ActiveStorage::RecordNotSaved.new("Failed to save the record", self))
      end

      def destroy
        ActiveStorage::InMemoryBackend::Transaction.enlist(self)
        destroyed = run_callbacks(:destroy) do
          next false unless persisted?

          self.class.store.delete(id)
          @persisted = false
          true
        end
        return false unless destroyed

        ActiveStorage::InMemoryBackend::Transaction.committed(self)
        true
      end

      def reload
        assign_attributes(self.class.find(id).attributes)
        @persisted = true
        clear_changes_information if respond_to?(:clear_changes_information)
        super
      end

      def initialize_dup(*)
        super
        self.id = nil
        @persisted = false
      end

      def regional_service_name
        :"disk_#{region}"
      end
    end

    Object.const_set(name, owner_class)
    owner_class.reset

    owner_class.has_one_attached :avatar
    owner_class.has_one_attached :icon, dependent: :purge
    owner_class.has_one_attached :cover_photo, dependent: false
    owner_class.has_one_attached :regional_avatar, service: ->(owner) { owner.regional_service_name }
    owner_class.has_one_attached :avatar_with_immediate_analysis, analyze: :immediately
    owner_class.has_one_attached :avatar_with_later_analysis, analyze: :later
    owner_class.has_one_attached :avatar_with_lazy_analysis, analyze: :lazily
    owner_class.has_one_attached :avatar_with_variants do |attachable|
      attachable.variant :thumb, resize_to_limit: [ 1, 1 ]
    end
    owner_class.has_many_attached :photos
    owner_class.has_many_attached :favorites, dependent: :purge
    owner_class.has_many_attached :documents, dependent: false

    owner_class
  end
end
