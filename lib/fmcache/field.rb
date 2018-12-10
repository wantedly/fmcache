module FMCache
  class Field
    class << self
      def to_s(prefix:, attr:)
        l = prefix + [attr]
        l.join(".")
      end
    end
  end
end
