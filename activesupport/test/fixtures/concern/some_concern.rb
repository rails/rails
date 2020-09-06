# frozen_string_literal: true

require 'active_support/concern'

module SomeConcern
  extend ActiveSupport::Concern

  included do
    # shouldn't raise when module is loaded more than once
  end

  prepended do
    # shouldn't raise when module is loaded more than once
  end
end
