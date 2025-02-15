describe APIToken, type: :model do
  let(:administrateur) { create(:administrateur) }

  describe '#generate' do
    let(:api_token_and_packed_token) { APIToken.generate(administrateur) }
    let(:api_token) { api_token_and_packed_token.first }
    let(:packed_token) { api_token_and_packed_token.second }

    before { api_token_and_packed_token }

    it 'with a full access token' do
      expect(api_token.administrateur).to eq(administrateur)
      expect(api_token.prefix).to eq(packed_token.slice(0, 5))
      expect(api_token.version).to eq(3)
      expect(api_token.write_access?).to eq(true)
      expect(api_token.procedure_ids).to eq([])
      expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
      expect(api_token.full_access?).to be_truthy
    end

    context 'updated read_only' do
      before { api_token.update(write_access: false) }

      it do
        expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: false, api_token_id: api_token.id)
      end
    end

    context 'with a new added procedure' do
      let(:procedure) { create(:procedure, administrateurs: [administrateur]) }

      before do
        procedure
        api_token.reload
      end

      it do
        expect(api_token.full_access?).to be_truthy
        expect(api_token.procedure_ids).to eq([procedure.id])
        expect(api_token.procedures).to eq([procedure])
        expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [procedure.id], write_access: true, api_token_id: api_token.id)
      end

      context 'and another procedure, but access only to the first one' do
        let(:other_procedure) { create(:procedure, administrateurs: [administrateur]) }

        before do
          other_procedure
          api_token.update(allowed_procedure_ids: [procedure.id])
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to match_array([procedure.id])
          expect(api_token.targetable_procedures).to eq([other_procedure])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [procedure.id], write_access: true, api_token_id: api_token.id)
        end

        context 'and then gain full access' do
          before do
            api_token.become_full_access!
            api_token.reload
          end

          it do
            expect(api_token.full_access?).to be(true)
            expect(api_token.procedure_ids).to match_array([procedure.id, other_procedure.id])
            expect(api_token.targetable_procedures).to eq([procedure, other_procedure])
          end
        end
      end

      context 'but acces to a wrong procedure_id' do
        let(:forbidden_procedure) { create(:procedure) }

        before do
          api_token.update(allowed_procedure_ids: [forbidden_procedure.id])
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to eq([])
          expect(api_token.targetable_procedures).to eq([procedure])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end

      context 'update with destroyed procedure_id' do
        let(:procedure) { create(:procedure, administrateurs: [administrateur]) }

        before do
          api_token.update(allowed_procedure_ids: [procedure.id])
          procedure.destroy
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to eq([])
          expect(api_token.targetable_procedures).to eq([])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end

      context 'update with detached procedure_id' do
        let(:procedure) { create(:procedure, administrateurs: [administrateur]) }
        let(:other_procedure) { create(:procedure, administrateurs: [administrateur]) }

        before do
          api_token.update(allowed_procedure_ids: [procedure.id])
          other_procedure
          administrateur.procedures.delete(procedure)
          api_token.reload
        end

        it do
          expect(api_token.full_access?).to be_falsey
          expect(api_token.procedure_ids).to eq([])
          expect(api_token.targetable_procedures).to eq([other_procedure])
          expect(api_token.context).to eq(administrateur_id: administrateur.id, procedure_ids: [], write_access: true, api_token_id: api_token.id)
        end
      end
    end
  end

  describe '#authenticate' do
    let(:api_token_and_packed_token) { APIToken.generate(administrateur) }
    let(:api_token) { api_token_and_packed_token.first }
    let(:packed_token) { api_token_and_packed_token.second }
    let(:bearer_token) { packed_token }

    subject { APIToken.authenticate(bearer_token) }

    context 'with the legit packed token' do
      it { is_expected.to eq(api_token) }
    end

    context 'with destroyed token' do
      before { api_token.destroy }

      it { is_expected.to be_nil }
    end

    context 'with destroyed administrateur' do
      before { api_token.administrateur.destroy }

      it { is_expected.to be_nil }
    end

    context "with a bearer token with the wrong plain_token" do
      let(:bearer_token) do
        APIToken::BearerToken.new(api_token.id, 'wrong').to_string
      end

      it { is_expected.to be_nil }
    end
  end
end
