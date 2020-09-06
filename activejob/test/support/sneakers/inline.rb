# frozen_string_literal: true

require 'sneakers'
require 'active_support/core_ext/module/redefine_method'

module Sneakers
  module Worker
    module ClassMethods
      redefine_method(:enqueue) do |msg|
        worker = new(nil, nil, {})
        worker.work(*msg)
      end
    end
  end
end
