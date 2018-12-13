module FMCache
  class Field
    class << self
      # @param [<Symbol>] prefix
      # @param [Symbol] attr
      # @return [String]
      def to_s(prefix:, attr:)
        l = prefix + [attr]
        l.join(".")
      end
    end
  end
end
