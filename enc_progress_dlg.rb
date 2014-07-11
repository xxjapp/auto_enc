#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class EncProgressDlg
#

require './simple_log'
require './utils'

class EncProgressDlg < Qt::Dialog
    LOG = SimpleLog.new $stdout

    slots 'on_clicked()'

    def initialize (data_source, cancel_button_text = 'Cancel', parent = nil)
        super(parent)

        @data_source        = data_source
        @cancel_button_text = cancel_button_text

        self.windowModality = Qt::ApplicationModal

        setWindowTitle class_name
        init_ui
        center
    end

    def init_ui
        @label         = Qt::Label.new
        @progress_bar  = Qt::ProgressBar.new
        @cancel_button = Qt::PushButton.new @cancel_button_text

        @progress_bar.textVisible = false
        @progress_bar.range = 0..100

        grid = Qt::GridLayout.new self

        grid.addWidget @label, 0, 0, 1, 3
        grid.addWidget @progress_bar, 2, 0, 1, 3
        grid.addWidget @cancel_button, 4, 1

        grid.setRowStretch 1, 1
        grid.setRowStretch 3, 1

        grid.setColumnStretch 0, 1
        grid.setColumnStretch 2, 1

        connect @cancel_button, SIGNAL('clicked()'), SLOT('on_clicked()')
    end

    def on_clicked()
        @wasCanceled = true
    end

    def show
        super

        label_width = 0

        while data = @data_source.pick
            Qt::Application.processEvents

            next  if data == :no_data
            break if data == :end

            if @wasCanceled
                @data_source.cancel
                return false
            end

            @progress_bar.value = data[0] % 100

            @label.text = "#{data[0]}: #{data[1]}"
            @label.adjustSize

            if @label.width > label_width
                label_width = @label.width
                center
            end
        end

        @progress_bar.value = 100
        Qt::MessageBox.information self, "Information", "Collecting files completed."
        return true
    ensure
        close
    end

    def center(parent = nil)
        parent = Qt::DesktopWidget.new if !parent

        adjustSize

        x = (parent.width - width) / 2 + parent.x
        y = (parent.height - height) / 2 + parent.y

        move x, y
    end
end
