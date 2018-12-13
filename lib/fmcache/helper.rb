module FMCache
  class Helper
    class << self
      # @param [FieldMaskParser::Node] field_mask
      # @return [<String>]
      def to_fields(field_mask, prefix: [])
        r = []
        field_mask.attrs.each do |attr|
          r << Field.to_s(prefix: prefix, attr: attr)
        end
        field_mask.assocs.each do |assoc|
          r += to_fields(assoc, prefix: prefix + [assoc.name])
        end
        r
      end

      # @param [<Integer>] ids
      # @return [<String>]
      def to_keys(ids)
        ids.map { |id| to_key(id) }
      end

      # @param [Integer] id
      # @return [String]
      def to_key(id)
        "fmcache:#{id}"
      end

      # @param [<Hash>] values
      # @param [<Integer>] ids
      # @return [<Hash>]
      def sort(values, ids)
        id_map = ids.map.with_index { |id, i| [id, i] }.to_h
        values.sort do |a, b|
          id_map.fetch(a.fetch(:id)) <=> id_map.fetch(b.fetch(:id))
        end
      end
    end
  end
end
