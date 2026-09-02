require 'ffi'
require 'nokogiri'
require 'logger'
require 'liberic/version'
require 'liberic/boot'
require 'liberic/certificate'
require 'liberic/helpers'
require 'liberic/response'
require 'liberic/sdk'
require 'liberic/process'
require 'liberic/config'

module Liberic
  class << self
    def instance
      return @instance if @instance
      @instance = SDK::API.mt_instanz_erzeugen(ERIC_LIB_FOLDER, nil)
      raise InitializationError.new('EricMtInstanzErzeugen failed') if @instance.null?
      check_eric_version!
      @instance
    end
  end

  def config
    @config ||= Config.new
  end
end
