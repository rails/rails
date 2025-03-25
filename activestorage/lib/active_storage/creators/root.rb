# frozen_string_literal: true

# = Active Storage \Creators \Root
module ActiveStorage::Creators
  class Root
    class << self
      def call!
        Models.call!
        Controllers.call!
        Routes.call!
        Jobs.call!
      end
    end
  end
end
