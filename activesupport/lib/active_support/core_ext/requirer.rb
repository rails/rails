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
# you can use Kernel.require(file) like below.
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
# Or, you can use Requirer#require.
#   Requirer.new(__FILE__).require
#
# Of course, you can exclude file(s) like this.
#   Requirer.new(__FILE__, exclude: ['access', 'wrap']).require
#     Or
#   Requirer.new(__FILE__).require(exclude: ['access', 'wrap'])
#
class Requirer
  DEFAULT_EXTENSION = '.rb'.freeze
  def initialize(file, exclude: [])
    @cwd      = dir(file)
    @excluded = normalize_files(exclude)
  end

  def require(exclude: [])
    @excluded += normalize_files(exclude)

    files =
      Dir.glob(@cwd / "**/*#{Regexp.escape(DEFAULT_EXTENSION)}") -
      @excluded.append_extension

    files.each { |f| Kernel.require f }
  end

  private

  def dir(file)
    Pathname(
      File
      .absolute_path(file)
      .sub(/#{Regexp.new(DEFAULT_EXTENSION)}$/, ''))
  end

  def normalize_files(files)
    files.map do |file|
      (@cwd / file.sub(/#{Regexp.escape(DEFAULT_EXTENSION)}$/, '')).to_s
    end
  end
end

class Array
  def append_extension(ext = '.rb')
    map do |elm|
      if elm.is_a?(String) && elm !~ /#{Regexp.new(ext)}$/
        elm + ext
      else
        elm
      end
    end
  end
end
