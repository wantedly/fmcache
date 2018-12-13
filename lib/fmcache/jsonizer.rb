require "fmcache/jsonizer/default_json_serializer"

module FMCache
  class Jsonizer
    # @param [#dump#load | nil] json_serializer
    def initialize(json_serializer)
      @json_serializer = json_serializer || DefaultJsonSerializer
    end

    # @param [{ String => { String => <Hash> } }] hash
    # @return [{ String => { String => String } }]
    def jsonize(hash)
      r = {}
      hash.each do |k, v|
        h = {}
        v.each do |kk, vv|
          h[kk] = @json_serializer.dump(vv)
        end
        r[k] = h
      end
      r
    end

    # @param [{ String => { String => String } }] hash
    # @return [{ String => { String => <Hash> } }]
    def dejsonize(hash)
      r = {}
      hash.each do |k, v|
        h = {}
        v.each do |kk, vv|
          if vv.nil?
            h[kk] = nil
          else
            begin
              h[kk] = @json_serializer.load(vv)
            rescue
              h[kk] = nil
            end
          end
        end
        r[k] = h
      end
      r
    end
  end
end
