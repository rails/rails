module ActiveRecord
  module Calculations #:nodoc:
    extend ActiveSupport::Concern

    module ClassMethods
      delegate :count, :average, :minimum, :maximum, :sum, :calculate, :to => :scoped
    end
  end
end
