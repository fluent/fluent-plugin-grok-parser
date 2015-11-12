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
        true
      end

      def firstline?(text)
        !@multiline_start_regexp.match(text)
      end
    end
  end
end
