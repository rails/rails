# frozen_string_literal: true

require "active_support/deprecation"

module Rails
  # Implements the logic behind <tt>Rails::Command::NotesCommand</tt>. See <tt>rails notes --help</tt> for usage information.
  #
  # Annotation objects are triplets <tt>:line</tt>, <tt>:tag</tt>, <tt>:text</tt> that
  # represent the line where the annotation lives, its tag, and its text. Note
  # the filename is not stored.
  #
  # Annotations are looked for in comments and modulus whitespace they have to
  # start with the tag optionally followed by a colon. Everything up to the end
  # of the line (or closing ERB comment tag) is considered to be their text.
  class SourceAnnotationExtractor
    class Annotation < Struct.new(:line, :tag, :text)
      def self.directories
        @@directories ||= %w(app config db lib test)
      end

      # Registers additional directories to be included
      #   Rails::SourceAnnotationExtractor::Annotation.register_directories("spec", "another")
      def self.register_directories(*dirs)
        directories.push(*dirs)
      end

      def self.tags
        @@tags ||= %w(OPTIMIZE FIXME TODO)
      end

      # Registers additional tags
      #   Rails::SourceAnnotationExtractor::Annotation.register_tags("TESTME", "DEPRECATEME")
      def self.register_tags(*additional_tags)
        tags.push(*additional_tags)
      end

      def self.extensions
        @@extensions ||= {}
      end

      # Registers new Annotations File Extensions
      #   Rails::SourceAnnotationExtractor::Annotation.register_extensions("css", "scss", "sass", "less", "js") { |tag| /\/\/\s*(#{tag}):?\s*(.*)$/ }
      def self.register_extensions(*exts, &block)
        extensions[/\.(#{exts.join("|")})$/] = block
      end

      register_extensions("builder", "rb", "rake", "yml", "yaml", "ruby") { |tag| /#\s*(#{tag}):?\s*(.*)$/ }
      register_extensions("css", "js") { |tag| /\/\/\s*(#{tag}):?\s*(.*)$/ }
      register_extensions("erb") { |tag| /<%\s*#\s*(#{tag}):?\s*(.*?)\s*%>/ }

      # Returns a representation of the annotation that looks like this:
      #
      #   [126] [TODO] This algorithm is simple and clearly correct, make it faster.
      #
      # If +options+ has a flag <tt>:tag</tt> the tag is shown as in the example above.
      # Otherwise the string contains just line and text.
      def to_s(options = {})
        s = +"[#{line.to_s.rjust(options[:indent])}] "
        s << "[#{tag}] " if options[:tag]
        s << text
      end

      # Used in annotations.rake
      #:nodoc:
      def self.notes_task_deprecation_warning
        ActiveSupport::Deprecation.warn("This rake task is deprecated and will be removed in Rails 6.1. \nRefer to `rails notes --help` for more information.\n")
        puts "\n"
      end
    end

    # Prints all annotations with tag +tag+ under the root directories +app+,
    # +config+, +db+, +lib+, and +test+ (recursively).
    #
    # If +tag+ is <tt>nil</tt>, annotations with either default or registered tags are printed.
    #
    # Specific directories can be explicitly set using the <tt>:dirs</tt> key in +options+.
    #
    #   Rails::SourceAnnotationExtractor.enumerate 'TODO|FIXME', dirs: %w(app lib), tag: true
    #
    # If +options+ has a <tt>:tag</tt> flag, it will be passed to each annotation's +to_s+.
    #
    # See <tt>#find_in</tt> for a list of file extensions that will be taken into account.
    #
    # This class method is the single entry point for the `rails notes` command.
    def self.enumerate(tag = nil, options = {})
      tag ||= Annotation.tags.join("|")
      extractor = new(tag)
      dirs = options.delete(:dirs) || Annotation.directories
      extractor.display(extractor.find(dirs), options)
    end

    attr_reader :tag

    def initialize(tag)
      @tag = tag
    end

    # Returns a hash that maps filenames under +dirs+ (recursively) to arrays
    # with their annotations.
    def find(dirs)
      dirs.inject({}) { |h, dir| h.update(find_in(dir)) }
    end

    # Returns a hash that maps filenames under +dir+ (recursively) to arrays
    # with their annotations. Files with extensions registered in
    # <tt>Rails::SourceAnnotationExtractor::Annotation.extensions</tt> are
    # taken into account. Only files with annotations are included.
    def find_in(dir)
      results = {}

      Dir.glob("#{dir}/*") do |item|
        next if File.basename(item)[0] == ?.

        if File.directory?(item)
          results.update(find_in(item))
        else
          extension = Annotation.extensions.detect do |regexp, _block|
            regexp.match(item)
          end

          if extension
            pattern = extension.last.call(tag)
            results.update(extract_annotations_from(item, pattern)) if pattern
          end
        end
      end

      results
    end

    # If +file+ is the filename of a file that contains annotations this method returns
    # a hash with a single entry that maps +file+ to an array of its annotations.
    # Otherwise it returns an empty hash.
    def extract_annotations_from(file, pattern)
      lineno = 0
      result = File.readlines(file, encoding: Encoding::BINARY).inject([]) do |list, line|
        lineno += 1
        next list unless line =~ pattern
        list << Annotation.new(lineno, $1, $2)
      end
      result.empty? ? {} : { file => result }
    end

    # Prints the mapping from filenames to annotations in +results+ ordered by filename.
    # The +options+ hash is passed to each annotation's +to_s+.
    def display(results, options = {})
      options[:indent] = results.flat_map { |f, a| a.map(&:line) }.max.to_s.size
      results.keys.sort.each do |file|
        puts "#{file}:"
        results[file].each do |note|
          puts "  * #{note.to_s(options)}"
        end
        puts
      end
    end
  end
end

# Remove this deprecated class in the next minor version
#:nodoc:
SourceAnnotationExtractor = ActiveSupport::Deprecation::DeprecatedConstantProxy.
  new("SourceAnnotationExtractor", "Rails::SourceAnnotationExtractor")
