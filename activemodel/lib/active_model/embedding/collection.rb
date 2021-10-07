# frozen_string_literal: true

require "active_model/embedding/collecting"

module ActiveModel
  module Embedding
    class Collection
      include Enumerable
      include Embedding::Collecting
    end
  end
end
