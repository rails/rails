Ruby on Rails Guides Guidelines
===============================

This guide documents guidelines for writing Ruby on Rails Guides. This guide follows itself in a graceful loop, serving itself as an example.

--------------------------------------------------------------------------------

Markdown
-------

Guides are written in [GitHub Flavored Markdown](http://github.github.com/github-flavored-markdown/). There is comprehensive [documentation for Markdown](http://daringfireball.net/projects/markdown/syntax), a [cheatsheet](http://daringfireball.net/projects/markdown/basics), and [additional documentation](http://github.github.com/github-flavored-markdown/) on the differences from traditional Markdown.

Prologue
--------

Each guide should start with motivational text at the top (that's the little introduction in the blue area). The prologue should tell the reader what the guide is about, and what they will learn. See for example the [Routing Guide](routing.html).

Titles
------

The title of every guide uses `h1`; guide sections use `h2`; subsections `h3`; etc. However, the generated HTML output will have the heading tag starting from `<h2>`.

```
Guide Title
===========

Section
-------

### Sub Section
```

Capitalize all words except for internal articles, prepositions, conjunctions, and forms of the verb to be:

```
#### Middleware Stack is an Array
#### When are Objects Saved?
```

Use the same typography as in regular text:

```
##### The `:content_type` Option
```

API Documentation Guidelines
----------------------------

The guides and the API should be coherent and consistent where appropriate. Please have a look at these particular sections of the [API Documentation Guidelines](api_documentation_guidelines.html:)

* [Wording](api_documentation_guidelines.html#wording)
* [Example Code](api_documentation_guidelines.html#example-code)
* [Filenames](api_documentation_guidelines.html#filenames)
* [Fonts](api_documentation_guidelines.html#fonts)

Those guidelines apply also to guides.

HTML Guides
-----------

### Generation

To generate all the guides, just `cd` into the **`guides`** directory and execute:

```
bundle exec rake guides:generate
```

or

```
bundle exec rake guides:generate:html
```

(You may need to run `bundle install` first to install the required gems.)

To process `my_guide.md` and nothing else use the `ONLY` environment variable:

```
touch my_guide.md
bundle exec rake guides:generate ONLY=my_guide
```

By default, guides that have not been modified are not processed, so `ONLY` is rarely needed in practice.

To force processing all the guides, pass `ALL=1`.

It is also recommended that you work with `WARNINGS=1`. This detects duplicate IDs and warns about broken internal links.

If you want to generate guides in a language other than English, you can keep them in a separate directory under `source` (eg. `source/es`) and use the `GUIDES_LANGUAGE` environment variable:

```
bundle exec rake guides:generate GUIDES_LANGUAGE=es
```

If you want to see all the environment variables you can use to configure the generation script just run:

```
rake
```

### Validation

Please validate the generated HTML with:

```
bundle exec rake guides:validate
```

Particularly, titles get an ID generated from their content and this often leads to duplicates. Please set `WARNINGS=1` when generating guides to detect them. The warning messages suggest a solution.

Kindle Guides
-------------

### Generation

To generate guides for the Kindle, use the following rake task:

```
bundle exec rake guides:generate:kindle
```
