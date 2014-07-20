#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class CheckButton
#

require './simple_log'

class CheckButton < Qt::PushButton
    LOG  = SimpleLog.new $stdout
    FONT = Qt::Font.new "Microsoft YaHei-X", 12

    attr_accessor :path, :encoding

    def initialize(path, encoding, dst_samples)
        if encoding
            samples = dst_samples.collect { |l| " #{l} " }
            text = [" [#{encoding}] ", '', samples].join("\n")
        else
            text = ' SKIP THIS FILE '
        end

        super(text)

        if encoding
            self.styleSheet = 'background-color:#eacd76;Text-align:left'
        else
            self.styleSheet = 'background-color:#96ce54;'
        end

        self.font       = FONT
        self.path       = path
        self.encoding   = encoding
    end
end
