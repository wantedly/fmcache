module FMCache
  class IdKeyGen
    DEFAULT_KEY_PREFIX = "fmcache"

    # @param [String, nil] prefix
    def initialize(prefix)
      p = prefix || DEFAULT_KEY_PREFIX
      @prefix = "#{p}:"
    end

    # @param [<Integer>] ids
    # @return [<String>]
    def to_keys(ids)
      ids.map { |id| to_key(id) }
    end

    # @param [Integer] id
    # @return [String]
    def to_key(id)
      "#{@prefix}#{id}"
    end

    # @param [<String>] keys
    # @return [<Integer>]
    def to_ids(keys)
      keys.map { |key| to_id(key) }
    end

    # @param [String] id
    # @return [Integer]
    def to_id(key)
      prefix_len = @prefix.size
      if key[0..(prefix_len-1)] == @prefix
        key[prefix_len..-1].to_i
      else
        raise "invalid key: #{key}"
      end
    end
  end
end
