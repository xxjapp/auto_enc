#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class DataSource
#

require 'awesome_print'
require './enc_test'
require './simple_log'
require './utils'

class DataSource
    LOG   = SimpleLog.new $stdout
    DEBUG = true

    attr_accessor :keywords

    def initialize(path, extensions, keywords)
        @path       = path
        @extensions = extensions
        @keywords   = keywords
        @queue      = Queue.new

        @encoded    = Qt::AtomicInt.new
        @skipped    = Qt::AtomicInt.new
    end

    def start_test_encode()
        Thread.new do
            begin
                collect_paths()
                push :collect_paths_finished
                test_encode()
            rescue => e
                Utils.report_error e
            end
        end
    end

    def collect_paths()
        pattern = "#{File.expand_path(@path)}/**/*.{#{@extensions.join(',')}}"
        flag    = File::FNM_DOTMATCH

        @paths = Dir.glob(pattern, flag)
        # ap @paths if DEBUG
    end

    def test_encode()
        @paths.each do |path|
            return if @wasCanceled

            LOG.info path

            begin
                src    = IO.binread path
                result = EncTest.encode_all(src)
            rescue => e
                result = {error: e}
                Utils.report_error e
            end

            result[:path] = path
            push result
            @encoded.fetchAndAddRelaxed(1)
        end

        push :end
    end

    def cancel
        @wasCanceled = true
        LOG.info 'wasCanceled'
    end

    def push(data)
        LOG.info data if data.is_a? Symbol
        @queue.push data
    end

    def pick_enc_data()
        return :no_data if @queue.empty?

        data = @queue.pop
        return data if data.is_a? Symbol

        bom   = data[:bom]
        cd    = data[:cd]
        error = data[:error]

        if bom || error || EncTest.is_ascii?(cd) || include_user_keywords(data)
            @skipped.fetchAndAddRelaxed(1)
            return pick_enc_data()
        else
            return data
        end
    end

    def include_user_keywords(result)
        return false if !@keywords

        result.each do |k, v|
            next if !v.is_a? Array

            # TODO: save encoding
            encoding    = k
            dst_samples = v

            dst_samples.each { |sample|
                @keywords.each { |keyword|
                    return true if sample.include? keyword
                }
            }
        end

        return false
    end

    def total
        @paths.size
    end

    def encoded
        @encoded.fetchAndAddRelaxed(0)
    end

    def skipped
        @skipped.fetchAndAddRelaxed(0)
    end
end
