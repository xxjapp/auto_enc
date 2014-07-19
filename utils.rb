#!/usr/bin/env ruby
# encoding: UTF-8
#
# - module Utils
#

require 'awesome_print'

module Utils
    def self.pm(obj, regexp)
        ap obj.methods.select { |m| m =~ regexp }
    end

    def self.pt(t)
        puts t
        puts t.encoding
        p t.bytes.to_a
    end

    def self.report_error(e, info = nil)
        $stderr.puts "Error during processing: #{$!} (#{e.class})"
        $stderr.puts "info = #{info}" if info
        $stderr.puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
    end
end

if __FILE__ == $0
    p self
    p self.class
    Utils.pm self, /to/i
    Utils.pt "窗口"
end
