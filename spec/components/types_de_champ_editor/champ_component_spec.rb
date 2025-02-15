describe TypesDeChampEditor::ChampComponent, type: :component do
  describe 'render' do
    let(:component) { described_class.new(coordinate:, upper_coordinates: []) }
    let(:routing_rules_stable_ids) { [] }

    before do
      Flipper.enable_actor(:engagement_juridique_type_de_champ, procedure)
      allow_any_instance_of(Procedure).to receive(:stable_ids_used_by_routing_rules).and_return(routing_rules_stable_ids)
      render_inline(component)
    end

    describe 'tdc dropdown' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :drop_down_list, libelle: 'Votre ville', options: ['Paris', 'Lyon', 'Marseille'] }]) }
      let(:tdc) { procedure.draft_revision.types_de_champ.first }
      let(:coordinate) { tdc.revision_type_de_champ }

      context 'drop down tdc not used for routing' do
        it do
          expect(page).not_to have_text(/utilisé pour\nle routage/)
          expect(page).not_to have_css("select[disabled=\"disabled\"]")
        end
      end

      context 'drop down tdc used for routing' do
        let(:routing_rules_stable_ids) { [tdc.stable_id] }

        it do
          expect(page).to have_css("select[disabled=\"disabled\"]")
          expect(page).to have_text(/utilisé pour\nle routage/)
        end
      end
    end

    describe 'tdc ej' do
      let(:procedure) { create(:procedure, types_de_champ_public: [{ type: :text }], types_de_champ_private: [{ type: :text }]) }

      context 'when coordinate public' do
        let(:coordinate) { procedure.draft_revision.revision_types_de_champ_public.first }

        it 'does not include Engagement Juridique' do
          expect(page).not_to have_css('option', text: "Engagement Juridique")
        end
      end

      context 'when coordinate private' do
        let(:coordinate) { procedure.draft_revision.revision_types_de_champ_private.first }

        it 'includes Engagement Juridique' do
          expect(page).to have_css('option', text: "Engagement Juridique")
        end
      end
    end
  end
end
