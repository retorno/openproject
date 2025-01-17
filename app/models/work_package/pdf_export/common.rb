#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module WorkPackage::PDFExport::Common
  include Redmine::I18n
  include ActionView::Helpers::TextHelper
  include ActionView::Helpers::NumberHelper
  include CustomFieldsHelper
  include OpenProject::TextFormatting

  private

  def get_pdf(_language)
    ::WorkPackage::PDFExport::View.new(current_language)
  end

  def field_value(work_package, attribute)
    value = work_package.send(attribute)

    case value
    when Date
      format_date value
    when Time
      format_time value
    else
      value.to_s
    end
  end

  def success(content)
    ::Exports::Result
      .new format: :pdf,
           title:,
           content:,
           mime_type: 'application/pdf'
  end

  def error(message)
    raise ::Exports::ExportError.new message
  end

  def with_margin(opts, &)
    with_vertical_margin(opts) do
      pdf.indent(opts[:margin_left] || 0, opts[:margin_right] || 0, &)
    end
  end

  def with_vertical_margin(opts)
    pdf.move_down(opts[:margin_top]) if opts.key?(:margin_top)
    yield
    pdf.move_down(opts[:margin_bottom]) if opts.key?(:margin_bottom)
  end

  def write_optional_page_break(threshold)
    space_from_bottom = pdf.y - pdf.bounds.bottom
    if space_from_bottom < threshold
      pdf.start_new_page
    end
  end

  def get_column_value(work_package, column)
    formatter = formatter_for(column)
    formatter.format(work_package)
  end

  def get_column_value_cell(work_package, column)
    value = escape_tags(get_column_value(work_package, column))
    return get_id_column_cell(work_package, value) if column == :id
    return get_subject_column_cell(work_package, value) if with_descriptions? && column == :subject

    value
  end

  def escape_tags(value)
    # only disable html tags, but do not replace html entities
    value.to_s.gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def get_id_column_cell(work_package, value)
    href = url_helpers.work_package_url(work_package)
    make_link_href_cell(href, value)
  end

  def get_subject_column_cell(work_package, value)
    make_link_anchor(work_package.id, value)
  end

  def make_link_href_cell(href, caption)
    "<color rgb='#{overview_table_link_color}'><link href='#{href}'>#{caption}</link></color>"
  end

  def make_link_anchor(anchor, caption)
    "<link anchor=\"#{anchor}\">#{caption}</link>"
  end

  def align_to_left_position(text, align, style)
    text_width = pdf.width_of(text, style)
    if align == :right
      pdf.bounds.right - text_width
    elsif align == :center
      (pdf.bounds.width - text_width) / 2
    else
      pdf.bounds.left
    end
  end

  def link_target_at_current_y(id)
    pdf_dest = pdf.dest_xyz(0, pdf.y)
    pdf.add_dest(id.to_s, pdf_dest)
  end

  def draw_repeating_text(text:, align:, top:, style:)
    left = align_to_left_position(text, align, style)
    opts = style.merge({ at: [left, top] })
    pdf.repeat :all do
      pdf.draw_text text, opts
    end
  end

  def draw_repeating_dynamic_text(align, top, style)
    pdf.repeat :all, dynamic: true do
      text = yield
      left = align_to_left_position(text, align, style)
      opts = style.merge({ at: [left, top] })
      pdf.draw_text text, opts
    end
  end

  def pdf_table_auto_widths(data, column_widths, options, &)
    pdf.table(data, options.merge({ width: pdf.bounds.width }), &)
  rescue Prawn::Errors::CannotFit
    pdf.table(data, options.merge({ column_widths: }), &)
  end

  def measure_text_width(text, opts)
    @pdf.save_font do
      @pdf.font(opts[:font], opts)
      @pdf.width_of(text, opts)
    end
  end

  def text_column?(column)
    column.is_a?(Queries::WorkPackages::Columns::CustomFieldColumn) &&
      %w(string text).include?(column.custom_field.field_format)
  end

  def url_helpers
    @url_helpers ||= OpenProject::StaticRouting::StaticUrlHelpers.new
  end

  def api_url_helpers
    API::V3::Utilities::PathHelper::ApiV3Path
  end

  def make_group_label(group)
    if group.blank?
      I18n.t(:label_none_parentheses)
    elsif group.is_a? Array
      group.join(', ')
    else
      group.to_s
    end
  end

  def with_descriptions?
    options[:show_descriptions]
  end

  def with_attachments?
    options[:show_attachments]
  end

  def current_page_nr
    pdf.page_number + @page_count
  end
end
