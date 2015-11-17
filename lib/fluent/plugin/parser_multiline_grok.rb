require 'fluent/plugin/parser_grok'

module Fluent
  class TextParser
    class MultilineGrokParser < GrokParser
      Plugin.register_parser('multiline_grok', self)
      config_param :multiline_start_regexp, :string, :default => nil


      def initialize
        super
      end

      def configure(conf={})
        super
      end

      def has_firstline?
        !!@multiline_start_regexp
      end

      def firstline?(text)
        @multiline_start_regexp && !@multiline_start_regexp.match(text)
      end

      def parse(text, &block)
        if block_given?
          @grok.parsers.each do |parser|
            parser.parse(text) do |time, record|
              if time and record
                yield time, record
                return
              end
            end
          end
        else
          @grok.parsers.each do |parser|
            parser.parse(text) do |time, record|
              if time and record
                return time, record
              end
            end
          end
        end
      end
    end
  end
end
