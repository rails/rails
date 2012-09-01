h2. API Documentation Guidelines

This guide documents the Ruby on Rails API documentation guidelines.

endprologue.

h3. RDoc

The Rails API documentation is generated with RDoc. Please consult the documentation for help with the "markup":http://rdoc.rubyforge.org/RDoc/Markup.html, and also take into account these "additional directives":http://rdoc.rubyforge.org/RDoc/Parser/Ruby.html.

h3. Wording

Write simple, declarative sentences. Brevity is a plus: get to the point.

Write in present tense: "Returns a hash that...", rather than "Returned a hash that..." or "Will return a hash that...".

Start comments in upper case. Follow regular punctuation rules:

<ruby>
# Declares an attribute reader backed by an internally-named instance variable.
def attr_internal_reader(*attrs)
  ...
end
</ruby>

Communicate to the reader the current way of doing things, both explicitly and implicitly. Use the idioms recommended in edge. Reorder sections to emphasize favored approaches if needed, etc. The documentation should be a model for best practices and canonical, modern Rails usage.

Documentation has to be concise but comprehensive. Explore and document edge cases. What happens if a module is anonymous? What if a collection is empty? What if an argument is nil?

The proper names of Rails components have a space in between the words, like "Active Support". +ActiveRecord+ is a Ruby module, whereas Active Record is an ORM. All Rails documentation should consistently refer to Rails components by their proper name, and if in your next blog post or presentation you remember this tidbit and take it into account that'd be phenomenal.

Spell names correctly: Arel, Test::Unit, RSpec, HTML, MySQL, JavaScript, ERB. When in doubt, please have a look at some authoritative source like their official documentation.

Use the article "an" for "SQL", as in "an SQL statement". Also "an SQLite database".

h3. English

Please use American English (<em>color</em>, <em>center</em>, <em>modularize</em>, etc.). See "a list of American and British English spelling differences here":http://en.wikipedia.org/wiki/American_and_British_English_spelling_differences.

h3. Example Code

Choose meaningful examples that depict and cover the basics as well as interesting points or gotchas.

Use two spaces to indent chunks of code--that is, for markup purposes, two spaces with respect to the left margin. The examples themselves should use "Rails coding conventions":contributing_to_ruby_on_rails.html#follow-the-coding-conventions.

Short docs do not need an explicit "Examples" label to introduce snippets; they just follow paragraphs:

<ruby>
# Converts a collection of elements into a formatted string by calling
# <tt>to_s</tt> on all elements and joining them.
#
#   Blog.all.to_formatted_s # => "First PostSecond PostThird Post"
</ruby>

On the other hand, big chunks of structured documentation may have a separate "Examples" section:

<ruby>
# ==== Examples
#
#   Person.exists?(5)
#   Person.exists?('5')
#   Person.exists?(:name => "David")
#   Person.exists?(['name LIKE ?', "%#{query}%"])
</ruby>

The results of expressions follow them and are introduced by "# => ", vertically aligned:

<ruby>
# For checking if a fixnum is even or odd.
#
#   1.even? # => false
#   1.odd?  # => true
#   2.even? # => true
#   2.odd?  # => false
</ruby>

If a line is too long, the comment may be placed on the next line:

<ruby>
#   label(:post, :title)
#   # => <label for="post_title">Title</label>
#
#   label(:post, :title, "A short title")
#   # => <label for="post_title">A short title</label>
#
#   label(:post, :title, "A short title", :class => "title_label")
#   # => <label for="post_title" class="title_label">A short title</label>
</ruby>

Avoid using any printing methods like +puts+ or +p+ for that purpose.

On the other hand, regular comments do not use an arrow:

<ruby>
#   polymorphic_url(record)  # same as comment_url(record)
</ruby>

h3. Filenames

As a rule of thumb, use filenames relative to the application root:

<plain>
config/routes.rb            # YES
routes.rb                   # NO
RAILS_ROOT/config/routes.rb # NO
</plain>

h3. Fonts

h4. Fixed-width Font

Use fixed-width fonts for:
* Constants, in particular class and module names.
* Method names.
* Literals like +nil+, +false+, +true+, +self+.
* Symbols.
* Method parameters.
* File names.

<ruby>
class Array
  # Calls <tt>to_param</tt> on all its elements and joins the result with
  # slashes. This is used by <tt>url_for</tt> in Action Pack.
  def to_param
    collect { |e| e.to_param }.join '/'
  end
end
</ruby>

WARNING: Using a pair of +&#43;...&#43;+ for fixed-width font only works with *words*; that is: anything matching <tt>\A\w&#43;\z</tt>. For anything else  use +&lt;tt&gt;...&lt;/tt&gt;+, notably symbols, setters, inline snippets, etc.

h4. Regular Font

When "true" and "false" are English words rather than Ruby keywords use a regular font:

<ruby>
# Runs all the validations within the specified context. Returns true if no errors are found,
# false otherwise.
#
# If the argument is false (default is +nil+), the context is set to <tt>:create</tt> if
# <tt>new_record?</tt> is true, and to <tt>:update</tt> if it is not.
#
# Validations with no <tt>:on</tt> option will run no matter the context. Validations with
# some <tt>:on</tt> option will only run in the specified context.
def valid?(context = nil)
  ...
end
</ruby>

h3. Description Lists

In lists of options, parameters, etc. use a hyphen between the item and its description (reads better than a colon because normally options are symbols):

<ruby>
# * <tt>:allow_nil</tt> - Skip validation if attribute is <tt>nil</tt>.
</ruby>

The description starts in upper case and ends with a full stop—it's standard English.

h3. Dynamically Generated Methods

Methods created with +(module|class)_eval(STRING)+ have a comment by their side with an instance of the generated code. That comment is 2 spaces away from the template:

<ruby>
for severity in Severity.constants
  class_eval <<-EOT, __FILE__, __LINE__
    def #{severity.downcase}(message = nil, progname = nil, &block)  # def debug(message = nil, progname = nil, &block)
      add(#{severity}, message, progname, &block)                    #   add(DEBUG, message, progname, &block)
    end                                                              # end
                                                                     #
    def #{severity.downcase}?                                        # def debug?
      #{severity} >= @level                                          #   DEBUG >= @level
    end                                                              # end
  EOT
end
</ruby>

If the resulting lines are too wide, say 200 columns or more, put the comment above the call:

<ruby>
# def self.find_by_login_and_activated(*args)
#   options = args.extract_options!
#   ...
# end
self.class_eval %{
  def self.#{method_id}(*args)
    options = args.extract_options!
    ...
  end
}
</ruby>
