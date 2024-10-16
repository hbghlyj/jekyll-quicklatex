require 'net/http'
require 'fileutils'
require 'digest'
require 'jekyll/quicklatex/version'

module Jekyll
  module Quicklatex
    class LatexBlock < Liquid::Block

      def initialize(tag_name, markup, parse_context)
        super
        init_param
        @text = markup
      end
      #Start raw: https://github.com/Shopify/liquid/blob/main/lib/liquid/tags/raw.rb
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

      def render(context)
        site = context.registers[:site]
        filename = remote_compile @body
        site.static_files << Jekyll::StaticFile.new(site, site.source, '/assets', filename)
        "<img src='/assets/#{filename}' style='vertical-align:middle;#{@text}'>"
      end

      def nodelist
        [@body]
      end

      def blank?
        @body.empty?
      end
      #End raw

      #Start QuickLatex: https://github.com/DreamAndDead/jekyll-quicklatex/blob/master/lib/jekyll/quicklatex.rb
      class Cache
        def initialize
          @cache = {}
          @cache_file = 'latex.cache'
          if File.exist? @cache_file
            File.open(@cache_file, 'r') do |f|
              while line = f.gets
                hash, url = line.split
                @cache[hash] = url
              end
            end
          end
        end

        def fetch(content)
          id = hash_id(content)
          @cache[id]
        end

        def cache(content, url)
          id = hash_id(content)
          @cache[id] = url
          File.open(@cache_file, 'a') do |f|
            f.syswrite("#{id} #{url}\n")
          end
        end

        private

        def hash_id(content)
          Digest::MD5.hexdigest(content)
        end
      end
      
      def init_param
        @site_uri = URI('https://quicklatex.com/latex3.f')
        @post_param = {
          :fsize => '30px',
          :fcolor => '000000',
          :mode => 0,
          :out => 1,
          :errors => 1,#report LaTeX errors
          :remhost => 'quicklatex.com',
        }
        @pic_regex = /https:\/\/quicklatex.com\/cache3\/[a-f0-9]{2}\/[^\.]*/
        @cache = Cache.new
      end

      def seperate_snippet(snippet)
        lines = snippet.lines
        preamble, formula = lines.partition { |line| line =~ /usepackage/ }

        def join_back(lines)
          lines.join('').gsub(/%/, '%25').gsub(/&/, '%26')#QuickLatex-customized form encoding of &
        end

        return {
          :preamble => join_back(preamble),
          :formula => join_back(formula),
        }
      end

      def remote_compile(snippet)
        if url = @cache.fetch(snippet)
          return url
        end
        
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

          #assert_equal the first char of the response is the char "0"
          if res.body[0] != '0'
            raise "QuickLatex Error: #{res.body}"
          end

          pic_uri = URI(res.body[@pic_regex] + '.svg')
          puts pic_uri
          
          filename = File.basename(pic_uri.path)

          Net::HTTP.start(pic_uri.host, use_ssl: true) do |http|
            # https get
            resp = http.get(pic_uri.path)
            File.open("assets/" + filename, "w") do |file|
              file.write(resp.body)
            end
          end
          
          @cache.cache(snippet, filename)
          filename
        else
          raise res.body
        end
      end
    end
    class AsyBlock < LatexBlock
      def remote_compile(snippet)
        if url = @cache.fetch(snippet)
          return url
        end
        
        uri = URI.parse("http://asymptote.ualberta.ca:10007?f=svg")
        request = Net::HTTP::Post.new(uri)
        request.body = snippet

        res = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.request(request)
        end

        case res
        when Net::HTTPSuccess, Net::HTTPRedirection          
          filename = Time.now.to_i.to_s + ".svg"
          File.open("assets/" + filename, "w") do |file|
            file.write(res.body)
          end
          
          @cache.cache(snippet, filename)
          filename
        else
          raise res.body
        end
      end
    end
  end
end


Liquid::Template.register_tag('latex', Jekyll::Quicklatex::LatexBlock)
Liquid::Template.register_tag('asy', Jekyll::Quicklatex::AsyBlock)
