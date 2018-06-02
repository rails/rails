# frozen_string_literal: true

require "rails/source_annotation_extractor"

desc "Enumerate all annotations (use notes:optimize, :fixme, :todo for focus)"
task :notes do
  Rails::SourceAnnotationExtractor.enumerate "OPTIMIZE|FIXME|TODO", tag: true
end

namespace :notes do
  ["OPTIMIZE", "FIXME", "TODO"].each do |annotation|
    # desc "Enumerate all #{annotation} annotations"
    task annotation.downcase.intern do
      Rails::SourceAnnotationExtractor.enumerate annotation
    end
  end

  desc "Enumerate a custom annotation, specify with ANNOTATION=CUSTOM"
  task :custom do
    Rails::SourceAnnotationExtractor.enumerate ENV["ANNOTATION"]
  end
end
