# frozen_string_literal: true

require "rails/source_annotation_extractor"

module Rails
  module Command
    class NotesCommand < Base # :nodoc:
      class_option :annotations, aliases: "-a", desc: "Filter by specific annotations, e.g. Foobar TODO", type: :array, default: %w(OPTIMIZE FIXME TODO)

      def perform(*)
        deprecation_warning
        display_annotations
      end

      private
        def display_annotations
          annotations = options[:annotations]
          tag = (annotations.length > 1)

          Rails::SourceAnnotationExtractor.enumerate annotations.join("|"), tag: tag, dirs: directories
        end

        def directories
          Rails::SourceAnnotationExtractor::Annotation.directories + source_annotation_directories
        end

        def deprecation_warning
          return if source_annotation_directories.empty?
          ActiveSupport::Deprecation.warn("`SOURCE_ANNOTATION_DIRECTORIES` will be deprecated in Rails 6.1. You can add default directories by using config.annotations.register_directories instead.")
        end

        def source_annotation_directories
          ENV["SOURCE_ANNOTATION_DIRECTORIES"].to_s.split(",")
        end
    end
  end
end
