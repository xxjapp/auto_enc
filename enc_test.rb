#!/usr/bin/env ruby
# encoding: UTF-8
#
# test encoding of source data
#

require 'awesome_print'
require 'rchardet19'
require './bom_utils'
require './simple_log'
require './utils'

module EncTest
    LOG = SimpleLog.new $stdout

    ENCODING_CANDIDATES = ['UTF-8', 'GB2312', 'ISO-8859-2', 'ISO-8859-1', 'SHIFT_JIS', 'WINDOWS-1250', 'UTF-16LE', 'UTF-16BE']
    TO_ENCODING         = 'UTF-8'
    MAX_SAMPLES         = 5
    DEBUG               = false

    def self.encode_all(src)
        result = {}

        bom = BomUtils.detect(src)

        if bom
            result[:bom] = bom
            return result
        end

        cd = CharDet.detect(src)
        result[:cd] = cd

        encoding0 = cd.encoding.upcase
        encode_and_check(src, encoding0, result)

        ENCODING_CANDIDATES.each do |encoding|
            next if encoding == encoding0
            encode_and_check(src, encoding, result)
        end

        return result
    end

    def self.encode_and_check(src, encoding, result)
        src.force_encoding(encoding)
        dst = src.encode(TO_ENCODING)
        result[encoding] = check_encode(encoding, src, dst)
    rescue => e
        Utils.report_error e
    end

    def self.check_encode(encoding, src, dst)
        src_lines = src.lines.to_a
        dst_lines = dst.lines.to_a

        if src_lines.size != dst_lines.size
            LOG.error "-1: src_lines.size(%d) != dst_lines.size(%d)" % [src_lines.size, dst_lines.size]
        end

        dst_samples = []

        0.upto(src_lines.size - 1) do |i|
            src_line = src_lines[i].encode(TO_ENCODING, encoding).chomp
            dst_line = dst_lines[i].chomp

            if src_line != dst_line
                LOG.error "-2: %d '%s' != '%s'" % [i + 1, src_line, dst_line]
                LOG.error src_lines[i].bytes.to_a
                LOG.error dst_lines[i].bytes.to_a
            end

            if dst_samples.count < MAX_SAMPLES && (i < 1 || dst_line =~ /[^[:ascii:]]/i)
                dst_samples << "%04d: %s" % [i + 1, dst_line]
            end
        end

        dst_samples
    end
end

# ----------------------------------------------------------------
# test

if __FILE__ == $0
    begin
        src    = IO.binread 'C:\RailsInstaller\DevKit\lib\perl5\5.8\unicore\NamesList.txt'
        result = EncTest.encode_all(src)
    rescue => e
        Utils.report_error e
        exit
    end

    ap result

    bom = result[:bom]

    if bom
        puts bom
        exit
    end

    puts result[:cd]

    result.each do |k, v|
        next if k == :cd

        encoding    = k
        dst_samples = v

        puts "X================ %s" % encoding
        puts dst_samples
        puts
    end
end
