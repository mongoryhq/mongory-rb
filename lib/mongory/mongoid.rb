# frozen_string_literal: true

# .
module Mongory
  # Only loaded when Mongoid is present
  module MongoidPatch
    # Regist Mongoid operator key object into KeyConverter
    # @see Converters::KeyConverter
    # @return [void]
    def self.patch!
      kc = Mongory::Converters::KeyConverter
      # It's Mongoid built-in key operator that born from `:key.gt`
      kc.register(::Mongoid::Criteria::Queryable::Key) do |v|
        kc.convert(@name.to_s, @operator => v)
      end
    end
  end

  MongoidPatch.patch!
end
