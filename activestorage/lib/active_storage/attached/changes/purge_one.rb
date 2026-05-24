# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::PurgeOne # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

    attr_reader :name, :record, :attachment

    def initialize(name, record, attachment)
      @name, @record, @attachment = name, record, attachment
    end

    def purge
      attachment&.purge
      reset_attachment
    end

    def purge_later
      attachment&.purge_later
      reset_attachment
    end
  end
end
