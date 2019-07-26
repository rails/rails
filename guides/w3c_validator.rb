# frozen_string_literal: true

# ---------------------------------------------------------------------------
#
# This script validates the generated guides against the W3C Validator.
#
# Guides are taken from the output directory, from where all .html files are
# submitted to the validator.
#
# This script is prepared to be launched from the guides directory as a rake task:
#
# rake guides:validate
#
# If nothing is specified, all files will be validated, but you can check just
# some of them using this environment variable:
#
#   ONLY
#     Use ONLY if you want to validate only one or a set of guides. Prefixes are
#     enough:
#
#       # validates only association_basics.html
#       rake guides:validate ONLY=assoc
#
#     Separate many using commas:
#
#       # validates only association_basics.html and command_line.html
#       rake guides:validate ONLY=assoc,command
#
# ---------------------------------------------------------------------------

require "w3c_validators"
include W3CValidators

module RailsGuides
  class Validator
    def validate
      # https://github.com/w3c-validators/w3c_validators/issues/25
      validator = NuValidator.new
      STDOUT.sync = true
      errors_on_guides = {}

      guides_to_validate.each do |f|
        begin
          results = validator.validate_file(f)
        rescue Exception => e
          puts "\nCould not validate #{f} because of #{e}"
          next
        end

        if results.errors.length > 0
          print "E"
          errors_on_guides[f] = results.errors
        else
          print "."
        end
      end

      show_results(errors_on_guides)
    end

    private
      def guides_to_validate
        guides = Dir["./output/*.html"]
        guides.delete("./output/layout.html")
        guides.delete("./output/_license.html")
        guides.delete("./output/_welcome.html")
        ENV.key?("ONLY") ? select_only(guides) : guides
      end

      def select_only(guides)
        prefixes = ENV["ONLY"].split(",").map(&:strip)
        guides.select do |guide|
          prefixes.any? { |p| guide.start_with?("./output/#{p}") }
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
              error_detail += "\n    " + error.to_s.delete("\n")
            end
          end

          puts "\n\nThere are #{error_list.size} guides with validation errors:\n" + error_summary
          puts "\nHere are the detailed errors for each guide:" + error_detail
        end
      end
  end
end

RailsGuides::Validator.new.validate
