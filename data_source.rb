#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class DataSource
#

require 'awesome_print'
require './enc_test'
require './simple_log'

class DataSource
    LOG   = SimpleLog.new $stdout
    DEBUG = true

    def initialize(path, extensions)
        @path       = path
        @extensions = extensions
        @queue      = Queue.new
    end

    def start_test_encode()
        Thread.new do
            collect_paths()
            test_encode()
        end
    end

    def collect_paths()
        pattern = "#{File.expand_path(@path)}/**/*.{#{@extensions.join(',')}}"
        flag    = File::FNM_DOTMATCH

        @paths = Dir.glob(pattern, flag)
        ap @paths if DEBUG
    end

    def test_encode()
        @paths.each do |path|
            LOG.info path

            src    = IO.binread path
            result = EncTest.test(src)
            result[:path] = path

            push result
        end

        push :end
    end

    def push(data)
        LOG.info data if data.is_a? Symbol
        @queue.push data
    end

    def pick_enc_data()
        return :no_data if @queue.empty?

        data = @queue.pop
        return data if data.is_a? Symbol

        cd = data[:cd]
        is_ascii?(cd) ? pick_enc_data() : data
    end

    def is_ascii?(cd)
        cd.encoding == 'ascii' && cd.confidence = 1.0
    end
end
