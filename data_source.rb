#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class DataSource
#

require 'awesome_print'
require './enc_test'
require './simple_log'

class DataSource < Qt::Object
    LOG   = SimpleLog.new $stdout
    DEBUG = true

    signals 'collect_paths_finished()'
    signals 'test_one_finished()'
    signals 'pick_one_skipped()'

    def initialize(path, extensions)
        super(nil)

        @path       = path
        @extensions = extensions
        @queue      = Queue.new
        @skipped    = 0
        @selected   = 0
    end

    def start_test_encode()
        Thread.new do
            collect_paths()
            emit collect_paths_finished()
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
            return if @wasCancelled

            LOG.info path

            src    = IO.binread path
            result = EncTest.test(src)
            result[:path] = path

            push result
            emit test_one_finished()
        end

        push :end
    end

    def cancel
        @wasCancelled = true
        LOG.info 'wasCancelled'
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

        if is_ascii?(cd)
            @skipped += 1
            emit pick_one_skipped()
            return pick_enc_data()
        else
            @selected += 1
            return data
        end
    end

    def total
        @paths.size
    end

    def skipped
        @skipped
    end

    def selected
        @selected
    end

    def is_ascii?(cd)
        cd.encoding == 'ascii' && cd.confidence = 1.0
    end
end
