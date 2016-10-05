require 'fluent/plugin/parser_grok'

module Fluent
  module Plugin
    class MultilineGrokParser < GrokParser
      Fluent::Plugin.register_parser('multiline_grok', self)

      desc 'The regexp to match beginning of multiline'
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
        @multiline_start_regexp && !!@grok.multiline_start_regexp.match(text)
      end

      def parse(text)
        @grok.parsers.each do |parser|
          parser.parse(text) do |time, record|
            if time and record
              yield time, record
              return
            end
          end
        end
      end
    end
  end
end
