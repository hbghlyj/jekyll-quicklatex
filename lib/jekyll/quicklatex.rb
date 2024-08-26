require 'net/http'
require 'fileutils'
require 'digest'
require 'jekyll/quicklatex/version'

module Jekyll
  module Quicklatex
    class Block < Liquid::Block
      Syntax = /\A\s*\z/

      def initialize(tag_name, markup, parse_context)
        super

        ensure_valid_markup(tag_name, markup, parse_context)
      end

      def parse(tokens)
        @body = +''
        while (token = tokens.shift)
          if block_delimiter == Regexp.last_match(2)
            parse_context.trim_whitespace = (token[-3] == WhitespaceControl)
            @body << Regexp.last_match(1) if Regexp.last_match(1) != ""
            return
          end
          @body << token unless token.empty?
        end
      end

      def render(_context, output)
        output << @body
        output
      end

      def nodelist
        [@body]
      end

      def blank?
        @body.empty?
      end

      protected

      def ensure_valid_markup(tag_name, markup, parse_context)
        unless Syntax.match?(markup)
          raise SyntaxError, parse_context.locale.t("errors.syntax.tag_unexpected_args", tag: tag_name)
        end
      end
    end
  end
end


Liquid::Template.register_tag('latex', Jekyll::Quicklatex::Block)
