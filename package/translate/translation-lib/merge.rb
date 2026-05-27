require_relative 'color'

PROJECT_ROOT = File.expand_path('../../', __dir__)
PO_DIR       = File.join(PROJECT_ROOT, 'translate')
TEMPLATE     = File.join(PO_DIR, 'template.pot')
STATUS_FILE  = File.join(PO_DIR, 'Status.md')

def parse_entries(lines)
    entries = []
    entry = []
    lines.each do |line|
        if line.strip.empty?
            entries << entry unless entry.empty?
            entry = []
        else
            entry << line
        end
    end
    entries << entry unless entry.empty?
    entries
end

def extract_id(entry)
    line = entry.find { |l| l.start_with?('msgid') }
    return nil unless line
    line.sub(/^msgid\s*/, '').strip
end

def extract_msgstr(entry)
    line = entry.find { |l| l.start_with?('msgstr') }
    return nil unless line
    line.sub(/^msgstr\s*/, '').strip
end

def extract_msgctxt(entry)
    line = entry.find { |l| l.start_with?('msgctxt') }
    return nil unless line
    line.sub(/^msgctxt\s*/, '').strip
end

def has_translation?(entry)
    entry.any? { |l| l.start_with?('msgstr') && l !~ /^msgstr\s*""\s*$/ }
end

Color.echo "[merge] Updating .po files...", :cyan

unless File.exist?(TEMPLATE)
    Color.echo "[merge] Missing template.pot at #{TEMPLATE}", :red
    exit 1
end

template_lines   = File.readlines(TEMPLATE)
template_entries = parse_entries(template_lines)

# Slipts .pot header (msgid "")
pot_header  = template_entries.find  { |e| extract_id(e) == '""' }
pot_entries = template_entries.reject { |e| extract_id(e) == '""' }

Dir.glob("#{PO_DIR}/*.po").each do |po_path|
    Color.echo "[merge] Updating #{File.basename(po_path)}", :blue

    po_lines   = File.readlines(po_path)
    po_entries = parse_entries(po_lines)

    # Keep .po header
    po_header  = po_entries.find  { |e| extract_id(e) == '""' }
    po_entries = po_entries.reject { |e| extract_id(e) == '""' }

    # Build index of existing translations: msgid => entry. The key includes msgctxt to distinguish entries with context
    po_index = {}
    po_entries.each do |entry|
        id  = extract_id(entry)
        ctx = extract_msgctxt(entry)
        key = "#{ctx}|#{id}"
        po_index[key] = entry
    end

    # Rebuild the .po file using the .pot file as a base. For each entry in the .pot file, search for an existing translation in the .po file
    new_entries = pot_entries.map do |pot_entry|
        id  = extract_id(pot_entry)
        ctx = extract_msgctxt(pot_entry)
        key = "#{ctx}|#{id}"

        existing = po_index[key] || po_index.values.find { |e| extract_id(e) == id }

        if existing && has_translation?(existing)
            msgstr = existing.find { |l| l.start_with?('msgstr') }
            pot_entry.map { |l| l.start_with?('msgstr') ? msgstr : l }
        else
            pot_entry.map { |l| l.start_with?('msgstr') ? "msgstr \"\"\n" : l }
        end
    end

    new_ids     = pot_entries.map { |e| extract_id(e) } -
                  po_entries.map  { |e| extract_id(e) }
    Color.echo "  New entries: #{new_ids.size}", :cyan
    new_ids.each { |id| Color.echo "    + #{id}", :yellow }

    # If .po header doesn't exist, use .pot header instead
    header = po_header || pot_header

    parts  = []
    parts << header.join if header
    parts += new_entries.map { |e| e.join }
    merged = parts.join("\n\n") + "\n"

    File.write(po_path, merged)
end

Color.echo "[merge] Done merging messages", :green
Color.echo "[merge] Translation progress:", :cyan

template_count = pot_entries.count
rows = []
rows << "| Locale   | Lines   | % Done |"
rows << "|----------|---------|--------|"
rows << "| Template | #{template_count.to_s.rjust(7)} |        |"

Dir.glob("#{PO_DIR}/*.po").sort.each do |po_path|
    locale      = File.basename(po_path, '.po')
    po_lines    = File.readlines(po_path)
    po_entries  = parse_entries(po_lines).reject { |e| extract_id(e) == '""' }
    translated  = po_entries.count { |e| has_translation?(e) }
    percent     = template_count > 0 ? ((translated.to_f / template_count) * 100).round : 0
    line_str    = "#{translated}/#{template_count}"
    percent_str = "#{percent}%".rjust(6)
    Color.echo "  #{locale.ljust(8)} #{line_str.ljust(10)} #{percent_str}", :blue
    rows << "| #{locale.ljust(8)} | #{line_str.rjust(7)} | #{percent_str} |"
end

File.write(STATUS_FILE, rows.join("\n") + "\n")
Color.echo "[merge] Translation status written to Status.md", :green
