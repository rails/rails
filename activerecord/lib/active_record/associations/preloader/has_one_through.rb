# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class HasOneThrough < SingularAssociation #:nodoc:
        include ThroughAssociation
      end
    end
  end
end
