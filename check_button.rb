#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class CheckButton
#

require './simple_log'

class CheckButton < Qt::PushButton
    LOG  = SimpleLog.new $stdout
    FONT = Qt::Font.new "Microsoft YaHei-X", 12

    attr_accessor :encoding

    def initialize(encoding, dst_samples)
        samples = dst_samples.collect { |l| " #{l} " }
        text = [" [#{encoding}] ", '', samples].join("\n")
        super(text)

        self.styleSheet = 'Text-align:left'
        self.font       = FONT
        self.encoding   = encoding
    end
end
