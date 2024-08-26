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
        init_param
        ensure_valid_markup(tag_name, markup, parse_context)
      end

      def parse(tokens)
        @body = +''
        while (token = tokens.shift)
          if token =~ /\A(.*)\{\%-?\s*(\w+)\s*(.*)?-?\%\}\z/om && block_delimiter == Regexp.last_match(2)
            parse_context.trim_whitespace = (token[-3] == '-')
            @body << Regexp.last_match(1) if Regexp.last_match(1) != ""
            return
          end
          @body << token unless token.empty?
        end
      end

      def render(_context)
        @output_dir = context.registers[:site].config['destination']
        remote_compile @body
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

      def init_param
        @site_uri = URI('https://quicklatex.com/latex3.f')
        @post_param = {
          :fsize => '30px',
          :fcolor => '000000',
          :mode => 0,
          :out => 1,
          :errors => 1,
          :remhost => 'quicklatex.com',
        }
        @pic_regex = /https:\/\/quicklatex.com\/cache3\/[^\.]*/
        @saved_dir = 'assets/latex'
      end

      def seperate_snippet(snippet)
        lines = snippet.lines
        preamble, formula = lines.partition { |line| line =~ /usepackage/ }

        def join_back(lines)
          lines.join('').gsub(/%/, '%25').gsub(/&/, '%26')
        end

        return {
          :preamble => join_back(preamble),
          :formula => join_back(formula),
        }
      end

      def remote_compile(snippet)

        param = @post_param.merge(seperate_snippet(snippet))

        req = Net::HTTP::Post.new(@site_uri)
        body_raw = param.inject('') do |result, nxt|
          "#{result}&#{nxt[0].to_s}=#{nxt[1].to_s}"
        end
        req.body = body_raw.sub('&', '')

        res = Net::HTTP.start(@site_uri.hostname, @site_uri.port, use_ssl: true) do |http|
          http.request(req)
        end

        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          puts res.body
          pic_uri = URI(res.body[@pic_regex]+'.svg')
          puts pic_uri

          Net::HTTP.start(pic_uri.host, use_ssl: true) do |http|
            # http get
            resp = http.get(pic_uri.path)
            return resp.body
          end
        else
          res.value
        end
      end
    end
  end
end


Liquid::Template.register_tag('latex', Jekyll::Quicklatex::Block)
