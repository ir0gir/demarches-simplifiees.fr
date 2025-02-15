module TagsSubstitutionConcern
  extend ActiveSupport::Concern

  include Rails.application.routes.url_helpers
  include ActionView::Helpers::UrlHelper

  module TagsParser
    include Parsby::Combinators
    extend self

    def parse(io)
      doc.parse io
    end

    def self.normalize(str)
      str
        .sub(/^[[:space:]]+/, '')
        .sub(/[[:space:]]+$/, '')
        .gsub(/[[:space:]]/, ' ')
        .gsub('&nbsp;', ' ')
    end

    define_combinator :doc do
      many(tag | text) < eof
    end

    define_combinator :text do
      join(many(any_char.that_fail(tag))).fmap do |str|
        { text: str.force_encoding('utf-8').encode }
      end
    end

    define_combinator :tag do
      between(tag_delimiter, tag_delimiter, tag_text).fmap do |tag|
        { tag: TagsParser.normalize(tag) }
      end
    end

    define_combinator :tag_delimiter do
      lit('--')
    end

    define_combinator :tag_text_first_char do
      any_char.that_fail(lit('-') | tag_delimiter | eol)
    end

    define_combinator :tag_text_char do
      any_char.that_fail(tag_delimiter | eol)
    end

    define_combinator :tag_text do
      join(single(tag_text_first_char) + many(tag_text_char)).fmap do |str|
        str.force_encoding('utf-8').encode.gsub(/[[:space:]]/, ' ')
      end
    end

    define_combinator :eol do
      lit("\r\n") | lit("\n")
    end
  end

  DOSSIER_TAGS = [
    {
      id: 'dossier_motivation',
      libelle: 'motivation',
      description: 'Motivation facultative associée à la décision finale d’acceptation, refus ou classement sans suite',
      target: :motivation,
      available_for_states: Dossier::TERMINE
    },
    {
      id: 'dossier_depose_at',
      libelle: 'date de dépôt',
      description: 'Date de dépôt du dossier par l’usager',
      lambda: -> (d) { format_date(d.depose_at) },
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'dossier_en_instruction_at',
      libelle: 'date de passage en instruction',
      description: '',
      lambda: -> (d) { format_date(d.en_instruction_at) },
      available_for_states: Dossier::INSTRUCTION_COMMENCEE
    },
    {
      id: 'dossier_processed_at',
      libelle: 'date de décision',
      description: 'Date de la décision d’acceptation, refus, ou classement sans suite',
      lambda: -> (d) { format_date(d.processed_at) },
      available_for_states: Dossier::TERMINE
    },
    {
      id: 'dossier_procedure_libelle',
      libelle: 'libellé démarche',
      description: '',
      lambda: -> (d) { d.procedure.libelle },
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'dossier_number',
      libelle: 'numéro du dossier',
      description: '',
      target: :id,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'dossier_service_name',
      libelle: 'nom du service',
      description: 'Le nom du service instructeur qui traite le dossier',
      lambda: -> (d) { d.procedure.organisation_name || '' },
      available_for_states: Dossier::SOUMIS
    }
  ]

  DOSSIER_TAGS_FOR_MAIL = [
    {
      id: 'dossier_url',
      libelle: 'lien dossier',
      description: '',
      lambda: -> (d) { external_link(dossier_url(d)) },
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'dossier_attestation_url',
      libelle: 'lien attestation',
      description: '',
      lambda: -> (d) { external_link(attestation_dossier_url(d)) },
      available_for_states: [Dossier.states.fetch(:accepte)]
    },
    {
      id: 'dossier_motivation_url',
      libelle: 'lien document justificatif',
      description: '',
      lambda: -> (d) {
        if d.justificatif_motivation.attached?
          external_link(url_for_justificatif_motivation(d), "Télécharger le document justificatif")
        else
          return "[l’instructeur n’a pas joint de document supplémentaire]"
        end
      },
      available_for_states: Dossier::TERMINE
    }
  ]

  INDIVIDUAL_TAGS = [
    {
      id: 'individual_gender',
      libelle: 'civilité',
      description: 'M., Mme',
      target: :gender,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'individual_first_name',
      libelle: 'nom',
      description: "nom de l'usager",
      target: :nom,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'individual_last_name',
      libelle: 'prénom',
      description: "prénom de l'usager",
      target: :prenom,
      available_for_states: Dossier::SOUMIS
    }
  ]

  ENTREPRISE_TAGS = [
    {
      id: 'entreprise_siren',
      libelle: 'SIREN',
      description: '',
      target: :siren,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'entreprise_numero_tva_intracommunautaire',
      libelle: 'numéro de TVA intracommunautaire',
      description: '',
      target: :numero_tva_intracommunautaire,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'entreprise_siret_siege_social',
      libelle: 'SIRET du siège social',
      description: '',
      target: :siret_siege_social,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'entreprise_raison_sociale',
      libelle: 'raison sociale',
      description: '',
      target: :raison_sociale,
      available_for_states: Dossier::SOUMIS
    },
    {
      id: 'entreprise_adresse',
      libelle: 'adresse',
      description: '',
      target: :inline_adresse,
      available_for_states: Dossier::SOUMIS
    }
  ]

  ROUTAGE_TAGS = [
    {
      id: 'dossier_groupe_instructeur',
      libelle: 'groupe instructeur',
      description: 'Le groupe instructeur en charge du dossier',
      lambda: -> (d) { d.groupe_instructeur&.label },
      available_for_states: Dossier::SOUMIS
    }
  ]

  SHARED_TAG_IDS = (DOSSIER_TAGS + DOSSIER_TAGS_FOR_MAIL + INDIVIDUAL_TAGS + ENTREPRISE_TAGS + ROUTAGE_TAGS).map { _1[:id] }

  def identity_tags
    if procedure.for_individual?
      INDIVIDUAL_TAGS
    else
      ENTREPRISE_TAGS
    end
  end

  def routage_tags
    if procedure.routing_enabled?
      ROUTAGE_TAGS
    else
      []
    end
  end

  def tags
    tags_for_dossier_state(identity_tags + dossier_tags + champ_public_tags + champ_private_tags + routage_tags)
  end

  def used_type_de_champ_tags(text)
    used_tags_and_libelle_for(text).filter_map do |(tag, libelle)|
      if tag.nil?
        [libelle]
      elsif !tag.in?(SHARED_TAG_IDS) && tag.start_with?('tdc')
        [libelle, tag.gsub(/^tdc/, '').to_i]
      end
    end
  end

  def used_tags_for(text)
    used_tags_and_libelle_for(text).map { _1.first.nil? ? _1.second : _1.first }
  end

  private

  def format_date(date)
    if date.present?
      date.strftime('%d/%m/%Y')
    else
      ''
    end
  end

  def external_link(url, title = nil)
    link_to(title || url, url, target: '_blank', rel: 'noopener')
  end

  def url_for_justificatif_motivation(dossier)
    if dossier.justificatif_motivation.attached?
      Rails.application.routes.url_helpers.url_for(dossier.justificatif_motivation)
    end
  end

  def dossier_tags
    # Overridden by MailTemplateConcern
    DOSSIER_TAGS
  end

  def tags_for_dossier_state(tags)
    # Implementation note: emails and attestation generations are generally
    # triggerred by changes to the dossier’s state. The email or attestation
    # is generated right after the dossier has reached its new state.
    #
    # DOSSIER_STATE should be equal to this new state.
    #
    # For instance, for an email that gets generated for the brouillon->en_construction
    # transition, DOSSIER_STATE should equal 'en_construction'.

    if !defined?(self.class::DOSSIER_STATE)
      raise NameError.new("The class #{self.class.name} includes TagsSubstitutionConcern, it should define the DOSSIER_STATE constant but it does not", :DOSSIER_STATE)
    end

    tags.filter { |tag| tag[:available_for_states].include?(self.class::DOSSIER_STATE) }
  end

  def champ_public_tags(dossier: nil)
    types_de_champ = (dossier || procedure.active_revision).types_de_champ_public.filter { !_1.condition? }
    types_de_champ_tags(types_de_champ, Dossier::SOUMIS)
  end

  def champ_private_tags(dossier: nil)
    types_de_champ = (dossier || procedure.active_revision).types_de_champ_private.filter { !_1.condition? }
    types_de_champ_tags(types_de_champ, Dossier::INSTRUCTION_COMMENCEE)
  end

  def types_de_champ_tags(types_de_champ, available_for_states)
    tags = types_de_champ.flat_map(&:tags_for_template)
    tags.each do |tag|
      tag[:available_for_states] = available_for_states
    end
    tags
  end

  def replace_tags(text, dossier)
    if text.nil?
      return ''
    end

    tokens = parse_tags(text)

    tags_and_datas = [
      [champ_public_tags(dossier: dossier), dossier.champs_public],
      [champ_private_tags(dossier: dossier), dossier.champs_private],
      [dossier_tags, dossier],
      [ROUTAGE_TAGS, dossier],
      [INDIVIDUAL_TAGS, dossier.individual],
      [ENTREPRISE_TAGS, dossier.etablissement&.entreprise]
    ].filter_map do |(tags, data)|
      data && [tags_for_dossier_state(tags).index_by { _1[:id] }, data]
    end

    tags_and_datas.reduce(tokens) do |tokens, (tags, data)|
      # Replace tags with their value
      tokens.map do |token|
        case token
        in { tag: _, id: id } if tags.key?(id)
          { text: replace_tag(tags.fetch(id), data) }
        in { tag: tag } if tags.key?(tag)
          { text: replace_tag(tags.fetch(tag), data) }
        else
          token
        end
      end
    end.map do |token|
      # Get tokens text representation
      case token
      in { tag: tag }
        "--#{tag}--"
      in { text: text }
        text
      end
    end.join('')
  end

  def replace_tag(tag, data)
    if tag.key?(:target)
      data.public_send(tag[:target])
    else
      instance_exec(data, &tag[:lambda])
    end
  end

  def procedure_types_de_champ_tags
    tags_for_dossier_state(types_de_champ_tags(procedure.types_de_champ_public_for_tags, Dossier::SOUMIS) +
      types_de_champ_tags(procedure.types_de_champ_private_for_tags, Dossier::INSTRUCTION_COMMENCEE) +
      identity_tags + dossier_tags + ROUTAGE_TAGS)
  end

  def parse_tags(text)
    tags = procedure_types_de_champ_tags.index_by { _1[:libelle] }

    # MD5 should be enough and it avoids long key
    tokens = Rails.cache.fetch(["parse_tags_v2", Digest::MD5.hexdigest(text)], expires_in: 1.day) { TagsParser.parse(text) }
    tokens.map do |token|
      case token
      in { tag: tag } if tags.key?(tag)
        { tag: tag, id: tags.fetch(tag).fetch(:id) }
      else
        token
      end
    end
  end

  def used_tags_and_libelle_for(text)
    parse_tags(text).filter_map do |token|
      case token
      in { tag: tag, id: id }
        [id, tag]
      in { tag: tag }
        [nil, tag]
      else
        nil
      end
    end
  end
end
