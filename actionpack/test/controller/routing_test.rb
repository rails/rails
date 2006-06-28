require File.dirname(__FILE__) + '/../abstract_unit'
require 'test/unit'
require File.dirname(__FILE__) + '/fake_controllers'
require 'stringio'

RunTimeTests = ARGV.include? 'time'

module ActionController::CodeGeneration

class SourceTests < Test::Unit::TestCase
  attr_accessor :source
  def setup
    @source = Source.new
  end
    
  def test_initial_state
    assert_equal [], source.lines
    assert_equal 0, source.indentation_level
  end
  
  def test_trivial_operations
    source << "puts 'Hello World'"
    assert_equal ["puts 'Hello World'"], source.lines
    assert_equal "puts 'Hello World'", source.to_s
    
    source.line "puts 'Goodbye World'"
    assert_equal ["puts 'Hello World'", "puts 'Goodbye World'"], source.lines
    assert_equal "puts 'Hello World'\nputs 'Goodbye World'", source.to_s
  end

  def test_indentation
    source << "x = gets.to_i"
    source << 'if x.odd?'
    source.indent { source << "puts 'x is odd!'" }
    source << 'else'
    source.indent { source << "puts 'x is even!'" }
    source << 'end'
    
    assert_equal ["x = gets.to_i", "if x.odd?", "  puts 'x is odd!'", 'else', "  puts 'x is even!'", 'end'], source.lines
    
    text = "x = gets.to_i
if x.odd?
  puts 'x is odd!'
else
  puts 'x is even!'
end"

    assert_equal text, source.to_s
  end 
end

class CodeGeneratorTests < Test::Unit::TestCase
  attr_accessor :generator
  def setup
    @generator = CodeGenerator.new
  end
  
  def test_initial_state
    assert_equal [], generator.source.lines
    assert_equal [], generator.locals
  end
    
  def test_trivial_operations
    ["puts 'Hello World'", "puts 'Goodbye World'"].each {|l| generator << l} 
    assert_equal ["puts 'Hello World'", "puts 'Goodbye World'"], generator.source.lines
    assert_equal "puts 'Hello World'\nputs 'Goodbye World'", generator.to_s
  end
  
  def test_if
    generator << "x = gets.to_i"
    generator.if("x.odd?") { generator << "puts 'x is odd!'" }
    
    assert_equal "x = gets.to_i\nif x.odd?\n  puts 'x is odd!'\nend", generator.to_s
  end
  
  def test_else
    test_if
    generator.else { generator << "puts 'x is even!'" }
    
    assert_equal "x = gets.to_i\nif x.odd?\n  puts 'x is odd!'\nelse \n  puts 'x is even!'\nend", generator.to_s
  end

  def test_dup
    generator << 'x = 2'
    generator.locals << :x
    
    g = generator.dup
    assert_equal generator.source, g.source
    assert_equal generator.locals, g.locals
    
    g << 'y = 3'
    g.locals << :y
    assert_equal [:x, :y], g.locals # Make sure they don't share the same array.
    assert_equal [:x], generator.locals
  end
end 

class RecognitionTests < Test::Unit::TestCase
  attr_accessor :generator
  alias :g :generator
  def setup
    @generator = RecognitionGenerator.new
  end

  def go(components)
    g.current = components.first
    g.after = components[1..-1] || []
    g.go
  end
  
  def execute(path, show = false)
    path = path.split('/') if path.is_a? String
    source = "index, path = 0, #{path.inspect}\n#{g.to_s}"
    puts source if show
    r = eval source
    r ? r.symbolize_keys : nil
  end
  
  Static = ::ActionController::Routing::StaticComponent
  Dynamic = ::ActionController::Routing::DynamicComponent
  Path = ::ActionController::Routing::PathComponent
  Controller = ::ActionController::Routing::ControllerComponent
  
  def test_all_static
    c = %w(hello world how are you).collect {|str| Static.new(str)}
    
    g.result :controller, "::ContentController", true
    g.constant_result :action, 'index' 
    
    go c
    
    assert_nil execute('x')
    assert_nil execute('hello/world/how')
    assert_nil execute('hello/world/how/are')
    assert_nil execute('hello/world/how/are/you/today')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hello/world/how/are/you'))
  end

  def test_basic_dynamic
    c = [Static.new("hi"), Dynamic.new(:action)]
    g.result :controller, "::ContentController", true
    go c
    
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi')
    assert_nil execute('hi/dude/what')
    assert_equal({:controller => ::ContentController, :action => 'dude'}, execute('hi/dude'))
  end 

  def test_basic_dynamic_backwards
    c = [Dynamic.new(:action), Static.new("hi")]
    go c

    assert_nil execute('')
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi')
    assert_equal({:action => 'index'}, execute('index/hi'))
    assert_equal({:action => 'show'}, execute('show/hi'))
    assert_nil execute('hi/dude')
  end

  def test_dynamic_with_default
    c = [Static.new("hi"), Dynamic.new(:action, :default => 'index')]
    g.result :controller, "::ContentController", true
    go c
    
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi/dude/what')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hi'))
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hi/index'))
    assert_equal({:controller => ::ContentController, :action => 'dude'}, execute('hi/dude'))
  end 

  def test_dynamic_with_string_condition
    c = [Static.new("hi"), Dynamic.new(:action, :condition => 'index')]
    g.result :controller, "::ContentController", true
    go c

    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi')
    assert_nil execute('hi/dude/what')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hi/index'))
    assert_nil execute('hi/dude')
  end

  def test_dynamic_with_string_condition_backwards
    c = [Dynamic.new(:action, :condition => 'index'), Static.new("hi")]
    g.result :controller, "::ContentController", true
    go c

    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi')
    assert_nil execute('dude/what/hi')
    assert_nil execute('index/what')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('index/hi'))
    assert_nil execute('dude/hi')
  end

  def test_dynamic_with_regexp_condition
    c = [Static.new("hi"), Dynamic.new(:action, :condition => /^[a-z]+$/)]
    g.result :controller, "::ContentController", true
    go c
    
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi')
    assert_nil execute('hi/FOXY')
    assert_nil execute('hi/138708jkhdf')
    assert_nil execute('hi/dkjfl8792343dfsf')
    assert_nil execute('hi/dude/what')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hi/index'))
    assert_equal({:controller => ::ContentController, :action => 'dude'}, execute('hi/dude'))
  end 
  
  def test_dynamic_with_regexp_and_default
    c = [Static.new("hi"), Dynamic.new(:action, :condition => /^[a-z]+$/, :default => 'index')]
    g.result :controller, "::ContentController", true
    go c
    
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi/FOXY')
    assert_nil execute('hi/138708jkhdf')
    assert_nil execute('hi/dkjfl8792343dfsf')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hi'))
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('hi/index'))
    assert_equal({:controller => ::ContentController, :action => 'dude'}, execute('hi/dude'))
    assert_nil execute('hi/dude/what')
  end

  def test_path
    c = [Static.new("hi"), Path.new(:file)]
    g.result :controller, "::ContentController", true
    g.constant_result :action, "download"
    
    go c
    
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_equal({:controller => ::ContentController, :action => 'download', :file => []}, execute('hi'))
    assert_equal({:controller => ::ContentController, :action => 'download', :file => %w(books agile_rails_dev.pdf)},
                 execute('hi/books/agile_rails_dev.pdf'))
    assert_equal({:controller => ::ContentController, :action => 'download', :file => ['dude']}, execute('hi/dude'))
    assert_equal 'dude/what', execute('hi/dude/what')[:file].to_s
  end

  def test_path_with_dynamic
    c = [Dynamic.new(:action), Path.new(:file)]
    g.result :controller, "::ContentController", true

    go c

    assert_nil execute('')
    assert_equal({:controller => ::ContentController, :action => 'download', :file => []}, execute('download'))
    assert_equal({:controller => ::ContentController, :action => 'download', :file => %w(books agile_rails_dev.pdf)},
                 execute('download/books/agile_rails_dev.pdf'))
    assert_equal({:controller => ::ContentController, :action => 'download', :file => ['dude']}, execute('download/dude'))
    assert_equal 'dude/what', execute('hi/dude/what')[:file].to_s
  end

  def test_path_with_dynamic_and_default
    c = [Dynamic.new(:action, :default => 'index'), Path.new(:file)]

    go c

    assert_equal({:action => 'index', :file => []}, execute(''))
    assert_equal({:action => 'index', :file => []}, execute('index'))
    assert_equal({:action => 'blarg', :file => []}, execute('blarg'))
    assert_equal({:action => 'index', :file => ['content']}, execute('index/content'))
    assert_equal({:action => 'show', :file => ['rails_dev.pdf']}, execute('show/rails_dev.pdf'))
  end
  
  def test_controller
    c = [Static.new("hi"), Controller.new(:controller)]
    g.constant_result :action, "hi"
    
    go c
    
    assert_nil execute('boo')
    assert_nil execute('boo/blah')
    assert_nil execute('hi/x')
    assert_nil execute('hi/13870948')
    assert_nil execute('hi/content/dog')
    assert_nil execute('hi/admin/user/foo')
    assert_equal({:controller => ::ContentController, :action => 'hi'}, execute('hi/content'))
    assert_equal({:controller => ::Admin::UserController, :action => 'hi'}, execute('hi/admin/user'))
  end
  
  def test_controller_with_regexp
    c = [Static.new("hi"), Controller.new(:controller, :condition => /^admin\/.+$/)]
    g.constant_result :action, "hi"
    
    go c
    
    assert_nil execute('hi')
    assert_nil execute('hi/x')
    assert_nil execute('hi/content')
    assert_equal({:controller => ::Admin::UserController, :action => 'hi'}, execute('hi/admin/user'))
    assert_equal({:controller => ::Admin::NewsFeedController, :action => 'hi'}, execute('hi/admin/news_feed'))
    assert_nil execute('hi/admin/user/foo')
  end
  
  def test_standard_route(time = ::RunTimeTests)
    c = [Controller.new(:controller), Dynamic.new(:action, :default => 'index'), Dynamic.new(:id, :default => nil)]
    go c
    
    # Make sure we get the right answers
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute('content'))
    assert_equal({:controller => ::ContentController, :action => 'list'}, execute('content/list'))
    assert_equal({:controller => ::ContentController, :action => 'show', :id => '10'}, execute('content/show/10'))
    
    assert_equal({:controller => ::Admin::UserController, :action => 'index'}, execute('admin/user'))
    assert_equal({:controller => ::Admin::UserController, :action => 'list'}, execute('admin/user/list'))
    assert_equal({:controller => ::Admin::UserController, :action => 'show', :id => 'nseckar'}, execute('admin/user/show/nseckar'))
    
    assert_nil execute('content/show/10/20')
    assert_nil execute('food')

    if time
      source = "def self.execute(path)
        path = path.split('/') if path.is_a? String
        index = 0
        r = #{g.to_s}
      end"
      eval(source)

      GC.start
      n = 1000
      time = Benchmark.realtime do n.times {
        execute('content')
        execute('content/list')
        execute('content/show/10')
        
        execute('admin/user')
        execute('admin/user/list')
        execute('admin/user/show/nseckar')
        
        execute('admin/user/show/nseckar/dude')
        execute('admin/why/show/nseckar')
        execute('content/show/10/20')
        execute('food')
      } end
      time -= Benchmark.realtime do n.times { } end
    
      
      puts "\n\nRecognition:"
      per_url = time / (n * 10)
    
      puts "#{per_url * 1000} ms/url"
      puts "#{1 / per_url} urls/s\n\n"
    end
  end

  def test_default_route
    g.result :controller, "::ContentController", true
    g.constant_result :action, 'index' 
    
    go []
    
    assert_nil execute('x')
    assert_nil execute('hello/world/how')
    assert_nil execute('hello/world/how/are')
    assert_nil execute('hello/world/how/are/you/today')
    assert_equal({:controller => ::ContentController, :action => 'index'}, execute([]))
  end
end

class GenerationTests < Test::Unit::TestCase
  attr_accessor :generator
  alias :g :generator
  def setup
    @generator = GenerationGenerator.new # ha!
  end
  
  def go(components)
    g.current = components.first
    g.after = components[1..-1] || []
    g.go
  end
  
  def execute(options, recall, show = false)
    source = "\n
expire_on = ::ActionController::Routing.expiry_hash(options, recall)
hash = merged = recall.merge(options)
not_expired = true

#{g.to_s}\n\n"
    puts source if show
    eval(source)
  end
  
  Static = ::ActionController::Routing::StaticComponent
  Dynamic = ::ActionController::Routing::DynamicComponent
  Path = ::ActionController::Routing::PathComponent
  Controller = ::ActionController::Routing::ControllerComponent
  
  def test_all_static_no_requirements
    c = [Static.new("hello"), Static.new("world")]
    go c
    
    assert_equal "/hello/world", execute({}, {})
  end
  
  def test_basic_dynamic
    c = [Static.new("hi"), Dynamic.new(:action)]
    go c
    
    assert_equal '/hi/index', execute({:action => 'index'}, {:action => 'index'})
    assert_equal '/hi/show', execute({:action => 'show'}, {:action => 'index'})
    assert_equal '/hi/list+people', execute({}, {:action => 'list people'})
    assert_nil execute({},{})
  end
  
  def test_dynamic_with_default
    c = [Static.new("hi"), Dynamic.new(:action, :default => 'index')]
    go c
    
    assert_equal '/hi', execute({:action => 'index'}, {:action => 'index'})
    assert_equal '/hi/show', execute({:action => 'show'}, {:action => 'index'})
    assert_equal '/hi/list+people', execute({}, {:action => 'list people'})
    assert_equal '/hi', execute({}, {})
  end
  
  def test_dynamic_with_regexp_condition
    c = [Static.new("hi"), Dynamic.new(:action, :condition => /^[a-z]+$/)]
    go c
    
    assert_equal '/hi/index', execute({:action => 'index'}, {:action => 'index'})
    assert_nil execute({:action => 'fox5'}, {:action => 'index'})
    assert_nil execute({:action => 'something_is_up'}, {:action => 'index'})
    assert_nil execute({}, {:action => 'list people'})
    assert_equal '/hi/abunchofcharacter', execute({:action => 'abunchofcharacter'}, {})
    assert_nil execute({}, {})
  end
  
  def test_dynamic_with_default_and_regexp_condition
    c = [Static.new("hi"), Dynamic.new(:action, :default => 'index', :condition => /^[a-z]+$/)]
    go c
    
    assert_equal '/hi', execute({:action => 'index'}, {:action => 'index'})
    assert_nil execute({:action => 'fox5'}, {:action => 'index'})
    assert_nil execute({:action => 'something_is_up'}, {:action => 'index'})
    assert_nil execute({}, {:action => 'list people'})
    assert_equal '/hi/abunchofcharacter', execute({:action => 'abunchofcharacter'}, {})
    assert_equal '/hi', execute({}, {})
  end

  def test_path
    c = [Static.new("hi"), Path.new(:file)]
    go c
    
    assert_equal '/hi', execute({:file => []}, {})
    assert_equal '/hi/books/agile_rails_dev.pdf', execute({:file => %w(books agile_rails_dev.pdf)}, {})
    assert_equal '/hi/books/development%26whatever/agile_rails_dev.pdf', execute({:file => %w(books development&whatever agile_rails_dev.pdf)}, {})
    
    assert_equal '/hi', execute({:file => ''}, {})
    assert_equal '/hi/books/agile_rails_dev.pdf', execute({:file => 'books/agile_rails_dev.pdf'}, {})
    assert_equal '/hi/books/development%26whatever/agile_rails_dev.pdf', execute({:file => 'books/development&whatever/agile_rails_dev.pdf'}, {})
  end
  
  def test_controller
    c = [Static.new("hi"), Controller.new(:controller)]
    go c
    
    assert_nil execute({}, {})
    assert_equal '/hi/content', execute({:controller => 'content'}, {})
    assert_equal '/hi/admin/user', execute({:controller => 'admin/user'}, {})
    assert_equal '/hi/content', execute({}, {:controller => 'content'}) 
    assert_equal '/hi/admin/user', execute({}, {:controller => 'admin/user'})
  end
  
  def test_controller_with_regexp
    c = [Static.new("hi"), Controller.new(:controller, :condition => /^admin\/.+$/)]
    go c
    
    assert_nil execute({}, {})
    assert_nil execute({:controller => 'content'}, {})
    assert_equal '/hi/admin/user', execute({:controller => 'admin/user'}, {})
    assert_nil execute({}, {:controller => 'content'}) 
    assert_equal '/hi/admin/user', execute({}, {:controller => 'admin/user'})
  end
  
  def test_standard_route(time = ::RunTimeTests)
    c = [Controller.new(:controller), Dynamic.new(:action, :default => 'index'), Dynamic.new(:id, :default => nil)]
    go c
    
    # Make sure we get the right answers
    assert_equal('/content', execute({:action => 'index'}, {:controller => 'content', :action => 'list'}))
    assert_equal('/content/list', execute({:action => 'list'}, {:controller => 'content', :action => 'index'}))
    assert_equal('/content/show/10', execute({:action => 'show', :id => '10'}, {:controller => 'content', :action => 'list'}))

    assert_equal('/admin/user', execute({:action => 'index'}, {:controller => 'admin/user', :action => 'list'}))
    assert_equal('/admin/user/list', execute({:action => 'list'}, {:controller => 'admin/user', :action => 'index'}))
    assert_equal('/admin/user/show/10', execute({:action => 'show', :id => '10'}, {:controller => 'admin/user', :action => 'list'}))

    if time
      GC.start
      n = 1000
      time = Benchmark.realtime do n.times {
        execute({:action => 'index'}, {:controller => 'content', :action => 'list'})
        execute({:action => 'list'}, {:controller => 'content', :action => 'index'})
        execute({:action => 'show', :id => '10'}, {:controller => 'content', :action => 'list'})

        execute({:action => 'index'}, {:controller => 'admin/user', :action => 'list'})
        execute({:action => 'list'}, {:controller => 'admin/user', :action => 'index'})
        execute({:action => 'show', :id => '10'}, {:controller => 'admin/user', :action => 'list'})
      } end
      time -= Benchmark.realtime do n.times { } end
    
      puts "\n\nGeneration:"
      per_url = time / (n * 6)
    
      puts "#{per_url * 1000} ms/url"
      puts "#{1 / per_url} urls/s\n\n"
    end
  end

  def test_default_route
    g.if(g.check_conditions(:controller => 'content', :action => 'welcome')) { go [] }
    
    assert_nil execute({:controller => 'foo', :action => 'welcome'}, {})
    assert_nil execute({:controller => 'content', :action => 'elcome'}, {})
    assert_nil execute({:action => 'elcome'}, {:controller => 'content'})

    assert_equal '/', execute({:controller => 'content', :action => 'welcome'}, {})
    assert_equal '/', execute({:action => 'welcome'}, {:controller => 'content'})
    assert_equal '/', execute({:action => 'welcome', :id => '10'}, {:controller => 'content'})
  end
end

class RouteTests < Test::Unit::TestCase
  
  def route(*args)
    @route = ::ActionController::Routing::Route.new(*args) unless args.empty?
    return @route
  end
  
  def rec(path, show = false)
    path = path.split('/') if path.is_a? String
    index = 0
    source = route.write_recognition.to_s
    puts "\n\n#{source}\n\n" if show
    r = eval(source)
    r ? r.symbolize_keys : r
  end
  def gen(options, recall = nil, show = false)
    recall ||= options.dup
    
    expire_on = ::ActionController::Routing.expiry_hash(options, recall)
    hash = merged = recall.merge(options)
    not_expired = true
    
    source = route.write_generation.to_s
    puts "\n\n#{source}\n\n" if show
    eval(source)
    
  end
  
  def test_static
    route 'hello/world', :known => 'known_value', :controller => 'content', :action => 'index'
    
    assert_nil rec('hello/turn')
    assert_nil rec('turn/world')
    assert_equal(
      {:known => 'known_value', :controller => ::ContentController, :action => 'index'},
      rec('hello/world')
    )
    
    assert_nil gen(:known => 'foo')
    assert_nil gen({})
    assert_equal '/hello/world', gen(:known => 'known_value', :controller => 'content', :action => 'index')
    assert_equal '/hello/world', gen(:known => 'known_value', :extra => 'hi', :controller => 'content', :action => 'index')
    assert_equal [:extra], route.extra_keys(:known => 'known_value', :extra => 'hi')
  end
  
  def test_dynamic
    route 'hello/:name', :controller => 'content', :action => 'show_person'
    
    assert_nil rec('hello')
    assert_nil rec('foo/bar')
    assert_equal({:controller => ::ContentController, :action => 'show_person', :name => 'rails'}, rec('hello/rails'))
    assert_equal({:controller => ::ContentController, :action => 'show_person', :name => 'Nicholas Seckar'}, rec('hello/Nicholas+Seckar'))
    
    assert_nil gen(:controller => 'content', :action => 'show_dude', :name => 'rails')
    assert_nil gen(:controller => 'content', :action => 'show_person')
    assert_nil gen(:controller => 'admin/user', :action => 'show_person', :name => 'rails')
    assert_equal '/hello/rails', gen(:controller => 'content', :action => 'show_person', :name => 'rails')
    assert_equal '/hello/Nicholas+Seckar', gen(:controller => 'content', :action => 'show_person', :name => 'Nicholas Seckar')
  end
  
  def test_typical
    route ':controller/:action/:id', :action => 'index', :id => nil
    assert_nil rec('hello')
    assert_nil rec('foo bar')
    assert_equal({:controller => ::ContentController, :action => 'index'}, rec('content'))
    assert_equal({:controller => ::Admin::UserController, :action => 'index'}, rec('admin/user'))
    
    assert_equal({:controller => ::Admin::UserController, :action => 'index'}, rec('admin/user/index'))
    assert_equal({:controller => ::Admin::UserController, :action => 'list'}, rec('admin/user/list'))
    assert_equal({:controller => ::Admin::UserController, :action => 'show', :id => '10'}, rec('admin/user/show/10'))
    
    assert_equal({:controller => ::ContentController, :action => 'list'}, rec('content/list'))
    assert_equal({:controller => ::ContentController, :action => 'show', :id => '10'}, rec('content/show/10'))
    
    
    assert_equal '/content', gen(:controller => 'content', :action => 'index')
    assert_equal '/content/list', gen(:controller => 'content', :action => 'list')
    assert_equal '/content/show/10', gen(:controller => 'content', :action => 'show', :id => '10')
    
    assert_equal '/admin/user', gen(:controller => 'admin/user', :action => 'index')
    assert_equal '/admin/user', gen(:controller => 'admin/user')
    assert_equal '/admin/user', gen({:controller => 'admin/user'}, {:controller => 'content', :action => 'list', :id => '10'})
    assert_equal '/admin/user/show/10', gen(:controller => 'admin/user', :action => 'show', :id => '10')
  end
end

class RouteSetTests < Test::Unit::TestCase
  attr_reader :rs
  def setup
    @rs = ::ActionController::Routing::RouteSet.new
    @rs.draw {|m| m.connect ':controller/:action/:id' }
    ::ActionController::Routing::NamedRoutes.clear
  end
  
  def test_default_setup
    assert_equal({:controller => ::ContentController, :action => 'index'}.stringify_keys, rs.recognize_path(%w(content)))
    assert_equal({:controller => ::ContentController, :action => 'list'}.stringify_keys, rs.recognize_path(%w(content list)))
    assert_equal({:controller => ::ContentController, :action => 'show', :id => '10'}.stringify_keys, rs.recognize_path(%w(content show 10)))
    
    assert_equal({:controller => ::Admin::UserController, :action => 'show', :id => '10'}.stringify_keys, rs.recognize_path(%w(admin user show 10)))
    
    assert_equal ['/admin/user/show/10', []], rs.generate({:controller => 'admin/user', :action => 'show', :id => 10})
    
    assert_equal ['/admin/user/show', []], rs.generate({:action => 'show'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
    assert_equal ['/admin/user/list/10', []], rs.generate({}, {:controller => 'admin/user', :action => 'list', :id => '10'})

    assert_equal ['/admin/stuff', []], rs.generate({:controller => 'stuff'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
    assert_equal ['/stuff', []], rs.generate({:controller => '/stuff'}, {:controller => 'admin/user', :action => 'list', :id => '10'})
  end
  
  def test_ignores_leading_slash
    @rs.draw {|m| m.connect '/:controller/:action/:id'}
    test_default_setup
  end
  
  def test_time_recognition
    n = 10000
    if RunTimeTests
      GC.start
      rectime = Benchmark.realtime do
        n.times do
          rs.recognize_path(%w(content))
          rs.recognize_path(%w(content list))
          rs.recognize_path(%w(content show 10))
          rs.recognize_path(%w(admin user))
          rs.recognize_path(%w(admin user list))
          rs.recognize_path(%w(admin user show 10))
        end
      end
      puts "\n\nRecognition (RouteSet):"
      per_url = rectime / (n * 6)
      puts "#{per_url * 1000} ms/url"
      puts "#{1 / per_url} url/s\n\n"
    end
  end
  def test_time_generation
    n = 5000
    if RunTimeTests
      GC.start
      pairs = [
        [{:controller => 'content', :action => 'index'}, {:controller => 'content', :action => 'show'}],
        [{:controller => 'content'}, {:controller => 'content', :action => 'index'}],   
        [{:controller => 'content', :action => 'list'}, {:controller => 'content', :action => 'index'}],
        [{:controller => 'content', :action => 'show', :id => '10'}, {:controller => 'content', :action => 'list'}],
        [{:controller => 'admin/user', :action => 'index'}, {:controller => 'admin/user', :action => 'show'}],
        [{:controller => 'admin/user'}, {:controller => 'admin/user', :action => 'index'}],
        [{:controller => 'admin/user', :action => 'list'}, {:controller => 'admin/user', :action => 'index'}],
        [{:controller => 'admin/user', :action => 'show', :id => '10'}, {:controller => 'admin/user', :action => 'list'}],
      ]
      p = nil
      gentime = Benchmark.realtime do
        n.times do
        pairs.each {|(a, b)| rs.generate(a, b)}
        end
      end
      
      puts "\n\nGeneration (RouteSet): (#{(n * 8)} urls)"
      per_url = gentime / (n * 8)
      puts "#{per_url * 1000} ms/url"
      puts "#{1 / per_url} url/s\n\n"
    end
  end

  def test_route_with_colon_first
    rs.draw do |map|
      map.connect '/:controller/:action/:id', :action => 'index', :id => nil
      map.connect ':url', :controller => 'tiny_url', :action => 'translate'
    end
  end

  def test_route_generating_string_literal_in_comparison_warning
    old_stderr = $stderr
    $stderr = StringIO.new
    rs.draw do |map|
      map.connect 'subscriptions/:action/:subscription_type', :controller => "subscriptions"
    end
    assert_equal "", $stderr.string
  ensure
    $stderr = old_stderr
  end

  def test_route_with_regexp_for_controller
    rs.draw do |map|
      map.connect ':controller/:admintoken/:action/:id', :controller => /admin\/.+/
      map.connect ':controller/:action/:id'
    end
    assert_equal({:controller => ::Admin::UserController, :admintoken => "foo", :action => "index"}.stringify_keys,
        rs.recognize_path(%w(admin user foo)))
    assert_equal({:controller => ::ContentController, :action => "foo"}.stringify_keys,
        rs.recognize_path(%w(content foo)))
    assert_equal ['/admin/user/foo', []], rs.generate(:controller => "admin/user", :admintoken => "foo", :action => "index")
    assert_equal ['/content/foo',[]], rs.generate(:controller => "content", :action => "foo")
  end
  
  def test_basic_named_route
    rs.home '', :controller => 'content', :action => 'list' 
    x = setup_for_named_route
    assert_equal({:controller => '/content', :action => 'list'},
                 x.new.send(:home_url))
  end

  def test_named_route_with_option
    rs.page 'page/:title', :controller => 'content', :action => 'show_page'
    x = setup_for_named_route
    assert_equal({:controller => '/content', :action => 'show_page', :title => 'new stuff'},
                 x.new.send(:page_url, :title => 'new stuff'))
  end

  def test_named_route_with_default
    rs.page 'page/:title', :controller => 'content', :action => 'show_page', :title => 'AboutPage'
    x = setup_for_named_route
    assert_equal({:controller => '/content', :action => 'show_page', :title => 'AboutPage'},
                 x.new.send(:page_url))
    assert_equal({:controller => '/content', :action => 'show_page', :title => 'AboutRails'},
                 x.new.send(:page_url, :title => "AboutRails"))

  end

  def setup_for_named_route
    x = Class.new
    x.send(:define_method, :url_for) {|x| x}
    x.send :include, ::ActionController::Routing::NamedRoutes
    x
  end

  def test_named_route_without_hash
    rs.draw do |map|
      rs.normal ':controller/:action/:id'
    end
  end

  def test_named_route_with_regexps
    rs.draw do |map|
      rs.article 'page/:year/:month/:day/:title', :controller => 'page', :action => 'show',
        :year => /^\d+$/, :month => /^\d+$/, :day => /^\d+$/
      rs.connect ':controller/:action/:id'
    end
    x = setup_for_named_route
    assert_equal(
      {:controller => '/page', :action => 'show', :title => 'hi'},
      x.new.send(:article_url, :title => 'hi')
    )
    assert_equal(
      {:controller => '/page', :action => 'show', :title => 'hi', :day => 10, :year => 2005, :month => 6},
      x.new.send(:article_url, :title => 'hi', :day => 10, :year => 2005, :month => 6)
    )
  end

  def test_changing_controller
    assert_equal ['/admin/stuff/show/10', []], rs.generate(
      {:controller => 'stuff', :action => 'show', :id => 10},
      {:controller => 'admin/user', :action => 'index'}
    )
  end  

  def test_paths_escaped
    rs.draw do |map|
      rs.path 'file/*path', :controller => 'content', :action => 'show_file'
      rs.connect ':controller/:action/:id'
    end
    results = rs.recognize_path %w(file hello+world how+are+you%3F)
    assert results, "Recognition should have succeeded"
    assert_equal ['hello world', 'how are you?'], results['path']

    results = rs.recognize_path %w(file)
    assert results, "Recognition should have succeeded"
    assert_equal [], results['path']
  end
  
  def test_non_controllers_cannot_be_matched
    rs.draw do
      rs.connect ':controller/:action/:id'
    end
    assert_nil rs.recognize_path(%w(not_a show 10)), "Shouldn't recognize non-controllers as controllers!"
  end

  def test_paths_do_not_accept_defaults
    assert_raises(ActionController::RoutingError) do
      rs.draw do |map|
        rs.path 'file/*path', :controller => 'content', :action => 'show_file', :path => %w(fake default)
        rs.connect ':controller/:action/:id'
      end
    end
    
    rs.draw do |map|
      rs.path 'file/*path', :controller => 'content', :action => 'show_file', :path => []
      rs.connect ':controller/:action/:id'
    end
  end
  
  def test_backwards
    rs.draw do |map|
      rs.connect 'page/:id/:action', :controller => 'pages', :action => 'show'
      rs.connect ':controller/:action/:id'
    end

    assert_equal ['/page/20', []], rs.generate({:id => 20}, {:controller => 'pages'})
    assert_equal ['/page/20', []], rs.generate(:controller => 'pages', :id => 20, :action => 'show')
    assert_equal ['/pages/boo', []], rs.generate(:controller => 'pages', :action => 'boo')
  end

  def test_route_with_fixnum_default
    rs.draw do |map|
      rs.connect 'page/:id', :controller => 'content', :action => 'show_page', :id => 1
      rs.connect ':controller/:action/:id'
    end

    assert_equal ['/page', []], rs.generate(:controller => 'content', :action => 'show_page')
    assert_equal ['/page', []], rs.generate(:controller => 'content', :action => 'show_page', :id => 1)
    assert_equal ['/page', []], rs.generate(:controller => 'content', :action => 'show_page', :id => '1')
    assert_equal ['/page/10', []], rs.generate(:controller => 'content', :action => 'show_page', :id => 10)

    ctrl = ::ContentController

    assert_equal({'controller' => ctrl, 'action' => 'show_page', 'id' => 1}, rs.recognize_path(%w(page)))
    assert_equal({'controller' => ctrl, 'action' => 'show_page', 'id' => '1'}, rs.recognize_path(%w(page 1)))
    assert_equal({'controller' => ctrl, 'action' => 'show_page', 'id' => '10'}, rs.recognize_path(%w(page 10)))
  end

  def test_action_expiry
    assert_equal ['/content', []], rs.generate({:controller => 'content'}, {:controller => 'content', :action => 'show'})
  end

  def test_recognition_with_uppercase_controller_name
    assert_equal({'controller' => ::ContentController, 'action' => 'index'}, rs.recognize_path(%w(Content)))
    assert_equal({'controller' => ::ContentController, 'action' => 'list'}, rs.recognize_path(%w(Content list)))
    assert_equal({'controller' => ::ContentController, 'action' => 'show', 'id' => '10'}, rs.recognize_path(%w(Content show 10)))

    assert_equal({'controller' => ::Admin::NewsFeedController, 'action' => 'index'}, rs.recognize_path(%w(Admin NewsFeed)))
    assert_equal({'controller' => ::Admin::NewsFeedController, 'action' => 'index'}, rs.recognize_path(%w(Admin News_Feed)))
  end

  def test_both_requirement_and_optional
    rs.draw do
      rs.blog('test/:year', :controller => 'post', :action => 'show',
        :defaults => { :year => nil },
        :requirements => { :year => /\d{4}/ }
      )
      rs.connect ':controller/:action/:id'
    end

    assert_equal ['/test', []], rs.generate(:controller => 'post', :action => 'show')
    assert_equal ['/test', []], rs.generate(:controller => 'post', :action => 'show', :year => nil)
    
    x = setup_for_named_route
    assert_equal({:controller => '/post', :action => 'show'},
                 x.new.send(:blog_url))
  end
  
  def test_set_to_nil_forgets
    rs.draw do
      rs.connect 'pages/:year/:month/:day', :controller => 'content', :action => 'list_pages', :month => nil, :day => nil
      rs.connect ':controller/:action/:id'
    end
    
    assert_equal ['/pages/2005', []],
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005)
    assert_equal ['/pages/2005/6', []],
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005, :month => 6)
    assert_equal ['/pages/2005/6/12', []],
      rs.generate(:controller => 'content', :action => 'list_pages', :year => 2005, :month => 6, :day => 12)
    
    assert_equal ['/pages/2005/6/4', []],
      rs.generate({:day => 4}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})

    assert_equal ['/pages/2005/6', []],
      rs.generate({:day => nil}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})

    assert_equal ['/pages/2005', []],
      rs.generate({:day => nil, :month => nil}, {:controller => 'content', :action => 'list_pages', :year => '2005', :month => '6', :day => '12'})
  end
  
  def test_url_with_no_action_specified
    rs.draw do
      rs.connect '', :controller => 'content'
      rs.connect ':controller/:action/:id'
    end
    
    assert_equal ['/', []], rs.generate(:controller => 'content', :action => 'index')
    assert_equal ['/', []], rs.generate(:controller => 'content')
  end

  def test_named_url_with_no_action_specified
    rs.draw do
      rs.root '', :controller => 'content'
      rs.connect ':controller/:action/:id'
    end
    
    assert_equal ['/', []], rs.generate(:controller => 'content', :action => 'index')
    assert_equal ['/', []], rs.generate(:controller => 'content')
    
    x = setup_for_named_route
    assert_equal({:controller => '/content', :action => 'index'},
                 x.new.send(:root_url))
  end
  
  def test_url_generated_when_forgetting_action
    [{:controller => 'content', :action => 'index'}, {:controller => 'content'}].each do |hash| 
      rs.draw do
        rs.root '', hash
        rs.connect ':controller/:action/:id'
      end
      assert_equal ['/', []], rs.generate({:action => nil}, {:controller => 'content', :action => 'hello'})
      assert_equal ['/', []], rs.generate({:controller => 'content'})
      assert_equal ['/content/hi', []], rs.generate({:controller => 'content', :action => 'hi'})
    end
  end
  
  def test_named_route_method
    rs.draw do
      assert_raises(ArgumentError) { rs.categories 'categories', :controller => 'content', :action => 'categories' }
      
      rs.named_route :categories, 'categories', :controller => 'content', :action => 'categories'
      rs.connect ':controller/:action/:id'
    end

    assert_equal ['/categories', []], rs.generate(:controller => 'content', :action => 'categories')
    assert_equal ['/content/hi', []], rs.generate({:controller => 'content', :action => 'hi'})
  end

  def test_named_route_helper_array
    test_named_route_method
    assert_equal [:categories_url, :hash_for_categories_url], ::ActionController::Routing::NamedRoutes::Helpers
  end

  def test_nil_defaults
    rs.draw do
      rs.connect 'journal',
        :controller => 'content',
        :action => 'list_journal',
        :date => nil, :user_id => nil
      rs.connect ':controller/:action/:id'
    end

    assert_equal ['/journal', []], rs.generate(:controller => 'content', :action => 'list_journal', :date => nil, :user_id => nil)
  end
end

class ControllerComponentTest < Test::Unit::TestCase
  
  def test_traverse_to_controller_should_not_load_arbitrary_files
    load_path = $:.dup
    base = File.dirname(File.dirname(File.expand_path(__FILE__)))
    $: << File.join(base, 'fixtures')
    Object.send :const_set, :RAILS_ROOT, File.join(base, 'fixtures/application_root')
    assert_equal nil, ActionController::Routing::ControllerComponent.traverse_to_controller(%w(dont_load pretty please))
  ensure
    $:[0..-1] = load_path
    Object.send :remove_const, :RAILS_ROOT
  end
  
  def test_traverse_should_not_trip_on_non_module_constants
    assert_equal nil, ActionController::Routing::ControllerComponent.traverse_to_controller(%w(admin some_constant a))
  end
  
  # This is evil, but people do it.
  def test_traverse_to_controller_should_pass_thru_classes
    load_path = $:.dup
    base = File.dirname(File.dirname(File.expand_path(__FILE__)))
    $: << File.join(base, 'fixtures')
    $: << File.join(base, 'fixtures/application_root/app/controllers')
    $: << File.join(base, 'fixtures/application_root/app/models')
    Object.send :const_set, :RAILS_ROOT, File.join(base, 'fixtures/application_root')
    pair = ActionController::Routing::ControllerComponent.traverse_to_controller(%w(a_class_that_contains_a_controller poorly_placed))
    
    # Make sure the container class was loaded properly
    assert defined?(AClassThatContainsAController)
    assert_kind_of Class, AClassThatContainsAController
    assert_equal :you_know_it, AClassThatContainsAController.is_special?
    
    # Make sure the controller was too
    assert_kind_of Array, pair
    assert_equal 2, pair[1]
    klass = pair.first
    assert_kind_of Class, klass
    assert_equal :decidedly_so, klass.is_evil?
    assert klass.ancestors.include?(ActionController::Base)
    assert defined?(AClassThatContainsAController::PoorlyPlacedController)
    assert_equal klass, AClassThatContainsAController::PoorlyPlacedController
  ensure
    $:[0..-1] = load_path
    Object.send :remove_const, :RAILS_ROOT
  end
  
  def test_traverse_to_nested_controller
    load_path = $:.dup
    base = File.dirname(File.dirname(File.expand_path(__FILE__)))
    $: << File.join(base, 'fixtures')
    $: << File.join(base, 'fixtures/application_root/app/controllers')
    Object.send :const_set, :RAILS_ROOT, File.join(base, 'fixtures/application_root')
    pair = ActionController::Routing::ControllerComponent.traverse_to_controller(%w(module_that_holds_controllers nested))
    
    assert_not_equal nil, pair
    
    # Make sure that we created a module for the dir
    assert defined?(ModuleThatHoldsControllers)
    assert_kind_of Module, ModuleThatHoldsControllers

    # Make sure the controller is ok
    assert_kind_of Array, pair
    assert_equal 2, pair[1]
    klass = pair.first
    assert_kind_of Class, klass
    assert klass.ancestors.include?(ActionController::Base)
    assert defined?(ModuleThatHoldsControllers::NestedController)
    assert_equal klass, ModuleThatHoldsControllers::NestedController
  ensure
    $:[0..-1] = load_path
    Object.send :remove_const, :RAILS_ROOT
  end
  
end

end
