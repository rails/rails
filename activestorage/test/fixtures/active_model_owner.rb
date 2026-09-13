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
          store.fetch(id.to_i) { raise ActiveStorage::RecordNotFound, "#{name} not found: #{id}" }
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
        id.present? && self.class.store.key?(id)
      end

      def save
        return false unless valid?

        self.id ||= self.class.id_sequence.increment
        run_callbacks(:save) do
          self.class.store[id] = self
          changes_applied if respond_to?(:changes_applied)
        end
        run_callbacks(:commit) { true } if self.class.respond_to?(:_commit_callbacks, true)
        true
      end

      def save!
        save || raise(ActiveStorage::RecordNotSaved.new("Failed to save the record", self))
      end

      def destroy
        run_callbacks(:destroy) { self.class.store.delete(id) }
        run_callbacks(:commit) { true } if self.class.respond_to?(:_commit_callbacks, true)
        true
      end

      def reload
        super
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
