module FMCache
  class IncompleteInfo
    def initialize(ids:, field_mask:)
      @ids        = ids
      @field_mask = field_mask
    end

    attr_reader :ids, :field_mask

    def ==(other)
      @ids == other.ids &&
        @field_mask.to_h == other.field_mask.to_h
    end

    def eql?(other)
      self == other
    end

    def hash
      @ids.hash ^ @field_mask.hash
    end
  end
end
