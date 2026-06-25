# frozen_string_literal: true

module ActionView
  class Template
    module Sources
      class File # :nodoc:
        def initialize(filename)
          @filename = filename
        end

        def to_s
          ::File.binread @filename
        end
      end
    end
  end
end
