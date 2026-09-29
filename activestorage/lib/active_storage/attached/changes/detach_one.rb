# frozen_string_literal: true

module ActiveStorage
  class Attached::Changes::DetachOne # :nodoc:
    include ActiveStorage::Attached::Changes::OwnerDispatch

    attr_reader :name, :record, :attachment

    def initialize(name, record, attachment)
      @name, @record, @attachment = name, record, attachment
    end

    def detach
      if attachment.present?
        attachment.delete
        reset_attachment
      end
    end
  end
end
