module Sections
  class TableSection
    def initialize(table_element, icon_translations: {})
      @table_element = table_element
      @icon_translations = icon_translations
    end

    def items
      @items ||= rows_cells_text.map { |cells_text| headers.zip(cells_text).to_h }
    end

    private

    attr_reader :table_element, :icon_translations

    def headers
      @headers ||= table_element.all('thead th').map(&:text)
    end

    def row_elements
      @row_elements ||= table_element.all('tbody tr')
    end

    def rows_cells_text
      row_elements.map { |row_element| row_element.all('td').map(&method(:cell_text)) }
    end

    def cell_text(cell_element)
      if icon_translations.present?
        icon = cell_element.first('.glyphicon')
        return icon_translation_for(icon) if icon
      end

      link = find_valid_link(cell_element)
      link ? "[#{link.text}](#{link[:href]})" : cell_element.text
    end

    def icon_translation_for(icon_element)
      icon_element['class'].split(' ').map {|klass|
        icon_translations[klass]
      }.compact.first
    end

    def find_valid_link(element)
      return unless element.has_css?('a')
      link = element.find('a')
      link[:href] == '#' ? nil : link
    end
  end
end
