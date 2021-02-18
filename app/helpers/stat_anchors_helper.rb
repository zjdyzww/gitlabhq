# frozen_string_literal: true

module StatAnchorsHelper
  def stat_anchor_attrs(anchor)
    {}.tap do |attrs|
      attrs[:class] = %w(nav-link gl-display-flex gl-align-items-center) << extra_classes(anchor)
      attrs[:itemprop] = anchor.itemprop if anchor.itemprop
    end
  end

  private

  def button_attribute(anchor)
    "btn-#{anchor.class_modifier || 'dashed'}"
  end

  def extra_classes(anchor)
    if anchor.is_link
      'stat-link'
    else
      "gl-button btn #{button_attribute(anchor)}"
    end
  end
end
