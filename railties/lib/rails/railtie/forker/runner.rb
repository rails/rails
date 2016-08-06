# This class is supposed to be abstract, and all
# runners should make their runner inherit from here
class Rails::Forker::Runner

  attr_reader :options  

  def initialize(opts={})
    @options = opts
  end

  def run!
    raise NotImplementedError, "your runner must implement #run!"
  end
end
