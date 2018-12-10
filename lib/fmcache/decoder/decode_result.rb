module FMCache
  class Decoder
    class DecodeResult
      def initialize(values:, invalid_values:, invalid_fields:)
        @values         = values
        @invalid_values = invalid_values
        @invalid_fields = invalid_fields
      end

      attr_reader :values, :invalid_values, :invalid_fields
    end
  end
end
