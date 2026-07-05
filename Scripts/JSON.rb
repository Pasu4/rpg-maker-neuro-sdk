class JSONParseError < Exception
end

module JSON
  # The string that is currently being parsed.
  # @type [String]
  @string = ""
  # The current position of the parsing head.
  # @type [Integer]
  @i = 0

  class << self
    # Escape a string so it can be pasted into a JSON string.
    # @param string [String] The string to escape.
    # @return [String] The escaped string.
    def escape(string)
      string
        .gsub(/["\\]/, "\\\\\\&")
        .gsub(/[\b]/, "\\\\b")
        .gsub(/\f/, "\\\\f")
        .gsub(/\n/, "\\\\n")
        .gsub(/\r/, "\\\\r")
        .gsub(/\t/, "\\\\t")
        # leaving out \u#### because no
    end

    # Parse a JSON string.
    #
    # Based on https://www.json.org/json-en.html.
    # @param string [String] The JSON string to parse.
    # @param start [Integer] The in the string index to start at.
    # @return [Hash, Array, Integer, Boolean, Float, nil]
    #   The object parsed from the JSON string.
    def parse(string)
      @string = string
      @i = 0
      parse_value
    end

    # Convert an object into a JSON string.
    # @param obj [Object]
    # @return [String]
    def stringify(obj)
      if obj.is_a? String
        '"' + escape(obj) + '"'
      elsif obj.is_a? Symbol
        '"' + obj.to_s + '"'
      elsif obj.is_a?(Integer) || obj.is_a?(Float) || obj.is_a?(TrueClass) || obj.is_a?(FalseClass)
        obj.to_s
      elsif obj.nil?
        'null'
      elsif obj.is_a? Array
        stringify_array(obj)
      elsif obj.is_a? Hash
        stringify_hash(obj)
      else
        stringify_object(obj)
      end
    end

    # Converts an object to a hash.
    # @param obj [Object] The object to convert.
    # @return [Hash] The hash.
    def obj_to_hash(obj)
      obj.instance_variables.each_with_object({}) do |var, hash|
        hash[var.to_s.delete('@')] = obj.instance_variable_get(var)
      end
    end

    private

    #------------------------------------------------------------------------
    #   Helper functions for parse
    #------------------------------------------------------------------------

    # @return [Hash, Array, Integer, Boolean, Float, nil]
    def parse_value()
      skip_whitespace

      case @string[@i]
      when '{'
        result = parse_object
      when '['
        result = parse_array
      when '"'
        result = parse_string
      when /\d|-/
        result = parse_number
      when /[a-z]/
        result = parse_literal
      else
        raise JSONParseError.new "Invalid syntax at #{@i}"
      end

      skip_whitespace
      return result
    end

    # @return [Hash]
    def parse_object
      check_char '{'
      skip_whitespace
      return {} if @string[@i] == '}'

      hash = {}
      while true
        property_name = parse_string
        skip_whitespace
        check_char ':'
        property_value = parse_value
        hash[property_name] = property_value

        break if @string[@i] == '}'
        check_char ','
        skip_whitespace
      end
      skip  # Skip '}'
      return hash
    end

    # @return [Array]
    def parse_array
      check_char '['
      skip_whitespace

      array = []
      while true
        array.push parse_value
        break if @string[@i] == ']'
        check_char ','
      end
      skip  # ']'
      return array
    end

    # @return [String]
    def parse_string
      check_char '"'
      result = ""
      while true
        match = @string.match(/[^"\\\b\f\n\r]*/, @i)[0]
        result << match
        @i += match.size
        break if @string[@i] == '"'
        check_char '\\'
        case @string[@i]
        when '"', '\\', '/'
          result << @string[@i]
          skip
        when 'b'
          result << "\b"
          skip
        when 'f'
          result << "\f"
          skip
        when 'n'
          result << "\n"
          skip
        when 'r'
          result << "\r"
          skip
        when 't'
          result << "\t"
          skip
        when 'u'
          skip
          hex_match = @string[@i...(@i+4)].match(/[0-9a-fA-F]{4}/, @i)
          if hex_match.nil?
            raise JSONParseError.new "Invalid unicode escape in string literal at #{@i}."
          end
          result << [hex_match[0].to_i(16)].pack('U*')
          skip 4
        end
      end
      skip  # Skip '"'
      return result
    end

    # @return [Integer, Float]
    def parse_number
      str = @string.match(/[^,\s}\]]+/, @i)[0]
      match = str.match(/^-?(0|[1-9]\d*)(\.\d+)?([Ee][+-]?\d+)?$/)
      if match.nil?
        raise JSONParseError.new "Invalid number literal '#{str}' at #{@i}."
      end
      skip str.size
      if match[2].nil? && match[3].nil?
        str.to_i
      else
        str.to_f
      end
    end

    # @return [Boolean, nil]
    def parse_literal
      literal = @string.match(/\w+/, @i)[0]
      case literal
      when 'true'
        skip 4
        true
      when 'false'
        skip 5
        false
      when 'null'
        skip 4
        nil
      else
        raise JSONParseError.new "Invalid literal '#{literal}' at #{@i}."
      end
    end

    # @param expected [String]
    # @param advance [Boolean]
    def check_char(expected, advance = true)
      raise JSONParseError.new("Expected '#{expected}' but got '#{@string[@i]}' at #{@i}.") if expected != @string[@i]
      @i += 1 if advance
    end

    def skip_whitespace
      @i += @string.match(/\s*/, @i)[0].size
    end

    # @param n [Integer]
    def skip(n = 1)
      @i += n
    end

    #------------------------------------------------------------------------
    #   Helper functions for stringify
    #------------------------------------------------------------------------

    # @param obj [Object]
    # @return [String]
    def stringify_object(obj)
      stringify_hash(obj_to_hash(obj))
    end

    # @param array [Array]
    # @return [String]
    def stringify_array(array)
      inner = array
        .select { |item| can_stringify?(item) }
        .map { |item| stringify(item) }
        .join(',')
      "[" + inner + "]"
    end

    # @param hash [Hash]
    # @return [String]
    def stringify_hash(hash)
      inner = hash
        .select { |_, value| can_stringify?(value) }
        .map { |key, value| '"' + escape(key.to_s) + '":' + stringify(value) }
        .join(',')
      "{" + inner + "}"
    end

    # @param obj [Object]
    # @return [Boolean]
    def can_stringify?(obj)
      !obj.is_a? Proc
    end
  end
end