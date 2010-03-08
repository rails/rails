module ActionView
  class Template
    class Lookup
      attr_reader :details, :view_paths

      class DetailsKey
        attr_reader :details
        alias :eql? :equal?

        @details_keys = Hash.new

        def self.get(details)
          @details_keys[details] ||= new(details)
        end

        def initialize(details)
          @details, @hash = details, details.hash
        end
      end

      def initialize(view_paths, details = {})
        @details = details
        self.view_paths = view_paths
      end

      def formats
        @details[:formats]
      end

      def formats=(value)
        self.details = @details.merge(:formats => Array(value))
      end

      def view_paths=(paths)
        @view_paths = ActionView::Base.process_view_paths(paths)
      end

      def details=(details)
        @details = details
        @details_key = nil if @details_key && @details_key.details != details
      end

      def details_key
        @details_key ||= DetailsKey.get(details) unless details.empty?
      end

      def find(name, prefix = nil, partial = false)
        @view_paths.find(name, details, prefix, partial || false, details_key)
      end

      def exists?(name, prefix = nil, partial = false)
        @view_paths.exists?(name, details, prefix, partial || false, details_key)
      end
    end
  end
end