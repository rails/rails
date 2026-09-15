# frozen_string_literal: true

require "active_model/errors"

module ActiveRecord
  # = Active Record \Errors
  #
  # Subclass of <tt>ActiveModel::Errors</tt> that maps association errors onto
  # the corresponding foreign key so form fields like +select :team_id+ can
  # trigger +field_with_errors+ when the association itself is invalid.
  #
  # Errors are not copied into the collection: iterating still yields the
  # association name (+:team+), while +errors[:team_id]+ and
  # +errors.include?(:team_id)+ read the same messages. Installed by
  # +to_model+ so the mapping is only relevant for views.
  class Errors < ActiveModel::Errors
    def initialize(base, errors = [], aliases = {}) # :nodoc:
      super(base)
      @errors = errors
      @aliases = aliases
    end

    def where(attribute, type = nil, **options) # :nodoc:
      result = super
      canonical = @aliases[attribute.to_sym]
      canonical ? result | super(canonical, type, **options) : result
    end

    def include?(attribute) # :nodoc:
      return true if super

      canonical = @aliases[attribute.to_sym]
      canonical ? super(canonical) : false
    end
  end
end
