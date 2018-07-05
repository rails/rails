# frozen_string_literal: true

require "rails/source_annotation_extractor"

task :notes do
  Rails::SourceAnnotationExtractor::Annotation.notes_task_deprecation_warning
  Rails::Command.invoke :notes
end

namespace :notes do
  ["OPTIMIZE", "FIXME", "TODO"].each do |annotation|
    task annotation.downcase.intern do
      Rails::SourceAnnotationExtractor::Annotation.notes_task_deprecation_warning
      Rails::Command.invoke :notes, ["--annotations", annotation]
    end
  end

  task :custom do
    Rails::SourceAnnotationExtractor::Annotation.notes_task_deprecation_warning
    Rails::Command.invoke :notes, ["--annotations", ENV["ANNOTATION"]]
  end
end
