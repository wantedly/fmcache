require "fmcache/decoder/decode_result"
require "fmcache/decoder/fields_checker"
require "fmcache/decoder/value_decoder"

module FMCache
  class Decoder
    # @param [Proc] field_mask_parser
    def initialize(field_mask_parser)
      @field_mask_parser = field_mask_parser
      @value_decoder     = ValueDecoder.new
      @fields_checker    = FieldsChecker.new
    end

    attr_reader :field_mask_parser, :value_decoder, :fields_checker

    # @param [{ String => { String => <Hash> } }] hash
    # @param [FieldMaskParser::Node] field_mask
    # @return [<Hash>, <Hash>, IncompleteInfo]
    def decode(hash, field_mask)
      list = hash.values
      check_result = fields_checker.check(list, field_mask)

      decode_result = decode_list(check_result.list, field_mask: field_mask)

      f = Helper.to_fields(field_mask) - check_result.missing_fields.to_a
      i_decode_result = decode_list(check_result.incomplete_list, fields: f)

      concat(check_result, decode_result, i_decode_result)
    end

  private

    # @param [<Hash>] list
    # @param [FieldMaskParser::Node] field_mask
    def decode_list(list, field_mask: nil, fields: nil)
      if field_mask.nil? && fields.nil?
        raise "invalid args!"
      end
      if fields
        field_mask = field_mask_parser.call(fields.map(&:to_s))
      end

      values         = []
      invalid_values = []
      invalid_fields = Set.new

      list.each do |d|
        v, i_fields = value_decoder.decode(d, field_mask)
        if i_fields.size == 0
          values << v
        else
          invalid_values << v
          invalid_fields |= i_fields
        end
      end

      DecodeResult.new(
        values:         values,
        invalid_values: invalid_values,
        invalid_fields: invalid_fields,
      )
    end

    # @param [DecodeResult] decode_result
    # @param [DecodeResult] invalid_decode_result
    # @return [<Hash>, <Hash>, IncompleteInfo]
    def concat(check_result, decode_result, invalid_decode_result)
      v = decode_result.values
      i_v = decode_result.invalid_values +
        invalid_decode_result.values +
        invalid_decode_result.invalid_values

      missing_fields = Set.new(
        check_result.missing_fields +
        decode_result.invalid_fields +
        invalid_decode_result.invalid_fields
      )
      incomplete_info = IncompleteInfo.new(
        ids:        i_v.map { |h| h.fetch(:id) },
        field_mask: field_mask_parser.call(missing_fields),
      )

      [v, i_v, incomplete_info]
    end
  end
end
