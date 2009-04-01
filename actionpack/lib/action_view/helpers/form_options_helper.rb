require 'cgi'
require 'erb'
require 'action_view/helpers/form_helper'

module ActionView
  module Helpers
    # Provides a number of methods for turning different kinds of containers into a set of option tags.
    # == Options
    # The <tt>collection_select</tt>, <tt>select</tt> and <tt>time_zone_select</tt> methods take an <tt>options</tt> parameter, a hash:
    #
    # * <tt>:include_blank</tt> - set to true or a prompt string if the first option element of the select element is a blank. Useful if there is not a default value required for the select element.
    #
    # For example,
    #
    #   select("post", "category", Post::CATEGORIES, {:include_blank => true})
    #
    # could become:
    #
    #   <select name="post[category]">
    #     <option></option>
    #     <option>joke</option>
    #     <option>poem</option>
    #   </select>
    #
    # Another common case is a select tag for an <tt>belongs_to</tt>-associated object.
    #
    # Example with @post.person_id => 2:
    #
    #   select("post", "person_id", Person.all.collect {|p| [ p.name, p.id ] }, {:include_blank => 'None'})
    #
    # could become:
    #
    #   <select name="post[person_id]">
    #     <option value="">None</option>
    #     <option value="1">David</option>
    #     <option value="2" selected="selected">Sam</option>
    #     <option value="3">Tobias</option>
    #   </select>
    #
    # * <tt>:prompt</tt> - set to true or a prompt string. When the select element doesn't have a value yet, this prepends an option with a generic prompt -- "Please select" -- or the given prompt string.
    #
    # Example:
    #
    #   select("post", "person_id", Person.all.collect {|p| [ p.name, p.id ] }, {:prompt => 'Select Person'})
    #
    # could become:
    #
    #   <select name="post[person_id]">
    #     <option value="">Select Person</option>
    #     <option value="1">David</option>
    #     <option value="2">Sam</option>
    #     <option value="3">Tobias</option>
    #   </select>
    # 
    # Like the other form helpers, +select+ can accept an <tt>:index</tt> option to manually set the ID used in the resulting output. Unlike other helpers, +select+ expects this 
    # option to be in the +html_options+ parameter.
    # 
    # Example: 
    # 
    #   select("album[]", "genre", %w[rap rock country], {}, { :index => nil })
    # 
    # becomes:
    # 
    #   <select name="album[][genre]" id="album__genre">
    #     <option value="rap">rap</option>
    #     <option value="rock">rock</option>
    #     <option value="country">country</option>
    #   </select>
    #
    # * <tt>:disabled</tt> - can be a single value or an array of values that will be disabled options in the final output.
    #
    # Example:
    #
    #   select("post", "category", Post::CATEGORIES, {:disabled => 'restricted'})
    #
    # could become:
    #
    #   <select name="post[category]">
    #     <option></option>
    #     <option>joke</option>
    #     <option>poem</option>
    #     <option disabled="disabled">restricted</option>
    #   </select>
    #
    # When used with the <tt>collection_select</tt> helper, <tt>:disabled</tt> can also be a Proc that identifies those options that should be disabled.
    #
    # Example:
    #
    #   collection_select(:post, :category_id, Category.all, :id, :name, {:disabled => lambda{|category| category.archived? }})
    #
    # If the categories "2008 stuff" and "Christmas" return true when the method <tt>archived?</tt> is called, this would return:
    #   <select name="post[category_id]">
    #     <option value="1" disabled="disabled">2008 stuff</option>
    #     <option value="2" disabled="disabled">Christmas</option>
    #     <option value="3">Jokes</option>
    #     <option value="4">Poems</option>
    #   </select>
    #
    module FormOptionsHelper
      include ERB::Util

      # Create a select tag and a series of contained option tags for the provided object and method.
      # The option currently held by the object will be selected, provided that the object is available.
      # See options_for_select for the required format of the choices parameter.
      #
      # Example with @post.person_id => 1:
      #   select("post", "person_id", Person.all.collect {|p| [ p.name, p.id ] }, { :include_blank => true })
      #
      # could become:
      #
      #   <select name="post[person_id]">
      #     <option value=""></option>
      #     <option value="1" selected="selected">David</option>
      #     <option value="2">Sam</option>
      #     <option value="3">Tobias</option>
      #   </select>
      #
      # This can be used to provide a default set of options in the standard way: before rendering the create form, a
      # new model instance is assigned the default options and bound to @model_name. Usually this model is not saved
      # to the database. Instead, a second model object is created when the create request is received.
      # This allows the user to submit a form page more than once with the expected results of creating multiple records.
      # In addition, this allows a single partial to be used to generate form inputs for both edit and create forms.
      #
      # By default, <tt>post.person_id</tt> is the selected option.  Specify <tt>:selected => value</tt> to use a different selection
      # or <tt>:selected => nil</tt> to leave all options unselected. Similarly, you can specify values to be disabled in the option
      # tags by specifying the <tt>:disabled</tt> option. This can either be a single value or an array of values to be disabled.
      def select(object, method, choices, options = {}, html_options = {})
        InstanceTag.new(object, method, self, options.delete(:object)).to_select_tag(choices, options, html_options)
      end

      # Returns <tt><select></tt> and <tt><option></tt> tags for the collection of existing return values of
      # +method+ for +object+'s class. The value returned from calling +method+ on the instance +object+ will
      # be selected. If calling +method+ returns +nil+, no selection is made without including <tt>:prompt</tt>
      # or <tt>:include_blank</tt> in the +options+ hash.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are methods to be called on each member
      # of +collection+. The return values are used as the +value+ attribute and contents of each
      # <tt><option></tt> tag, respectively.
      # 
      # Example object structure for use with this method:
      #   class Post < ActiveRecord::Base
      #     belongs_to :author
      #   end
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated Author for an instance of Post, <tt>@post</tt>):
      #   collection_select(:post, :author_id, Author.all, :id, :name_with_initial, {:prompt => true})
      #
      # If <tt>@post.author_id</tt> is already <tt>1</tt>, this would return:
      #   <select name="post[author_id]">
      #     <option value="">Please select</option>
      #     <option value="1" selected="selected">D. Heinemeier Hansson</option>
      #     <option value="2">D. Thomas</option>
      #     <option value="3">M. Clark</option>
      #   </select>
      def collection_select(object, method, collection, value_method, text_method, options = {}, html_options = {})
        InstanceTag.new(object, method, self, options.delete(:object)).to_collection_select_tag(collection, value_method, text_method, options, html_options)
      end

      # Return select and option tags for the given object and method, using
      # #time_zone_options_for_select to generate the list of option tags.
      #
      # In addition to the <tt>:include_blank</tt> option documented above,
      # this method also supports a <tt>:model</tt> option, which defaults
      # to TimeZone. This may be used by users to specify a different time
      # zone model object. (See +time_zone_options_for_select+ for more
      # information.)
      #
      # You can also supply an array of TimeZone objects
      # as +priority_zones+, so that they will be listed above the rest of the
      # (long) list. (You can use TimeZone.us_zones as a convenience for
      # obtaining a list of the US time zones, or a Regexp to select the zones
      # of your choice)
      #
      # Finally, this method supports a <tt>:default</tt> option, which selects
      # a default TimeZone if the object's time zone is +nil+.
      #
      # Examples:
      #   time_zone_select( "user", "time_zone", nil, :include_blank => true)
      #
      #   time_zone_select( "user", "time_zone", nil, :default => "Pacific Time (US & Canada)" )
      #
      #   time_zone_select( "user", 'time_zone', TimeZone.us_zones, :default => "Pacific Time (US & Canada)")
      #
      #   time_zone_select( "user", 'time_zone', [ TimeZone['Alaska'], TimeZone['Hawaii'] ])
      #
      #   time_zone_select( "user", 'time_zone', /Australia/)
      #
      #   time_zone_select( "user", "time_zone", TZInfo::Timezone.all.sort, :model => TZInfo::Timezone)
      def time_zone_select(object, method, priority_zones = nil, options = {}, html_options = {})
        InstanceTag.new(object, method, self,  options.delete(:object)).to_time_zone_select_tag(priority_zones, options, html_options)
      end

      # Accepts a container (hash, array, enumerable, your type) and returns a string of option tags. Given a container
      # where the elements respond to first and last (such as a two-element array), the "lasts" serve as option values and
      # the "firsts" as option text. Hashes are turned into this form automatically, so the keys become "firsts" and values
      # become lasts. If +selected+ is specified, the matching "last" or element will get the selected option-tag.  +selected+
      # may also be an array of values to be selected when using a multiple select.
      #
      # Examples (call, result):
      #   options_for_select([["Dollar", "$"], ["Kroner", "DKK"]])
      #     <option value="$">Dollar</option>\n<option value="DKK">Kroner</option>
      #
      #   options_for_select([ "VISA", "MasterCard" ], "MasterCard")
      #     <option>VISA</option>\n<option selected="selected">MasterCard</option>
      #
      #   options_for_select({ "Basic" => "$20", "Plus" => "$40" }, "$40")
      #     <option value="$20">Basic</option>\n<option value="$40" selected="selected">Plus</option>
      #
      #   options_for_select([ "VISA", "MasterCard", "Discover" ], ["VISA", "Discover"])
      #     <option selected="selected">VISA</option>\n<option>MasterCard</option>\n<option selected="selected">Discover</option>
      #
      # If you wish to specify disabled option tags, set +selected+ to be a hash, with <tt>:disabled</tt> being either a value
      # or array of values to be disabled. In this case, you can use <tt>:selected</tt> to specify selected option tags.
      #
      # Examples:
      #   options_for_select(["Free", "Basic", "Advanced", "Super Platinum"], :disabled => "Super Platinum")
      #     <option value="Free">Free</option>\n<option value="Basic">Basic</option>\n<option value="Advanced">Advanced</option>\n<option value="Super Platinum" disabled="disabled">Super Platinum</option>
      #
      #   options_for_select(["Free", "Basic", "Advanced", "Super Platinum"], :disabled => ["Advanced", "Super Platinum"])
      #     <option value="Free">Free</option>\n<option value="Basic">Basic</option>\n<option value="Advanced" disabled="disabled">Advanced</option>\n<option value="Super Platinum" disabled="disabled">Super Platinum</option>
      #
      #   options_for_select(["Free", "Basic", "Advanced", "Super Platinum"], :selected => "Free", :disabled => "Super Platinum")
      #     <option value="Free" selected="selected">Free</option>\n<option value="Basic">Basic</option>\n<option value="Advanced">Advanced</option>\n<option value="Super Platinum" disabled="disabled">Super Platinum</option>
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in a regular HTML select tag.
      def options_for_select(container, selected = nil)
        return container if String === container

        container = container.to_a if Hash === container
        selected, disabled = extract_selected_and_disabled(selected)

        options_for_select = container.inject([]) do |options, element|
          text, value = option_text_and_value(element)
          selected_attribute = ' selected="selected"' if option_value_selected?(value, selected)
          disabled_attribute = ' disabled="disabled"' if disabled && option_value_selected?(value, disabled)
          options << %(<option value="#{html_escape(value.to_s)}"#{selected_attribute}#{disabled_attribute}>#{html_escape(text.to_s)}</option>)
        end

        options_for_select.join("\n")
      end

      # Returns a string of option tags that have been compiled by iterating over the +collection+ and assigning the
      # the result of a call to the +value_method+ as the option value and the +text_method+ as the option text.
      # Example:
      #   options_from_collection_for_select(@people, 'id', 'name')
      # This will output the same HTML as if you did this:
      #   <option value="#{person.id}">#{person.name}</option>
      #
      # This is more often than not used inside a #select_tag like this example:
      #   select_tag 'person', options_from_collection_for_select(@people, 'id', 'name')
      #
      # If +selected+ is specified as a value or array of values, the element(s) returning a match on +value_method+
      # will be selected option tag(s).
      #
      # If +selected+ is specified as a Proc, those members of the collection that return true for the anonymous
      # function are the selected values.
      #
      # +selected+ can also be a hash, specifying both <tt>:selected</tt> and/or <tt>:disabled</tt> values as required.
      #
      # Be sure to specify the same class as the +value_method+ when specifying selected or disabled options.
      # Failure to do this will produce undesired results. Example:
      #   options_from_collection_for_select(@people, 'id', 'name', '1')
      # Will not select a person with the id of 1 because 1 (an Integer) is not the same as '1' (a string)
      #   options_from_collection_for_select(@people, 'id', 'name', 1)
      # should produce the desired results.
      def options_from_collection_for_select(collection, value_method, text_method, selected = nil)
        options = collection.map do |element|
          [element.send(text_method), element.send(value_method)]
        end
        selected, disabled = extract_selected_and_disabled(selected)
        select_deselect = {}
        select_deselect[:selected] = extract_values_from_collection(collection, value_method, selected)
        select_deselect[:disabled] = extract_values_from_collection(collection, value_method, disabled)

        options_for_select(options, select_deselect)
      end

      # Returns a string of <tt><option></tt> tags, like <tt>options_from_collection_for_select</tt>, but
      # groups them by <tt><optgroup></tt> tags based on the object relationships of the arguments.
      #
      # Parameters:
      # * +collection+ - An array of objects representing the <tt><optgroup></tt> tags.
      # * +group_method+ - The name of a method which, when called on a member of +collection+, returns an
      #   array of child objects representing the <tt><option></tt> tags.
      # * group_label_method+ - The name of a method which, when called on a member of +collection+, returns a
      #   string to be used as the +label+ attribute for its <tt><optgroup></tt> tag.
      # * +option_key_method+ - The name of a method which, when called on a child object of a member of
      #   +collection+, returns a value to be used as the +value+ attribute for its <tt><option></tt> tag.
      # * +option_value_method+ - The name of a method which, when called on a child object of a member of
      #   +collection+, returns a value to be used as the contents of its <tt><option></tt> tag.
      # * +selected_key+ - A value equal to the +value+ attribute for one of the <tt><option></tt> tags,
      #   which will have the +selected+ attribute set. Corresponds to the return value of one of the calls
      #   to +option_key_method+. If +nil+, no selection is made. Can also be a hash if disabled values are
      #   to be specified.
      #
      # Example object structure for use with this method:
      #   class Continent < ActiveRecord::Base
      #     has_many :countries
      #     # attribs: id, name
      #   end
      #   class Country < ActiveRecord::Base
      #     belongs_to :continent
      #     # attribs: id, name, continent_id
      #   end
      #
      # Sample usage:
      #   option_groups_from_collection_for_select(@continents, :countries, :name, :id, :name, 3)
      #
      # Possible output:
      #   <optgroup label="Africa">
      #     <option value="1">Egypt</option>
      #     <option value="4">Rwanda</option>
      #     ...
      #   </optgroup>
      #   <optgroup label="Asia">
      #     <option value="3" selected="selected">China</option>
      #     <option value="12">India</option>
      #     <option value="5">Japan</option>
      #     ...
      #   </optgroup>
      #
      # <b>Note:</b> Only the <tt><optgroup></tt> and <tt><option></tt> tags are returned, so you still have to
      # wrap the output in an appropriate <tt><select></tt> tag.
      def option_groups_from_collection_for_select(collection, group_method, group_label_method, option_key_method, option_value_method, selected_key = nil)
        collection.inject("") do |options_for_select, group|
          group_label_string = eval("group.#{group_label_method}")
          options_for_select += "<optgroup label=\"#{html_escape(group_label_string)}\">"
          options_for_select += options_from_collection_for_select(eval("group.#{group_method}"), option_key_method, option_value_method, selected_key)
          options_for_select += '</optgroup>'
        end
      end

      # Returns a string of <tt><option></tt> tags, like <tt>options_for_select</tt>, but
      # wraps them with <tt><optgroup></tt> tags.
      #
      # Parameters:
      # * +grouped_options+ - Accepts a nested array or hash of strings.  The first value serves as the
      #   <tt><optgroup></tt> label while the second value must be an array of options. The second value can be a
      #   nested array of text-value pairs. See <tt>options_for_select</tt> for more info.
      #    Ex. ["North America",[["United States","US"],["Canada","CA"]]]
      # * +selected_key+ - A value equal to the +value+ attribute for one of the <tt><option></tt> tags,
      #   which will have the +selected+ attribute set. Note: It is possible for this value to match multiple options
      #   as you might have the same option in multiple groups.  Each will then get <tt>selected="selected"</tt>.
      # * +prompt+ - set to true or a prompt string. When the select element doesn’t have a value yet, this
      #   prepends an option with a generic prompt — "Please select" — or the given prompt string.
      #
      # Sample usage (Array):
      #   grouped_options = [
      #    ['North America',
      #      [['United States','US'],'Canada']],
      #    ['Europe',
      #      ['Denmark','Germany','France']]
      #   ]
      #   grouped_options_for_select(grouped_options)
      #
      # Sample usage (Hash):
      #   grouped_options = {
      #    'North America' => [['United States','US], 'Canada'],
      #    'Europe' => ['Denmark','Germany','France']
      #   }
      #   grouped_options_for_select(grouped_options)
      #
      # Possible output:
      #   <optgroup label="Europe">
      #     <option value="Denmark">Denmark</option>
      #     <option value="Germany">Germany</option>
      #     <option value="France">France</option>
      #   </optgroup>
      #   <optgroup label="North America">
      #     <option value="US">United States</option>
      #     <option value="Canada">Canada</option>
      #   </optgroup>
      #
      # <b>Note:</b> Only the <tt><optgroup></tt> and <tt><option></tt> tags are returned, so you still have to
      # wrap the output in an appropriate <tt><select></tt> tag.
      def grouped_options_for_select(grouped_options, selected_key = nil, prompt = nil)
        body = ''
        body << content_tag(:option, prompt, :value => "") if prompt

        grouped_options = grouped_options.sort if grouped_options.is_a?(Hash)

        grouped_options.each do |group|
          body << content_tag(:optgroup, options_for_select(group[1], selected_key), :label => group[0])
        end

        body
      end

      # Returns a string of option tags for pretty much any time zone in the
      # world. Supply a TimeZone name as +selected+ to have it marked as the
      # selected option tag. You can also supply an array of TimeZone objects
      # as +priority_zones+, so that they will be listed above the rest of the
      # (long) list. (You can use TimeZone.us_zones as a convenience for
      # obtaining a list of the US time zones, or a Regexp to select the zones
      # of your choice)
      #
      # The +selected+ parameter must be either +nil+, or a string that names
      # a TimeZone.
      #
      # By default, +model+ is the TimeZone constant (which can be obtained
      # in Active Record as a value object). The only requirement is that the
      # +model+ parameter be an object that responds to +all+, and returns
      # an array of objects that represent time zones.
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in
      # a regular HTML select tag.
      def time_zone_options_for_select(selected = nil, priority_zones = nil, model = ::ActiveSupport::TimeZone)
        zone_options = ""

        zones = model.all
        convert_zones = lambda { |list| list.map { |z| [ z.to_s, z.name ] } }

        if priority_zones
	        if priority_zones.is_a?(Regexp)
            priority_zones = model.all.find_all {|z| z =~ priority_zones}
	        end
          zone_options += options_for_select(convert_zones[priority_zones], selected)
          zone_options += "<option value=\"\" disabled=\"disabled\">-------------</option>\n"

          zones = zones.reject { |z| priority_zones.include?( z ) }
        end

        zone_options += options_for_select(convert_zones[zones], selected)
        zone_options
      end

      private
        def option_text_and_value(option)
          # Options are [text, value] pairs or strings used for both.
          if !option.is_a?(String) and option.respond_to?(:first) and option.respond_to?(:last)
            [option.first, option.last]
          else
            [option, option]
          end
        end

        def option_value_selected?(value, selected)
          if selected.respond_to?(:include?) && !selected.is_a?(String)
            selected.include? value
          else
            value == selected
          end
        end

        def extract_selected_and_disabled(selected)
          if selected.is_a?(Hash)
            [selected[:selected], selected[:disabled]]
          else
            [selected, nil]
          end
        end

        def extract_values_from_collection(collection, value_method, selected)
          if selected.is_a?(Proc)
            collection.map do |element|
              element.send(value_method) if selected.call(element)
            end.compact
          else
            selected
          end
        end
    end

    class InstanceTag #:nodoc:
      include FormOptionsHelper

      def to_select_tag(choices, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        selected_value = options.has_key?(:selected) ? options[:selected] : value
        disabled_value = options.has_key?(:disabled) ? options[:disabled] : nil
        content_tag("select", add_options(options_for_select(choices, :selected => selected_value, :disabled => disabled_value), options, selected_value), html_options)
      end

      def to_collection_select_tag(collection, value_method, text_method, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        disabled_value = options.has_key?(:disabled) ? options[:disabled] : nil
        selected_value = options.has_key?(:selected) ? options[:selected] : value
        content_tag(
          "select", add_options(options_from_collection_for_select(collection, value_method, text_method, :selected => selected_value, :disabled => disabled_value), options, value), html_options
        )
      end

      def to_time_zone_select_tag(priority_zones, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        content_tag("select",
          add_options(
            time_zone_options_for_select(value || options[:default], priority_zones, options[:model] || ActiveSupport::TimeZone),
            options, value
          ), html_options
        )
      end

      private
        def add_options(option_tags, options, value = nil)
          if options[:include_blank]
            option_tags = "<option value=\"\">#{options[:include_blank] if options[:include_blank].kind_of?(String)}</option>\n" + option_tags
          end
          if value.blank? && options[:prompt]
            ("<option value=\"\">#{options[:prompt].kind_of?(String) ? options[:prompt] : 'Please select'}</option>\n") + option_tags
          else
            option_tags
          end
        end
    end

    class FormBuilder
      def select(method, choices, options = {}, html_options = {})
        @template.select(@object_name, method, choices, objectify_options(options), @default_options.merge(html_options))
      end

      def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_select(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_options.merge(html_options))
      end

      def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
        @template.time_zone_select(@object_name, method, priority_zones, objectify_options(options), @default_options.merge(html_options))
      end
    end
  end
end
