# frozen_string_literal: true

module ActiveRecord
  module Associations
    class Preloader
      class HasManyThrough < CollectionAssociation #:nodoc:
        include ThroughAssociation
      end
    end
  end
end
