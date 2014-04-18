require 'active_support/concern'

module SomeModule
  extend ActiveSupport::Concern

  included do
    # shouldn't raise
  end
end
