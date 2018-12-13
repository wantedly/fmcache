module FMCache
  class Decoder
    class FieldsChecker
      class CheckResult
        def initialize(list:, incomplete_list:, missing_fields:)
          @list            = list
          @incomplete_list = incomplete_list
          @missing_fields  = missing_fields
        end

        attr_reader :list, :incomplete_list, :missing_fields
      end

      # @param [<Hash>] list
      # @param [FieldMaskParser::Node] field_mask
      # @return [CheckResult]
      def check(list, field_mask)
        l              = []
        incomplete_l   = []
        missing_fields = Set.new

        list.each do |d|
          _, m_fields = check_fields(d, field_mask)
          if m_fields.size == 0
            l << d
          else
            incomplete_l << d
            missing_fields |= m_fields
          end
        end

        CheckResult.new(
          list:            l,
          incomplete_list: incomplete_l,
          missing_fields:  missing_fields,
        )
      end

      # @param [Hash] data
      # @param [FieldMaskParser::Node] field_mask
      def check_fields(data, field_mask, prefix = [])
        fields         = []
        missing_fields = []

        id_exists = false
        field_mask.attrs.each do |attr|
          f = Field.to_s(prefix: prefix, attr: attr)
          if data.fetch(f)
            fields << f
            id_exists = true if attr == :id
          else  # NOTE: When nil, cache of the field does not exist
            missing_fields << f
          end
        end

        if id_exists
          field_mask.assocs.each do |assoc|
            f, m_f = check_fields(data, assoc, (prefix + [assoc.name]))
            fields         += f
            missing_fields += m_f
          end
        else
          # NOTE: When the cache of id does not exist, treat current and lower
          # layer as missing fields
          # TODO(south37) Improve performance
          missing_fields += fields
          fields         = []

          field_mask.assocs.each do |assoc|
            missing_fields += Helper.to_fields(assoc, prefix: prefix + [assoc.name])
          end
        end

        [fields, missing_fields]
      end
    end
  end
end
