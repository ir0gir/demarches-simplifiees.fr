module ReleaseNotesHelper
  def announce_category_badge(category)
    color_class = case category.to_sym
    when :administrateur
      'fr-background-flat--blue-france fr-text-inverted--blue-france'
    when :instructeur
      'fr-background-contrast--yellow-tournesol'
    when :expert
      'fr-background-contrast--purple-glycine'
    when :usager
      'fr-background-contrast--green-emeraude'
    when :api
      'fr-background-contrast--blue-ecume'
    end

    content_tag(:span, ReleaseNote.human_attribute_name("categories.#{category}"), class: "fr-badge #{color_class}")
  end

  def infer_default_announce_categories
    if administrateur_signed_in?
      ReleaseNote.default_categories_for_role(:administrateur, current_administrateur)
    elsif instructeur_signed_in?
      ReleaseNote.default_categories_for_role(:instructeur, current_instructeur)
    elsif expert_signed_in?
      ReleaseNote.default_categories_for_role(:expert, current_expert)
    else
      ReleaseNote.default_categories_for_role(:usager)
    end
  end

  def render_release_note_content(content)
    allowed_attributes.merge ["rel", "target"] # title already allowed

    content.body.fragment.source.css("a[href]").each do |link|
      uri = URI.parse(link['href'])

      link.set_attribute('rel', 'noreferrer noopener')
      link.set_attribute('target', '_blank')
      link.set_attribute('title', new_tab_suffix(uri.host))
    end

    content
  end
end
