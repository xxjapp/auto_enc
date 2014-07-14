#!/usr/bin/env ruby
# encoding: UTF-8
#
# - class EncFolderDlg
#

class EncFolderDlg < Qt::Dialog
    TEXT_PATH   = 'Select path'
    TEXT_OK     = 'OK'
    TEXT_CANCEL = 'Cancel'

    slots 'on_clicked()'

    attr_accessor :path, :extensions

    def initialize(parent, path, extensions)
        super(parent)

        @path       = path
        @extensions = extensions

        setWindowTitle class_name
        init_ui

        resize 500, 0
    end

    def init_ui
        path_label  = Qt::Label.new 'Path'
        @path_edit  = Qt::LineEdit.new
        path_button = Qt::PushButton.new TEXT_PATH

        extensions_label = Qt::Label.new 'Extensions'
        @extensions_edit = Qt::LineEdit.new

        ok_button     = Qt::PushButton.new TEXT_OK
        cancel_button = Qt::PushButton.new TEXT_CANCEL

        ok_button.default = true

        grid = Qt::GridLayout.new self

        grid.addWidget path_label, 0, 0
        grid.addWidget @path_edit, 0, 1, 1, 2
        grid.addWidget path_button, 0, 3

        grid.addWidget extensions_label, 1, 0
        grid.addWidget @extensions_edit, 1, 1, 1, 2

        grid.addWidget ok_button, 2, 2
        grid.addWidget cancel_button, 2, 3

        grid.setColumnStretch 1, 1

        @path_edit.text = @path
        @path_edit.placeholderText = 'Select a folder'

        @extensions_edit.text = @extensions.join(' ')
        @extensions_edit.placeholderText= "Specify extensions seperated with ','"

        connect path_button,   SIGNAL('clicked()'), SLOT('on_clicked()')
        connect ok_button,     SIGNAL('clicked()'), SLOT('on_clicked()')
        connect cancel_button, SIGNAL('clicked()'), SLOT('on_clicked()')
    end

    def on_clicked()
        if sender.text == TEXT_PATH
            select_folder
        elsif sender.text == TEXT_OK
            @path       = @path_edit.text
            @extensions = @extensions_edit.text.strip.split(/\s+/)

            accept()
        elsif sender.text == TEXT_CANCEL
            reject()
        end
    end

    def select_folder
        dlg = Qt::FileDialog.new(self, "Select folder", @path)

        dlg.fileMode = Qt::FileDialog::Directory
        dlg.options  = Qt::FileDialog::ShowDirsOnly

        if dlg.exec == 1
            @path_edit.text = dlg.selectedFiles[0].force_encoding('UTF-8')
        end
    end
end
