#!/usr/bin/env ruby
# encoding: UTF-8
#
# convert file encoding to UTF-8
#

require 'fileutils'
require 'digest'
require 'open3'

# ----------------------------------------------------------------
# initialize

# ----------------------------------------------------------------
# utils

# ----------------------------------------------------------------
# methods

def do_convert(files)
    i = 0

    IO.foreach(files, encode: 'UTF-8') do |file|
        file      = file.force_encoding('UTF-8').chomp
        file_orig = "#{file}.original~"

        # report file
        puts "%04d -- [ %s ]" % [i += 1, file]

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
    end
end

def convert_encoding(file_orig, file)
    @statistic = {}

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

    puts @statistic
end

def convert_encoding_of_file(src, dst)
    ['UTF-8', 'GB2312', 'SJIS', 'WINDOWS-1250', 'UTF-16', 'ISO-8859-1'].each do |src_encoding|
        cmd = "iconv -f #{src_encoding} -t UTF-8 \"#{src}\" > \"#{dst}\""

        stdin, stdout, stderr = Open3.popen3(cmd)
        err = stderr.readlines

        if err.size > 0
            # puts cmd
            err.each { |line| puts line.encode('UTF-8') }
        else
            @statistic[src_encoding] = @statistic[src_encoding].to_i + 1
            return if check_convert_ok(src, dst, src_encoding)
        end
    end

    raise "can not convert from #{src} to #{dst}"
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

    IO.foreach(src, encode: src_encoding) do |line|
        src_data << line.force_encoding(src_encoding).encode('UTF-8')
    end

    i = 0

    IO.foreach(dst, encode: 'UTF-8') do |line|
        i += 1

        line = line.force_encoding('UTF-8')
        line.gsub!('¥', "\\") if src_encoding == 'SJIS'
        dst_data << line

        if line !~ %r[^[0-9a-z]*$]i
            puts "%04d: %s" % [i, line]
        end
    end

    if src_data.size != dst_data.size
        puts "-1: src_data.size != dst_data.size"
        return false
    end

    0.upto(src_data.size - 1) do |i|
        if src_data[i] != dst_data[i]
            puts "-2: %d '%s' != '%s'" % [i + 1, src_data[i].chomp, dst_data[i].chomp]
            return false
        end
    end

    if src_encoding == 'SJIS'
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
