# rails/activesupport/lib/active_support/core_ext/array
#                                                   ├── access.rb
#                                                   ├── conversions.rb
#                                                   ├── extract_options.rb
#                                                   ├── grouping.rb
#                                                   ├── inquiry.rb
#                                                   ├── prepend_and_append.rb
#                                                   └── wrap.rb
#
# If you want to require all files in the array directory,
# you can use Kernel.require(file) like below as always.
#
# rails/activesupport/lib/active_support/core_ext/array.rb
#   require 'active_support/core_ext/array/access'
#   require 'active_support/core_ext/array/conversions'
#   require 'active_support/core_ext/array/extract_options'
#   require 'active_support/core_ext/array/grouping'
#   require 'active_support/core_ext/array/inquiry'
#   require 'active_support/core_ext/array/prepend_and_append'
#   require 'active_support/core_ext/array/wrap'
#
# Or, you can use Requirer#require_all.
#   Requirer.new(__FILE__).require_all
#
# If the first parameter of Requirer constructor is "/path/to/example.rb",
# all files will be required recursively which are in "/path/to/example".
#
# Of course, you can exclude file(s) like this.
#   Requirer.new(__FILE__, exclude: ['access', 'wrap']).require_all
#     Or
#   Requirer.new(__FILE__).require_all(exclude: ['access', 'wrap'])
#
class Requirer
  DEFAULT_EXTENSION = '.rb'.freeze

  def initialize(file, exclude: [])
    @cwd      = dir(file)
    @excluded = normalize_files(exclude)
  end

  def require_all(exclude: [])
    @excluded += normalize_files(exclude)

    files =
      Dir.glob(@cwd / "**/*#{Regexp.escape(DEFAULT_EXTENSION)}") -
      @excluded.append_extension

    files.each { |f| Kernel.require f }
  end

  private

  def dir(file)
    directory =
      Pathname(
        File
        .absolute_path(file)
        .sub(/#{Regexp.new(DEFAULT_EXTENSION)}$/, ''))

    return directory if directory.directory?
    raise LoadError, "directory \"#{directory}\" does not exist."
  end

  def normalize_files(files)
    files.map do |file|
      (@cwd / file.sub(/#{Regexp.escape(DEFAULT_EXTENSION)}$/, '')).to_s
    end
  end
end

# Define Array#append_extension(extension = '.rb')
# which does append the extension to each string element.
#
# [1, [], 'hogerb', 'fuga.rb'].append_extension
# => [1, [], 'hogerb.rb', 'fuga.rb']
#
class Array
  method_name = :append_extension

  if instance_methods(false).include? method_name
    raise NameError, "##{method_name} has already been defined."
  else
    define_method method_name do |ext = '.rb'|
      map do |elm|
        if elm.is_a?(String) && elm !~ /#{Regexp.escape(ext)}$/
          elm + ext
        else
          elm
        end
      end
    end
  end
end
