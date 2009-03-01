require 'pathname'

class Pathname
  # Clean the paths contained in the provided string.
  def self.clean_within(string)
    string.gsub(%r{[\w. ]+(/[\w. ]+)+(\.rb)?(\b|$)}) do |path|
      new(path).cleanpath
    end
  end
end
