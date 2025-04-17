# frozen_string_literal: true

require 'rails'
require_relative 'utils/rails_patch'

module Mongory
  # @see Utils::RailsPatch
  class Railtie < Rails::Railtie
    initializer 'mongory.patch_utils' do
      [Mongory::Utils, *Mongory::Utils.included_classes].each do |klass|
        klass.prepend(Mongory::Utils::RailsPatch)
      end
    end
  end
end
