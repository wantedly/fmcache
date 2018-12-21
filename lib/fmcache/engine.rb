module FMCache
  class Engine
    DEFAULT_TTL = 7 * 24 * 3600  # 7 days

    # @param [Redis | MockRRedis] client
    # @param [Proc] fm_parser
    # @param [Integer] ttl
    # @param [Proc] notifier
    # @param [#dump#load] json_serializer
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
      fields = Helper.to_fields(field_mask)
      h = client.get(keys: keys, fields: fields)

      with_id, with_no_id = split(h)
      v, i_v, i_i = decode(@jsonizer.dejsonize(with_id), field_mask)
      with_no_id_list = Helper.to_ids(with_no_id.keys)

      return v, i_v, merge(i_i, with_no_id_list, field_mask)
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
      return values if incomplete_info.ids.size == 0

      # NOTE: get new data
      d = block.call(incomplete_info.ids, incomplete_info.field_mask)
      write(values: d, field_mask: incomplete_info.field_mask)

      older = encode(incomplete_values, field_mask)
      newer = encode(d,                 incomplete_info.field_mask)

      v, i_v, i_i = decode(older.deep_merge(newer), field_mask)

      if i_i.ids.size == 0
        r = values + v + i_v
      else
        # NOTE: Fallback to block.call with full field_mask
        d2 = block.call(i_i.ids, field_mask)
        write(values: d2, field_mask: field_mask)
        r = values + d2
      end

      Helper.sort(r, ids)
    end

    # @param [<Integer | String>] ids
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

    # @param [Proc] fm_parser
    # @return [Proc]
    def wrap(fm_parser)
      -> (fields) {
        n = fm_parser.call(fields)
        normalize!(n)
        n
      }
    end

    # @param [FieldMaskParser::Node] field_mask
    def normalize!(field_mask)
      if !field_mask.attrs.include?(:id)
        field_mask.attrs << :id
      end
      field_mask.assocs.each do |a|
        normalize!(a)
      end
    end

    def split(h)
      with_id    = {}
      with_no_id = {}

      h.each do |k, v|
        if v.fetch("id").nil?
          with_no_id[k] = v
        else
          with_id[k] = v
        end
      end

      return with_id, with_no_id
    end

    # @param [IncompleteInfo] incomplete_info
    # @param [<Integer>] with_no_id_list
    # @param [FieldMaskParser::Node] field_mask
    # @return [IncompleteInfo]
    def merge(incomplete_info, with_no_id_list, field_mask)
      if with_no_id_list.size == 0
        return incomplete_info
      end

      ids = incomplete_info.ids + with_no_id_list
      fields = Set.new(Helper.to_fields(incomplete_info.field_mask)) | Set.new(Helper.to_fields(field_mask))

      IncompleteInfo.new(ids: ids, field_mask: fm_parser.call(fields))
    end
  end
end
