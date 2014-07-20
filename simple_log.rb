#!/usr/bin/env ruby
# encoding: UTF-8
#
# - module SimpleLog
#

require 'logger'

class SimpleLog < Logger
    def initialize(logdev, shift_age = 0, shift_size = 1048576)
        super(logdev, shift_age, shift_size)

        self.formatter = proc do |severity, datetime, progname, msg|
            file, line, method = caller[4].match(%r{([^/]+):(\d+):in `(.+)'}).captures
            "#{datetime.to_s[0..-7]} #{severity[0]} [Th-#{Thread.current.object_id}] (#{file}:#{line}) #{method} - #{msg}\n"
        end
    end
end

if __FILE__ == $0
    LOG = SimpleLog.new(STDOUT)

    def func
        LOG.info("info")
    end

    func
    LOG.fatal("fatal")
end
