module Fluent
  class TextParser
    class GrokPatternNotFoundError < Exception; end

    class GrokParser
      include Configurable
      config_param :time_format, :string, :default => nil
      config_param :grok_pattern, :string

      PATTERN_RE = \
          /%\{    # match '%{' not prefixed with '\'
             (?<name>     # match the pattern name
               (?<pattern>[A-z0-9]+)
               (?::(?<subname>[@\[\]A-z0-9_:.-]+))?
             )
           \}/x

      def initialize
        super
        @pattern_map = {}
        pattern_dir = File.expand_path('../../../../patterns/*', __FILE__)
        Dir.glob(pattern_dir) do |pattern_file_path|
          add_patterns_from_file(pattern_file_path)
        end
      end

      def configure(conf={})
        super

        begin
          regexp = expand_pattern(conf['grok_pattern'])
          $log.info "Expanded the pattern #{conf['grok_pattern']} into #{regexp}"
          @parser = RegexpParser.new(Regexp.new(regexp), conf)
        rescue => e
          $log.error e.backtrace
        end
      end

      def add_patterns_from_file(path)
        File.new(path).each_line do |line|
          next if line[0] == '#' || /^$/ =~ line
          name, pat = line.chomp.split(/\s+/, 2)
          @pattern_map[name] = pat
        end
      end

      def expand_pattern(pattern)
        # It's okay to modify in place. no need to expand it more than once.
        while true
          m = PATTERN_RE.match(pattern)
          break if not m
          curr_pattern = @pattern_map[m["pattern"]]
          raise GrokPatternNotFoundError if not curr_pattern
          replacement_pattern = if m["subname"]
                                  "(?<#{m["subname"]}>#{curr_pattern})"
                                else
                                  curr_pattern
                                end
          pattern.sub!(m[0], replacement_pattern)
        end
      
        pattern 
      end

      def call(text, &block)
        if block
          @parser.call(text, &block)
        else
          @parser.call(text)
        end
      end
    end

    TextParser.register_template('grok', Proc.new { GrokParser.new })
  end
end
