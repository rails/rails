module ActiveModel
  # == Active \Model \Presence
  #
  # A Module that explicitly defines `present?` and `blank?`.
  module Presence
    # Every model object is present:
    #
    #   Model.new.present?  #=> true
    #
    # @return [true]
    def present?
      true
    end

    # No model object is blank:
    #
    #   Model.new.blank?  #=> false
    #
    # @return [false]
    def blank?
      false
    end
  end
end
