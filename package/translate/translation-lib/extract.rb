require 'find'
require 'time'
require 'pathname'
require_relative 'color'

PROJECT_ROOT = File.expand_path('../../', __dir__)
SOURCE_DIR   = File.join(PROJECT_ROOT, 'contents')
OUTPUT_FILE  = File.join(PROJECT_ROOT, 'translate', 'template.pot')

KEYWORDS = {
    'i18n'  => { args: 1 },
    'i18nc' => { args: 2 },
    'qsTr'  => { args: 1 }
}

EXTENSIONS   = ['.qml', '.js', '.cpp', '.h', '.c']
DESKTOP_KEYS = ['Name', 'GenericName', 'Comment', 'Keywords']

raw_entries = []

Color.echo "[extract] Scanning source files...", :cyan

Find.find(SOURCE_DIR) do |path|
    ext = File.extname(path)
    next unless EXTENSIONS.include?(ext)
    rel_path = Pathname(path).relative_path_from(Pathname(PROJECT_ROOT)).to_s
    file_key = File.basename(path)

    File.readlines(path, chomp: true).each_with_index do |line, index|
        KEYWORDS.each do |kw, meta|
            if line =~ /#{kw}\(\s*"((?:[^"\\]|\\.)*)"(?:\s*,\s*"((?:[^"\\]|\\.)*)")?[^)]*\)/
                    if meta[:args] == 1
                        msgid   = $1.encode('UTF-8')
                        #context = "#{kw}@#{file_key}:#{index + 1}"
                        context = nil
            elsif meta[:args] == 2
                context = $1.encode('UTF-8')
                msgid   = $2&.encode('UTF-8')
            end
            next unless msgid
            raw_entries << { msgid:, context:, file: rel_path, line: index + 1 }
        end
    end
end
end

Color.echo "[extract] Scanning .desktop files...", :cyan

Dir.glob("#{SOURCE_DIR}/**/*.desktop").each do |path|
    rel_path = Pathname(path).relative_path_from(Pathname(PROJECT_ROOT)).to_s
    File.readlines(path, chomp: true).each_with_index do |line, index|
        DESKTOP_KEYS.each do |key|
            if line =~ /^#{key}=(.+)$/
                    msgid   = $1.encode('UTF-8')
                context = "desktop@#{File.basename(path)}:#{index + 1}"
                raw_entries << { msgid:, context:, file: rel_path, line: index + 1 }
            end
        end
    end
end

Color.echo "[extract] Total raw entries: #{raw_entries.size}", :blue

deduped = {}
duplicates = []

raw_entries.each do |entry|
    id = entry[:msgid]
    next if id.nil? || id.empty?
    if deduped.key?(id)
        duplicates << id
    else
        deduped[id] = entry
    end
end

Color.echo "[extract] Unique msgid entries: #{deduped.size}", :blue
Color.echo "[extract] Removed duplicates: #{duplicates.uniq.size}", :dim
duplicates.uniq.each { |id| Color.echo "  - #{id}", :dim }

if deduped.empty?
    Color.echo "[extract] No translatable strings found. Nothing to extract.", :yellow
    exit 0
end

Color.echo "[extract] Writing #{OUTPUT_FILE}...", :cyan

File.open(OUTPUT_FILE, 'w:utf-8') do |f|
    f.puts <<~HEADER
    msgid ""
    msgstr ""
    "Project-Id-Version: Darwin Menu\\n"
    "Report-Msgid-Bugs-To: https://github.com/lasaczka\\n"
    "POT-Creation-Date: #{Time.now.strftime('%Y-%m-%d %H:%M%z')}\\n"
    "PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"
    "Last-Translator: FULL NAME <EMAIL@ADDRESS>\\n"
    "Language-Team: LANGUAGE <LL@li.org>\\n"
    "Language: \\n"
    "MIME-Version: 1.0\\n"
    "Content-Type: text/plain; charset=UTF-8\\n"
    "Content-Transfer-Encoding: 8bit\\n"
    HEADER
    f.puts

    deduped.each_value do |entry|
        f.puts "#: #{entry[:file]}:#{entry[:line]}"
        f.puts "#. Preserve numbered parameters like %1, %2" if entry[:msgid] =~ /%[0-9]/
        f.puts "msgctxt \"#{entry[:context].gsub(/["\\]/) { "\\#{_1}" }}\"" if entry[:context]
        f.puts "msgid \"#{entry[:msgid].gsub(/["\\]/) { "\\#{_1}" }}\""
        f.puts "msgstr \"\""
        f.puts
    end
end

Color.echo "[extract] Done. Saved to #{OUTPUT_FILE}", :green
