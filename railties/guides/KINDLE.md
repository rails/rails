# Rails Guides on the Kindle

## Synopsis

  1. Obtain `kindlegen` from the link below and put the binary in your path
  2. Run `ruby rails_guides.rb` to generate the guides and .mobi files
  3. Copy the .mobi files you wish to read to your Kindle
  
## Resources

  * [Kindle Publishing guidelines](http://kindlegen.s3.amazonaws.com/AmazonKindlePublishingGuidelines.pdf)
  * [KindleGen & Kindle Previewer](http://www.amazon.com/gp/feature.html?ie=UTF8&docId=1000234621) 
  
## TODO

### Minimum Viable Product

  * Embed a cover image, as per the Kindle guidelines
  * Remove hacks from `rails_guides/generator.rb`, have Kindle generation as an option on `rails_guides.rb` instead.
  * Ensure sidebar / footnotes are rendered correctly
  * Integrate credits + contribute as separate pages, put in kindle TOC.
  * Work out optimum ordering of welcome/toc/content
  
### Post release

  * Tweak heading styles (most docs use h3/h4/h5, which end up being smaller than the text under it)
  * Tweak table styles (smaller text? Many of the tables are unusable on a Kindle in portrait mode)
  * Have the HTML/XML TOC 'drill down' into the TOCs of the individual guides
  * `.epub` generation.
  