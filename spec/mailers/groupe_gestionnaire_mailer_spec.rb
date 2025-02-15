RSpec.describe GroupeGestionnaireMailer, type: :mailer do
  describe '#notify_removed_gestionnaire' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:gestionnaire_to_remove) { create(:gestionnaire, email: 'int3@g') }

    let(:current_super_admin_email) { 'toto@email.com' }

    subject { described_class.notify_removed_gestionnaire(groupe_gestionnaire, gestionnaire_to_remove, current_super_admin_email) }

    it { expect(subject.body).to include('Vous venez d’être supprimé(e) du groupe') }
    it { expect(subject.to).to match_array(['int3@g']) }
  end

  describe '#notify_added_gestionnaires' do
    let(:groupe_gestionnaire) { create(:groupe_gestionnaire) }

    let(:gestionnaires_to_add) { [create(:gestionnaire, email: 'int3@g'), create(:gestionnaire, email: 'int4@g')] }

    let(:current_super_admin_email) { 'toto@email.com' }

    subject { described_class.notify_added_gestionnaires(groupe_gestionnaire, gestionnaires_to_add, current_super_admin_email) }

    before { gestionnaires_to_add.each { groupe_gestionnaire.add(_1) } }

    it { expect(subject.body).to include('Vous venez d’être nommé gestionnaire du groupe gestionnaire') }
    it { expect(subject.bcc).to match_array(['int3@g', 'int4@g']) }
  end
end
