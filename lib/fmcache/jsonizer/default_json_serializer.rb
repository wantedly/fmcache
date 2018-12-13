module FMCache
  class Jsonizer
    class DefaultJsonSerializer
      class << self
        # @param [Hash | Array] obj
        # @return [String]
        def dump(obj)
          JSON.dump(obj)
        end

        # @param [String] json
        # @return [Hash | Array]
        def load(json)
          JSON.parse(json, symbolize_names: true)
        end
      end
    end
  end
end
