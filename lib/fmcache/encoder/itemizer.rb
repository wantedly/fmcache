module FMCache
  class Encoder
    class Itemizer
      # @param [Hash] value
      # @param [FieldMaskParser::Node] field_mask
      def initialize(value, field_mask)
        @value      = value
        @field_mask = field_mask
        @items      = {}
      end

      # [{ String => <Hash> }]
      attr_reader :items

      def run!
        traverse!(value: @value, field_mask: @field_mask, prefix: [], p_id: nil)
      end

    private

      def traverse!(value:, field_mask:, prefix:, p_id:)
        id = value[:id]

        field_mask.attrs.each do |attr|
          f = Field.to_s(prefix: prefix, attr: attr)
          v = value[attr]
          @items[f] ||= []
          @items[f] << { value: v, id: id, p_id: p_id }
        end

        field_mask.has_ones.each do |assoc|
          v = value[assoc.name]
          if v  # NOTE: Proceed only when value exists
            p = prefix + [assoc.name]
            traverse!(value: v, field_mask: assoc, prefix: p, p_id: id)
          end
        end

        field_mask.has_manies.each do |assoc|
          values = value[assoc.name] || []
          p      = prefix + [assoc.name]

          values.each do |v|
            traverse!(value: v, field_mask: assoc, prefix: p, p_id: id)
           end
        end
      end
    end
  end
end
