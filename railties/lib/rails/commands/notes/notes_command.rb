# frozen_string_literal: true

require "rails/source_annotation_extractor"

module Rails
  module Command
    class NotesCommand < Base # :nodoc:
      class_option :annotations, aliases: "-a", desc: "Filter by specific annotations, e.g. Foobar TODO", type: :array

      desc "notes", "Show comments in your code annotated with FIXME, OPTIMIZE, and TODO"
      def perform(*)
        boot_application!

        display_annotations
      end

      private
        def display_annotations
          annotations = options[:annotations] || Rails::SourceAnnotationExtractor::Annotation.tags
          tag = (annotations.length > 1)

          Rails::SourceAnnotationExtractor.enumerate annotations.join("|"), tag: tag, dirs: directories
        end

        def directories
          Rails::SourceAnnotationExtractor::Annotation.directories
        end
    end
  end
end
