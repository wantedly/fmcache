module FMCache
  class Decoder
    class ValueDecoder
      class Data
        def initialize(field_mask:)
          has_one_names  = field_mask.has_ones.map(&:name)
          has_many_names = field_mask.has_manies.map(&:name)

          @attr_names = Set.new(field_mask.attrs)
          @attrs      = {}
          @has_ones   = has_one_names.map { |n| [n, nil] }.to_h
          @has_manies = has_many_names.map { |n| [n, []] }.to_h
        end

        def push_attr(name:, item:)
          if !@attr_names.include?(name)
            raise "invalid data"
          end
          @attrs[name] = item
        end

        def push_has_one(name:, data:)
          if !@has_ones.has_key?(name)
            raise "invalid data"
          end
          @has_ones[name] = data
        end

        def push_has_many(name:, data:)
          if !@has_manies.has_key?(name)
            raise "inavlid data"
          end
          @has_manies[name] << data
        end

        def valid?
          @attr_names == Set.new(@attrs.keys)
        end

        def id
          raise "internal error!" if @attrs.size == 0
          @attrs.values[0].id
        end

        def p_id
          raise "internal error!" if @attrs.size == 0
          @attrs.values[0].p_id
        end

        def to_h
          r = { id: id }
          @attrs.each do |name, item|
            r[name] = item.value
          end
          @has_ones.each do |name, data|
            r[name] = data.to_h
          end
          @has_manies.each do |name, data_list|
            r[name] = data_list.map(&:to_h)
          end
          r
        end
      end
    end
  end
end
