module FMCache
  class Decoder
    class ValueDecoder
      class Item
        def initialize(id:, p_id:, value:)
          @id    = id
          @p_id  = p_id
          @value = value
        end

        attr_reader :id, :p_id, :value
      end
    end
  end
end
