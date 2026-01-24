# frozen_string_literal: true

require "erb"
require "active_support/core_ext/string/output_safety"
require "active_support/core_ext/array/extract_options"
require "active_support/core_ext/array/wrap"
require "action_view/helpers/text_helper"

module ActionView
  module Helpers # :nodoc:
    # = Action View Form Option \Helpers
    #
    # Provides a number of methods for turning different kinds of containers into a set of option tags.
    #
    # The #collection_select, #select and #time_zone_select methods take an <tt>options</tt> parameter, a hash:
    #
    # * <tt>:include_blank</tt> - set to true or a prompt string if the first option element of the select element is a blank. Useful if there is not a default value required for the select element.
    #
    #     select(:post, :category, Post::CATEGORIES, { include_blank: true })
    #
    #   could become:
    #
    #     <select name="post[category]" id="post_category">
    #       <option value="" label=" "></option>
    #       <option value="joke">joke</option>
    #       <option value="poem">poem</option>
    #     </select>
    #
    #   Another common case is a select tag for a <tt>belongs_to</tt>-associated object.
    #
    #   Example with <tt>@post.person_id => 2</tt>:
    #
    #     select(:post, :person_id, Person.all.collect { |p| [ p.name, p.id ] }, { include_blank: "None" })
    #
    #   could become:
    #
    #     <select name="post[person_id]" id="post_person_id">
    #       <option value="">None</option>
    #       <option value="1">David</option>
    #       <option value="2" selected="selected">Eileen</option>
    #       <option value="3">Rafael</option>
    #     </select>
    #
    # * <tt>:prompt</tt> - set to true or a prompt string. When the select element doesn't have a value yet, this prepends an option with a generic prompt -- "Please select" -- or the given prompt string.
    #
    #     select(:post, :person_id, Person.all.collect { |p| [ p.name, p.id ] }, { prompt: "Select Person" })
    #
    #   could become:
    #
    #     <select name="post[person_id]" id="post_person_id">
    #       <option value="">Select Person</option>
    #       <option value="1">David</option>
    #       <option value="2">Eileen</option>
    #       <option value="3">Rafael</option>
    #     </select>
    #
    # * <tt>:index</tt> - like the other form helpers, #select can accept an <tt>:index</tt> option to manually set the ID used in the resulting output. Unlike other helpers, #select expects this
    #   option to be in the +html_options+ parameter.
    #
    #     select("album[]", :genre, %w[ rap rock country ], {}, { index: nil })
    #
    #   becomes:
    #
    #     <select name="album[][genre]" id="album__genre">
    #       <option value="rap">rap</option>
    #       <option value="rock">rock</option>
    #       <option value="country">country</option>
    #     </select>
    #
    # * <tt>:disabled</tt> - can be a single value or an array of values that will be disabled options in the final output.
    #
    #     select(:post, :category, Post::CATEGORIES, { disabled: "restricted" })
    #
    #   could become:
    #
    #     <select name="post[category]" id="post_category">
    #       <option value="joke">joke</option>
    #       <option value="poem">poem</option>
    #       <option disabled="disabled" value="restricted">restricted</option>
    #     </select>
    #
    #   When used with the #collection_select helper, <tt>:disabled</tt> can also be a Proc that identifies those options that should be disabled.
    #
    #     collection_select(:post, :category_id, Category.all, :id, :name, { disabled: -> (category) { category.archived? } })
    #
    #   If the categories "2008 stuff" and "Christmas" return true when the method <tt>archived?</tt> is called, this would return:
    #     <select name="post[category_id]" id="post_category_id">
    #       <option value="1" disabled="disabled">2008 stuff</option>
    #       <option value="2" disabled="disabled">Christmas</option>
    #       <option value="3">Jokes</option>
    #       <option value="4">Poems</option>
    #     </select>
    module FormOptionsHelper
      # ERB::Util can mask some helpers like textilize. Make sure to include them.
      include TextHelper

      # Create a select tag and a series of contained option tags for the provided object and method.
      # The option currently held by the object will be selected, provided that the object is available.
      #
      # There are two possible formats for the +choices+ parameter, corresponding to other helpers' output:
      #
      # * A flat collection (see <tt>options_for_select</tt>).
      # * A nested collection (see <tt>grouped_options_for_select</tt>).
      #
      # Example with <tt>@post.person_id => 2</tt>:
      #
      #   select :post, :person_id, Person.all.collect { |p| [ p.name, p.id ] }, { include_blank: true }
      #
      # would become:
      #
      #   <select name="post[person_id]" id="post_person_id">
      #     <option value="" label=" "></option>
      #     <option value="1">David</option>
      #     <option value="2" selected="selected">Eileen</option>
      #     <option value="3">Rafael</option>
      #   </select>
      #
      # This can be used to provide a default set of options in the standard way: before rendering the create form, a
      # new model instance is assigned the default options and bound to @model_name. Usually this model is not saved
      # to the database. Instead, a second model object is created when the create request is received.
      # This allows the user to submit a form page more than once with the expected results of creating multiple records.
      # In addition, this allows a single partial to be used to generate form inputs for both edit and create forms.
      #
      # By default, <tt>post.person_id</tt> is the selected option. Specify <tt>selected: value</tt> to use a different selection
      # or <tt>selected: nil</tt> to leave all options unselected. Similarly, you can specify values to be disabled in the option
      # tags by specifying the <tt>:disabled</tt> option. This can either be a single value or an array of values to be disabled.
      #
      # A block can be passed to #select to customize how the options tags will be rendered. This
      # is useful when the options tag has complex attributes.
      #
      #   select(report, :campaign_ids) do
      #     available_campaigns.each do |c|
      #       tag.option(c.name, value: c.id, data: { tags: c.tags.to_json })
      #     end
      #   end
      #
      # ==== Gotcha
      #
      # The HTML specification says when +multiple+ parameter passed to select and all options got deselected
      # web browsers do not send any value to server. Unfortunately this introduces a gotcha:
      # if a +User+ model has many +roles+ and have +role_ids+ accessor, and in the form that edits roles of the user
      # the user deselects all roles from +role_ids+ multiple select box, no +role_ids+ parameter is sent. So,
      # any mass-assignment idiom like
      #
      #   @user.update(params[:user])
      #
      # wouldn't update roles.
      #
      # To prevent this the helper generates an auxiliary hidden field before
      # every multiple select. The hidden field has the same name as multiple select and blank value.
      #
      # <b>Note:</b> The client either sends only the hidden field (representing
      # the deselected multiple select box), or both fields. This means that the resulting array
      # always contains a blank string.
      #
      # In case if you don't want the helper to generate this hidden field you can specify
      # <tt>include_hidden: false</tt> option.
      def select(object, method, choices = nil, options = {}, html_options = {}, &block)
        Tags::Select.new(object, method, self, choices, options, html_options, &block).render
      end

      # Returns <tt><select></tt> and <tt><option></tt> tags for the collection of existing return values of
      # +method+ for +object+'s class. The value returned from calling +method+ on the instance +object+ will
      # be selected. If calling +method+ returns +nil+, no selection is made without including <tt>:prompt</tt>
      # or <tt>:include_blank</tt> in the +options+ hash.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are methods to be called on each member
      # of +collection+. The return values are used as the +value+ attribute and contents of each
      # <tt><option></tt> tag, respectively. They can also be any object that responds to +call+, such
      # as a +proc+, that will be called for each member of the +collection+ to
      # retrieve the value/text.
      #
      # Example object structure for use with this method:
      #
      #   class Post < ActiveRecord::Base
      #     belongs_to :author
      #   end
      #
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated Author for an instance of Post, <tt>@post</tt>):
      #
      #   collection_select(:post, :author_id, Author.all, :id, :name_with_initial, prompt: true)
      #
      # If <tt>@post.author_id</tt> is already <tt>1</tt>, this would return:
      #   <select name="post[author_id]" id="post_author_id">
      #     <option value="">Please select</option>
      #     <option value="1" selected="selected">D. Heinemeier Hansson</option>
      #     <option value="2">D. Thomas</option>
      #     <option value="3">M. Clark</option>
      #   </select>
      def collection_select(object, method, collection, value_method, text_method, options = {}, html_options = {})
        Tags::CollectionSelect.new(object, method, self, collection, value_method, text_method, options, html_options).render
      end

      # Returns <tt><select></tt>, <tt><optgroup></tt> and <tt><option></tt> tags for the collection of existing return values of
      # +method+ for +object+'s class. The value returned from calling +method+ on the instance +object+ will
      # be selected. If calling +method+ returns +nil+, no selection is made without including <tt>:prompt</tt>
      # or <tt>:include_blank</tt> in the +options+ hash.
      #
      # Parameters:
      # * +object+ - The instance of the class to be used for the select tag
      # * +method+ - The attribute of +object+ corresponding to the select tag
      # * +collection+ - An array of objects representing the <tt><optgroup></tt> tags.
      # * +group_method+ - The name of a method which, when called on a member of +collection+, returns an
      #   array of child objects representing the <tt><option></tt> tags. It can also be any object that responds
      #   to +call+, such as a +proc+, that will be called for each member of the +collection+ to retrieve the
      #   value.
      # * +group_label_method+ - The name of a method which, when called on a member of +collection+, returns a
      #   string to be used as the +label+ attribute for its <tt><optgroup></tt> tag. It can also be any object
      #   that responds to +call+, such as a +proc+, that will be called for each member of the +collection+ to
      #   retrieve the label.
      # * +option_key_method+ - The name of a method which, when called on a child object of a member of
      #   +collection+, returns a value to be used as the +value+ attribute for its <tt><option></tt> tag.
      # * +option_value_method+ - The name of a method which, when called on a child object of a member of
      #   +collection+, returns a value to be used as the contents of its <tt><option></tt> tag.
      #
      # Example object structure for use with this method:
      #
      #   # attributes: id, name
      #   class Continent < ActiveRecord::Base
      #     has_many :countries
      #   end
      #
      #   # attributes: id, name, continent_id
      #   class Country < ActiveRecord::Base
      #     belongs_to :continent
      #   end
      #
      #   # attributes: id, name, country_id
      #   class City < ActiveRecord::Base
      #     belongs_to :country
      #   end
      #
      # Sample usage:
      #
      #   grouped_collection_select(:city, :country_id, @continents, :countries, :name, :id, :name)
      #
      # Possible output:
      #
      #   <select name="city[country_id]" id="city_country_id">
      #     <optgroup label="Africa">
      #       <option value="1">South Africa</option>
      #       <option value="3">Somalia</option>
      #     </optgroup>
      #     <optgroup label="Europe">
      #       <option value="7" selected="selected">Denmark</option>
      #       <option value="2">Ireland</option>
      #     </optgroup>
      #   </select>
      def grouped_collection_select(object, method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
        Tags::GroupedCollectionSelect.new(object, method, self, collection, group_method, group_label_method, option_key_method, option_value_method, options, html_options).render
      end

      # Returns select and option tags for the given object and method, using
      # #time_zone_options_for_select to generate the list of option tags.
      #
      # In addition to the <tt>:include_blank</tt> option documented above,
      # this method also supports a <tt>:model</tt> option, which defaults
      # to ActiveSupport::TimeZone. This may be used by users to specify a
      # different time zone model object. (See #time_zone_options_for_select
      # for more information.)
      #
      # You can also supply an array of ActiveSupport::TimeZone objects
      # as +priority_zones+ so that they will be listed above the rest of the
      # (long) list. You can use ActiveSupport::TimeZone.us_zones for a list
      # of US time zones, ActiveSupport::TimeZone.country_zones(country_code)
      # for another country's time zones, or a Regexp to select the zones of
      # your choice.
      #
      # Finally, this method supports a <tt>:default</tt> option, which selects
      # a default ActiveSupport::TimeZone if the object's time zone is +nil+.
      #
      #   time_zone_select(:user, :time_zone, nil, include_blank: true)
      #
      #   time_zone_select(:user, :time_zone, nil, default: "Pacific Time (US & Canada)")
      #
      #   time_zone_select(:user, :time_zone, ActiveSupport::TimeZone.us_zones, default: "Pacific Time (US & Canada)")
      #
      #   time_zone_select(:user, :time_zone, [ ActiveSupport::TimeZone["Alaska"], ActiveSupport::TimeZone["Hawaii"] ])
      #
      #   time_zone_select(:user, :time_zone, /Australia/)
      #
      #   time_zone_select(:user, :time_zone, ActiveSupport::TimeZone.all.sort, model: ActiveSupport::TimeZone)
      def time_zone_select(object, method, priority_zones = nil, options = {}, html_options = {})
        Tags::TimeZoneSelect.new(object, method, self, priority_zones, options, html_options).render
      end

      # Returns select and option tags for the given object and method, using
      # #weekday_options_for_select to generate the list of option tags.
      def weekday_select(object, method, options = {}, html_options = {}, &block)
        Tags::WeekdaySelect.new(object, method, self, options, html_options, &block).render
      end

      # Accepts a container (hash, array, enumerable, your type) and returns a string of option tags. Given a container
      # where the elements respond to first and last (such as a two-element array), the "lasts" serve as option values and
      # the "firsts" as option text. Hashes are turned into this form automatically, so the keys become "firsts" and values
      # become lasts. If +selected+ is specified, the matching "last" or element will get the selected option-tag. +selected+
      # may also be an array of values to be selected when using a multiple select.
      #
      #   options_for_select([["Dollar", "$"], ["Kroner", "DKK"]])
      #   # => <option value="$">Dollar</option>
      #   # => <option value="DKK">Kroner</option>
      #
      #   options_for_select([ "VISA", "MasterCard" ], "MasterCard")
      #   # => <option value="VISA">VISA</option>
      #   # => <option selected="selected" value="MasterCard">MasterCard</option>
      #
      #   options_for_select({ "Basic" => "$20", "Plus" => "$40" }, "$40")
      #   # => <option value="$20">Basic</option>
      #   # => <option value="$40" selected="selected">Plus</option>
      #
      #   options_for_select([ "VISA", "MasterCard", "Discover" ], ["VISA", "Discover"])
      #   # => <option selected="selected" value="VISA">VISA</option>
      #   # => <option value="MasterCard">MasterCard</option>
      #   # => <option selected="selected" value="Discover">Discover</option>
      #
      # You can optionally provide HTML attributes as the last element of the array.
      #
      #   options_for_select([ "Denmark", ["USA", { class: 'bold' }], "Sweden" ], ["USA", "Sweden"])
      #   # => <option value="Denmark">Denmark</option>
      #   # => <option value="USA" class="bold" selected="selected">USA</option>
      #   # => <option value="Sweden" selected="selected">Sweden</option>
      #
      #   options_for_select([["Dollar", "$", { class: "bold" }], ["Kroner", "DKK", { onclick: "alert('HI');" }]])
      #   # => <option value="$" class="bold">Dollar</option>
      #   # => <option value="DKK" onclick="alert('HI');">Kroner</option>
      #
      # If you wish to specify disabled option tags, set +selected+ to be a hash, with <tt>:disabled</tt> being either a value
      # or array of values to be disabled. In this case, you can use <tt>:selected</tt> to specify selected option tags.
      #
      #   options_for_select(["Free", "Basic", "Advanced", "Super Platinum"], disabled: "Super Platinum")
      #   # => <option value="Free">Free</option>
      #   # => <option value="Basic">Basic</option>
      #   # => <option value="Advanced">Advanced</option>
      #   # => <option value="Super Platinum" disabled="disabled">Super Platinum</option>
      #
      #   options_for_select(["Free", "Basic", "Advanced", "Super Platinum"], disabled: ["Advanced", "Super Platinum"])
      #   # => <option value="Free">Free</option>
      #   # => <option value="Basic">Basic</option>
      #   # => <option value="Advanced" disabled="disabled">Advanced</option>
      #   # => <option value="Super Platinum" disabled="disabled">Super Platinum</option>
      #
      #   options_for_select(["Free", "Basic", "Advanced", "Super Platinum"], selected: "Free", disabled: "Super Platinum")
      #   # => <option value="Free" selected="selected">Free</option>
      #   # => <option value="Basic">Basic</option>
      #   # => <option value="Advanced">Advanced</option>
      #   # => <option value="Super Platinum" disabled="disabled">Super Platinum</option>
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in a regular HTML select tag.
      def options_for_select(container, selected = nil)
        return container if String === container

        selected, disabled = extract_selected_and_disabled(selected).map do |r|
          Array(r).map(&:to_s)
        end

        container.map do |element|
          html_attributes = option_html_attributes(element)
          text, value = option_text_and_value(element).map(&:to_s)

          html_attributes[:selected] ||= option_value_selected?(value, selected)
          html_attributes[:disabled] ||= disabled && option_value_selected?(value, disabled)
          html_attributes[:value] = value

          tag_builder.option(text, **html_attributes)
        end.join("\n").html_safe
      end

      # Returns a string of option tags that have been compiled by iterating over the +collection+ and assigning
      # the result of a call to the +value_method+ as the option value and the +text_method+ as the option text.
      #
      #   options_from_collection_for_select(@people, 'id', 'name')
      #   # => <option value="#{person.id}">#{person.name}</option>
      #
      # This is more often than not used inside a #select_tag like this example:
      #
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
          [value_for_collection(element, text_method), value_for_collection(element, value_method), option_html_attributes(element)]
        end
        selected, disabled = extract_selected_and_disabled(selected)
        select_deselect = {
          selected: extract_values_from_collection(collection, value_method, selected),
          disabled: extract_values_from_collection(collection, value_method, disabled)
        }

        options_for_select(options, select_deselect)
      end

      # Returns a string of <tt><option></tt> tags, like #options_from_collection_for_select, but
      # groups them by <tt><optgroup></tt> tags based on the object relationships of the arguments.
      #
      # Parameters:
      # * +collection+ - An array of objects representing the <tt><optgroup></tt> tags.
      # * +group_method+ - The name of a method which, when called on a member of +collection+, returns an
      #   array of child objects representing the <tt><option></tt> tags.
      # * +group_label_method+ - The name of a method which, when called on a member of +collection+, returns a
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
      #
      #   class Continent < ActiveRecord::Base
      #     has_many :countries
      #     # attribs: id, name
      #   end
      #
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
        collection.map do |group|
          option_tags = options_from_collection_for_select(
            value_for_collection(group, group_method), option_key_method, option_value_method, selected_key)

          content_tag("optgroup", option_tags, label: value_for_collection(group, group_label_method))
        end.join.html_safe
      end

      # Returns a string of <tt><option></tt> tags, like #options_for_select, but
      # wraps them with <tt><optgroup></tt> tags:
      #
      #   grouped_options = [
      #    ['North America',
      #      [['United States','US'],'Canada']],
      #    ['Europe',
      #      ['Denmark','Germany','France']]
      #   ]
      #   grouped_options_for_select(grouped_options)
      #
      #   grouped_options = {
      #     'North America' => [['United States','US'], 'Canada'],
      #     'Europe' => ['Denmark','Germany','France']
      #   }
      #   grouped_options_for_select(grouped_options)
      #
      # Possible output:
      #   <optgroup label="North America">
      #     <option value="US">United States</option>
      #     <option value="Canada">Canada</option>
      #   </optgroup>
      #   <optgroup label="Europe">
      #     <option value="Denmark">Denmark</option>
      #     <option value="Germany">Germany</option>
      #     <option value="France">France</option>
      #   </optgroup>
      #
      # ==== Parameters
      #
      # * +grouped_options+ - Accepts a nested array or hash of strings. The first value serves as the
      #   <tt><optgroup></tt> label while the second value must be an array of options. The second value can be a
      #   nested array of text-value pairs. See <tt>options_for_select</tt> for more info.
      #    Ex. ["North America",[["United States","US"],["Canada","CA"]]]
      #   An optional third value can be provided as HTML attributes for the <tt>optgroup</tt>.
      #    Ex. ["North America",[["United States","US"],["Canada","CA"]], { disabled: "disabled" }]
      # * +selected_key+ - A value equal to the +value+ attribute for one of the <tt><option></tt> tags,
      #   which will have the +selected+ attribute set. Note: It is possible for this value to match multiple options
      #   as you might have the same option in multiple groups. Each will then get <tt>selected="selected"</tt>.
      #
      # ==== Options
      #
      # * <tt>:prompt</tt> - set to true or a prompt string. When the select element doesn't have a value yet, this
      #   prepends an option with a generic prompt - "Please select" - or the given prompt string.
      # * <tt>:divider</tt> - the divider for the options groups.
      #
      #     grouped_options = [
      #       [['United States','US'], 'Canada'],
      #       ['Denmark','Germany','France']
      #     ]
      #     grouped_options_for_select(grouped_options, nil, divider: '---------')
      #
      #   Possible output:
      #     <optgroup label="---------">
      #       <option value="US">United States</option>
      #       <option value="Canada">Canada</option>
      #     </optgroup>
      #     <optgroup label="---------">
      #       <option value="Denmark">Denmark</option>
      #       <option value="Germany">Germany</option>
      #       <option value="France">France</option>
      #     </optgroup>
      #
      # <b>Note:</b> Only the <tt><optgroup></tt> and <tt><option></tt> tags are returned, so you still have to
      # wrap the output in an appropriate <tt><select></tt> tag.
      def grouped_options_for_select(grouped_options, selected_key = nil, options = {})
        prompt  = options[:prompt]
        divider = options[:divider]

        body = "".html_safe

        if prompt
          body.safe_concat content_tag("option", prompt_text(prompt), value: "")
        end

        grouped_options.each do |container|
          html_attributes = option_html_attributes(container)

          if divider
            label = divider
          else
            label, container = container
          end

          html_attributes = { label: label }.merge!(html_attributes)
          body.safe_concat content_tag("optgroup", options_for_select(container, selected_key), html_attributes)
        end

        body
      end

      # Returns a string of option tags for pretty much any time zone in the
      # world. Supply an ActiveSupport::TimeZone name as +selected+ to have it
      # marked as the selected option tag. You can also supply an array of
      # ActiveSupport::TimeZone objects as +priority_zones+, so that they will
      # be listed above the rest of the (long) list. (You can use
      # ActiveSupport::TimeZone.us_zones as a convenience for obtaining a list
      # of the US time zones, or a Regexp to select the zones of your choice)
      #
      # The +selected+ parameter must be either +nil+, or a string that names
      # an ActiveSupport::TimeZone.
      #
      # By default, +model+ is the ActiveSupport::TimeZone constant (which can
      # be obtained in Active Record as a value object). The +model+ parameter
      # must respond to +all+ and return an array of objects that represent time
      # zones; each object must respond to +name+. If a Regexp is given it will
      # attempt to match the zones using <code>match?</code> method.
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in
      # a regular HTML select tag.
      def time_zone_options_for_select(selected = nil, priority_zones = nil, model = ::ActiveSupport::TimeZone)
        zone_options = "".html_safe

        zones = model.all
        convert_zones = lambda { |list| list.map { |z| [ z.to_s, z.name ] } }

        if priority_zones
          if priority_zones.is_a?(Regexp)
            priority_zones = zones.select { |z| z.match?(priority_zones) }
          end

          zone_options.safe_concat options_for_select(convert_zones[priority_zones], selected)
          zone_options.safe_concat content_tag("option", "-------------", value: "", disabled: true)
          zone_options.safe_concat "\n"

          zones = zones - priority_zones
        end

        zone_options.safe_concat options_for_select(convert_zones[zones], selected)
      end

      # Returns a string of option tags for the days of the week.
      #
      # ====Options
      #
      # * <tt>:index_as_value</tt> - Defaults to false, set to true to use the indexes from
      #   <tt>I18n.translate("date.day_names")</tt> as the values. By default, Sunday is always 0.
      # * <tt>:day_format</tt> - The I18n key of the array to use for the weekday options.
      #   Defaults to +:day_names+, set to +:abbr_day_names+ for abbreviations.
      # * <tt>:beginning_of_week</tt> - Defaults to Date.beginning_of_week.
      #
      # NOTE: Only the option tags are returned, you have to wrap this call in
      # a regular HTML select tag.
      def weekday_options_for_select(selected = nil, index_as_value: false, day_format: :day_names, beginning_of_week: Date.beginning_of_week)
        day_names = I18n.translate("date.#{day_format}")
        day_names = day_names.map.with_index.to_a if index_as_value
        day_names = day_names.rotate(Date::DAYS_INTO_WEEK.fetch(beginning_of_week))

        options_for_select(day_names, selected)
      end

      # Returns radio button tags for the collection of existing return values
      # of +method+ for +object+'s class. The value returned from calling
      # +method+ on the instance +object+ will be selected. If calling +method+
      # returns +nil+, no selection is made.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are
      # methods to be called on each member of +collection+. The return values
      # are used as the +value+ attribute and contents of each radio button tag,
      # respectively. They can also be any object that responds to +call+, such
      # as a +proc+, that will be called for each member of the +collection+ to
      # retrieve the value/text.
      #
      # Example object structure for use with this method:
      #
      #   class Post < ActiveRecord::Base
      #     belongs_to :author
      #   end
      #
      #   class Author < ActiveRecord::Base
      #     has_many :posts
      #
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated Author for an instance of Post, <tt>@post</tt>):
      #   collection_radio_buttons(:post, :author_id, Author.all, :id, :name_with_initial)
      #
      # If <tt>@post.author_id</tt> is already <tt>1</tt>, this would return:
      #   <input id="post_author_id_1" name="post[author_id]" type="radio" value="1" checked="checked" />
      #   <label for="post_author_id_1">D. Heinemeier Hansson</label>
      #   <input id="post_author_id_2" name="post[author_id]" type="radio" value="2" />
      #   <label for="post_author_id_2">D. Thomas</label>
      #   <input id="post_author_id_3" name="post[author_id]" type="radio" value="3" />
      #   <label for="post_author_id_3">M. Clark</label>
      #
      # It is also possible to customize the way the elements will be shown by
      # giving a block to the method:
      #   collection_radio_buttons(:post, :author_id, Author.all, :id, :name_with_initial) do |b|
      #     b.label { b.radio_button }
      #   end
      #
      # The argument passed to the block is a special kind of builder for this
      # collection, which has the ability to generate the label and radio button
      # for the current item in the collection, with proper text and value.
      # Using it, you can change the label and radio button display order or
      # even use the label as wrapper, as in the example above.
      #
      # The builder methods <tt>label</tt> and <tt>radio_button</tt> also accept
      # extra HTML options:
      #   collection_radio_buttons(:post, :author_id, Author.all, :id, :name_with_initial) do |b|
      #     b.label(class: "radio_button") { b.radio_button(class: "radio_button") }
      #   end
      #
      # There are also three special methods available: <tt>object</tt>, <tt>text</tt> and
      # <tt>value</tt>, which are the current item being rendered, its text and value methods,
      # respectively. You can use them like this:
      #   collection_radio_buttons(:post, :author_id, Author.all, :id, :name_with_initial) do |b|
      #      b.label(:"data-value" => b.value) { b.radio_button + b.text }
      #   end
      #
      # ==== Gotcha
      #
      # The HTML specification says when nothing is selected on a collection of radio buttons
      # web browsers do not send any value to server.
      # Unfortunately this introduces a gotcha:
      # if a +User+ model has a +category_id+ field and in the form no category is selected, no +category_id+ parameter is sent. So,
      # any strong parameters idiom like:
      #
      #   params.expect(user: [...])
      #
      # will raise an error since no <tt>{user: ...}</tt> will be present.
      #
      # To prevent this the helper generates an auxiliary hidden field before
      # every collection of radio buttons. The hidden field has the same name as collection radio button and blank value.
      #
      # In case if you don't want the helper to generate this hidden field you can specify
      # <tt>include_hidden: false</tt> option.
      def collection_radio_buttons(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionRadioButtons.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end

      # Returns check box tags for the collection of existing return values of
      # +method+ for +object+'s class. The value returned from calling +method+
      # on the instance +object+ will be selected. If calling +method+ returns
      # +nil+, no selection is made.
      #
      # The <tt>:value_method</tt> and <tt>:text_method</tt> parameters are
      # methods to be called on each member of +collection+. The return values
      # are used as the +value+ attribute and contents of each check box tag,
      # respectively. They can also be any object that responds to +call+, such
      # as a +proc+, that will be called for each member of the +collection+ to
      # retrieve the value/text.
      #
      # Example object structure for use with this method:
      #   class Post < ActiveRecord::Base
      #     has_and_belongs_to_many :authors
      #   end
      #   class Author < ActiveRecord::Base
      #     has_and_belongs_to_many :posts
      #     def name_with_initial
      #       "#{first_name.first}. #{last_name}"
      #     end
      #   end
      #
      # Sample usage (selecting the associated Author for an instance of Post, <tt>@post</tt>):
      #   collection_checkboxes(:post, :author_ids, Author.all, :id, :name_with_initial)
      #
      # If <tt>@post.author_ids</tt> is already <tt>[1]</tt>, this would return:
      #   <input id="post_author_ids_1" name="post[author_ids][]" type="checkbox" value="1" checked="checked" />
      #   <label for="post_author_ids_1">D. Heinemeier Hansson</label>
      #   <input id="post_author_ids_2" name="post[author_ids][]" type="checkbox" value="2" />
      #   <label for="post_author_ids_2">D. Thomas</label>
      #   <input id="post_author_ids_3" name="post[author_ids][]" type="checkbox" value="3" />
      #   <label for="post_author_ids_3">M. Clark</label>
      #   <input name="post[author_ids][]" type="hidden" value="" />
      #
      # It is also possible to customize the way the elements will be shown by
      # giving a block to the method:
      #   collection_checkboxes(:post, :author_ids, Author.all, :id, :name_with_initial) do |b|
      #     b.label { b.checkbox }
      #   end
      #
      # The argument passed to the block is a special kind of builder for this
      # collection, which has the ability to generate the label and check box
      # for the current item in the collection, with proper text and value.
      # Using it, you can change the label and check box display order or even
      # use the label as wrapper, as in the example above.
      #
      # The builder methods <tt>label</tt> and <tt>checkbox</tt> also accept
      # extra HTML options:
      #   collection_checkboxes(:post, :author_ids, Author.all, :id, :name_with_initial) do |b|
      #     b.label(class: "checkbox") { b.checkbox(class: "checkbox") }
      #   end
      #
      # There are also three special methods available: <tt>object</tt>, <tt>text</tt> and
      # <tt>value</tt>, which are the current item being rendered, its text and value methods,
      # respectively. You can use them like this:
      #   collection_checkboxes(:post, :author_ids, Author.all, :id, :name_with_initial) do |b|
      #      b.label(:"data-value" => b.value) { b.checkbox + b.text }
      #   end
      #
      # ==== Gotcha
      #
      # When no selection is made for a collection of checkboxes most
      # web browsers will not send any value.
      #
      # For example, if we have a +User+ model with +category_ids+ field and we
      # have the following code in our update action:
      #
      #   @user.update(params[:user])
      #
      # If no +category_ids+ are selected then we can safely assume this field
      # will not be updated.
      #
      # This is possible thanks to a hidden field generated by the helper method
      # for every collection of checkboxes.
      # This hidden field is given the same field name as the checkboxes with a
      # blank value.
      #
      # In the rare case you don't want this hidden field, you can pass the
      # <tt>include_hidden: false</tt> option to the helper method.
      def collection_checkboxes(object, method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        Tags::CollectionCheckBoxes.new(object, method, self, collection, value_method, text_method, options, html_options).render(&block)
      end
      alias_method :collection_check_boxes, :collection_checkboxes

      private
        def option_html_attributes(element)
          if Array === element
            element.select { |e| Hash === e }.reduce({}, :merge!)
          else
            {}
          end
        end

        def option_text_and_value(option)
          # Options are [text, value] pairs or strings used for both.
          if !option.is_a?(String) && option.respond_to?(:first) && option.respond_to?(:last)
            option = option.reject { |e| Hash === e } if Array === option
            [option.first, option.last]
          else
            [option, option]
          end
        end

        def option_value_selected?(value, selected)
          Array(selected).include? value
        end

        def extract_selected_and_disabled(selected)
          if selected.is_a?(Proc)
            [selected, nil]
          else
            selected = Array.wrap(selected)
            options = selected.extract_options!.symbolize_keys
            selected_items = options.fetch(:selected, selected)
            [selected_items, options[:disabled]]
          end
        end

        def extract_values_from_collection(collection, value_method, selected)
          if selected.is_a?(Proc)
            collection.filter_map do |element|
              element.public_send(value_method) if selected.call(element)
            end
          else
            selected
          end
        end

        def value_for_collection(item, value)
          value.respond_to?(:call) ? value.call(item) : item.public_send(value)
        end

        def prompt_text(prompt)
          prompt.kind_of?(String) ? prompt : I18n.translate("helpers.select.prompt", default: "Please select")
        end
    end

    class FormBuilder
      # Wraps ActionView::Helpers::FormOptionsHelper#select for form builders:
      #
      #   <%= form_with model: @post do |f| %>
      #     <%= f.select :person_id, Person.all.collect { |p| [ p.name, p.id ] }, include_blank: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def select(method, choices = nil, options = {}, html_options = {}, &block)
        @template.select(@object_name, method, choices, objectify_options(options), @default_html_options.merge(html_options), &block)
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#collection_select for form builders:
      #
      #   <%= form_with model: @post do |f| %>
      #     <%= f.collection_select :person_id, Author.all, :id, :name_with_initial, prompt: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def collection_select(method, collection, value_method, text_method, options = {}, html_options = {})
        @template.collection_select(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#grouped_collection_select for form builders:
      #
      #   <%= form_with model: @city do |f| %>
      #     <%= f.grouped_collection_select :country_id, @continents, :countries, :name, :id, :name %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def grouped_collection_select(method, collection, group_method, group_label_method, option_key_method, option_value_method, options = {}, html_options = {})
        @template.grouped_collection_select(@object_name, method, collection, group_method, group_label_method, option_key_method, option_value_method, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#time_zone_select for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.time_zone_select :time_zone, nil, include_blank: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def time_zone_select(method, priority_zones = nil, options = {}, html_options = {})
        @template.time_zone_select(@object_name, method, priority_zones, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#weekday_select for form builders:
      #
      #   <%= form_with model: @user do |f| %>
      #     <%= f.weekday_select :weekday, include_blank: true %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def weekday_select(method, options = {}, html_options = {})
        @template.weekday_select(@object_name, method, objectify_options(options), @default_html_options.merge(html_options))
      end

      # Wraps ActionView::Helpers::FormOptionsHelper#collection_checkboxes for form builders:
      #
      #   <%= form_with model: @post do |f| %>
      #     <%= f.collection_checkboxes :author_ids, Author.all, :id, :name_with_initial %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def collection_checkboxes(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        @template.collection_checkboxes(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_html_options.merge(html_options), &block)
      end
      alias_method :collection_check_boxes, :collection_checkboxes

      # Wraps ActionView::Helpers::FormOptionsHelper#collection_radio_buttons for form builders:
      #
      #   <%= form_with model: @post do |f| %>
      #     <%= f.collection_radio_buttons :author_id, Author.all, :id, :name_with_initial %>
      #     <%= f.submit %>
      #   <% end %>
      #
      # Please refer to the documentation of the base helper for details.
      def collection_radio_buttons(method, collection, value_method, text_method, options = {}, html_options = {}, &block)
        @template.collection_radio_buttons(@object_name, method, collection, value_method, text_method, objectify_options(options), @default_html_options.merge(html_options), &block)
      end
    end
  end
end
