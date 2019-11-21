require "fmcache/encoder/itemizer"

module FMCache
  class Encoder
    # @param [FMCache::IdKeyGen]
    def initialize(id_key_gen)
      @id_key_gen = id_key_gen
    end

    # @param [<Hash>] values
    # @param [FieldMaskParser::Node] field_mask
    # @return [{ String => { String => <Hash> } }]
    def encode(values, field_mask)
      fields = Helper.to_fields(field_mask)

      r = {}
      values.each do |value|
        # NOTE: `[]` is the default value of each field.
        h = fields.map { |f| [f, []] }.to_h

        h.merge! encode_one(value, field_mask)

        id = value.fetch(:id)
        r[@id_key_gen.to_key(id)] = h
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
