#!/usr/bin/env ruby
# encoding: UTF-8
#
# test encoding of source data
#

require 'awesome_print'
require 'rchardet19'
require './utils'

ENCODING_CANDIDATES = ['UTF-8', 'GB2312', 'ISO-8859-2', 'ISO-8859-1', 'SHIFT_JIS', 'WINDOWS-1250', 'UTF-16LE', 'UTF-16BE']
TO_ENCODING         = 'UTF-8'
MAX_SAMPLES         = 5
DEBUG               = false

module EncTest
    def self.encode(src, encoding)
        return src.encode(TO_ENCODING, encoding)
    rescue => e
        return e
    end

    def self.encode_all(src, result)
        cd        = CharDet.detect(src)
        encoding0 = cd.encoding.upcase
        result[:cd] = cd

        yield encoding0, encode(src, encoding0)

        ENCODING_CANDIDATES.each do |encoding|
            next if encoding == encoding0
            yield encoding, encode(src, encoding)
        end
    end

    def self.check_encode(encoding, src, dst)
        res = []

        src_lines = src.lines.to_a
        dst_lines = dst.lines.to_a

        if src_lines.size != dst_lines.size
            res << false
            res << "-1: src_lines.size(%d) != dst_lines.size(%d)" % [src_lines.size, dst_lines.size]
            return res
        end

        dst_samples = []

        0.upto(src_lines.size - 1) do |i|
            src_line = src_lines[i].encode(TO_ENCODING, encoding).chomp
            dst_line = dst_lines[i].chomp

            if src_line != dst_line
                res << false
                res <<  "-2: %d '%s' != '%s'" % [i + 1, src_line, dst_line]
                res <<  src_lines[i].bytes.to_a
                res <<  dst_lines[i].bytes.to_a
                return res
            end

            if dst_samples.count < MAX_SAMPLES && (i < 1 || dst_line =~ /[^[:ascii:]]/i)
                dst_samples << "%04d: %s" % [i + 1, dst_line]
            end
        end

        res << true
        res << dst_samples
        return res
    rescue => e
        Utils.report_error e if DEBUG

        res << false
        res << e
        return res
    end

    def self.test(src)
        result = {}

        encode_all(src, result) do |encoding, dst|
            if dst.is_a? Exception
                next
            end

            src.force_encoding(encoding)
            result[encoding] = check_encode(encoding, src, dst)
        end

        return result
    end
end

# ----------------------------------------------------------------
# test

if __FILE__ == $0
    src = IO.binread 'C:\Users\XX9150\Desktop\downloads.txt'

    result = EncTest.test(src)
    ap result if DEBUG

    puts result[:cd]

    result.each do |k, v|
        next if k == :cd

        encoding    = k
        ok          = v[0]
        dst_samples = v[1]

        if ok
            puts "X================ %s" % encoding
            puts dst_samples
            puts
        end
    end
end
