#!/usr/bin/env ruby
# encoding: UTF-8
#
# convert encoding of file
#

require './enc_test'

module EncConvert
    def self.convert(files)
        IO.foreach(files, mode: 'r:UTF-8') do |file|
            # file.chomp!
            file = "#{file.chomp}.original~"

            src = IO.binread file
            report_test file, EncTest.test(src)
        end
    end

    def self.report_test(file, result)
        cd = result[:cd]
        return if cd[:confidence] == 1.0

        puts file

        ap result if DEBUG
        puts cd
        puts

        result.each do |k, v|
            next if k == :cd

            encoding    = k
            ok          = v[0]
            dst_samples = v[1]

            if ok
                puts "    X---------------------------------------------------------------- %s" % encoding
                puts dst_samples.each.collect { |line| "    | %s" % line }
                puts "    +---------------------------------------------------------------- %s" % encoding
                puts
            end
        end
        # exit
    end
end

if __FILE__ == $0
    ARGV.each { |arg| EncConvert.convert arg }
end
