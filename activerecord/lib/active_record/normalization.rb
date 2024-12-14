# frozen_string_literal: true

module ActiveRecord # :nodoc:
  module Normalization
    extend ActiveSupport::Concern

    included do
      include ActiveModel::Attributes::Normalization
    end
  end
end
