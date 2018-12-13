module FMCache
  class Engine
    DEFAULT_TTL = 7 * 24 * 3600  # 7 days

    # @param [Redis | MockRRedis] client
    def initialize(client:, fm_parser:, ttl: DEFAULT_TTL, notifier: nil, json_serializer: nil)
      @client    = Client.new(client, notifier)
      @fm_parser = wrap(fm_parser)
      @ttl       = ttl
      @encoder   = Encoder.new
      @decoder   = Decoder.new(@fm_parser)
      @jsonizer  = Jsonizer.new(json_serializer)
    end

    attr_reader :client, :fm_parser, :encoder, :decoder

    # @param [<Hash>] values
    # @param [FieldMaskParser::Node] field_mask
    # @return [Boolean]
    def write(values:, field_mask:)
      normalize!(field_mask)
      h = encode(values, field_mask)
      client.set(values: @jsonizer.jsonize(h), ttl: @ttl)
    end

    # @param [<Integer | String>] ids
    # @param [FieldMaskParser::Node] field_mask
    # @return [<Hash>, <Hash>, IncompleteInfo]
    def read(ids:, field_mask:)
      ids = ids.map(&:to_i)
      normalize!(field_mask)

      keys   = Helper.to_keys(ids)
      fields = Helper.to_fields(field_mask).map(&:to_s)
      h = client.get(keys: keys, fields: fields)
      decode(merge(@jsonizer.dejsonize(h), ids), field_mask)
    end

    # @param [<Integer | String>] ids
    # @param [FieldMaskParser::Node] field_mask
    # @yieldparam [<Integer>, FieldMaskParser::Node] ids, field_mask
    # @yieldreturn [<Hash>]
    # @return [<Hash>]
    def fetch(ids:, field_mask:, &block)
      ids = ids.map(&:to_i)
      normalize!(field_mask)

      values, incomplete_values, incomplete_info = read(ids: ids, field_mask: field_mask)
      return values if incomplete_values.size == 0

      # NOTE: get new data
      d = block.call(incomplete_info.ids, incomplete_info.field_mask)
      write(values: d, field_mask: incomplete_info.field_mask)

      older = encode(incomplete_values, field_mask)
      newer = encode(d,                 incomplete_info.field_mask)

      v, i_v, i_i = decode(older.deep_merge(newer), field_mask)

      # NOTE: Delete invalid data as read repair
      client.hdel(
        keys:   Helper.to_keys(i_i.ids),
        fields: Helper.to_fields(i_i.field_mask),
      )

      Helper.sort(values + v + i_v, ids)
    end

    def delete(ids:)
      ids = ids.map(&:to_i)
      client.del(keys: Helper.to_keys(ids))
    end

  private

    # @param [{ String => { String => <Hash> } }] hash
    # @param [FieldMaskParser::Node] field_mask
    # @return [<Hash>, <Hash>, IncompleteInfo]
    def decode(hash, field_mask)
      decoder.decode(hash, field_mask)
    end

    # @param [<Hash>] values
    # @param [FieldMaskParser::Node] field_mask
    # @rerturn [{ String => { String => <Hash> } }]
    def encode(values, field_mask)
      encoder.encode(values, field_mask)
    end

    # @param [{ String => { String => <Hash> } }] hash
    # @param [<Integer>] ids
    # @return [{ String => { String => <Hash> } }]
    def merge(hash, ids)
      # NOTE: Set `id` to list. json format must be consistent with Encoder and Decoder
      ids.each do |id|
        h = hash.fetch(Helper.to_key(id))
        h.merge!({ "id" => [{ id: id, p_id: nil, value: id }] })
      end
      hash
    end

    def wrap(fm_parser)
      -> (fields) {
        n = fm_parser.call(fields)
        normalize!(n)
        n
      }
    end

    def normalize!(field_mask)
      if !field_mask.attrs.include?(:id)
        field_mask.attrs << :id
      end
      field_mask.assocs.each do |a|
        normalize!(a)
      end
    end
  end
end
