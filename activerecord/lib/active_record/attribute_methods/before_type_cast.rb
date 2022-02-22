# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # See ActiveModel::BeforeTypeCast.
    module BeforeTypeCast
      extend ActiveSupport::Concern
      include ActiveModel::BeforeTypeCast
    end
  end
end
