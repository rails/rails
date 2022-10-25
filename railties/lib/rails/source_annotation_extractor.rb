# frozen_string_literal: true

require "ripper"

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
    # Wraps a regular expression that will be tested against each of the source
    # file's comments.
    class ParserExtractor < Struct.new(:pattern)
      class Parser < Ripper
        attr_reader :comments, :pattern

        def initialize(source, pattern:)
          super(source)
          @pattern = pattern
          @comments = []
        end

        def on_comment(value)
          @comments << Annotation.new(lineno, $1, $2) if value =~ pattern
        end
      end

      def annotations(file)
        contents = File.read(file, encoding: Encoding::BINARY)
        parser = Parser.new(contents, pattern: pattern).tap(&:parse)
        parser.error? ? [] : parser.comments
      end
    end

    # Wraps a regular expression that will iterate through a file's lines and
    # test each one for the given pattern.
    class PatternExtractor < Struct.new(:pattern)
      def annotations(file)
        lineno = 0

        File.readlines(file, encoding: Encoding::BINARY).inject([]) do |list, line|
          lineno += 1
          next list unless line =~ pattern
          list << Annotation.new(lineno, $1, $2)
        end
      end
    end

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

      register_extensions("builder", "rb", "rake", "ruby") do |tag|
        ParserExtractor.new(/#\s*(#{tag}):?\s*(.*)$/)
      end

      register_extensions("yml", "yaml") do |tag|
        PatternExtractor.new(/#\s*(#{tag}):?\s*(.*)$/)
      end

      register_extensions("css", "js") do |tag|
        PatternExtractor.new(/\/\/\s*(#{tag}):?\s*(.*)$/)
      end

      register_extensions("erb") do |tag|
        PatternExtractor.new(/<%\s*#\s*(#{tag}):?\s*(.*?)\s*%>/)
      end

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
    # See SourceAnnotationExtractor#find_in for a list of file extensions that will be taken into account.
    #
    # This class method is the single entry point for the <tt>rails notes</tt> command.
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
        next if File.basename(item).start_with?(".")

        if File.directory?(item)
          results.update(find_in(item))
        else
          extension = Annotation.extensions.detect do |regexp, _block|
            regexp.match(item)
          end

          if extension
            pattern = extension.last.call(tag)

            # In case a user-defined pattern returns nothing for the given set
            # of tags, we exit early.
            next unless pattern

            # If a user-defined pattern returns a regular expression, we will
            # wrap it in a PatternExtractor to keep the same API.
            pattern = PatternExtractor.new(pattern) if pattern.is_a?(Regexp)

            annotations = pattern.annotations(item)
            results.update(item => annotations) if annotations.any?
          end
        end
      end

      results
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
