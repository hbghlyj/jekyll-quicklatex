require 'net/http'
require 'fileutils'
require 'digest'
require 'jekyll/quicklatex/version'

module Jekyll
  module Quicklatex
    class Block < Liquid::Block
      def initialize tag_name, markup, tokens
        super
        init_param
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
  
        self.raise_tag_never_closed(block_name)
      end
    
      def render(context)
        @output_dir = context.registers[:site].config['destination']
        snippet = filter_snippet(super)
        remote_compile snippet
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

      def filter_snippet(snippet)
        # text is html
        # strip all html tags
        no_html_tag = snippet.gsub(/<\/?[^>]*>/, "")
          .gsub(/&gt;/, '>')
          .gsub(/&lt;/, '<')

        # strip all comments in latex code snippet
        lines = no_html_tag.lines
        lines.reject do |l|
          # blank line or comments(start with %)
          l =~ /^\s*$/ or l =~ /^\s*%/
        end.join
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
