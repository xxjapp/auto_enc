#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class EncApp
#

require 'Qt'

require './check_button'
require './data_source'
require './enc_folder_dlg'
require './simple_log'
require './utils'

class EncApp < Qt::MainWindow
    LOG = SimpleLog.new $stdout

    TITLE         = 'Enc App'
    SELECT_FOLDER = 'Select folder'
    FONT          = Qt::Font.new "Microsoft YaHei-X", 12

    slots 'on_triggered()'
    slots 'on_clicked()'

    slots 'on_collect_paths_finished()'
    slots 'on_test_one_finished()'
    slots 'on_pick_one_skipped()'

    def initialize
        super

        @icon       = Qt::Icon.new('red_24.png')
        # use File.dirname(File.expand_path(__FILE__))
        # "C:/"
        @path       = "C:/Users/XX9150/Desktop/old2"
        @extensions = %w[txt]

        self.windowTitle = TITLE
        self.windowIcon  = @icon

        init_ui

        resize 800, 400
        show
    end

    def init_ui
        init_toolbar
        init_statusbar

        # @widget1 & @grid1
        @widget1.close if @widget1
        @widget1 = Qt::Widget.new
        self.centralWidget = @widget1

        @widget1.font = FONT

        @grid1 = Qt::GridLayout.new @widget1

        @path_label       = Qt::Label.new
        @extensions_label = Qt::Label.new

        @grid1.addWidget @path_label, 0, 0
        @grid1.addWidget @extensions_label, 1, 0

        @grid1.setRowStretch 2, 1
    end

    def init_toolbar
        toolbar = addToolBar 'main toolbar'

        select_folder = toolbar.addAction @icon, SELECT_FOLDER
        connect select_folder, SIGNAL('triggered()'), SLOT('on_triggered()')
    end

    def init_statusbar
        statusBar.styleSheet = 'background-color:#f9e7ef;'

        @progress_encode = Qt::ProgressBar.new
        @progress_select = Qt::ProgressBar.new
        @label_total     = Qt::Label.new
        @label_skipped   = Qt::Label.new
        @label_selected  = Qt::Label.new

        @progress_encode.hide
        @progress_select.hide

        statusBar.addPermanentWidget @progress_encode, 1
        statusBar.addPermanentWidget @progress_select, 1
        statusBar.addPermanentWidget @label_total
        statusBar.addPermanentWidget @label_skipped
        statusBar.addPermanentWidget @label_selected
    end

    def on_triggered()
        if sender.text == SELECT_FOLDER
            select_folder
        end
    end

    def select_folder
        folder_dlg = EncFolderDlg.new(self, @path, @extensions)

        # hide first to open a modal dialog
        folder_dlg.hide

        if folder_dlg.exec == 1
            @path       = folder_dlg.path
            @extensions = folder_dlg.extensions.collect { |e| e.downcase }

            @path_label.text       = @path.force_encoding('UTF-8')
            @extensions_label.text = "[#{@extensions.join(', ')}]".force_encoding('UTF-8')

            start_process
        end
    end

    def start_process
        @data_source.cancel if @data_source
        @data_source = DataSource.new(@path, @extensions)

        connect @data_source, SIGNAL('collect_paths_finished()'),   SLOT('on_collect_paths_finished()')
        connect @data_source, SIGNAL('test_one_finished()'),        SLOT('on_test_one_finished()')
        connect @data_source, SIGNAL('pick_one_skipped()'),         SLOT('on_pick_one_skipped()')

        init_statusbar_on_start()
        @data_source.start_test_encode
        show_selection
    end

    def init_statusbar_on_start()
        @label_total.text    = " Total: 0 "
        @label_skipped.text  = " Skipped: 0 "
        @label_selected.text = " Selected: 0 "

        @progress_encode.show
        @progress_select.show

        @progress_encode.range = 0..0
        @progress_select.range = 0..0

        @progress_encode.value = 0
        @progress_select.value = 0
    end

    def on_collect_paths_finished()
        LOG.info __method__

        total = @data_source.total

        @label_total.text    = " Total: #{total} "

        @progress_encode.range = 0..total
        @progress_select.range = 0..total
    end

    def on_test_one_finished()
        LOG.info __method__

        @progress_encode.value += 1
    end

    def on_pick_one_skipped()
        LOG.info __method__

        skipped = @data_source.skipped
        @label_skipped.text = " Skipped: #{skipped} "

        @progress_select.value += 1
    end

    def on_clicked()
        LOG.info __method__

        selected = @data_source.selected
        @label_selected.text = " Selected: #{selected} "

        @progress_select.value += 1

        show_selection
    end

    def show_selection
        @widget2.enabled = false if @widget2

        while (result = @data_source.pick_enc_data) == :no_data
            Qt::Application.processEvents
        end

        @widget2.close if @widget2

        if result == :end
            LOG.info "end reached"
            return
        end

        @widget2 = Qt::Widget.new
        @grid1.addWidget @widget2, 2, 0

        @grid2 = Qt::GridLayout.new @widget2

        label_path = Qt::Label.new result[:path]
        label_cd   = Qt::Label.new result[:cd].to_s

        @grid2.addWidget label_path, 0, 0
        @grid2.addWidget label_cd, 1, 0

        @widget3 = Qt::Widget.new
        @widget3.styleSheet = 'background-color:#e9e7ef;'

        @grid2.addWidget @widget3, 2, 0
        @grid2.setRowStretch 2, 1

        @grid3 = Qt::GridLayout.new @widget3

        buttons = []
        max_width = 1

        result.each do |k, v|
            next if [:cd, :path].include? k

            encoding    = k
            ok          = v[0]
            dst_samples = v[1]

            if ok
                button = CheckButton.new(encoding, dst_samples)
                button.adjustSize
                max_width = [max_width, button.width].max
                buttons << button

                connect button, SIGNAL('clicked()'), SLOT('on_clicked()')
            end
        end

        total_width  = self.width
        column_count = calc_column_count(total_width, max_width)

        # LOG.info "total_width = #{total_width}"
        # LOG.info "max_width = #{max_width}"

        0.upto(buttons.size - 1) do |i|
            buttons[i].minimumWidth = max_width
            @grid3.addWidget buttons[i], i / column_count + 1, i % column_count
        end
    end

    WIDGET_MARGIN   = 9
    BUTTON_MARGIN   = 9
    BUTTON_INTERVAL = 6

    def calc_column_count(total_width, max_width)
        # 4 * WIDGET_MARGIN + 2 * BUTTON_MARGIN + N * max_width + (N - 1) * BUTTON_INTERVAL = total_width
        [1, (total_width - 4 * WIDGET_MARGIN - 2 * BUTTON_MARGIN + BUTTON_INTERVAL) / (max_width + BUTTON_INTERVAL)].max
    end
end

app = Qt::Application.new(ARGV)
EncApp.new
app.exec
