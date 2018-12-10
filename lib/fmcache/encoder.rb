require "fmcache/encoder/itemizer"

module FMCache
  class Encoder
    # @param [<Hash>] values
    # @param [FieldMaskParser::Node] field_mask
    # @return [{ String => { String => <Hash> } }]
    def encode(values, field_mask)
      r = {}
      values.each do |value|
        h = {}

        # NOTE: initialize each field by array
        fields = Helper.to_fields(field_mask).map(&:to_s)
        fields.each do |f|
          h[f] = []
        end

        encode_one(value, field_mask).each do |f, v|
          h[f] = v
        end

        id = value.fetch(:id)
        r[Helper.to_key(id)] = h
      end
      r
    end

    # @param [Hash] value
    # @param [FieldMaskParser::Node] field_mask
    # @return [{ String => <Hash> }]
    def encode_one(value, field_mask)
      itemizer = Itemizer.new(value, field_mask)
      itemizer.run!
      itemizer.items
    end
  end
end
