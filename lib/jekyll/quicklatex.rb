require 'net/http'
require 'fileutils'
require 'digest'
require 'jekyll/quicklatex/version'

module Jekyll
  class Quicklatex < Liquid::Tag

    def initialize(tag_name, text, tokens)
      super
      @text = text
    end

    def render(context)
      "{% raw %}#{@text}{% endraw %}"
    end
  end
end

Liquid::Template.register_tag('latex', Jekyll::Quicklatex::Block)
