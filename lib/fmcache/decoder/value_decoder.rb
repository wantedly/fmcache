require "fmcache/decoder/value_decoder/data"
require "fmcache/decoder/value_decoder/item"

module FMCache
  class Decoder
    class ValueDecoder
      # @param [Hash] data
      # @param [FieldMaskParser::Node] field_mask
      # @return [<Hash, <String>>]
      def decode(data, field_mask)
        @data           = data
        @invalid_fields = Set.new

        h = fetch(field_mask, [])

        d = h.values.first  # NOTE: Top of h is a user

        [d.to_h, @invalid_fields]
      end

    private

      # @param [FieldMaskParser::Node] field_mask
      # @param [<Symbol>] prefix
      # @return [{ Integer => Data }]
      def fetch(field_mask, prefix)
        r = fetch_layer(field_mask, prefix)
        assign_has_one!(r, field_mask, prefix)
        assign_has_many!(r, field_mask, prefix)
        r
      end

      # @param [FieldMaskParser::Node] field_mask
      # @param [<Symbol>] prefix
      # @return [{ Integer => Data }]
      def fetch_layer(field_mask, prefix)
        r = {}

        fetch_items(field_mask, prefix).each do |attr, items|
          items.each do |item|
            r[item.id] ||= Data.new(field_mask: field_mask)
            r[item.id].push_attr(name: attr, item: item)
          end
        end

        r.each do |_, data|
          if !data.valid?
            # NOTE: If data is invalid, we treat this layer as invalid.
            @invalid_fields |= Set.new(Helper.to_fields(field_mask, prefix: prefix))
          end
        end

        r
      end

      def fetch_items(field_mask, prefix)
        r = {}
        field_mask.attrs.each do |attr|
          f = Field.to_s(prefix: prefix, attr: attr)
          h = @data.fetch(f)
          if h.nil?
            raise "invalid json: `#{h}` with field: #{f}"
          end
          r[attr] = itemize(h)
        end
        r
      end

      # @param [String] h
      def itemize(h)
        h.map do |hh|
          Item.new(id: hh.fetch(:id), p_id: hh.fetch(:p_id), value: hh.fetch(:value))
        end
      end

      # @param [{ Integer => Data }]
      # @param [FieldMaskParser::Node] field_mask
      # @param [<Symbol>] prefix
      def assign_has_one!(parents, field_mask, prefix)
        field_mask.has_ones.each do |assoc|
          fetch(assoc, prefix + [assoc.name]).each do |_, data|
            p = parents[data.p_id]
            # NOTE: if p is nil, parent layer is inconsistent with this layer.
            # So we treat them as invalid.
            if p.nil?
              @invalid_fields |= Set.new(Helper.to_fields(field_mask, prefix: prefix))
            else
              p.push_has_one(name: assoc.name, data: data)
            end
          end
        end
      end

      # @param [{ Integer => Data }]
      # @param [FieldMaskParser::Node] field_mask
      # @param [<Symbol>] prefix
      def assign_has_many!(parents, field_mask, prefix)
        field_mask.has_manies.each do |assoc|
          fetch(assoc, prefix + [assoc.name]).each do |_, data|
            p = parents[data.p_id]
            # NOTE: if p is nil, parent layer is inconsistent with this layer.
            # So we treat them as invalid.
            if p.nil?
              @invalid_fields |= Set.new(Helper.to_fields(field_mask, prefix: prefix))
            else
              p.push_has_many(name: assoc.name, data: data)
            end
          end
        end
      end
    end
  end
end
