#!/usr/bin/env ruby
# encoding: UTF-8
#
# - module BomUtils
#

module BomUtils
    BOM_LIST = {
        UTF_8:    "\xEF\xBB\xBF".force_encoding('ASCII-8BIT'),
        UTF_16BE: "\xFE\xFF".force_encoding('ASCII-8BIT'),
        UTF_16LE: "\xFF\xFE".force_encoding('ASCII-8BIT'),
        UTF_32BE: "\x00\x00\xFE\xFF".force_encoding('ASCII-8BIT'),
        UTF_32LE: "\xFE\xFF\x00\x00".force_encoding('ASCII-8BIT'),
    }

    def self.detect(src)
        BOM_LIST.each do |bom, value|
            return bom if src.start_with?(value)
        end

        return nil
    end
end
