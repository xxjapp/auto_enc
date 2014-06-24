#!/usr/bin/env ruby
# encoding: UTF-8
#
# convert file encoding to UTF-8
#

require 'digest'
require 'fileutils'
require 'open3'
require 'rchardet19'

# ----------------------------------------------------------------
# initialize

# ENCODINGS = ['UTF-8', 'GB2312', 'SHIFT_JIS', 'ISO-8859-1', 'ISO-8859-2', 'WINDOWS-1250', 'UTF-16LE', 'UTF-16BE']
ENCODINGS = ['UTF-8', 'GB2312', 'ISO-8859-2', 'ISO-8859-1', 'SHIFT_JIS', 'WINDOWS-1250', 'UTF-16LE', 'UTF-16BE']

# ----------------------------------------------------------------
# utils

# ----------------------------------------------------------------
# methods

def do_convert(files)
    @statistic = {}

    i = 0

    IO.foreach(files, encode: 'UTF-8') do |file|
        # break if i > 0

        file      = file.force_encoding('UTF-8').chomp
        file_orig = "#{file}.original~"

        # report file
        puts "★★★ %04d -- [ %s ]" % [i += 1, file]

        # backup to "xx.original~"
        if !File.exist?(file_orig)
            old_file_orig = "#{file}.original"

            if !File.exist?(old_file_orig)
                FileUtils.cp file, file_orig
            else
                FileUtils.cp old_file_orig, file_orig
            end
        end

        # convert file encoding
        convert_encoding(file_orig, file)

        puts
    end

    puts Hash[@statistic.sort_by{|k, v| v}.reverse]
end

def convert_encoding(file_orig, file)
    dir       = File.dirname(file)
    name      = File.basename(file)
    name_orig = "#{name}.original~"

    dir_res  = (dir  =~ %r{^[a-z0-9.\-+_ #~()':\\]+$}i)
    name_res = (name =~ %r{^[a-z0-9.\-+_ #~()']+$}i)

    if dir_res && name_res
        src = file_orig
        dst = file
        convert_encoding_of_file(src, dst)
    elsif !dir_res && name_res
        src = name_orig
        dst = name

        Dir.chdir dir
        convert_encoding_of_file(src, dst)
    else
        src = Digest::MD5.hexdigest(name_orig)
        dst = Digest::MD5.hexdigest(name)

        Dir.chdir dir
        FileUtils.cp name_orig, src
        convert_encoding_of_file(src, dst)

        loop do
            break if File.exist? dst
            puts "sleep 1"
            sleep 1
        end

        FileUtils.mv dst, name
        FileUtils.rm src
    end
end

def convert_encoding_of_file(src, dst)
    src_data = IO.binread(src)
    cd       = CharDet.detect(src_data)

    puts cd

    src_encoding0 = CharDet.detect(src_data).encoding.upcase

    if cd.confidence >= 0.6 && ENCODINGS.include?(src_encoding0)
        return if convert_encoding_of_file_with_encoding(src, dst, src_encoding0)
    end

    ENCODINGS.each do |src_encoding|
        next   if src_encoding == src_encoding0
        return if convert_encoding_of_file_with_encoding(src, dst, src_encoding)
    end

    raise "can not convert from #{src} to #{dst}"
end

def convert_encoding_of_file_with_encoding(src, dst, src_encoding)
    cmd = "iconv -f #{src_encoding} -t UTF-8 \"#{src}\" > \"#{dst}\""

    stdin, stdout, stderr = Open3.popen3(cmd)
    err = stderr.readlines

    if err.size > 0
        # puts cmd
        err.each { |line| puts line.chomp.encode('UTF-8') + " with '#{src_encoding}'" }
        return false
    end

    if !check_convert_ok(src, dst, src_encoding)
        return false
    end

    @statistic[src_encoding] = @statistic[src_encoding].to_i + 1
    return true
end

def check_convert_ok(src, dst, src_encoding)
    src_md5 = Digest::MD5.file(src).hexdigest
    dst_md5 = Digest::MD5.file(dst).hexdigest

    if src_md5 == dst_md5
        puts "0: src_encoding = #{src_encoding}"
        return true
    end

    src_data = []
    dst_data = []

    mode  = ['UTF-16LE', 'UTF-16BE'].include?(src_encoding) ? 'rb' : 'r'
    mode += ":#{src_encoding}:UTF-8"

    begin
        IO.foreach(src, mode: mode) do |line|
            src_data << line
        end
    rescue => e
        puts e
        return false
    end

    i = 0

    IO.foreach(dst, encode: 'UTF-8') do |line|
        i += 1

        line = line.force_encoding('UTF-8')

        if src_encoding == 'SHIFT_JIS'
            line.gsub!('¥', "\\")
            line.gsub!('‾', "~")
        end

        dst_data << line

        if line !~ %r[^[0-9a-z \t\[\]\| /(){}<>;.,~!#&%'"=+-_*]*$]i && !line.start_with?("\xEF\xBB\xBF")
            puts "    %04d: %s" % [i, line]
        end
    end

    if src_data.size != dst_data.size
        puts "-1: src_data.size(%d) != dst_data.size(%d)" % [src_data.size, dst_data.size]
        return false
    end

    0.upto(src_data.size - 1) do |i|
        if src_data[i].chomp != dst_data[i].chomp
            puts "-2: %d '%s' != '%s'" % [i + 1, src_data[i].chomp, dst_data[i].chomp]
            p src_data[i].bytes.to_a
            p dst_data[i].bytes.to_a
            return false
        end
    end

    if src_encoding == 'SHIFT_JIS'
        File.open(dst, "w+") do |f|
            f.puts(dst_data)
        end
    end

    puts "1: src_encoding = #{src_encoding}"
    return true
end

# ----------------------------------------------------------------
# main entry

def main(argv)
    argv.each do |arg|
        do_convert(arg)
    end
rescue => e
    puts "Error during processing: #{$!}"
    puts "Backtrace:\n\t#{e.backtrace.join("\n\t")}"
end

main(ARGV)
