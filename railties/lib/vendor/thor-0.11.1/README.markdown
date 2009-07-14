thor
====

Map options to a class. Simply create a class with the appropriate annotations
and have options automatically map to functions and parameters.

Example:

    class App < Thor                                                 # [1]
      map "-L" => :list                                              # [2]
      
      desc "install APP_NAME", "install one of the available apps"   # [3]
      method_options :force => :boolean, :alias => :string           # [4]
      def install(name)
        user_alias = options[:alias]
        if options.force?
          # do something
        end
        # other code
      end
      
      desc "list [SEARCH]", "list all of the available apps, limited by SEARCH"
      def list(search="")
        # list everything
      end
    end

Thor automatically maps commands as such:

    thor app:install myname --force

That gets converted to:

    App.new.install("myname")
    # with {'force' => true} as options hash

1.  Inherit from Thor to turn a class into an option mapper
2.  Map additional non-valid identifiers to specific methods. In this case, convert -L to :list
3.  Describe the method immediately below. The first parameter is the usage information, and the second parameter is the description
4.  Provide any additional options that will be available the instance method options.

Types for `method_options`
--------------------------

<dl>
  <dt><code>:boolean</code></dt>
    <dd>is parsed as --option or --option=true</dd>
  <dt><code>:string</code></dt>
    <dd>is parsed as --option=VALUE</dd>
  <dt><code>:numeric</code></dt>
    <dd>is parsed as --option=N</dd>
  <dt><code>:array</code></dt>
    <dd>is parsed as --option=one two three</dd>
  <dt><code>:hash</code></dt>
    <dd>is parsed as --option=key:value key:value key:value</dd>
</dl>

Besides, method_option allows a default value to be given, examples:

    method_options :force => false
    #=> Creates a boolean option with default value false

    method_options :alias => "bar"
    #=> Creates a string option with default value "bar"

    method_options :threshold => 3.0
    #=> Creates a numeric option with default value 3.0

You can also supply :option => :required to mark an option as required. The
type is assumed to be string. If you want a required hash with default values
as option, you can use `method_option` which uses a more declarative style:

    method_option :attributes, :type => :hash, :default => {}, :required => true

All arguments can be set to nil (except required arguments), by suppling a no or
skip variant. For example:

    thor app name --no-attributes

In previous versions, aliases for options were created automatically, but now
they should be explicit. You can supply aliases in both short and declarative
styles:

    method_options %w( force -f ) => :boolean

Or:

    method_option :force, :type => :boolean, :aliases => "-f"

You can supply as many aliases as you want.

NOTE: Type :optional available in Thor 0.9.0 was deprecated. Use :string or :boolean instead.

Namespaces
----------

By default, your Thor tasks are invoked using Ruby namespace. In the example
above, tasks are invoked as:

    thor app:install name --force

However, you could namespace your class as:

    module Sinatra
      class App < Thor
        # tasks
      end
    end

And then you should invoke your tasks as:

    thor sinatra:app:install name --force

If desired, you can change the namespace:

    module Sinatra
      class App < Thor
        namespace :myapp
        # tasks
      end
    end

And then your tasks hould be invoked as:

    thor myapp:install name --force

Invocations
-----------

Thor comes with a invocation-dependency system as well which allows a task to be
invoked only once. For example:

    class Counter < Thor
      desc "one", "Prints 1, 2, 3"
      def one
        puts 1
        invoke :two
        invoke :three
      end
      
      desc "two", "Prints 2, 3"
      def two
        puts 2
        invoke :three
      end
      
      desc "three", "Prints 3"
      def three
        puts 3
      end
    end

When invoking the task one:

    thor counter:one

The output is "1 2 3", which means that the three task was invoked only once.
You can even invoke tasks from another class, so be sure to check the
documentation.

Thor::Group
-----------

Thor has a special class called Thor::Group. The main difference to Thor class
is that it invokes all tasks at once. The example above could be rewritten in
Thor::Group as this:

    class Counter < Thor::Group
      desc "Prints 1, 2, 3"
      
      def one
        puts 1
      end
     
      def two
        puts 2
      end
      
      def three
        puts 3
      end
    end

When invoked:

    thor counter

It prints "1 2 3" as well. Notice you should described (desc) only the class
and not each task anymore. Thor::Group is a great tool to create generators,
since you can define several steps which are invoked in the order they are
defined (Thor::Group is the tool use in generators in Rails 3.0).

Besides, Thor::Group can parse arguments and options as Thor tasks:

    class Counter < Thor::Group
      # number will be available as attr_accessor
      argument :number, :type => :numeric, :desc => "The number to start counting"
      desc "Prints the 'number' given upto 'number+2'"
      
      def one
        puts number + 0
      end
      
      def two
        puts number + 1
      end
      
      def three
        puts number + 2
      end
    end

The counter above expects one parameter and has the folling outputs:

    thor counter 5
    # Prints "5 6 7"

    thor counter 11
    # Prints "11 12 13"

You can also give options to Thor::Group, but instead of using `method_option` and
`method_options`, you should use `class_option` and `class_options`. Both argument
and class_options methods are available to Thor class as well.

Actions
-------

Thor comes with several actions which helps with script and generator tasks. You
might be familiar with them since some came from Rails Templates. They are: `say`,
`ask`, `yes?`, `no?`, `add_file`, `remove_file`, `copy_file`, `template`,
`directory`, `inside`, `run`, `inject_into_file` and a couple more.

To use them, you just need to include Thor::Actions in your Thor classes:

    class App < Thor
      include Thor::Actions
      # tasks
    end

Some actions like copy file requires that a class method called source_root is
defined in your class. This is the directory where your templates should be
placed. Be sure to check the documentation.

License
-------

See MIT LICENSE.
