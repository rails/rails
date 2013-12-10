# Implements the logic behind the rake tasks for annotations like
#
#   rake notes
#   rake notes:optimize
#
# and friends. See <tt>rake -T notes</tt> and <tt>railties/lib/tasks/annotations.rake</tt>.
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
      @@directories ||= %w(app config db lib test) + (ENV['SOURCE_ANNOTATION_DIRECTORIES'] || '').split(',')
    end

    # Returns a representation of the annotation that looks like this:
    #
    #   [126] [TODO] This algorithm is simple and clearly correct, make it faster.
    #
    # If +options+ has a flag <tt>:tag</tt> the tag is shown as in the example above.
    # Otherwise the string contains just line and text.
    def to_s(options={})
      s = "[#{line.to_s.rjust(options[:indent])}] "
      s << "[#{tag}] " if options[:tag]
      s << text
    end
  end

  # Prints all annotations with tag +tag+ under the root directories +app+,
  # +config+, +db+, +lib+, and +test+ (recursively).
  #
  # Additional directories may be added using a comma-delimited list set using
  # <tt>ENV['SOURCE_ANNOTATION_DIRECTORIES']</tt>.
  #
  # Directories may also be explicitly set using the <tt>:dirs</tt> key in +options+.
  #
  #   SourceAnnotationExtractor.enumerate 'TODO|FIXME', dirs: %w(app lib), tag: true
  #
  # If +options+ has a <tt>:tag</tt> flag, it will be passed to each annotation's +to_s+.
  #
  # See <tt>#find_in</tt> for a list of file extensions that will be taken into account.
  #
  # This class method is the single entry point for the rake tasks.
  def self.enumerate(tag, options={})
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
  # with their annotations. Only files with annotations are included. Files
  # with extension +.builder+, +.rb+, +.erb+, +.haml+, +.slim+, +.css+,
  # +.scss+, +.js+, +.coffee+, +.rake+, +.sass+ and +.less+
  # are taken into account.
  def find_in(dir)
    results = {}

    Dir.glob("#{dir}/*") do |item|
      next if File.basename(item)[0] == ?.

      if File.directory?(item)
        results.update(find_in(item))
      else
        pattern =
            case item
            when /\.(builder|rb|coffee|rake)$/
              /#\s*(#{tag}):?\s*(.*)$/
            when /\.(css|scss|sass|less|js)$/
              /\/\/\s*(#{tag}):?\s*(.*)$/
            when /\.erb$/
              /<%\s*#\s*(#{tag}):?\s*(.*?)\s*%>/
            when /\.haml$/
              /-\s*#\s*(#{tag}):?\s*(.*)$/
            when /\.slim$/
              /\/\s*\s*(#{tag}):?\s*(.*)$/
            else nil
            end
        results.update(extract_annotations_from(item, pattern)) if pattern
      end
    end

    results
  end

  # If +file+ is the filename of a file that contains annotations this method returns
  # a hash with a single entry that maps +file+ to an array of its annotations.
  # Otherwise it returns an empty hash.
  def extract_annotations_from(file, pattern)
    lineno = 0
    result = File.readlines(file).inject([]) do |list, line|
      lineno += 1
      next list unless line =~ pattern
      list << Annotation.new(lineno, $1, $2)
    end
    result.empty? ? {} : { file => result }
  end

  # Prints the mapping from filenames to annotations in +results+ ordered by filename.
  # The +options+ hash is passed to each annotation's +to_s+.
  def display(results, options={})
    options[:indent] = results.map { |f, a| a.map(&:line) }.flatten.max.to_s.size
    results.keys.sort.each do |file|
      puts "#{file}:"
      results[file].each do |note|
        puts "  * #{note.to_s(options)}"
      end
      puts
    end
  end
end
