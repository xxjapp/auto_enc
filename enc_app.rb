#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class EncApp
#

require 'thread'
require 'Qt'

require './check_button'
require './data_source'
require './enc_folder_dlg'
require './simple_log'
require './utils'

class EncApp < Qt::MainWindow
    LOG = SimpleLog.new $stdout

    TITLE            = 'Enc App'
    SELECT_FOLDER    = 'Select folder'
    SPECIFY_KEYWORDS = 'Specify keywords'
    KEYWORD_FILE     = '.keywords'

    FONT = Qt::Font.new "Microsoft YaHei-X", 12

    slots 'on_triggered()'
    slots 'on_clicked()'
    slots 'on_timeout()'

    def initialize
        super

        @icon0 = Qt::Icon.new('red_24.png')
        @icon1 = Qt::Icon.new('green_24.png')

        @path       = File.dirname(File.expand_path(__FILE__))
        @extensions = %w[txt]
        @keywords   = read_keywords()

        self.windowTitle = TITLE
        self.windowIcon  = @icon0

        init_ui

        resize 800, 400
        show
    end

    def read_keywords()
        keywords = []

        begin
            IO.foreach(KEYWORD_FILE, encoding: 'UTF-8') do |line|
                line.chomp!
                keywords << line
            end
        rescue Errno::ENOENT
        end

        return keywords
    end

    def save_keywords(keywords)
        File.open(KEYWORD_FILE, 'w+') do |f|
            keywords.each { |keyword| f.puts(keyword) }
        end
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
        @keywords_edit    = Qt::TextEdit.new "[#{@keywords.join(' ')}]".force_encoding('UTF-8')

        @keywords_edit.readOnly = true

        @grid1.addWidget @path_label, 0, 0
        @grid1.addWidget @extensions_label, 1, 0
        @grid1.addWidget @keywords_edit, 2, 0

        @grid1.setRowStretch 4, 1
    end

    def init_toolbar
        toolbar = addToolBar 'main toolbar'

        select_folder = toolbar.addAction @icon0, SELECT_FOLDER
        connect select_folder, SIGNAL('triggered()'), SLOT('on_triggered()')

        specify_keywords = toolbar.addAction @icon1, SPECIFY_KEYWORDS
        connect specify_keywords, SIGNAL('triggered()'), SLOT('on_triggered()')
    end

    def init_statusbar
        statusBar.styleSheet = 'background-color:#f9e7ef;'

        @progress_encode     = Qt::ProgressBar.new
        @progress_select     = Qt::ProgressBar.new
        @label_total         = Qt::Label.new
        @label_auto_inferred = Qt::Label.new
        @label_selected      = Qt::Label.new
        @label_skipped       = Qt::Label.new

        @progress_encode.hide
        @progress_select.hide

        @progress_encode.toolTip     = "background encoding progress"
        @progress_select.toolTip     = "user selection plus auto-infer progress"
        @label_total.toolTip         = "total file count"
        @label_auto_inferred.toolTip = "auto-inferred file count including files with bom or pure ascii or including user key words"
        @label_selected.toolTip      = "user selected file count"
        @label_skipped.toolTip       = "user skipped file count"

        statusBar.addPermanentWidget @progress_encode, 1
        statusBar.addPermanentWidget @progress_select, 1
        statusBar.addPermanentWidget @label_total
        statusBar.addPermanentWidget @label_auto_inferred
        statusBar.addPermanentWidget @label_selected
        statusBar.addPermanentWidget @label_skipped
    end

    def on_triggered()
        if sender.text == SELECT_FOLDER
            select_folder
        elsif sender.text == SPECIFY_KEYWORDS
            specify_keywords
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
            @extensions_label.text = "[#{@extensions.join(' ')}]".force_encoding('UTF-8')

            start_process
        end
    end

    def specify_keywords
        input_dlg = Qt::InputDialog.new(self)

        input_dlg.windowTitle = "Keywords"
        input_dlg.labelText   = "Specify keywords"
        input_dlg.textValue   = @keywords.join(' ')

        if input_dlg.exec == 1
            keywords = input_dlg.textValue

            if keywords
                @keywords = keywords.force_encoding('UTF-8').split(/\s+/)
                @keywords_edit.text = "[#{@keywords.join(' ')}]".force_encoding('UTF-8')
                save_keywords(@keywords)

                @data_source.keywords = @keywords if @data_source
            end
        end
    end

    def start_process
        @data_source.cancel if @data_source
        @data_source = DataSource.new(@path, @extensions, @keywords)

        init_statusbar_on_start()
        @data_source.start_test_encode
        show_selection
        start_timer

        @selected = 0
        @skipped  = 0
    end

    def start_timer
        return if @timer

        @timer = Qt::Timer.new(self)
        @timer.start(16)

        connect @timer, SIGNAL('timeout()'), SLOT('on_timeout()')
    end

    def on_timeout()
        auto_inferred = @data_source.auto_inferred
        encoded       = @data_source.encoded

        @label_auto_inferred.text = " Auto: #{auto_inferred} "

        @progress_encode.value = encoded
        @progress_select.value = auto_inferred + @selected + @skipped
    end

    def init_statusbar_on_start()
        @label_total.text         = " Total: 0 "
        @label_auto_inferred.text = " Auto: 0 "
        @label_selected.text      = " Selected: 0 "
        @label_skipped.text       = " Skipped: 0 "

        @progress_encode.show
        @progress_select.show

        @progress_encode.range = 0..0
        @progress_select.range = 0..0

        @progress_encode.value = 0
        @progress_select.value = 0
    end

    def on_collect_paths_finished()
        total = @data_source.total

        @label_total.text    = " Total: #{total} "

        @progress_encode.range = 0..total
        @progress_select.range = 0..total
    end

    def on_clicked()
        if sender.encoding
            @selected += 1
            @label_selected.text = " Selected: #{@selected} "
            @data_source.save_encoding(sender.path, sender.encoding)
        else
            @skipped += 1
            @label_skipped.text = " Skipped: #{@skipped} "
        end

        show_selection
    end

    def process_events()
        while true
            result = @data_source.pick_enc_data

            case result
            when :collect_paths_finished
                on_collect_paths_finished()
            when :no_data
                Qt::Application.processEvents
            when :end
                break
            else
                break
            end
        end

        result
    end

    def show_selection
        @widget2.enabled = false if @widget2
        result = process_events()
        @widget2.close if @widget2

        if result == :end
            LOG.info "test end reached"
            report_test_end()
            return
        end

        @widget2 = Qt::Widget.new
        @grid1.addWidget @widget2, 4, 0

        @grid2 = Qt::GridLayout.new @widget2

        edit_path = Qt::LineEdit.new result[:path]
        label_cd  = Qt::Label.new result[:cd].to_s

        edit_path.readOnly = true

        @grid2.addWidget edit_path, 0, 0
        @grid2.addWidget label_cd, 1, 0

        @widget3 = Qt::Widget.new
        @widget3.styleSheet = 'background-color:#e9e7ef;'

        @grid2.addWidget @widget3, 2, 0
        @grid2.setRowStretch 2, 1

        @grid3 = Qt::GridLayout.new @widget3

        buttons    = []
        max_width  = 1
        max_height = 1

        result.each do |k, v|
            next if !v.is_a? Array

            encoding    = k
            dst_samples = v

            button, max_width, max_height = add_button(result[:path], encoding, dst_samples, max_width, max_height)
            buttons << button
        end

        button, max_width, max_height = add_button(result[:path], nil, nil, max_width, max_height)
        buttons << button

        total_width  = self.width
        column_count = calc_column_count(total_width, max_width)

        # LOG.info "total_width = #{total_width}"
        # LOG.info "max_width   = #{max_width}"
        # LOG.info "max_height  = #{max_height}"

        0.upto(buttons.size - 1) do |i|
            buttons[i].minimumWidth  = max_width
            buttons[i].minimumHeight = max_height
            @grid3.addWidget buttons[i], i / column_count + 1, i % column_count
        end
    end

    def add_button(path, encoding, dst_samples, max_width, max_height)
        button = CheckButton.new(path, encoding, dst_samples)
        button.adjustSize
        max_width  = [max_width, button.width].max
        max_height = [max_height, button.height].max
        connect button, SIGNAL('clicked()'), SLOT('on_clicked()')

        return [button, max_width, max_height]
    end

    WIDGET_MARGIN   = 9
    BUTTON_MARGIN   = 9
    BUTTON_INTERVAL = 6

    def calc_column_count(total_width, max_width)
        # 4 * WIDGET_MARGIN + 2 * BUTTON_MARGIN + N * max_width + (N - 1) * BUTTON_INTERVAL = total_width
        [1, (total_width - 4 * WIDGET_MARGIN - 2 * BUTTON_MARGIN + BUTTON_INTERVAL) / (max_width + BUTTON_INTERVAL)].max
    end

    def report_test_end()
        msgbox = Qt::MessageBox.new

        msgbox.icon            = Qt::MessageBox::Information
        msgbox.text            = "Encoding test completed."
        msgbox.informativeText = "Do you want to convert these files to '#{EncTest::TO_ENCODING}'?"

        msgbox.standardButtons = Qt::MessageBox::Ok | Qt::MessageBox::Cancel

        if msgbox.exec == Qt::MessageBox::Ok
            @progress_encode.value = 0
            @data_source.start_convert_encoding(@skipped)
        end
    end
end

app = Qt::Application.new(ARGV)
EncApp.new
app.exec
