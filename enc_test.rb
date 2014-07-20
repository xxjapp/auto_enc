#!/usr/bin/env ruby
# encoding: UTF-8
#
# test encoding of source data
#

require 'awesome_print'
require 'rchardet19'
require 'timeout'
require './bom_utils'
require './simple_log'
require './utils'

module EncTest
    LOG = SimpleLog.new $stdout

    ENCODING_CANDIDATES = ['UTF-8', 'GB18030', 'WINDOWS-1250', 'ISO-8859-2', 'ISO-8859-1', 'SHIFT_JIS', 'UTF-16LE', 'UTF-16BE']
    TO_ENCODING         = 'UTF-8'
    UNREPORT_ERRORS     = [Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError, ArgumentError]
    MAX_SAMPLES         = 5
    DEBUG               = false

    def self.encode_all(src, info = nil)
        result = {}

        bom = BomUtils.detect(src)

        if bom
            result[:bom] = bom
            return result
        end

        encoding0 = nil

        begin
            Timeout::timeout(10) {
                cd = CharDet.detect(src)
                result[:cd] = cd

                if is_ascii?(cd)
                    return result
                end

                if cd.encoding
                    encoding0 = cd.encoding.upcase
                    encode_and_check(src, encoding0, result, info)
                end
            }
        rescue Timeout::Error => e
            Utils.report_error(e, info)
        end

        ENCODING_CANDIDATES.each do |encoding|
            next if encoding == encoding0
            encode_and_check(src, encoding, result, info)
        end

        # remove encoding which count of dst_samples is not correct
        result.reject! do |k, v|
            v.is_a?(Array) && v.size != result[:samples_count]
        end

        return result
    end

    def self.is_ascii?(cd)
        cd && cd.encoding == 'ascii' && cd.confidence = 1.0
    end

    def self.encode_and_check(src, encoding, result, info = nil)
        src.force_encoding(encoding)

        dst         = src.encode(TO_ENCODING)
        dst_samples = check_encode(encoding, src, dst)

        result[encoding]       = dst_samples
        result[:samples_count] = dst_samples.size if dst_samples.size > result[:samples_count].to_i
    rescue => e
        if DEBUG || !UNREPORT_ERRORS.include?(e.class)
            Utils.report_error(e, info)
        end
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
    path = __FILE__

    begin
        src    = IO.binread path
        result = EncTest.encode_all(src, path)
    rescue => e
        Utils.report_error(e, path)
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
        next if !v.is_a? Array

        encoding    = k
        dst_samples = v

        puts "X================ %s" % encoding
        puts dst_samples
        puts
    end
end
