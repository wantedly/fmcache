module FMCache
  class Helper
    class << self
      # @param [FieldMaskParser::Node] field_mask
      # @param [<Symbol>] prefix
      # @return [<String>]
      def to_fields(field_mask, prefix: [])
        field_mask.to_paths(prefix: prefix, sort: false)
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
