# frozen_string_literal: true

require "yaml"

module RailsGuides
  module Helpers
    def guide(name, url, options = {}, &block)
      link = content_tag(:a, href: url) { name }
      result = content_tag(:dt, link)

      if options[:work_in_progress]
        result << content_tag(:dd, "Work in progress", class: "work-in-progress")
      end

      result << content_tag(:dd, capture(&block))
      result
    end

    def documents_by_section
      @documents_by_section ||= YAML.load_file(File.expand_path("../source/#{@language ? @language + '/' : ''}documents.yaml", __dir__))
    end

    def documents_flat
      documents_by_section.flat_map { |section| section["documents"] }
    end

    def finished_documents(documents)
      documents.reject { |document| document["work_in_progress"] }
    end

    def docs_for_menu(position = nil)
      if position.nil?
        documents_by_section
      elsif position == "L"
        documents_by_section.to(3)
      else
        documents_by_section.from(4)
      end
    end

    def code(&block)
      c = capture(&block)
      content_tag(:code, c)
    end
  end
end
