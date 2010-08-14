# ---------------------------------------------------------------------------
#
# This script validates the generated guides against the W3C Validator.
#
# Guides are taken from the output directory, from where all .html files are
# submitted to the validator.
#
# This script is prepared to be launched from the railties directory as a rake task:
#
# rake validate_guides
#
# If nothing is specified, all files will be validated, but you can check just
# some of them using this environment variable:
#
#   ONLY
#     Use ONLY if you want to validate only one or a set of guides. Prefixes are
#     enough:
#
#       # validates only association_basics.html
#       ONLY=assoc rake validate_guides
#
#     Separate many using commas:
#
#       # validates only
#       ONLY=assoc,migrations rake validate_guides
#
# ---------------------------------------------------------------------------

require 'rubygems'
require 'w3c_validators'
include W3CValidators

module RailsGuides
  class Validator

    def validate
      validator = MarkupValidator.new
      STDOUT.sync = true
      errors_on_guides = {}

      guides_to_validate.each do |f|
        results = validator.validate_file(f)

        if results.validity
          print "."
        else
          print "E"
          errors_on_guides[f] = results.errors
        end
      end

      show_results(errors_on_guides)
    end

    private
    def guides_to_validate
      guides = Dir["./guides/output/*.html"]
      guides.delete("./guides/output/layout.html")
      ENV.key?('ONLY') ? select_only(guides) : guides
    end

    def select_only(guides)
      prefixes = ENV['ONLY'].split(",").map(&:strip)
      guides.select do |guide|
        prefixes.any? {|p| guide.start_with?("./guides/output/#{p}")}
      end
    end

    def show_results(error_list)
      if error_list.size == 0
        puts "\n\nAll checked guides validate OK!"
      else
        error_summary = error_detail = ""

        error_list.each_pair do |name, errors|
          error_summary += "\n  #{name}"
          error_detail += "\n\n  #{name} has #{errors.size} validation error(s):\n"
          errors.each do |error|
            error_detail += "\n    "+error.to_s.gsub("\n", "")
          end
        end

        puts "\n\nThere are #{error_list.size} guides with validation errors:\n" + error_summary
        puts "\nHere are the detailed errors for each guide:" + error_detail
      end
    end

  end
end

RailsGuides::Validator.new.validate