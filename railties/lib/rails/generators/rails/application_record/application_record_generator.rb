# frozen_string_literal: true

module Rails
  module Generators
    class ApplicationRecordGenerator < Base # :nodoc:
      hook_for :orm, required: true, desc: "ORM to be invoked"

      class << self
        delegate(:desc, to: :orm_generator)
      end
    end
  end
end
