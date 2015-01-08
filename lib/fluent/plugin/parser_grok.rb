module Fluent
  class TextParser
    class GrokPatternNotFoundError < Exception; end

    class GrokParser < Parser
      Plugin.register_parser('grok', self)
      config_param :time_format, :string, :default => nil
      config_param :grok_pattern, :string, :default => nil
      config_param :custom_pattern_path, :string, :default => nil

      # Much of the Grok implementation is based on Jordan Sissel's jls-grok
      # See https://github.com/jordansissel/ruby-grok/blob/master/lib/grok-pure.rb
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
        default_pattern_dir = File.expand_path('../../../../patterns/*', __FILE__)
        Dir.glob(default_pattern_dir) do |pattern_file_path|
          add_patterns_from_file(pattern_file_path)
        end
        @default_parser = NoneParser.new
        @parsers = []
      end

      def configure(conf={})
        super

        if @custom_pattern_path
          if Dir.exists? @custom_pattern_path
            Dir.glob(@custom_pattern_path + '/*') do |pattern_file_path|
              add_patterns_from_file(pattern_file_path)
            end
          elsif File.exists? @custom_pattern_path
            add_patterns_from_file(@custom_pattern_path)
          end
        end

        if @grok_pattern
          @parsers = [expand_pattern_exn(@grok_pattern, conf)]
        else
          grok_confs = conf.elements.select {|e| e.name == 'grok'}
          grok_confs.each do |grok_conf|
            @parsers << expand_pattern_exn(grok_conf['pattern'], grok_conf)
          end
        end
      end

      def add_patterns_from_file(path)
        File.new(path).each_line do |line|
          next if line[0] == '#' || /^$/ =~ line
          name, pat = line.chomp.split(/\s+/, 2)
          @pattern_map[name] = pat
        end
      end

      def expand_pattern_exn(pattern, conf)
        regexp = expand_pattern(pattern)
        $log.info "Expanded the pattern #{conf['grok_pattern']} into #{regexp}"
        RegexpParser.new(Regexp.new(regexp), conf)
      rescue => e
        $log.error e.backtrace.join("\n")
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
          pattern.sub!(m[0]) do |s| replacement_pattern end
        end
      
        pattern 
      end

      def parse(text)
        if block_given?
          @parsers.each do |parser|
            parser.parse(text) do |time, record|
              if time and record
                yield time, record
                return
              end
            end
          end
          yield @default_parser.parse(text)
        else
          @parsers.each do |parser|
            parser.parse(text) do |time, record|
              if time and record
                return time, record
              end
            end
          end
          return @default_parser.parse(text)
        end
      end
    end
  end
end
